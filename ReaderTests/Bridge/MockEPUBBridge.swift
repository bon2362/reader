import Foundation
@testable import Reader

@MainActor
final class MockEPUBBridge: EPUBBridgeProtocol {
    weak var delegate: EPUBBridgeDelegate?
    var pageInCurrentChapter: Int = 0

    var pingCallCount = 0
    var loadBookCalls: [URL] = []
    var goToCFICalls: [String] = []
    var nextPageCallCount = 0
    var prevPageCallCount = 0
    var searchCalls: [String] = []
    var highlightCalls: [(cfiStart: String, cfiEnd: String, color: HighlightColor, id: String)] = []
    var removeHighlightCalls: [String] = []
    var getAnnotationPositionsCallCount = 0
    var scrollToAnnotationCalls: [String] = []
    var getTOCCallCount = 0
    var setAnnotationsCalls: [[AnnotationAnchor]] = []
    var goToSpineCalls: [Int] = []
    var goToSpinePageCalls: [(index: Int, pageInChapter: Int)] = []

    func ping() { pingCallCount += 1 }
    func loadBook(url: URL) { loadBookCalls.append(url) }
    func goToCFI(_ cfi: String) { goToCFICalls.append(cfi) }
    func nextPage() { nextPageCallCount += 1 }
    func prevPage() { prevPageCallCount += 1 }
    func search(query: String) { searchCalls.append(query) }
    func highlightRange(cfiStart: String, cfiEnd: String, color: HighlightColor, id: String) {
        highlightCalls.append((cfiStart, cfiEnd, color, id))
    }
    func removeHighlight(id: String) { removeHighlightCalls.append(id) }
    func getAnnotationPositions() { getAnnotationPositionsCallCount += 1 }
    func scrollToAnnotation(cfi: String) { scrollToAnnotationCalls.append(cfi) }
    func getTOC() { getTOCCallCount += 1 }
    func setAnnotations(_ anchors: [AnnotationAnchor]) { setAnnotationsCalls.append(anchors) }
    func goToSpine(index: Int) { goToSpineCalls.append(index) }
    func goToSpine(index: Int, pageInChapter: Int) {
        goToSpinePageCalls.append((index, pageInChapter))
    }
    var setCachedChapterPageCountsCalls: [[Int]] = []
    func setCachedChapterPageCounts(_ counts: [Int]) { setCachedChapterPageCountsCalls.append(counts) }
    var setPendingInitialCFICalls: [String?] = []
    func setPendingInitialCFI(_ cfi: String?) { setPendingInitialCFICalls.append(cfi) }
    var goBackFromLinkCallCount = 0
    func goBackFromLink() { goBackFromLinkCallCount += 1 }

    func simulatePong() { delegate?.bridgeDidReceivePong() }
    func simulatePageChanged(cfi: String, spineIndex: Int, currentPage: Int, totalPages: Int, sectionHref: String? = nil) {
        delegate?.bridgeDidChangePage(cfi: cfi, spineIndex: spineIndex, currentPage: currentPage, totalPages: totalPages, sectionHref: sectionHref)
    }
    func simulateTextSelected(cfiStart: String, cfiEnd: String, text: String) {
        delegate?.bridgeDidSelectText(cfiStart: cfiStart, cfiEnd: cfiEnd, text: text)
    }
    func simulateSearchResults(_ results: [SearchResult]) {
        delegate?.bridgeDidReceiveSearchResults(results)
    }
    func simulateAnnotationPositions(_ positions: [AnnotationPosition]) {
        delegate?.bridgeDidReceiveAnnotationPositions(positions)
    }
    func simulateTOCLoaded(_ entries: [TOCEntry]) {
        delegate?.bridgeDidLoadTOC(entries)
    }
    func simulateHighlightTapped(id: String) {
        delegate?.bridgeDidTapHighlight(id: id)
    }
}

@MainActor
final class DelegateRecorder: EPUBBridgeDelegate {
    var pongReceived = false
    var lastPageCFI: String?
    var lastTotalPages: Int?
    var lastSelectedText: String?

    func bridgeDidReceivePong() { pongReceived = true }
    func bridgeDidChangePage(cfi: String, spineIndex: Int, currentPage: Int, totalPages: Int, sectionHref: String?) {
        lastPageCFI = cfi
        lastTotalPages = totalPages
    }
    func bridgeDidSelectText(cfiStart: String, cfiEnd: String, text: String) {
        lastSelectedText = text
    }
    func bridgeDidTapPage(x: Double, y: Double) {}
    func bridgeDidReceiveSearchResults(_ results: [SearchResult]) {}
    func bridgeDidReceiveAnnotationPositions(_ positions: [AnnotationPosition]) {}
    func bridgeDidLoadTOC(_ entries: [TOCEntry]) {}
    func bridgeDidTapHighlight(id: String) {}
    func bridgeDidFailToLoadBook(message: String) {}
}
