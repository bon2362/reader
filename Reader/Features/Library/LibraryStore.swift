import Foundation
import Observation

@MainActor
@Observable
final class LibraryStore {
    var books: [Book] = []
    var isLoading: Bool = false
    var errorMessage: String?

    private let repository: LibraryRepositoryProtocol

    init(repository: LibraryRepositoryProtocol) {
        self.repository = repository
    }

    func loadBooks() async {
        isLoading = true
        defer { isLoading = false }
        do {
            books = try await repository.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importBook(from url: URL) async {
        do {
            let book = try await BookImporter.importBook(from: url, using: repository)
            books.insert(book, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteBook(id: String) async {
        do {
            try await repository.delete(id: id)
            try FileAccess.deleteBookFiles(bookId: id)
            books.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resolveBookURL(_ book: Book) -> URL? {
        let url = URL(fileURLWithPath: book.filePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
