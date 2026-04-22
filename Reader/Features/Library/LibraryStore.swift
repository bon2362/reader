import Foundation
import Observation

@MainActor
@Observable
final class LibraryStore {
    var books: [Book] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedBookID: String?

    private let repository: LibraryRepositoryProtocol

    init(repository: LibraryRepositoryProtocol) {
        self.repository = repository
    }

    func loadBooks() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetchedBooks = try await repository.fetchAll()
            books = await repairBrokenPDFMetadataIfNeeded(in: fetchedBooks)
            if let selectedBookID, books.contains(where: { $0.id == selectedBookID }) == false {
                self.selectedBookID = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importBook(from url: URL) async {
        do {
            let book = try await BookImporter.importBook(from: url, using: repository)
            books.insert(book, at: 0)
            selectedBookID = book.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func latestBook(id: String) async -> Book? {
        do {
            return try await repository.fetch(id: id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func deleteBook(id: String) async {
        do {
            try await repository.delete(id: id)
            try FileAccess.deleteBookFiles(bookId: id)
            books.removeAll { $0.id == id }
            if selectedBookID == id {
                selectedBookID = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectBook(id: String) {
        selectedBookID = id
    }

    func clearSelection() {
        selectedBookID = nil
    }

    func resolveBookURL(_ book: Book) -> URL? {
        let url = URL(fileURLWithPath: book.filePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func repairBrokenPDFMetadataIfNeeded(in fetchedBooks: [Book]) async -> [Book] {
        var repairedBooks = fetchedBooks

        for index in repairedBooks.indices {
            let book = repairedBooks[index]
            guard book.format == .pdf,
                  PDFBookLoader.needsMetadataRepair(title: book.title, author: book.author),
                  FileManager.default.fileExists(atPath: book.filePath) else {
                continue
            }
            guard let metadata = try? PDFBookLoader.parseMetadata(from: URL(fileURLWithPath: book.filePath)) else {
                continue
            }

            var repaired = book
            repaired.title = metadata.title
            repaired.author = metadata.author

            guard repaired.title != book.title || repaired.author != book.author else {
                continue
            }

            do {
                try await repository.update(repaired)
                repairedBooks[index] = repaired
            } catch {
                continue
            }
        }

        return repairedBooks
    }
}
