import Testing
@testable import Reader

@Suite("PDFReadingProgress")
struct PDFReadingProgressTests {
    @Test func restoresFromAnchorWhenAvailable() {
        let restored = PDFReadingProgress.restoredPageIndex(
            lastCFI: PDFAnchor.encodePage(4),
            currentPage: 2,
            pageCount: 10
        )

        #expect(restored == 4)
    }

    @Test func fallsBackToCurrentPageWhenAnchorMissing() {
        let restored = PDFReadingProgress.restoredPageIndex(
            lastCFI: nil,
            currentPage: 3,
            pageCount: 10
        )

        #expect(restored == 2)
    }

    @Test func clampsRestoredIndexIntoDocumentBounds() {
        let restored = PDFReadingProgress.restoredPageIndex(
            lastCFI: PDFAnchor.encodePage(99),
            currentPage: 1,
            pageCount: 5
        )

        #expect(restored == 4)
    }

    @Test func createsClampedAnchorForPersistence() {
        let anchor = PDFReadingProgress.pageAnchor(for: 12, pageCount: 4)

        #expect(anchor == PDFAnchor.encodePage(3))
    }
}
