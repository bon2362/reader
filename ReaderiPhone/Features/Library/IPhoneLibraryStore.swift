import Foundation
import Observation

struct IPhoneOpenedBook: Identifiable, Hashable {
    let book: Book
    let url: URL
    let annotationRepository: AnnotationRepositoryProtocol

    var id: String { book.id }

    static func == (lhs: IPhoneOpenedBook, rhs: IPhoneOpenedBook) -> Bool {
        lhs.book.id == rhs.book.id && lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(book.id)
        hasher.combine(url)
    }
}

@MainActor
@Observable
final class IPhoneLibraryStore {
    var books: [Book] = []
    var isLoading = false
    var isImporting = false
    var errorMessage: String?

    let libraryRepository: LibraryRepositoryProtocol
    let annotationRepository: AnnotationRepositoryProtocol

    init(
        libraryRepository: LibraryRepositoryProtocol,
        annotationRepository: AnnotationRepositoryProtocol
    ) {
        self.libraryRepository = libraryRepository
        self.annotationRepository = annotationRepository
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            books = try await libraryRepository.fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importPDF(from url: URL) async {
        guard url.pathExtension.lowercased() == BookFormat.pdf.rawValue else {
            errorMessage = "Поддерживаются только PDF-файлы."
            return
        }

        isImporting = true
        defer { isImporting = false }

        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            _ = try await BookImporter.importBook(from: url, using: libraryRepository)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareOpenBook(_ book: Book) async -> IPhoneOpenedBook? {
        let localURL = URL(fileURLWithPath: book.filePath)

        guard FileManager.default.fileExists(atPath: localURL.path) else {
            errorMessage = "Локальный PDF не найден на этом iPhone."
            await load()
            return nil
        }

        guard FileManager.default.isReadableFile(atPath: localURL.path) else {
            errorMessage = "Локальный PDF недоступен для чтения."
            await load()
            return nil
        }

        return IPhoneOpenedBook(
            book: book,
            url: localURL,
            annotationRepository: annotationRepository
        )
    }
}
