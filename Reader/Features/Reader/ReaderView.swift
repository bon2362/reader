import SwiftUI

struct ReaderView: View {
    @Bindable var store: ReaderStore
    let book: Book
    let resolvedURL: URL
    let onClose: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            readerPane

            HStack(spacing: 0) {
                if store.tocStore.isVisible {
                    TOCView(
                        store: store.tocStore,
                        onSelect: { entry in store.navigateToTOCEntry(entry) },
                        onClose: { store.tocStore.toggleVisibility() }
                    )
                    .frame(width: 260)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .leading).combined(with: .opacity))

                    Divider()
                }

                Spacer(minLength: 0)

                if store.searchStore.isVisible {
                    Divider()
                    SearchView(
                        store: store.searchStore,
                        onSelect: { _ in },
                        onClose: { store.searchStore.hide() }
                    )
                    .frame(width: 300)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }

                if store.annotationPanelStore.isVisible {
                    Divider()
                    AnnotationPanelView(
                        store: store.annotationPanelStore,
                        onSelect: { item in
                            store.navigateToAnnotation(item)
                            store.annotationPanelStore.hide()
                        },
                        onClose: { store.annotationPanelStore.hide() }
                    )
                    .frame(width: 320)
                    .background(.ultraThinMaterial)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .allowsHitTesting(store.tocStore.isVisible || store.searchStore.isVisible || store.annotationPanelStore.isVisible)
        }
        .animation(.easeInOut(duration: 0.2), value: store.tocStore.isVisible)
        .animation(.easeInOut(duration: 0.2), value: store.searchStore.isVisible)
        .animation(.easeInOut(duration: 0.2), value: store.annotationPanelStore.isVisible)
        .background(
            ZStack {
                Button("") { store.searchStore.toggleVisibility() }
                    .keyboardShortcut("f", modifiers: .command)
                Button("") { store.addStickyNoteForCurrentPage() }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            .opacity(0)
        )
    }

    private var readerPane: some View {
        VStack(spacing: 0) {
            ChapterHeaderBar(chapterTitle: store.tocStore.currentEntry?.label)

            GeometryReader { geo in
                ZStack {
                    NativeEPUBWebView { bridge in
                        store.bindBridge(bridge)
                        store.openBook(book, resolvedURL: resolvedURL)
                    }
                    .ignoresSafeArea(edges: [.bottom, .leading, .trailing])

                    HStack(spacing: 0) {
                        EdgeClickArea(onTap: { store.prevPage() })
                            .frame(width: 80)
                        Spacer()
                        EdgeClickArea(onTap: { store.nextPage() })
                            .frame(width: 80)
                    }

                    StickyNotesOverlayView(
                        notes: store.stickyNotesStore.notesForPage(
                            spineIndex: store.currentSpineIndex,
                            pageInChapter: store.currentPageInChapter
                        ),
                        expandedId: store.stickyNotesStore.expandedId,
                        onToggle: { id in store.stickyNotesStore.toggleExpand(id: id) },
                        onUpdate: { id, body in Task { await store.stickyNotesStore.updateBody(id: id, body: body) } },
                        onDelete: { id in Task { await store.stickyNotesStore.delete(id: id) } }
                    )

                    MarginOverlayView(
                        positions: store.textNotesStore.visiblePositions,
                        notes: store.textNotesStore.notes,
                        expandedId: store.textNotesStore.expandedNoteId,
                        onToggle: { id in store.textNotesStore.toggleExpand(id: id) },
                        onEdit: { id in store.textNotesStore.beginEdit(noteId: id) },
                        onDelete: { id in Task { await store.textNotesStore.deleteNote(id: id) } }
                    )
                    .allowsHitTesting(true)

                    TextNotePopoverOverlay(
                        tappedId: store.textNotesStore.tappedNoteId,
                        point: store.textNotesStore.tappedNotePoint,
                        notes: store.textNotesStore.notes,
                        onEdit: { id in store.textNotesStore.beginEdit(noteId: id) },
                        onDelete: { id in Task { await store.textNotesStore.deleteNote(id: id) } },
                        onDismiss: { store.textNotesStore.dismissTappedNote() }
                    )

                    // Floating icon controls — top corners.
                    VStack {
                        HStack(alignment: .top) {
                            leftControls
                            Spacer()
                            rightControls
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        Spacer()
                    }

                    // Selection highlight picker — positioned near the selection rect.
                    if let selection = store.highlightsStore.pendingSelection {
                        let anchor = pickerPosition(for: selection.rect, in: geo.size)
                        HighlightColorPicker(
                            onPick: { color in
                                Task { await store.highlightsStore.applyColor(color) }
                            },
                            onNote: {
                                store.textNotesStore.beginNote(for: selection)
                                store.highlightsStore.cancelPendingSelection()
                            }
                        )
                        .position(anchor)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else if let active = store.highlightsStore.activeHighlight {
                        VStack {
                            Spacer()
                            HighlightColorPicker(
                                onPick: { color in
                                    Task { await store.highlightsStore.changeActiveColor(color) }
                                },
                                onDismiss: { store.highlightsStore.dismissActiveHighlight() },
                                activeColor: active.color,
                                showDelete: true,
                                onDelete: {
                                    Task { await store.highlightsStore.deleteActive() }
                                }
                            )
                            .padding(.bottom, 56)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }

                    // Page indicator — permanent, bottom center.
                    VStack {
                        Spacer()
                        PageIndicator(
                            currentPage: store.currentPage,
                            totalPages: store.totalPages,
                            isReady: store.isPageCountReady
                        )
                        .padding(.bottom, 14)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: store.highlightsStore.pendingSelection)
                .animation(.easeInOut(duration: 0.15), value: store.highlightsStore.activeHighlightId)
            }
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear { isFocused = true }
        .onKeyPress(.leftArrow) {
            store.prevPage()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            store.nextPage()
            return .handled
        }
        .onKeyPress(.space) {
            store.nextPage()
            return .handled
        }
        .sheet(isPresented: Binding(
            get: { store.textNotesStore.isEditorPresented },
            set: { if !$0 { store.textNotesStore.cancelEditor() } }
        )) {
            NoteEditorView(
                selectedText: store.textNotesStore.draftSelection?.text,
                initialBody: store.textNotesStore.draftEditingNote?.body ?? "",
                onSave: { body in
                    if store.textNotesStore.draftEditingNote != nil {
                        Task { await store.textNotesStore.updateNote(body: body) }
                    } else {
                        Task { await store.textNotesStore.addNote(body: body) }
                    }
                },
                onCancel: { store.textNotesStore.cancelEditor() }
            )
        }
        .alert(
            "Ошибка",
            isPresented: .init(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // MARK: - Floating controls

    @ViewBuilder
    private var leftControls: some View {
        HStack(spacing: 8) {
            FloatingIconButton(systemName: "chevron.left", help: "Вернуться в библиотеку", action: onClose)
            FloatingIconButton(systemName: "list.bullet", help: "Оглавление") {
                store.tocStore.toggleVisibility()
            }
            if store.canGoBackFromLink {
                FloatingIconButton(systemName: "arrow.uturn.backward", help: "Вернуться к месту, откуда вы перешли") {
                    store.goBackFromLink()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: store.canGoBackFromLink)
    }

    @ViewBuilder
    private var rightControls: some View {
        HStack(spacing: 8) {
            FloatingIconButton(systemName: "magnifyingglass", help: "Поиск (⌘F)") {
                store.searchStore.toggleVisibility()
            }
            FloatingIconButton(systemName: "bookmark", help: "Аннотации") {
                store.annotationPanelStore.toggleVisibility()
            }
            FloatingIconButton(systemName: "note.text.badge.plus", help: "Sticky-заметка (⌘⇧N)") {
                store.addStickyNoteForCurrentPage()
            }
        }
    }

    // MARK: - Picker positioning

    /// Compute picker center position in the reader ZStack coords, given the
    /// selection bounding rect reported by JS (in webview viewport coords).
    /// JS rects are in CSS pixels ≈ SwiftUI points on macOS.
    private func pickerPosition(for rect: CGRect?, in size: CGSize) -> CGPoint {
        let pickerWidth: CGFloat = 220
        let pickerHalf = pickerWidth / 2
        let margin: CGFloat = 8

        guard let rect else {
            return CGPoint(x: size.width / 2, y: size.height - 80)
        }

        var x = rect.midX
        // Clamp horizontally so the pill doesn't spill off edges
        x = max(pickerHalf + margin, min(size.width - pickerHalf - margin, x))

        // Prefer below the selection; fallback above if it would clip.
        let below = rect.maxY + 24
        let above = rect.minY - 24
        let y: CGFloat
        if below + 30 < size.height - margin {
            y = below
        } else if above - 30 > margin {
            y = above
        } else {
            y = min(size.height - 40, max(40, rect.midY))
        }
        return CGPoint(x: x, y: y)
    }
}

private struct EdgeClickArea: View {
    let onTap: () -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { onTap() }
    }
}
