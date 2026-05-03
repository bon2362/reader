import SwiftUI
import UIKit

struct IPhoneEPUBReaderView: View {
    @State private var store: IPhoneEPUBReaderStore
    @State private var loadError: String?
    @State private var isTOCVisible = false
    @State private var isAnnotationsVisible = false
    @State private var isSettingsVisible = false
    @State private var isSearchVisible = false
    @State private var noteDraft: IPhoneTextNoteDraft?
    @State private var isPageEntryVisible = false
    @State private var pageEntryText = ""
    @State private var isActionTrayVisible = false
    @State private var isClosing = false
    @Environment(\.dismiss) private var dismiss
    private let onClose: (() -> Void)?

    init(
        openedBook: IPhoneOpenedBook,
        libraryRepository: LibraryRepositoryProtocol,
        onClose: (() -> Void)? = nil
    ) {
        self.onClose = onClose
        _store = State(initialValue: IPhoneEPUBReaderStore(
            book: openedBook.book,
            resolvedURL: openedBook.url,
            libraryRepository: libraryRepository,
            annotationRepository: openedBook.annotationRepository
        ))
    }

    var body: some View {
        ZStack {
            store.themeBackgroundColor
                .ignoresSafeArea()

            // MARK: Reading content
            IPhoneEPUBWebView(store: store)
                .ignoresSafeArea()

            if store.isLoading {
                Color(UIColor.systemBackground).ignoresSafeArea()
                ProgressView("Загрузка...")
            } else if let error = loadError {
                ContentUnavailableView(
                    "Не удалось открыть книгу",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                // MARK: Edge tap zones (always active, hidden)
                edgeTapZones

                // MARK: Menu overlay
                if store.isMenuVisible {
                    menuOverlay
                        .transition(.opacity)
                }

                if isActionTrayVisible {
                    actionTray
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
                }

                if store.hasLinkReturnPosition, !store.isMenuVisible, !isActionTrayVisible {
                    linkReturnButton
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomTrailing)))
                }

                // MARK: Annotation popups
                if let sel = store.pendingSelection {
                    highlightPickerOverlay(for: sel)
                } else if let h = store.highlightForEditingId() {
                    editHighlightOverlay(for: h)
                } else if let n = store.noteForEditingId() {
                    noteViewOverlay(for: n)
                }

                // MARK: TOC drawer
                if isTOCVisible {
                    tocDrawer
                        .transition(.move(edge: .leading))
                }
            }
        }
        .opacity(isClosing ? 0 : 1)
        .scaleEffect(isClosing ? 0.985 : 1)
        .offset(y: isClosing ? 8 : 0)
        .animation(.easeInOut(duration: 0.2), value: store.isMenuVisible)
        .animation(.easeInOut(duration: 0.16), value: isActionTrayVisible)
        .animation(.easeInOut(duration: 0.25), value: isTOCVisible)
        .animation(.easeInOut(duration: 0.18), value: isClosing)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: store.requestDismiss) { _, requested in
            if requested {
                requestCloseReader()
            }
        }
        .task {
            await store.load()
            if let msg = store.errorMessage { loadError = msg }
        }
        .onDisappear {
            store.cancelPageCalculation()
        }
        .sheet(isPresented: $isAnnotationsVisible) {
            IPhoneAnnotationsView(store: store)
        }
        .sheet(isPresented: $isSettingsVisible) {
            IPhoneReaderSettingsView(store: store)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $isSearchVisible) {
            IPhoneReaderSearchView(store: store)
        }
        .sheet(item: $noteDraft) { draft in
            IPhoneTextNoteEditorSheet(
                draft: draft,
                onCancel: { noteDraft = nil },
                onSave: { body in
                    Task {
                        await store.saveTextNote(body: body, draft: draft)
                        noteDraft = nil
                    }
                }
            )
            .presentationDetents([.medium])
        }
        .alert("Перейти на страницу", isPresented: $isPageEntryVisible) {
            TextField("Номер страницы", text: $pageEntryText)
                .keyboardType(.numberPad)
            Button("Отмена", role: .cancel) {}
            Button("Перейти") {
                submitGlobalPageEntry()
            }
        } message: {
            if let total = store.totalBookPages {
                Text("Введите номер от 1 до \(total)")
            } else {
                Text("Сквозная нумерация ещё рассчитывается.")
            }
        }
    }

    // MARK: - Edge tap zones (15% | 70% | 15%)

    private var edgeTapZones: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: geo.size.width * 0.15)
                    .contentShape(Rectangle())
                    .onTapGesture { store.goToPreviousPage() }

                Color.clear
                    .frame(maxWidth: .infinity)

                Color.clear
                    .frame(width: geo.size.width * 0.15)
                    .contentShape(Rectangle())
                    .onTapGesture { store.goToNextPage() }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Menu overlay

    private var menuOverlay: some View {
        VStack {
            HStack {
                Button {
                    store.dismissMenu()
                    isActionTrayVisible = false
                    isTOCVisible.toggle()
                } label: {
                    menuIcon("book.closed")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Оглавление")

                Spacer()

                Text(store.chapterTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Spacer()

                Button {
                    isActionTrayVisible = false
                    requestCloseReader()
                } label: {
                    menuIcon("xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Закрыть")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .safeAreaPadding(.top)

            Spacer()

            HStack {
                Spacer()

                Button {
                    isActionTrayVisible = false
                    pageEntryText = store.globalPage.map(String.init) ?? ""
                    isPageEntryVisible = true
                } label: {
                    Text(store.pageCounterText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(store.totalBookPages == nil)

                Spacer()

                Button {
                    isActionTrayVisible.toggle()
                } label: {
                    menuIcon("ellipsis")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Действия")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .safeAreaPadding(.bottom)
        }
    }

    private var actionTray: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    actionTrayButton("textformat", "Настройки") {
                        closeActionTrayAndMenu()
                        isSettingsVisible = true
                    }
                    actionTrayButton("magnifyingglass", "Поиск") {
                        closeActionTrayAndMenu()
                        isSearchVisible = true
                    }
                    actionTrayButton("square.and.pencil", "Заметка") {
                        closeActionTrayAndMenu()
                        Task { noteDraft = await store.preparePageNoteDraft() }
                    }
                    actionTrayButton("bookmark", "Закладки") {
                        closeActionTrayAndMenu()
                        isAnnotationsVisible = true
                    }
                }
                .padding(.trailing, 14)
                .padding(.bottom, 58)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture {
            isActionTrayVisible = false
        }
    }

    private var linkReturnButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    store.returnToPreviousLinkPosition()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(.thinMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Вернуться")
                .padding(.trailing, 14)
                .padding(.bottom, 58)
            }
        }
        .ignoresSafeArea()
    }

    private func actionTrayButton(
        _ systemImage: String,
        _ accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(.thinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func menuIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .background(.thinMaterial, in: Circle())
            .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .contentShape(Circle())
    }

    private func closeActionTrayAndMenu() {
        isActionTrayVisible = false
        store.dismissMenu()
    }

    private func submitGlobalPageEntry() {
        guard let total = store.totalBookPages,
              let page = Int(pageEntryText.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...total).contains(page) else { return }
        store.goToGlobalPage(page)
    }

    private func requestCloseReader() {
        guard !isClosing else { return }
        isActionTrayVisible = false
        isClosing = true
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            closeReader()
        }
    }

    private func closeReader() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    // MARK: - Highlight picker

    private func highlightPickerOverlay(for sel: EPUBTextSelection) -> some View {
        GeometryReader { geo in
            let pickerHeight: CGFloat = 52
            let gap: CGFloat = 10
            let safeTop = geo.safeAreaInsets.top + 8
            let safeBottom = geo.safeAreaInsets.bottom + 8
            let bottomY = sel.rect.maxY + gap
            let topY = sel.firstRect.minY - pickerHeight - gap
            let canFitBelow = bottomY + pickerHeight <= geo.size.height - safeBottom
            let canFitAbove = topY >= safeTop
            // Prefer above the selection so the color picker stays clear of lower drag handles.
            let unclampedY = canFitAbove ? topY : (canFitBelow ? bottomY : (geo.size.height - pickerHeight) / 2)
            let clampedY = min(max(safeTop, unclampedY), geo.size.height - pickerHeight - safeBottom)
            let editingHighlight = store.highlightForEditingId()

            pickerBackdrop {
                IPhoneHighlightColorPicker(
                    onPick: { color in
                        Task { await store.addHighlight(color: color) }
                    },
                    activeColor: editingHighlight?.color,
                    onDelete: {
                        guard let editingHighlight else { return }
                        Task { await store.deleteHighlight(id: editingHighlight.id) }
                    },
                    onCopy: {
                        copyToPasteboard(sel.text)
                        store.dismissSelection()
                    },
                    onNote: {
                        Task {
                            noteDraft = await store.prepareHighlightNoteDraft()
                        }
                    }
                )
                .position(x: geo.size.width / 2, y: clampedY + pickerHeight / 2)
            }
        }
        .ignoresSafeArea()
    }

    private func editHighlightOverlay(for h: Highlight) -> some View {
        GeometryReader { geo in
            pickerBackdrop {
                IPhoneHighlightColorPicker(
                    onPick: { color in
                        Task { await store.updateHighlightColor(id: h.id, color: color) }
                    },
                    activeColor: h.color,
                    onDelete: { Task { await store.deleteHighlight(id: h.id) } },
                    onCopy: {
                        copyToPasteboard(h.selectedText ?? "")
                        store.dismissSelection()
                    },
                    onNote: {
                        Task {
                            noteDraft = await store.prepareHighlightNoteDraft()
                        }
                    }
                )
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .ignoresSafeArea()
    }

    private func pickerBackdrop<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            content()
        }
    }

    private func copyToPasteboard(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UIPasteboard.general.string = trimmed
    }

    // MARK: - Note view popup

    private func noteViewOverlay(for note: TextNote) -> some View {
        GeometryReader { geo in
            ZStack {
                // Dimming backdrop — tap outside card to dismiss
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { store.dismissNoteEditing() }

                // Note card — buttons have full gesture priority
                VStack(alignment: .leading, spacing: 8) {
                    if let selected = note.selectedText, !selected.isEmpty {
                        Text(selected)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Text(note.body)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            Task { await store.deleteTextNote(id: note.id) }
                        } label: {
                            Label("Удалить", systemImage: "trash")
                                .font(.caption.weight(.medium))
                        }
                        Button { store.dismissNoteEditing() } label: {
                            Image(systemName: "xmark")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: geo.size.width * 0.85)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(radius: 10, y: 4)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - TOC drawer

    private var tocDrawer: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Dimming background
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { isTOCVisible = false }

                // Panel
                IPhoneTOCView(
                    store: store,
                    onSelect: { isTOCVisible = false }
                )
                .frame(width: geo.size.width * 0.82)
                .background(Color(UIColor.systemBackground))
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }
}

private struct IPhoneTextNoteEditorSheet: View {
    let draft: IPhoneTextNoteDraft
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var bodyText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if let selected = draft.selectedText, !selected.isEmpty {
                    Text(selected)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }

                TextEditor(text: $bodyText)
                    .focused($isFocused)
                    .font(.body)
                    .frame(minHeight: 180)
                    .padding(6)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.18), lineWidth: 1))
            }
            .padding(16)
            .navigationTitle(draft.kind == .highlight ? "Заметка к хайлайту" : "Заметка к странице")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { onSave(trimmedBody) }
                        .disabled(trimmedBody.isEmpty)
                }
            }
            .onAppear { isFocused = true }
        }
    }

    private var trimmedBody: String {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
