import Foundation
import SwiftUI
import WebKit
import Observation

// MARK: - Supporting Types

struct EPUBTextSelection {
    let startOffset: Int
    let endOffset: Int
    let text: String
    let rect: CGRect
}

struct EPUBSearchResult: Identifiable {
    let id = UUID()
    let offset: Int
    let length: Int
    let snippet: String
}

enum ReaderTheme: String, CaseIterable {
    case auto, light, sepia, dark

    var displayName: String {
        switch self {
        case .auto:  return "Авто"
        case .light: return "Светлая"
        case .sepia: return "Сепия"
        case .dark:  return "Тёмная"
        }
    }
}

// MARK: - Store

@MainActor
@Observable
final class IPhoneEPUBReaderStore {

    // MARK: Navigation state
    var chapterTitle: String = ""
    var pageInChapter: Int = 0
    var totalInChapter: Int = 1
    var isLoading: Bool = true
    var errorMessage: String?

    // MARK: UI overlay state (driven by JS messages)
    var isMenuVisible: Bool = false

    // MARK: Annotation state
    var highlights: [Highlight] = []
    var textNotes: [TextNote] = []
    var pendingSelection: EPUBTextSelection?
    var editingHighlightId: String?
    var editingNoteId: String?

    // MARK: Reading settings (persisted)
    var readerTheme: ReaderTheme {
        didSet { UserDefaults.standard.set(readerTheme.rawValue, forKey: "reader.theme"); applyTheme() }
    }
    var fontSize: Int {
        didSet { UserDefaults.standard.set(fontSize, forKey: "reader.fontSize"); applyFontSize() }
    }
    var lineHeight: Double {
        didSet { UserDefaults.standard.set(lineHeight, forKey: "reader.lineHeight"); applyLineHeight() }
    }

    // Default values — kept in one place to stay in sync with JS defaults and applyAppearanceSettings
    static let defaultFontSize: Int    = 17
    static let defaultLineHeight: Double = 1.65

    let bookTitle: String
    let book: Book

    private let bookURL: URL
    private let libraryRepository: LibraryRepositoryProtocol
    private let annotationRepository: AnnotationRepositoryProtocol
    private var epubBook: (any BookContentProvider)?
    private var currentChapterIndex: Int = 0
    private var pendingRestorePage: Int?
    private weak var webView: WKWebView?
    private var saveProgressDebounceTask: Task<Void, Never>?

    // MARK: - Init

    init(
        book: Book,
        resolvedURL: URL,
        libraryRepository: LibraryRepositoryProtocol,
        annotationRepository: AnnotationRepositoryProtocol
    ) {
        self.book = book
        self.bookTitle = book.title
        self.bookURL = resolvedURL
        self.libraryRepository = libraryRepository
        self.annotationRepository = annotationRepository

        // Load persisted settings
        let ud = UserDefaults.standard
        self.readerTheme = ReaderTheme(rawValue: ud.string(forKey: "reader.theme") ?? "") ?? .auto
        self.fontSize = ud.integer(forKey: "reader.fontSize").nonZero ?? Self.defaultFontSize
        self.lineHeight = ud.double(forKey: "reader.lineHeight").nonZero ?? Self.defaultLineHeight
    }

    // MARK: - WebView attachment

    func attachWebView(_ webView: WKWebView) {
        self.webView = webView
    }

    // MARK: - Load

