import Foundation
import Observation

struct AnnotationImportFeedback: Equatable {
    var title: String
    var message: String
}

struct LibrarySearchTextSegment: Equatable {
    let text: String
    let isHighlighted: Bool
}

@MainActor
@Observable
final class LibraryStore {
    var books: [Book] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedBookID: String?
    var isExportingAnnotations: Bool = false
    var exportFeedback: AnnotationExportFeedback?
    var isImportingAnnotations: Bool = false
    var importPreview: AnnotationImportPreviewSummary?
    var importFeedback: AnnotationImportFeedback?
    var libraryImportFeedback: AnnotationImportFeedback?

    private let database: DatabaseManager
    private let repository: LibraryRepositoryProtocol
    private let annotationRepository: AnnotationRepositoryProtocol
    private var pendingAnnotationImportURLs: [URL] = []

    init(
        database: DatabaseManager,
        repository: LibraryRepositoryProtocol,
        annotationRepository: AnnotationRepositoryProtocol
    ) {
        self.database = database
        self.repository = repository
        self.annotationRepository = annotationRepository
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
        await importBooks(from: [url])
    }

    func importBooks(from urls: [URL]) async {
        guard !urls.isEmpty else { return }

        errorMessage = nil
        libraryImportFeedback = nil

        var importedBooks: [Book] = []
        var failedImports: [String] = []

        for url in urls {
            do {
                let book = try await BookImporter.importBook(from: url, using: repository)
                importedBooks.append(book)
            } catch {
                failedImports.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }

        if !importedBooks.isEmpty {
            books = importedBooks.reversed() + books
            selectedBookID = importedBooks.last?.id
        }

        if !failedImports.isEmpty {
            if importedBooks.isEmpty {
                errorMessage = failedImports.joined(separator: "\n")
            } else {
                libraryImportFeedback = AnnotationImportFeedback(
                    title: "Импорт завершён частично",
                    message: makeLibraryImportFeedbackMessage(
                        importedCount: importedBooks.count,
                        failedImports: failedImports
                    )
                )
            }
        } else if importedBooks.count > 1 {
            libraryImportFeedback = AnnotationImportFeedback(
                title: "Книги импортированы",
                message: "Добавлено книг: \(importedBooks.count)"
            )
        }
    }

    private func makeLibraryImportFeedbackMessage(
        importedCount: Int,
        failedImports: [String]
    ) -> String {
        var lines = ["Добавлено книг: \(importedCount)"]
        lines.append("Не удалось импортировать:")
        lines.append(contentsOf: failedImports)
        return lines.joined(separator: "\n")
    }

    func clearLibraryImportFeedback() {
        libraryImportFeedback = nil
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

    var displayedBooks: [Book] {
        let query = normalizedSearchQuery
        guard !query.isEmpty else {
            return books
        }

        return books.filter { book in
            matchesSearch(book: book, query: query)
        }
    }

    func highlightedSegments(for text: String) -> [LibrarySearchTextSegment] {
        Self.highlightedSegments(in: text, query: normalizedSearchQuery)
    }

    func exportAllAnnotations(to directoryURL: URL) async {
        isExportingAnnotations = true
        defer { isExportingAnnotations = false }

        let service = AnnotationExportService(
            libraryRepository: repository,
            annotationRepository: annotationRepository
        )
        let summary = await service.exportAll(to: directoryURL)

        if summary.exportedCount == 0, summary.failedCount > 0 {
            let failedTitles = summary.results.compactMap { result -> String? in
                if case .failed = result.status {
                    return result.title
                }
                return nil
            }
            errorMessage = failedTitles.isEmpty
                ? "Не удалось экспортировать заметки."
                : "Не удалось экспортировать заметки: \(failedTitles.joined(separator: ", "))"
            return
        }

        exportFeedback = AnnotationExportFeedback(
            title: "Экспорт завершён",
            message: makeExportFeedbackMessage(summary: summary, directoryURL: directoryURL)
        )
    }

    func prepareAnnotationImportPreview(urls: [URL]) async {
        guard !urls.isEmpty else { return }

        isImportingAnnotations = true
        defer { isImportingAnnotations = false }

        let service = AnnotationImportPreviewService(
            libraryRepository: repository,
            annotationRepository: annotationRepository
        )
        let summary = await service.preview(urls: urls)
        pendingAnnotationImportURLs = urls
        importPreview = summary
    }

    func applyPreparedAnnotationImport() async {
        guard !pendingAnnotationImportURLs.isEmpty else { return }

        isImportingAnnotations = true
        defer { isImportingAnnotations = false }

        let service = AnnotationImportService(
            database: database,
            libraryRepository: repository
        )
        let summary = await service.apply(urls: pendingAnnotationImportURLs)

        clearImportPreview()

        if summary.importedBookCount == 0,
           summary.failedBookCount > 0 || summary.invalidFileCount > 0 {
            errorMessage = makeImportFailureMessage(summary: summary)
            return
        }

        importFeedback = AnnotationImportFeedback(
            title: "Импорт завершён",
            message: makeImportFeedbackMessage(summary: summary)
        )
    }

    func clearImportPreview() {
        importPreview = nil
        pendingAnnotationImportURLs = []
    }

    var canApplyPreparedImport: Bool {
        guard let importPreview else { return false }
        return importPreview.files.contains { file in
            if case .ready = file.status {
                return true
            }
            return false
        }
    }

    func resolveBookURL(_ book: Book) -> URL? {
        let url = URL(fileURLWithPath: book.filePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func makeExportFeedbackMessage(
        summary: AnnotationExportSummary,
        directoryURL: URL
    ) -> String {
        var lines = ["Папка: \(directoryURL.path)"]
        lines.append("Экспортировано книг: \(summary.exportedCount)")

        if summary.skippedCount > 0 {
            lines.append("Пропущено без заметок: \(summary.skippedCount)")
        }

        if summary.failedCount > 0 {
            lines.append("Ошибок: \(summary.failedCount)")
        }

        return lines.joined(separator: "\n")
    }

    private func makeImportFeedbackMessage(summary: AnnotationImportSummary) -> String {
        var lines = ["Импортировано книг: \(summary.importedBookCount)"]
        lines.append("Создано аннотаций: \(summary.createCount)")
        lines.append("Обновлено аннотаций: \(summary.updateCount)")

        if summary.skipCount > 0 {
            lines.append("Пропущено аннотаций: \(summary.skipCount)")
        }
        if summary.unmatchedBookCount > 0 {
            lines.append("Файлов без найденной книги: \(summary.unmatchedBookCount)")
        }
        if summary.invalidFileCount > 0 {
            lines.append("Невалидных файлов: \(summary.invalidFileCount)")
        }
        if summary.failedBookCount > 0 {
            lines.append("Ошибок по книгам: \(summary.failedBookCount)")
        }

        return lines.joined(separator: "\n")
    }

    private func makeImportFailureMessage(summary: AnnotationImportSummary) -> String {
        var issues: [String] = []

        let failedTitles = summary.results.compactMap { result -> String? in
            if case .failed = result.status {
                return result.title
            }
            return nil
        }
        if !failedTitles.isEmpty {
            issues.append("Ошибки книг: \(failedTitles.joined(separator: ", "))")
        }
        if summary.invalidFileCount > 0 {
            issues.append("Невалидных файлов: \(summary.invalidFileCount)")
        }
        if summary.unmatchedBookCount > 0 {
            issues.append("Файлов без совпавшей книги: \(summary.unmatchedBookCount)")
        }

        if issues.isEmpty {
            return "Не удалось импортировать аннотации."
        }
        return issues.joined(separator: "\n")
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

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchesSearch(book: Book, query: String) -> Bool {
        book.title.localizedStandardContains(query)
        || (book.author?.localizedStandardContains(query) ?? false)
    }

    static func highlightedSegments(in text: String, query: String) -> [LibrarySearchTextSegment] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty, !text.isEmpty else {
            return [LibrarySearchTextSegment(text: text, isHighlighted: false)]
        }

        var segments: [LibrarySearchTextSegment] = []
        var cursor = text.startIndex

        while cursor < text.endIndex,
              let range = text.range(
                of: trimmedQuery,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: cursor..<text.endIndex,
                locale: .current
              ) {
            if cursor < range.lowerBound {
                segments.append(
                    LibrarySearchTextSegment(
                        text: String(text[cursor..<range.lowerBound]),
                        isHighlighted: false
                    )
                )
            }

            segments.append(
                LibrarySearchTextSegment(
                    text: String(text[range]),
                    isHighlighted: true
                )
            )
            cursor = range.upperBound
        }

        if cursor < text.endIndex {
            segments.append(
                LibrarySearchTextSegment(
                    text: String(text[cursor..<text.endIndex]),
                    isHighlighted: false
                )
            )
        }

        return segments.isEmpty
            ? [LibrarySearchTextSegment(text: text, isHighlighted: false)]
            : segments
    }
}
