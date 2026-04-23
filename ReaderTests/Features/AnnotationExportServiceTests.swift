import Foundation
import Testing
@testable import Reader

@Suite("Annotation Export Service")
struct AnnotationExportServiceTests {

    @Test func exportsMultipleBooksAndSkipsBooksWithoutAnnotations() async throws {
        let database = try DatabaseManager.inMemory()
        let libraryRepository = LibraryRepository(database: database)
        let annotationRepository = AnnotationRepository(database: database)
        let service = AnnotationExportService(
            libraryRepository: libraryRepository,
            annotationRepository: annotationRepository
        )
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let exportedBook = try makeBook(title: "Export Me", format: .epub)
        let skippedBook = try makeBook(title: "Skip Me", format: .pdf)
        try await libraryRepository.insert(exportedBook)
        try await libraryRepository.insert(skippedBook)
        try await annotationRepository.insertHighlight(
            Highlight(
                bookId: exportedBook.id,
                cfiStart: "start",
                cfiEnd: "end",
                color: .yellow,
                selectedText: "Important quote",
                exchangeId: "highlight-1",
                createdAt: Date(timeIntervalSince1970: 10),
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        )

        let summary = await service.exportAll(to: directory)
        let exportedFiles = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

        #expect(summary.exportedCount == 1)
        #expect(summary.skippedCount == 1)
        #expect(summary.failedCount == 0)
        #expect(exportedFiles.count == 1)

        let markdown = try String(contentsOf: exportedFiles[0], encoding: .utf8)
        #expect(markdown.contains("# Annotations"))
        #expect(markdown.contains("## Highlights"))
        #expect(markdown.contains("Important quote"))
    }

    @Test func failureForOneBookDoesNotStopRemainingExports() async throws {
        let database = try DatabaseManager.inMemory()
        let libraryRepository = LibraryRepository(database: database)
        let annotationRepository = AnnotationRepository(database: database)
        let service = AnnotationExportService(
            libraryRepository: libraryRepository,
            annotationRepository: annotationRepository
        )
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let goodBook = try makeBook(title: "Good Book", format: .pdf)
        let missingFileBook = Book(
            title: "Broken Book",
            filePath: "/definitely/missing/\(UUID().uuidString).epub",
            format: .epub
        )
        try await libraryRepository.insert(goodBook)
        try await libraryRepository.insert(missingFileBook)
        try await annotationRepository.insertTextNote(
            TextNote(
                bookId: goodBook.id,
                cfiAnchor: "pdf:3|12-20",
                body: "Body",
                exchangeId: "note-1",
                createdAt: Date(timeIntervalSince1970: 10),
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        )
        try await annotationRepository.insertTextNote(
            TextNote(
                bookId: missingFileBook.id,
                cfiAnchor: "anchor",
                body: "Broken",
                exchangeId: "note-2",
                createdAt: Date(timeIntervalSince1970: 10),
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        )

        let summary = await service.exportAll(to: directory)

        #expect(summary.exportedCount == 1)
        #expect(summary.failedCount == 1)
        #expect(summary.skippedCount == 0)
        #expect(summary.results.contains {
            if case .failed = $0.status { return $0.bookId == missingFileBook.id }
            return false
        })
        #expect(summary.results.contains {
            if case .exported = $0.status { return $0.bookId == goodBook.id }
            return false
        })
    }

    @Test func exportsSelectedTextForStandaloneTextNote() async throws {
        let database = try DatabaseManager.inMemory()
        let libraryRepository = LibraryRepository(database: database)
        let annotationRepository = AnnotationRepository(database: database)
        let service = AnnotationExportService(
            libraryRepository: libraryRepository,
            annotationRepository: annotationRepository
        )
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let book = try makeBook(title: "Standalone Note", format: .epub)
        try await libraryRepository.insert(book)
        try await annotationRepository.insertTextNote(
            TextNote(
                bookId: book.id,
                cfiAnchor: "epubcfi(/6/2)||epubcfi(/6/4)",
                selectedText: "Captured excerpt",
                body: "Body"
            )
        )

        let summary = await service.exportAll(to: directory)
        let exportedURL = try #require(summary.results.compactMap { result -> URL? in
            if case let .exported(fileURL) = result.status {
                return fileURL
            }
            return nil
        }.first)
        let markdown = try String(contentsOf: exportedURL, encoding: .utf8)

        #expect(markdown.contains("**Selected text**"))
        #expect(markdown.contains("Captured excerpt"))
    }

    @Test func filenamesAreStableAndFileSafe() async throws {
        let database = try DatabaseManager.inMemory()
        let libraryRepository = LibraryRepository(database: database)
        let annotationRepository = AnnotationRepository(database: database)
        let service = AnnotationExportService(
            libraryRepository: libraryRepository,
            annotationRepository: annotationRepository
        )
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let book = try makeBook(title: "A/B:C*D?E", format: .epub)
        try await libraryRepository.insert(book)
        try await annotationRepository.insertPageNote(
            PageNote(
                bookId: book.id,
                spineIndex: 2,
                pageInChapter: 4,
                body: "Sticky",
                exchangeId: "sticky-1",
                createdAt: Date(timeIntervalSince1970: 10),
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        )

        let summary = await service.exportAll(to: directory)
        let exportedURL = try #require(summary.results.compactMap { result -> URL? in
            if case let .exported(fileURL) = result.status {
                return fileURL
            }
            return nil
        }.first)

        #expect(exportedURL.lastPathComponent == "a-b-c-d-e--\(String(book.id.prefix(8))).md")
    }

    @Test func stickyExportUsesGlobalPageWhenChapterCountsAreKnown() async throws {
        let database = try DatabaseManager.inMemory()
        let libraryRepository = LibraryRepository(database: database)
        let annotationRepository = AnnotationRepository(database: database)
        let service = AnnotationExportService(
            libraryRepository: libraryRepository,
            annotationRepository: annotationRepository
        )
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let bookURL = try makeBookFile(named: "global-page.epub", contents: "book")
        defer { try? FileManager.default.removeItem(at: bookURL) }

        let book = Book(
            title: "Global Page Book",
            author: "Author",
            filePath: bookURL.path,
            chapterPageCountsJSON: Book.encodeChapterPageCounts([4, 4, 4, 4, 4, 3, 10]),
            format: .epub
        )
        try await libraryRepository.insert(book)
        try await annotationRepository.insertPageNote(
            PageNote(
                bookId: book.id,
                spineIndex: 6,
                pageInChapter: 8,
                body: "Sticky",
                exchangeId: "sticky-1",
                createdAt: Date(timeIntervalSince1970: 10),
                updatedAt: Date(timeIntervalSince1970: 20)
            )
        )

        let summary = await service.exportAll(to: directory)
        let exportedURL = try #require(summary.results.compactMap { result -> URL? in
            if case let .exported(fileURL) = result.status {
                return fileURL
            }
            return nil
        }.first)
        let markdown = try String(contentsOf: exportedURL, encoding: .utf8)

        #expect(markdown.contains("pageLabel: \"Page 32\""))
        #expect(markdown.contains("> Page 32"))
    }

    private func makeBook(title: String, format: BookFormat) throws -> Book {
        let url = try makeBookFile(
            named: UUID().uuidString,
            fileExtension: format.rawValue,
            contents: "book-\(title)"
        )

        return Book(
            title: title,
            author: "Author",
            filePath: url.path,
            format: format
        )
    }

    private func makeBookFile(named name: String, fileExtension: String, contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension(fileExtension)
        try Data(contents.utf8).write(to: url)
        return url
    }

    private func makeBookFile(named name: String, contents: String) throws -> URL {
        try makeBookFile(named: name, fileExtension: "epub", contents: contents)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
