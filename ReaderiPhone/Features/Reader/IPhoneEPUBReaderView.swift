import SwiftUI

struct IPhoneEPUBReaderView: View {
    @State private var store: IPhoneEPUBReaderStore
    @State private var loadError: String?
    @State private var isTOCVisible = false
    @State private var isAnnotationsVisible = false
    @State private var isSettingsVisible = false
    @State private var isSearchVisible = false
    @Environment(\.dismiss) private var dismiss

    init(openedBook: IPhoneOpenedBook, libraryRepository: LibraryRepositoryProtocol) {
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
        .animation(.easeInOut(duration: 0.2), value: store.isMenuVisible)
        .animation(.easeInOut(duration: 0.25), value: isTOCVisible)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await store.load()
            if let msg = store.errorMessage { loadError = msg }
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
            // Top bar — content sits within safe area; background bleeds behind Dynamic Island
            HStack {
                Button {
                    store.dismissMenu()
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
                    .lineLimit(1)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .top)
            )

            Spacer()

            // Bottom bar — background bleeds behind home indicator
            HStack {
                Spacer()

                Text("\(store.pageInChapter + 1) из \(store.totalInChapter)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    Button {
                        store.dismissMenu()
                        isAnnotationsVisible = true
                    } label: {
                        Label("Закладки и хайлайты", systemImage: "bookmark")
                    }
                    Button {
                        store.dismissMenu()
                        isSearchVisible = true
                    } label: {
                        Label("Поиск", systemImage: "magnifyingglass")
                    }
                    Divider()
                    Button {
                        store.dismissMenu()
                        isSettingsVisible = true
                    } label: {
                        Label("Настройки текста", systemImage: "textformat.size")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    // MARK: - Highlight picker

    private func highlightPickerOverlay(for sel: EPUBTextSelection) -> some View {
        GeometryReader { geo in
            let pickerHeight: CGFloat = 52
            let yPos = sel.rect.maxY + 8
            let clampedY = min(yPos, geo.size.height - pickerHeight - 20)

            IPhoneHighlightColorPicker(
                onPick: { color in
                    Task { await store.addHighlight(color: color) }
                },
                onDismiss: { store.dismissSelection() }
            )
            .position(x: geo.size.width / 2, y: clampedY + pickerHeight / 2)
        }
        .ignoresSafeArea()
    }

    private func editHighlightOverlay(for h: Highlight) -> some View {
        GeometryReader { geo in
            IPhoneHighlightColorPicker(
                onPick: { color in
                    Task { await store.updateHighlightColor(id: h.id, color: color) }
                },
                onDismiss: { store.dismissSelection() },
                activeColor: h.color,
                showDelete: true,
                onDelete: { Task { await store.deleteHighlight(id: h.id) } }
            )
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .ignoresSafeArea()
    }

    // MARK: - Note view popup

    private func noteViewOverlay(for note: TextNote) -> some View {
        GeometryReader { geo in
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
        .ignoresSafeArea()
        .onTapGesture { store.dismissNoteEditing() }
    }

    // MARK: - TOC drawer

    private var tocDrawer: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Dimming background
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation { isTOCVisible = false } }

                // Panel
                IPhoneTOCView(
                    store: store,
                    onSelect: { withAnimation { isTOCVisible = false } }
                )
                .frame(width: geo.size.width * 0.82)
                .background(Color(UIColor.systemBackground))
                .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }
}
