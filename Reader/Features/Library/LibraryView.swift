import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct LibraryView: View {
    @Bindable var store: LibraryStore
    let onOpenBook: (Book, URL) -> Void
    let onOpenTest: (Book, URL) -> Void

    @State private var activeImporter: ActiveImporter?
    @State private var pendingDeletionBook: Book?
    @State private var securityScopedAnnotationImportURLs: [URL] = []

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                AddBookCardView {
                    activeImporter = .book
                }

                ForEach(store.books) { book in
                    BookCardView(
                        book: book,
                        isSelected: store.selectedBookID == book.id,
                        onSelect: { store.selectBook(id: book.id) },
                        onOpen: {
                            store.selectBook(id: book.id)
                            openBook(book)
                        },
                        onOpenTest: { openBookTest(book) },
                        onDelete: { requestDeletion(of: book) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            store.clearSelection()
        }
        .navigationTitle("Библиотека")
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button(action: startAnnotationImportFlow) {
                    Label(
                        "Импортировать аннотации",
                        systemImage: store.isImportingAnnotations ? "arrow.down.circle.fill" : "square.and.arrow.down"
                    )
                }
                .disabled(store.isImportingAnnotations || store.isExportingAnnotations)
                .help(store.isImportingAnnotations ? "Импорт аннотаций..." : "Импортировать аннотации из Markdown")
            }
            ToolbarItem(placement: .secondaryAction) {
                Button(action: chooseExportDirectoryAndStart) {
                    Label("Экспортировать всё", systemImage: store.isExportingAnnotations ? "arrow.up.circle.fill" : "square.and.arrow.up")
                }
                .disabled(store.isExportingAnnotations || store.isImportingAnnotations)
                .help(store.isExportingAnnotations ? "Экспорт всех заметок..." : "Экспортировать заметки всех книг")
            }
        }
        .onDeleteCommand(perform: requestDeletionOfSelectedBook)
        .fileImporter(
            isPresented: Binding(
                get: { activeImporter != nil },
                set: { _ in }
            ),
            allowedContentTypes: importerAllowedContentTypes,
            allowsMultipleSelection: importerAllowsMultipleSelection
        ) { result in
            handleImporterResult(result)
        }
        .confirmationDialog(
            "Удалить книгу?",
            isPresented: .init(
                get: { pendingDeletionBook != nil },
                set: { if !$0 { pendingDeletionBook = nil } }
            ),
            presenting: pendingDeletionBook
        ) { book in
            Button("Удалить", role: .destructive) {
                pendingDeletionBook = nil
                Task { await store.deleteBook(id: book.id) }
            }
            Button("Отмена", role: .cancel) {
                pendingDeletionBook = nil
            }
        } message: { book in
            Text("Книга \"\(book.title)\" будет удалена из библиотеки вместе с локальным файлом.")
        }
        .alert(
            "Ошибка",
            isPresented: .init(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert(
            store.exportFeedback?.title ?? "Экспорт",
            isPresented: .init(
                get: { store.exportFeedback != nil },
                set: { if !$0 { store.exportFeedback = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.exportFeedback = nil }
        } message: {
            Text(store.exportFeedback?.message ?? "")
        }
        .alert(
            store.importFeedback?.title ?? "Импорт",
            isPresented: .init(
                get: { store.importFeedback != nil },
                set: { if !$0 { store.importFeedback = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.importFeedback = nil }
        } message: {
            Text(store.importFeedback?.message ?? "")
        }
        .sheet(
            isPresented: .init(
                get: { store.importPreview != nil },
                set: { if !$0 { dismissAnnotationImportPreview() } }
            )
        ) {
            if let preview = store.importPreview {
                AnnotationImportPreviewSheet(
                    preview: preview,
                    isApplyingImport: store.isImportingAnnotations,
                    canApplyImport: store.canApplyPreparedImport,
                    onCancel: dismissAnnotationImportPreview,
                    onApply: applyPreparedAnnotationImport
                )
            }
        }
        .task { await store.loadBooks() }
    }

    private var selectedBook: Book? {
        guard let selectedBookID = store.selectedBookID else {
            return nil
        }
        return store.books.first(where: { $0.id == selectedBookID })
    }

    private var importerAllowedContentTypes: [UTType] {
        switch activeImporter {
        case .book:
            return [UTType(filenameExtension: "epub") ?? .item, UTType.pdf]
        case .annotations:
            return [UTType(filenameExtension: "md") ?? .plainText]
        case nil:
            return [.item]
        }
    }

    private var importerAllowsMultipleSelection: Bool {
        switch activeImporter {
        case .annotations:
            return true
        case .book, nil:
            return false
        }
    }

    private func handleImporterResult(_ result: Result<[URL], Error>) {
        let importer = activeImporter
        switch importer {
        case .book:
            handleBookImportSelection(result)
        case .annotations:
            handleAnnotationImportSelection(result)
        case nil:
            break
        }
        activeImporter = nil
    }

    private func handleBookImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            Task {
                await store.importBook(from: url)
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
        case .failure(let error):
            store.errorMessage = error.localizedDescription
        }
    }

    private func requestDeletion(of book: Book) {
        store.selectBook(id: book.id)
        pendingDeletionBook = book
    }

    private func requestDeletionOfSelectedBook() {
        guard let selectedBook else {
            return
        }
        pendingDeletionBook = selectedBook
    }

    private func openBook(_ book: Book) {
        Task {
            let latestBook = await store.latestBook(id: book.id) ?? book
            guard let url = store.resolveBookURL(latestBook) else {
                store.errorMessage = "Файл книги не найден"
                return
            }
            onOpenBook(latestBook, url)
        }
    }

    private func openBookTest(_ book: Book) {
        Task {
            let latestBook = await store.latestBook(id: book.id) ?? book
            guard let url = store.resolveBookURL(latestBook) else {
                store.errorMessage = "Файл книги не найден"
                return
            }
            onOpenTest(latestBook, url)
        }
    }

    private func chooseExportDirectoryAndStart() {
        guard !store.isExportingAnnotations else { return }

        let panel = NSOpenPanel()
        panel.title = "Выберите папку для экспорта заметок"
        panel.message = "Приложение создаст markdown-файлы для всех книг с заметками."
        panel.prompt = "Экспортировать"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let directoryURL = panel.url else { return }

        Task {
            await store.exportAllAnnotations(to: directoryURL)
        }
    }

    private func startAnnotationImportFlow() {
        guard !store.isImportingAnnotations else { return }
        activeImporter = .annotations
    }

    private func handleAnnotationImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else { return }

            releaseSecurityScopedAnnotationImportURLs()
            securityScopedAnnotationImportURLs = urls.filter { $0.startAccessingSecurityScopedResource() }

            Task {
                await store.prepareAnnotationImportPreview(urls: urls)
            }
        case .failure(let error):
            store.errorMessage = error.localizedDescription
        }
    }

    private func dismissAnnotationImportPreview() {
        store.clearImportPreview()
        releaseSecurityScopedAnnotationImportURLs()
    }

    private func applyPreparedAnnotationImport() {
        Task {
            await store.applyPreparedAnnotationImport()
            releaseSecurityScopedAnnotationImportURLs()
        }
    }

    private func releaseSecurityScopedAnnotationImportURLs() {
        for url in securityScopedAnnotationImportURLs {
            url.stopAccessingSecurityScopedResource()
        }
        securityScopedAnnotationImportURLs = []
    }
}

private enum ActiveImporter {
    case book
    case annotations
}

private struct AnnotationImportPreviewSheet: View {
    let preview: AnnotationImportPreviewSummary
    let isApplyingImport: Bool
    let canApplyImport: Bool
    let onCancel: () -> Void
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Предпросмотр импорта")
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Создать: \(preview.createCount)")
                Text("Обновить: \(preview.updateCount)")
                Text("Пропустить: \(preview.skipCount)")
                if preview.invalidCount > 0 {
                    Text("Невалидных файлов: \(preview.invalidCount)")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            List(preview.files, id: \.sourceURL) { file in
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.sourceURL.lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                    Text(statusText(for: file))
                        .font(.system(size: 11))
                        .foregroundStyle(statusColor(for: file))
                    if case .ready = file.status {
                        Text("Создать: \(file.createCount) · Обновить: \(file.updateCount) · Пропустить: \(file.skipCount)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.plain)
            .frame(minHeight: 260)

            HStack {
                Button("Отмена", action: onCancel)
                Spacer()
                Button(action: onApply) {
                    if isApplyingImport {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Импортировать")
                    }
                }
                .disabled(isApplyingImport || !canApplyImport)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 420)
    }

    private func statusText(for file: AnnotationImportPreviewFileResult) -> String {
        switch file.status {
        case .ready:
            return "Готов к импорту"
        case .unmatchedBook:
            return "Книга не найдена по contentHash"
        case .invalid(let reason):
            return "Невалидный файл: \(reason)"
        }
    }

    private func statusColor(for file: AnnotationImportPreviewFileResult) -> Color {
        switch file.status {
        case .ready:
            return .green
        case .unmatchedBook:
            return .orange
        case .invalid:
            return .red
        }
    }
}
