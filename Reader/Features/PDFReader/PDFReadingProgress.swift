import Foundation

enum PDFReadingProgress {
    static func restoredPageIndex(lastCFI: String?, currentPage: Int?, pageCount: Int) -> Int {
        let fallbackIndex = max(0, (currentPage ?? 1) - 1)
        let parsedIndex = PDFAnchor.parse(lastCFI ?? "")?.pageIndex ?? fallbackIndex
        return clampedPageIndex(parsedIndex, pageCount: pageCount)
    }

    static func clampedPageIndex(_ pageIndex: Int, pageCount: Int) -> Int {
        guard pageCount > 0 else { return 0 }
        return max(0, min(pageIndex, pageCount - 1))
    }

    static func pageAnchor(for pageIndex: Int, pageCount: Int) -> String {
        PDFAnchor.encodePage(clampedPageIndex(pageIndex, pageCount: pageCount))
    }
}
