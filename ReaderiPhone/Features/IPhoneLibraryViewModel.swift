import Foundation
import Observation

@MainActor
@Observable
final class IPhoneLibraryViewModel {
    enum Availability: Equatable {
        case cloudOnly
        case downloading
        case ready(URL)
        case failed(String)
    }

    var books: [Book] = []
    var availability: [String: Availability] = [:]
    var errorMessage: String?

    private let libraryRepository: LibraryRepositoryProtocol
    private let syncCoordinator: SyncCoordinator

    init(libraryRepository: LibraryRepositoryProtocol, syncCoordinator: SyncCoordinator) {
        self.libraryRepository = libraryRepository
        self.syncCoordinator = syncCoordinator
    }

    func load() async {
        await syncCoordinator.syncOnLaunch()
        await reloadBooks()
    }

    func refresh() async {
        await syncCoordinator.syncOnLaunch()
        await reloadBooks()
    }

    func openURL(for book: Book) async -> URL? {
        if !book.filePath.isEmpty {
            let localURL = URL(fileURLWithPath: book.filePath)
            if FileManager.default.fileExists(atPath: localURL.path) {
                availability[book.id] = .ready(localURL)
                return localURL
            }
        }

        availability[book.id] = .downloading
        guard let localURL = await syncCoordinator.hydrateAssetIfNeeded(for: book) else {
            availability[book.id] = .failed("Не удалось скачать PDF")
            return nil
        }
        availability[book.id] = .ready(localURL)
        await reloadBooks()
        return localURL
    }

    func state(for book: Book) -> Availability {
        if let state = availability[book.id] {
            return state
        }
        if !book.filePath.isEmpty, FileManager.default.fileExists(atPath: book.filePath) {
            return .ready(URL(fileURLWithPath: book.filePath))
        }
        return .cloudOnly
    }

    private func reloadBooks() async {
        do {
            books = try await libraryRepository.fetchAll().filter { $0.format == .pdf }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