    func load() async {
        defer { isLoading = false }
        do {
            let epub = try BookContentLoader.load(from: bookURL)
            self.epubBook = epub
            await loadAnnotations()
            let (chapter, page) = parsePosition(book.lastCFI, in: epub)
            loadChapter(at: chapter, restorePage: page)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Page navigation

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
                self.dismissMenu()
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
                self.dismissMenu()
            } else if result.after == 0 {
                self.advanceChapter(by: -1)
            }
        }
    }

    // MARK: - TOC navigation

    var tocItems: [EPUBTOCNode] {
        epubBook?.toc ?? []
    }

    func goToChapter(at index: Int) {
        loadChapter(at: index, restorePage: 0)
    }

    func chapterIndexForTOCItem(_ node: EPUBTOCNode) -> Int? {
        guard let epub = epubBook else { return nil }
        let tocHref = EPUBBook.normalizeHref(node.href.components(separatedBy: "#")[0])
        return epub.chapters.firstIndex { EPUBBook.normalizeHref($0.href) == tocHref }
    }

    // MARK: - Message handling

    func handleMessage(type: String, data: [String: Any]) {
        switch type {
        case "tap":
            isMenuVisible.toggle()

        case "ready":
            if let page = pendingRestorePage {
                pendingRestorePage = nil
                if page == .max {
                    webView?.evaluateJavaScript("window.__reader && window.__reader.goToLastPage();", completionHandler: nil)
                } else if page > 0 {
                    webView?.evaluateJavaScript("window.__reader && window.__reader.goToPage(\(page));", completionHandler: nil)
                    pageInChapter = page
                }
            }
            applyAppearanceSettings()
            applyAnnotationsToCurrentChapter()

        case "pageChanged":
            if let page = data["page"] as? Int, let total = data["totalPages"] as? Int {
                pageInChapter = page
                totalInChapter = max(1, total)
                saveProgress()
            }

        case "textSelected":
            let startOffset = data["startOffset"] as? Int ?? 0
            let endOffset   = data["endOffset"]   as? Int ?? 0
            let text        = data["text"]         as? String ?? ""
            var rect = CGRect.zero
            if let r = data["rect"] as? [String: Any] {
                rect = CGRect(
                    x: r["x"] as? Double ?? 0,
                    y: r["y"] as? Double ?? 0,
                    width:  r["w"] as? Double ?? 0,
                    height: r["h"] as? Double ?? 0
                )
            }
            pendingSelection = EPUBTextSelection(
                startOffset: startOffset,
                endOffset: endOffset,
                text: text,
                rect: rect
            )
            editingHighlightId = nil

        case "selectionCleared":
            pendingSelection = nil

        case "highlightTapped":
            if let id = data["id"] as? String {
                editingHighlightId = id
                editingNoteId = nil
                pendingSelection = nil
            }

        case "noteTapped":
            if let id = data["id"] as? String {
                editingNoteId = id
                editingHighlightId = nil
                pendingSelection = nil
            }

        case "linkTapped":
            if let href = data["href"] as? String {
                handleLinkTapped(href: href)
            }

        case "jsError":
            NSLog("[IPhoneEPUBReader] JS error: %@", (data["msg"] as? String) ?? "")

        default:
            break
        }
    }

    // MARK: - Annotations

    private func loadAnnotations() async {
        highlights = (try? await annotationRepository.fetchHighlights(bookId: book.id)) ?? []
        textNotes  = (try? await annotationRepository.fetchTextNotes(bookId: book.id)) ?? []
    }

    func addHighlight(color: HighlightColor) async {
        guard let sel = pendingSelection else { return }
        let href = currentChapterHref
        let h = Highlight(
            bookId: book.id,
            cfiStart: EPUBBook.makeOffsetAnchor(href: href, offset: sel.startOffset),
            cfiEnd:   EPUBBook.makeOffsetAnchor(href: href, offset: sel.endOffset),
            color: color,
            selectedText: sel.text
        )
        try? await annotationRepository.insertHighlight(h)
        highlights.append(h)
        pendingSelection = nil

        let js = hlJS(id: h.id, start: sel.startOffset, end: sel.endOffset, color: color.rawValue)
        webView?.evaluateJavaScript("window.__reader && window.__reader.addHighlight(\(js));", completionHandler: nil)
    }

    func updateHighlightColor(id: String, color: HighlightColor) async {
        guard var h = highlights.first(where: { $0.id == id }) else { return }
        h.color = color
        h.updatedAt = Date()
        try? await annotationRepository.updateHighlight(h)
        if let idx = highlights.firstIndex(where: { $0.id == id }) {
            highlights[idx] = h
        }
        editingHighlightId = nil

        if let start = offsetFromCFI(h.cfiStart), let end = offsetFromCFI(h.cfiEnd) {
            let js = hlJS(id: h.id, start: start, end: end, color: color.rawValue)
            webView?.evaluateJavaScript("window.__reader && window.__reader.addHighlight(\(js));", completionHandler: nil)
        }
    }

    func deleteHighlight(id: String) async {
        try? await annotationRepository.deleteHighlight(id: id)
        highlights.removeAll { $0.id == id }
        editingHighlightId = nil
        pendingSelection = nil
        let safeId = jsEscapeString(id)
        webView?.evaluateJavaScript("window.__reader && window.__reader.removeHighlight(\"\(safeId)\");", completionHandler: nil)
    }

    func addTextNote(text: String) async {
        guard let sel = pendingSelection else { return }
        let href = currentChapterHref
        let n = TextNote(
            bookId: book.id,
            cfiAnchor: EPUBBook.makeOffsetAnchor(href: href, offset: sel.startOffset),
            selectedText: sel.text,
            body: text
        )
        try? await annotationRepository.insertTextNote(n)
        textNotes.append(n)
        pendingSelection = nil

        let js = noteJS(id: n.id, start: sel.startOffset, end: sel.endOffset)
        webView?.evaluateJavaScript("window.__reader && window.__reader.addNote(\(js));", completionHandler: nil)
    }

    func deleteTextNote(id: String) async {
        try? await annotationRepository.deleteTextNote(id: id)
        textNotes.removeAll { $0.id == id }
        editingNoteId = nil
    }

    private func applyAnnotationsToCurrentChapter() {
        guard let webView else { return }

        let chapterHighlights = highlights.filter { isCurrentChapter($0.cfiStart) }
        if !chapterHighlights.isEmpty {
            let arr = chapterHighlights.compactMap { h -> String? in
                guard let s = offsetFromCFI(h.cfiStart), let e = offsetFromCFI(h.cfiEnd) else { return nil }
                return hlJS(id: h.id, start: s, end: e, color: h.color.rawValue)
            }.joined(separator: ",")
            webView.evaluateJavaScript("window.__reader && window.__reader.applyHighlights([\(arr)]);", completionHandler: nil)
        }

        let chapterNotes = textNotes.filter { isCurrentChapter($0.cfiAnchor) }
        if !chapterNotes.isEmpty {
            let arr = chapterNotes.compactMap { n -> String? in
                guard let s = offsetFromCFI(n.cfiAnchor) else { return nil }
                let len = n.selectedText?.count ?? 1
                return noteJS(id: n.id, start: s, end: s + len)
            }.joined(separator: ",")
            webView.evaluateJavaScript("window.__reader && window.__reader.applyNotes([\(arr)]);", completionHandler: nil)
        }
    }

    // MARK: - Reading appearance

    func applyTheme() {
        webView?.evaluateJavaScript("window.__reader && window.__reader.setTheme('\(readerTheme.rawValue)');", completionHandler: nil)
    }

    func applyFontSize() {
        webView?.evaluateJavaScript("window.__reader && window.__reader.setFontSize(\(fontSize));", completionHandler: nil)
    }

    func applyLineHeight() {
        webView?.evaluateJavaScript("window.__reader && window.__reader.setLineHeight(\(lineHeight));", completionHandler: nil)
    }

    private func applyAppearanceSettings() {
        if readerTheme != .auto                   { applyTheme() }
        if fontSize    != Self.defaultFontSize    { applyFontSize() }
        if lineHeight  != Self.defaultLineHeight  { applyLineHeight() }
    }

    // MARK: - Search

    func search(query: String) async -> [EPUBSearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty,
              let webView else { return [] }

        // Escape characters that would break a JS single-quoted string literal
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'",  with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        let js = "JSON.stringify(window.__reader ? window.__reader.search('\(escaped)') : []);"

        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(js) { result, _ in
                guard let jsonStr = result as? String,
                      let data = jsonStr.data(using: .utf8),
                      let arr = try? JSONDecoder().decode([[String: AnyDecodable]].self, from: data) else {
                    continuation.resume(returning: [])
                    return
                }
                let results = arr.compactMap { d -> EPUBSearchResult? in
                    guard let offset = d["offset"]?.value as? Int,
                          let length = d["length"]?.value as? Int else { return nil }
                    let snippet = d["snippet"]?.value as? String ?? ""
                    return EPUBSearchResult(offset: offset, length: length, snippet: snippet)
                }
                continuation.resume(returning: results)
            }
        }
    }

    func goToSearchResult(offset: Int) {
        webView?.evaluateJavaScript("window.__reader && window.__reader.goToOffset(\(offset));", completionHandler: nil)
        isMenuVisible = false
    }

    // MARK: - Helpers

    func dismissMenu() {
        guard isMenuVisible else { return }
        isMenuVisible = false
    }

    func dismissSelection() {
        pendingSelection = nil
        editingHighlightId = nil
        webView?.evaluateJavaScript("window.getSelection && window.getSelection().removeAllRanges();", completionHandler: nil)
    }

    func highlightForEditingId() -> Highlight? {
        guard let id = editingHighlightId else { return nil }
        return highlights.first { $0.id == id }
    }

    func noteForEditingId() -> TextNote? {
        guard let id = editingNoteId else { return nil }
        return textNotes.first { $0.id == id }
    }

    func dismissNoteEditing() {
        editingNoteId = nil
    }

    // MARK: - Private helpers

    private func handleLinkTapped(href: String) {
        if href.hasPrefix("#") {
            // Fragment within current chapter
            let anchor = String(href.dropFirst())
            let safe = anchor
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            webView?.evaluateJavaScript(
                "window.__reader && window.__reader.goToAnchor('\(safe)');",
                completionHandler: nil
            )
        } else {
            // Cross-chapter link — navigate to chapter, ignore anchor for now
            let hrefPart = EPUBBook.normalizeHref(href.components(separatedBy: "#")[0])
            if let epub = epubBook, let idx = epub.chapterIndex(forHref: hrefPart) {
                loadChapter(at: idx, restorePage: 0)
            }
        }
    }

    private var currentChapterHref: String {
        guard let epub = epubBook, epub.chapters.indices.contains(currentChapterIndex) else { return "" }
        return EPUBBook.normalizeHref(epub.chapters[currentChapterIndex].href)
    }

    private func isCurrentChapter(_ cfi: String) -> Bool {
        let hrefPart = cfi.components(separatedBy: "|").first ?? ""
        return EPUBBook.normalizeHref(hrefPart) == currentChapterHref
    }

    private func offsetFromCFI(_ cfi: String) -> Int? {
        let parts = cfi.components(separatedBy: "|o:")
        guard parts.count == 2, let v = Int(parts[1]) else { return nil }
        return v
    }

    private func hlJS(id: String, start: Int, end: Int, color: String) -> String {
        let safeId = jsEscapeString(id)
        return "{\"id\":\"\(safeId)\",\"startOffset\":\(start),\"endOffset\":\(end),\"color\":\"\(color)\"}"
    }

    private func noteJS(id: String, start: Int, end: Int) -> String {
        let safeId = jsEscapeString(id)
        return "{\"id\":\"\(safeId)\",\"startOffset\":\(start),\"endOffset\":\(end)}"
    }

    /// Escapes backslashes and double-quotes so a value can be safely embedded inside
    /// a JS double-quoted string literal without breaking out of it.
    private func jsEscapeString(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - Chapter management

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

    private func chapterLabel(at index: Int, in epub: any BookContentProvider) -> String {
        let href = EPUBBook.normalizeHref(epub.chapters[index].href)
        if let node = epub.toc.first(where: {
            EPUBBook.normalizeHref($0.href.components(separatedBy: "#")[0]) == href
        }) {
            return node.label
        }
        return "Глава \(index + 1)"
    }

    private func saveProgress() {
        // Debounce: cancel the previous pending save so rapid page-flips don't spam the DB.
        saveProgressDebounceTask?.cancel()
        guard let epub = epubBook, epub.chapters.indices.contains(currentChapterIndex) else { return }
        let href = EPUBBook.normalizeHref(epub.chapters[currentChapterIndex].href)
        let cfi = EPUBBook.makePageAnchor(href: href, page: pageInChapter)
        let bookID = book.id
        let repo = libraryRepository
        let chapterNumber = currentChapterIndex + 1
        let chapterCount = epub.chapters.count
        saveProgressDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return // cancelled — a newer save is queued
            }
            guard self != nil else { return }
            try? await repo.updateReadingProgress(
                id: bookID,
                lastCFI: cfi,
                currentPage: chapterNumber,
                totalPages: chapterCount
            )
        }
    }

    private func parsePosition(_ cfi: String?, in epub: any BookContentProvider) -> (chapter: Int, page: Int) {
        guard let cfi, !cfi.isEmpty else { return (0, 0) }
        let parts = cfi.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return (0, 0) }
        let href = String(parts[0])
        let loc  = String(parts[1])
        let page: Int = loc.hasPrefix("p:") ? (Int(loc.dropFirst(2)) ?? 0) : 0
        let chapter = epub.chapterIndex(forHref: href) ?? 0
        return (chapter, page)
    }

    // MARK: - JS page turn helper

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
            return { before, after: window.__reader.currentPage(), totalPages: window.__reader.totalPages() };
        })();
        """
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(js) { result, _ in
                guard let dict = result as? [String: Any],
                      let before = dict["before"] as? Int,
                      let after  = dict["after"]  as? Int,
                      let total  = dict["totalPages"] as? Int else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: PageTurnResult(before: before, after: after, totalPages: total))
            }
        }
    }
}

// MARK: - Helpers

private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

private extension Double {
    var nonZero: Double? { self == 0 ? nil : self }
}

// Minimal Any-type decodable for JSON parsing
private struct AnyDecodable: Decodable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self)   { value = v; return }
        if let v = try? c.decode(Int.self)    { value = v; return }
        if let v = try? c.decode(Double.self) { value = v; return }
        if let v = try? c.decode(String.self) { value = v; return }
        value = NSNull()
    }
}
