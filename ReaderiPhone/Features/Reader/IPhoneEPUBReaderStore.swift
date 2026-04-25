import Foundation
import WebKit
import Observation

@MainActor
@Observable
final class IPhoneEPUBReaderStore {
    var chapterTitle: String = ""
    var pageInChapter: Int = 0
    var totalInChapter: Int = 1
    var isLoading: Bool = true
    var errorMessage: String?

    private let book: Book
    private let bookURL: URL
    private let libraryRepository: LibraryRepositoryProtocol
    private var epubBook: EPUBBook?
    private var currentChapterIndex: Int = 0
    private var pendingRestorePage: Int?
    private weak var webView: WKWebView?

    init(
        book: Book,
        resolvedURL: URL,
        libraryRepository: LibraryRepositoryProtocol
    ) {
        self.book = book
        self.bookURL = resolvedURL
        self.libraryRepository = libraryRepository
    }

    func attachWebView(_ webView: WKWebView) {
        self.webView = webView
    }

    func load() async {
        defer { isLoading = false }
        do {
            let epub = try EPUBBookLoader.load(from: bookURL)
            self.epubBook = epub
            let (chapter, page) = parsePosition(book.lastCFI, in: epub)
            loadChapter(at: chapter, restorePage: page)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var canGoToPreviousPage: Bool {
        pageInChapter > 0 || currentChapterIndex > 0
    }

    var canGoToNextPage: Bool {
        guard let epub = epubBook else { return false }
        return pageInChapter < totalInChapter - 1 || currentChapterIndex < epub.chapters.count - 1
    }

    func goToNextPage() {
        Task { [weak self] in
            guard let self else { return }
            guard let webView = self.webView else { return }
            guard let result = await self.evaluatePageTurn(webView: webView, call: "nextPage()") else { return }
            if result.didMove {
                self.syncPage(result.after, total: result.totalPages)
            } else if result.after >= result.totalPages - 1 {
                self.advanceChapter(by: 1)
            }
        }
    }

    func goToPreviousPage() {
        Task { [weak self] in
            guard let self else { return }
            guard let webView = self.webView else { return }
            guard let result = await self.evaluatePageTurn(webView: webView, call: "prevPage()") else { return }
            if result.didMove {
                self.syncPage(result.after, total: result.totalPages)
            } else if result.after == 0 {
                self.advanceChapter(by: -1)
            }
        }
    }

    func handleMessage(type: String, data: [String: Any]) {
        switch type {
        case "ready":
            let total = (data["totalPages"] as? Int) ?? 1
            totalInChapter = max(1, total)
            if let page = pendingRestorePage {
                pendingRestorePage = nil
                if page == .max {
                    webView?.evaluateJavaScript("window.__reader && window.__reader.goToLastPage();")
                    // pageInChapter will be updated via subsequent pageChanged
                } else if page > 0 {
                    webView?.evaluateJavaScript("window.__reader && window.__reader.goToPage(\(page));")
                    pageInChapter = page
                }
            }
        case "pageChanged":
            if let page = data["page"] as? Int, let total = data["totalPages"] as? Int {
                pageInChapter = page
                totalInChapter = max(1, total)
                saveProgress()
            }
        case "jsError":
            let msg = (data["msg"] as? String) ?? ""
            NSLog("[IPhoneEPUBReader] JS error: %@", msg)
        default:
            break
        }
    }

    // MARK: - Private

    private func loadChapter(at index: Int, restorePage: Int? = nil) {
        guard let epub = epubBook, epub.chapters.indices.contains(index) else { return }
        currentChapterIndex = index
        pageInChapter = 0
        totalInChapter = 1
        pendingRestorePage = restorePage
        chapterTitle = chapterLabel(at: index, in: epub)
        webView?.loadFileURL(epub.chapters[index].fileURL, allowingReadAccessTo: epub.rootDir)
    }

    private func advanceChapter(by delta: Int) {
        guard let epub = epubBook else { return }
        let next = currentChapterIndex + delta
        guard epub.chapters.indices.contains(next) else { return }
        let restorePage: Int? = (delta < 0) ? Int.max : 0
        loadChapter(at: next, restorePage: restorePage)
    }

    private func syncPage(_ page: Int, total: Int) {
        pageInChapter = page
        totalInChapter = max(1, total)
        saveProgress()
    }

    private func chapterLabel(at index: Int, in epub: EPUBBook) -> String {
        let href = EPUBBook.normalizeHref(epub.chapters[index].href)
        if let node = epub.toc.first(where: {
            EPUBBook.normalizeHref($0.href.components(separatedBy: "#")[0]) == href
        }) {
            return node.label
        }
        return "Chapter \(index + 1)"
    }

    private func saveProgress() {
        guard let epub = epubBook, epub.chapters.indices.contains(currentChapterIndex) else { return }
        let href = EPUBBook.normalizeHref(epub.chapters[currentChapterIndex].href)
        let cfi = EPUBBook.makePageAnchor(href: href, page: pageInChapter)
        let bookID = book.id
        let repo = libraryRepository
        let chapterNumber = currentChapterIndex + 1
        let chapterCount = epub.chapters.count
        Task {
            try? await repo.updateReadingProgress(
                id: bookID,
                lastCFI: cfi,
                currentPage: chapterNumber,
                totalPages: chapterCount
            )
        }
    }

    private func parsePosition(_ cfi: String?, in epub: EPUBBook) -> (chapter: Int, page: Int) {
        guard let cfi, !cfi.isEmpty else { return (0, 0) }
        let parts = cfi.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return (0, 0) }
        let href = String(parts[0])
        let loc = String(parts[1])
        let page: Int = loc.hasPrefix("p:") ? (Int(loc.dropFirst(2)) ?? 0) : 0
        let chapter = epub.chapterIndex(forHref: href) ?? 0
        return (chapter, page)
    }

    // MARK: - JS helpers

    private struct PageTurnResult {
        let before, after, totalPages: Int
        var didMove: Bool { before != after }
    }

    private func evaluatePageTurn(webView: WKWebView, call: String) async -> PageTurnResult? {
        let js = """
        (() => {
            if (!window.__reader) return null;
            const before = window.__reader.currentPage();
            window.__reader.\(call);
            return {
                before,
                after: window.__reader.currentPage(),
                totalPages: window.__reader.totalPages()
            };
        })();
        """
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(js) { result, _ in
                guard let dict = result as? [String: Any],
                      let before = dict["before"] as? Int,
                      let after = dict["after"] as? Int,
                      let total = dict["totalPages"] as? Int else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: PageTurnResult(before: before, after: after, totalPages: total))
            }
        }
    }
}
