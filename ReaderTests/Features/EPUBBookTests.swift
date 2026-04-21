import Foundation
import Testing
@testable import Reader

@Suite("EPUBBook")
struct EPUBBookTests {

    @Test func searchReturnsOffsetAnchorsAndExcerpts() throws {
        let url = try EPUBTestFactory.makeMinimalEPUB(
            chapterBodyHTML: "<p>Alpha beta.</p><p>Another Beta here.</p>"
        )
        let book = try EPUBBookLoader.load(from: url)

        let results = book.search(query: "beta", limit: 10)

        #expect(results.count == 2)
        #expect(results.allSatisfy { $0.cfi.hasPrefix("chap1.xhtml|o:") })
        #expect(results.first?.excerpt.localizedCaseInsensitiveContains("beta") == true)
    }

    @Test func htmlTextContentDecodesCommonEntities() {
        let text = EPUBBook.htmlTextContent("<html><body><p>Tom &amp; Jerry&nbsp; &lt;3</p></body></html>")

        #expect(text.contains("Tom & Jerry  <3"))
    }

    @Test func loadFailureRemovesTemporaryExtractionDirectory() throws {
        let before = epubTempRoots()
        let badURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bad-\(UUID().uuidString).epub")
        try Data("not a zip".utf8).write(to: badURL)

        #expect(throws: EPUBBookError.self) {
            _ = try EPUBBookLoader.load(from: badURL)
        }

        let after = epubTempRoots()
        #expect(after.subtracting(before).isEmpty)
    }

    private func epubTempRoots() -> Set<String> {
        let tmp = FileManager.default.temporaryDirectory
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: tmp,
            includingPropertiesForKeys: nil
        )) ?? []
        return Set(urls.filter { $0.lastPathComponent.hasPrefix("epub-") }.map(\.lastPathComponent))
    }
}
