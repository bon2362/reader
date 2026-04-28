import SwiftUI

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
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.2), value: store.isMenuVisible)
        .animation(.easeInOut(duration: 0.16), value: isActionTrayVisible)
        .animation(.easeInOut(duration: 0.25), value: isTOCVisible)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: store.requestDismiss) { _, requested in
            if requested {
                closeReader()
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
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Text(store.chapterTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Spacer()

                Button {
                    isActionTrayVisible = false
                    closeReader()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.primary)
                }
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
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.primary)
                }
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
                VStack(spacing: 4) {
                    actionTrayButton("textformat.size", "Настройки") {
                        closeActionTrayAndMenu()
                        isSettingsVisible = true
                    }
                    actionTrayButton("magnifyingglass", "Поиск") {
                        closeActionTrayAndMenu()
                        isSearchVisible = true
                    }
                    actionTrayButton("note.text.badge.plus", "Заметка") {
                        closeActionTrayAndMenu()
                        Task { noteDraft = await store.preparePageNoteDraft() }
                    }
                    actionTrayButton("bookmark", "Закладки") {
                        closeActionTrayAndMenu()
                        isAnnotationsVisible = true
                    }
                }
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(radius: 10, y: 3)
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

    private func actionTrayButton(
        _ systemImage: String,
        _ accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 42, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
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
            let bottomY = sel.rect.maxY + gap
            let topY = sel.rect.minY - pickerHeight - gap
            let canFitBelow = bottomY + pickerHeight <= geo.size.height - 20
            let unclampedY = canFitBelow ? bottomY : topY
            let clampedY = min(max(20, unclampedY), geo.size.height - pickerHeight - 20)
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
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { store.dismissSelection() }

            content()
        }
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
