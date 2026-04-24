import Testing
import Foundation
@testable import Reader

@Suite("BookImporter")
struct BookImporterTests {
    private func makeRepo() throws -> LibraryRepository {
        let db = try DatabaseManager.inMemory()
        return LibraryRepository(database: db)
    }

    @Test func parsesTitleAndAuthor() throws {
        let url = try EPUBTestFactory.makeMinimalEPUB(title: "Война и мир", author: "Лев Толстой")
        defer { try? FileManager.default.removeItem(at: url) }

        let meta = try BookImporter.parseMetadata(from: url)
        #expect(meta.title == "Война и мир")
        #expect(meta.author == "Лев Толстой")
    }

    @Test func parsesBookWithoutAuthor() throws {
        let url = try EPUBTestFactory.makeMinimalEPUB(title: "Anon", author: nil)
        defer { try? FileManager.default.removeItem(at: url) }

        let meta = try BookImporter.parseMetadata(from: url)
        #expect(meta.title == "Anon")
        #expect(meta.author == nil)
    }

    @Test func extractsCoverWhenPresent() throws {
        let url = try EPUBTestFactory.makeMinimalEPUB(includeCover: true)
        defer { try? FileManager.default.removeItem(at: url) }

        let meta = try BookImporter.parseMetadata(from: url)
        #expect(meta.coverData != nil)
        #expect(meta.coverMimeType == "image/png")
    }

    @Test func noCoverWhenAbsent() throws {
        let url = try EPUBTestFactory.makeMinimalEPUB(includeCover: false)
        defer { try? FileManager.default.removeItem(at: url) }

        let meta = try BookImporter.parseMetadata(from: url)
        #expect(meta.coverData == nil)
    }

    @Test func throwsOnMissingArchive() {
        let url = URL(fileURLWithPath: "/tmp/definitely-not-exist-\(UUID().uuidString).epub")
        #expect(throws: Error.self) {
            _ = try BookImporter.parseMetadata(from: url)
        }
    }

    @MainActor
    @Test func importsPDFIntoLocalRepository() async throws {
        let repo = try makeRepo()
        let url = try TestPDFFactory.makeTextPDF(
            text: "Standalone import",
            title: "Imported PDF",
            author: "On Device"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let book = try await BookImporter.importBook(from: url, using: repo)
        let fetched = try await repo.fetch(id: book.id)

        #expect(fetched?.format == .pdf)
        #expect(fetched?.title == "Imported PDF")
        #expect(fetched?.author == "On Device")
        #expect(fetched?.filePath.hasSuffix(".pdf") == true)

        try? FileAccess.deleteBookFiles(bookId: book.id)
    }

    @Test func invalidPDFDoesNotCreateBrokenRecord() async throws {
        let repo = try makeRepo()
        let invalidPDF = FileManager.default.temporaryDirectory
            .appendingPathComponent("broken-\(UUID().uuidString)")
            .appendingPathExtension("pdf")
        try Data("not a real pdf".utf8).write(to: invalidPDF)
        defer { try? FileManager.default.removeItem(at: invalidPDF) }

        await #expect(throws: Error.self) {
            _ = try await BookImporter.importBook(from: invalidPDF, using: repo)
        }

        let allBooks = try await repo.fetchAll()
        #expect(allBooks.isEmpty)
    }
}
