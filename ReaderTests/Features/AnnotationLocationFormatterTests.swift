import Foundation
import Testing
@testable import Reader

@Suite("Annotation Location Formatter")
struct AnnotationLocationFormatterTests {
    private let formatter = AnnotationLocationFormatter()

    @Test func epubUsesGlobalPageWhenChapterCountsAreKnown() {
        let note = PageNote(bookId: "book-1", spineIndex: 6, pageInChapter: 8, body: "")

        let overlayLabel = formatter.overlayLabel(
            for: note,
            format: .epub,
            chapterPageCounts: [4, 4, 4, 4, 4, 3, 10]
        )
        let exportLabel = formatter.exportLabel(
            for: note,
            format: .epub,
            chapterPageCounts: [4, 4, 4, 4, 4, 3, 10]
        )

        #expect(overlayLabel == "Стр. 32")
        #expect(exportLabel == "Page 32")
    }

    @Test func epubFallsBackToRawChapterPageWithoutCounts() {
        let note = PageNote(bookId: "book-1", spineIndex: 6, pageInChapter: 8, body: "")

        let overlayLabel = formatter.overlayLabel(
            for: note,
            format: .epub,
            chapterPageCounts: nil
        )
        let exportLabel = formatter.exportLabel(
            for: note,
            format: .epub,
            chapterPageCounts: nil
        )

        #expect(overlayLabel == "Гл. 7 · стр. 9")
        #expect(exportLabel == "Chapter 7 · Page 9")
    }
}
