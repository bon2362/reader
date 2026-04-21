import Foundation
import Testing
@testable import Reader

@Suite("PDFAnchor")
struct PDFAnchorTests {

    @Test func encodesAndParsesPageAnchor() {
        let raw = PDFAnchor.encodePage(7)
        let anchor = PDFAnchor.parse(raw)

        #expect(raw == "pdf:7")
        #expect(anchor == PDFAnchor(pageIndex: 7))
        #expect(anchor?.range == nil)
    }

    @Test func encodesAndParsesRangeAnchor() {
        let raw = PDFAnchor.encode(pageIndex: 3, charStart: 12, charEnd: 20)
        let anchor = PDFAnchor.parse(raw)

        #expect(raw == "pdf:3|12-20")
        #expect(anchor == PDFAnchor(pageIndex: 3, charStart: 12, charEnd: 20))
        #expect(anchor?.range == NSRange(location: 12, length: 8))
    }

    @Test func rejectsMalformedAnchors() {
        #expect(PDFAnchor.parse("epub:1") == nil)
        #expect(PDFAnchor.parse("pdf:-1") == nil)
        #expect(PDFAnchor.parse("pdf:1|10-2") == nil)
        #expect(PDFAnchor.parse("pdf:1|a-b") == nil)
    }
}
