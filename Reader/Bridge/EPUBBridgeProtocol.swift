import Foundation
import CoreGraphics

@MainActor
protocol EPUBBridgeProtocol: AnyObject {
    var delegate: EPUBBridgeDelegate? { get set }

    func ping()
    func loadBook(url: URL)
    func goToCFI(_ cfi: String)
    func nextPage()
    func prevPage()
    func search(query: String)
    func highlightRange(cfiStart: String, cfiEnd: String, color: HighlightColor, id: String)
    func removeHighlight(id: String)
    func getAnnotationPositions()
    func scrollToAnnotation(cfi: String)
    func getTOC()
    func setAnnotations(_ anchors: [AnnotationAnchor])
    func goToSpine(index: Int)
    func setCachedChapterPageCounts(_ counts: [Int])
    func setPendingInitialCFI(_ cfi: String?)
    func goBackFromLink()
}

@MainActor
protocol EPUBBridgeDelegate: AnyObject {
    func bridgeDidReceivePong()
    func bridgeDidChangePage(cfi: String, spineIndex: Int, currentPage: Int, totalPages: Int, sectionHref: String?)
    func bridgeDidSelectText(cfiStart: String, cfiEnd: String, text: String)
    func bridgeDidTapPage(x: Double, y: Double)
    func bridgeDidReceiveSearchResults(_ results: [SearchResult])
    func bridgeDidReceiveAnnotationPositions(_ positions: [AnnotationPosition])
    func bridgeDidLoadTOC(_ entries: [TOCEntry])
    func bridgeDidTapHighlight(id: String)
    func bridgeDidLoadBook(chapterCount: Int)
    func bridgeDidTapNote(id: String, x: Double, y: Double)
    func bridgeDidFinishPageCountPreflight(counts: [Int])
    func bridgeDidUpdateSelectionRect(_ rect: CGRect?)
    func bridgeDidClearSelection()
    func bridgeDidUpdateLinkBackAvailability(canGoBack: Bool)
}

extension EPUBBridgeDelegate {
    func bridgeDidLoadBook(chapterCount: Int) {}
    func bridgeDidTapNote(id: String, x: Double, y: Double) {}
    func bridgeDidFinishPageCountPreflight(counts: [Int]) {}
    func bridgeDidUpdateSelectionRect(_ rect: CGRect?) {}
    func bridgeDidClearSelection() {}
    func bridgeDidUpdateLinkBackAvailability(canGoBack: Bool) {}
}
