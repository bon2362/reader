import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct LibraryView: View {
    @Bindable var store: LibraryStore
    let onOpenBook: (Book, URL) -> Void
    let onOpenTest: (Book, URL) -> Void

    @State private var showImporter = false
    @State private var pendingDeletionBook: Book?

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                AddBookCardView {
                    showImporter = true
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
            .padding(24)

            if store.books.isEmpty && !store.isLoading {
                ContentUnavailableView(
                    "Нет книг",
                    systemImage: "books.vertical",
                    description: Text("Первая плитка в библиотеке добавляет EPUB и PDF файлы.")
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.clearSelection()
        }
        .navigationTitle("Библиотека")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: chooseExportDirectoryAndStart) {
                    Label("Экспортировать всё", systemImage: store.isExportingAnnotations ? "arrow.up.circle.fill" : "square.and.arrow.up")
                }
                .disabled(store.isExportingAnnotations)
                .help(store.isExportingAnnotations ? "Экспорт всех заметок..." : "Экспортировать заметки всех книг")
            }
        }
        .onDeleteCommand(perform: requestDeletionOfSelectedBook)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "epub") ?? .item,
                UTType.pdf
            ],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
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
            Text("Книга \"\(book.title)\" будет удалена из библиотеки. Приложение также удалит свою локальную копию файла, но исходный файл на вашем диске останется на месте.")
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
        .task { await store.loadBooks() }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
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
        guard let selectedBookID = store.selectedBookID,
              let selectedBook = store.books.first(where: { $0.id == selectedBookID }) else {
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
}
