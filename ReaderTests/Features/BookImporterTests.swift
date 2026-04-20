import Testing
import Foundation
@testable import Reader

@Suite("BookImporter")
struct BookImporterTests {

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
}
