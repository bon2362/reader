import Foundation
import PDFKit
import Testing
@testable import Reader

@Suite("PDFSelectionAnchorResolver")
@MainActor
struct PDFSelectionAnchorResolverTests {

    @Test func choosesOccurrenceClosestToSelectionBoundsForRepeatedText() throws {
        let url = try TestPDFFactory.makeTextPDF(
            text: "Echo Echo Echo",
            title: "Repeated Text",
            filename: "repeated-anchor-test"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let document = try #require(PDFDocument(url: url))
        let page = try #require(document.page(at: 0))
        let selectedRange = NSRange(location: 5, length: 4)
        let selection = try #require(page.selection(for: selectedRange))

        let anchor = try #require(
            PDFSelectionAnchorResolver.makeAnchor(for: selection, on: page, pageIndex: 0)
        )

        #expect(anchor == PDFAnchor(pageIndex: 0, charStart: 5, charEnd: 9))
    }
}
