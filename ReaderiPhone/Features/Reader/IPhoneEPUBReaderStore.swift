import Foundation
import SwiftUI
import UIKit
import WebKit
import Observation

// MARK: - Supporting Types

struct EPUBTextSelection {
    let startOffset: Int
    let endOffset: Int
    let text: String
    let rect: CGRect
    let firstRect: CGRect
}

struct IPhoneTextNoteDraft: Identifiable, Equatable {
    enum Kind: Equatable {
        case highlight
        case page
    }

    let id = UUID()
    let kind: Kind
    let highlightId: String?
    let cfiAnchor: String
    let selectedText: String?
    let renderStartOffset: Int
    let renderEndOffset: Int
}

private enum IPhoneHighlightEditSource {
    case selectionOverlap
    case tappedHighlight
}

struct EPUBSearchResult: Identifiable {
    let id = UUID()
    let chapterIndex: Int
    let chapterTitle: String
    let chapterHref: String
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
    var globalPage: Int?
    var totalBookPages: Int?
    var chapterPageCounts: [Int] = []
    var pageCalculationState: BookPageCalculationState = .idle
    var isLoading: Bool = true
    var isChapterReady: Bool = false
    var errorMessage: String?

    // MARK: UI overlay state (driven by JS messages)
    var isMenuVisible: Bool = false
    var requestDismiss: Bool = false

    // MARK: Annotation state
    var highlights: [Highlight] = []
    var textNotes: [TextNote] = []
    var pendingSelection: EPUBTextSelection?
    var editingHighlightId: String?
    var editingNoteId: String?
    private var editingHighlightSource: IPhoneHighlightEditSource?

    // MARK: Reading settings (persisted)
    var readerTheme: ReaderTheme {
        didSet { UserDefaults.standard.set(readerTheme.rawValue, forKey: "reader.theme"); applyTheme() }
    }
    var fontSize: Int {
        didSet {
            UserDefaults.standard.set(fontSize, forKey: "reader.fontSize")
            applyFontSize()
            invalidatePageCountsAndRecalculate()
        }
    }
    var lineHeight: Double {
        didSet {
            UserDefaults.standard.set(lineHeight, forKey: "reader.lineHeight")
            applyLineHeight()
            invalidatePageCountsAndRecalculate()
        }
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
    private var pendingOffsetNavigation: (chapterIndex: Int, offset: Int, token: Int)?
    private var offsetNavigationToken = 0
    private weak var webView: WKWebView?
    private let pageCountCache = BookPageCountCache()
    private var pageCalculator: BookPageCalculator?
    private var pageCalculationKey: BookPageLayoutKey?
    private var viewportWidth: Int = 0
    private var viewportHeight: Int = 0
    private var viewportSafeAreaTop: Int = 0
    private var viewportSafeAreaBottom: Int = 0
    private var saveProgressDebounceTask: Task<Void, Never>?
    private var highlightSelectionsInFlight = Set<String>()
    private var chapterLoadToken = 0

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
            startPageCalculationIfPossible(for: epub)
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
            guard isReadyForCurrentChapter(data) else { return }
            let readyToken = chapterLoadToken
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
            let waitsForOffsetNavigation = applyPendingOffsetNavigationIfNeeded()
            scheduleChapterReady(token: readyToken, waitsForOffsetNavigation: waitsForOffsetNavigation)

        case "pageChanged":
            if let page = data["page"] as? Int, let total = data["totalPages"] as? Int {
                pageInChapter = page
                totalInChapter = max(1, total)
                updateVisibleViewport(
                    width: data["iw"] as? Int ?? viewportWidth,
                    height: data["ih"] as? Int ?? viewportHeight
                )
                updateGlobalPage()
                saveProgress()
            }

        case "textSelected":
            let startOffset = data["startOffset"] as? Int ?? 0
            let endOffset   = data["endOffset"]   as? Int ?? 0
            let text        = data["text"]         as? String ?? ""
            let rect = rectFromMessage(data["rect"])
            let firstRect = rectFromMessage(data["firstRect"]) ?? rect ?? .zero
            let normalized = normalizedRange(startOffset, endOffset)
            let selection = EPUBTextSelection(
                startOffset: normalized.start,
                endOffset: normalized.end,
                text: text,
                rect: rect ?? firstRect,
                firstRect: firstRect
            )
            pendingSelection = selection
            if let overlapping = overlappingHighlight(for: selection) {
                editingHighlightId = overlapping.id
                editingHighlightSource = .selectionOverlap
            } else {
                editingHighlightId = nil
                editingHighlightSource = nil
            }

        case "selectionCleared":
            pendingSelection = nil
            if editingHighlightSource == .selectionOverlap {
                editingHighlightId = nil
                editingHighlightSource = nil
            }

        case "highlightTapped":
            if let id = data["id"] as? String {
                editingHighlightId = id
                editingHighlightSource = .tappedHighlight
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
        if let existing = overlappingHighlight(for: sel) {
            pendingSelection = nil
            if existing.color == color {
                editingHighlightId = nil
                editingHighlightSource = nil
            } else {
                await updateHighlightColor(id: existing.id, color: color)
            }
            return
        }

        let href = currentChapterHref
        let selectionKey = highlightSelectionKey(href: href, start: sel.startOffset, end: sel.endOffset)
        guard !highlightSelectionsInFlight.contains(selectionKey) else {
            pendingSelection = nil
            editingHighlightId = nil
            editingHighlightSource = nil
            return
        }
        highlightSelectionsInFlight.insert(selectionKey)
        pendingSelection = nil
        editingHighlightId = nil
        editingHighlightSource = nil
        defer { highlightSelectionsInFlight.remove(selectionKey) }

        if let existing = overlappingHighlight(start: sel.startOffset, end: sel.endOffset) {
            if existing.color != color {
                await updateHighlightColor(id: existing.id, color: color)
            }
            return
        }

        let h = Highlight(
            bookId: book.id,
            cfiStart: EPUBBook.makeOffsetAnchor(href: href, offset: sel.startOffset),
            cfiEnd:   EPUBBook.makeOffsetAnchor(href: href, offset: sel.endOffset),
            color: color,
            selectedText: sel.text
        )
        do {
            try await annotationRepository.insertHighlight(h)
        } catch {
            errorMessage = "Не удалось сохранить хайлайт"
            return
        }
        highlights.append(h)

        let js = hlJS(id: h.id, start: sel.startOffset, end: sel.endOffset, color: color.rawValue)
        webView?.evaluateJavaScript("window.__reader && window.__reader.addHighlight(\(js));", completionHandler: nil)
    }

    func updateHighlightColor(id: String, color: HighlightColor) async {
        guard var h = highlights.first(where: { $0.id == id }) else { return }
        h.color = color
        h.updatedAt = Date()
        do {
            try await annotationRepository.updateHighlight(h)
        } catch {
            errorMessage = "Не удалось обновить хайлайт"
            return
        }
        if let idx = highlights.firstIndex(where: { $0.id == id }) {
            highlights[idx] = h
        }
        editingHighlightId = nil
        editingHighlightSource = nil

        if let start = offsetFromCFI(h.cfiStart), let end = offsetFromCFI(h.cfiEnd) {
            let js = hlJS(id: h.id, start: start, end: end, color: color.rawValue)
            webView?.evaluateJavaScript("window.__reader && window.__reader.addHighlight(\(js));", completionHandler: nil)
        }
    }

    func deleteHighlight(id: String) async {
        do {
            try await annotationRepository.deleteHighlight(id: id)
        } catch {
            errorMessage = "Не удалось удалить хайлайт"
            return
        }
        highlights.removeAll { $0.id == id }
        for idx in textNotes.indices where textNotes[idx].highlightId == id {
            textNotes[idx].highlightId = nil
        }
        editingHighlightId = nil
        editingHighlightSource = nil
        pendingSelection = nil
        let safeId = jsEscapeString(id)
        webView?.evaluateJavaScript("window.__reader && window.__reader.removeHighlight(\"\(safeId)\");", completionHandler: nil)
    }

    func addTextNote(text: String) async {
        guard let sel = pendingSelection else { return }
        let href = currentChapterHref
        let draft = IPhoneTextNoteDraft(
            kind: .page,
            highlightId: nil,
            cfiAnchor: EPUBBook.makeOffsetAnchor(href: href, offset: sel.startOffset),
            selectedText: sel.text,
            renderStartOffset: sel.startOffset,
            renderEndOffset: sel.endOffset
        )
        await saveTextNote(body: text, draft: draft)
    }

    func prepareHighlightNoteDraft(defaultColor: HighlightColor = .yellow) async -> IPhoneTextNoteDraft? {
        if let id = editingHighlightId, let h = highlights.first(where: { $0.id == id }) {
            pendingSelection = nil
            editingHighlightId = nil
            editingHighlightSource = nil
            return highlightNoteDraft(for: h)
        }

        guard let sel = pendingSelection else { return nil }
        let highlight: Highlight
        if let existing = overlappingHighlight(for: sel) {
            pendingSelection = nil
            editingHighlightId = nil
            editingHighlightSource = nil
            highlight = existing
        } else {
            let href = currentChapterHref
            let selectionKey = highlightSelectionKey(href: href, start: sel.startOffset, end: sel.endOffset)
            guard !highlightSelectionsInFlight.contains(selectionKey) else {
                pendingSelection = nil
                editingHighlightId = nil
                editingHighlightSource = nil
                return nil
            }
            highlightSelectionsInFlight.insert(selectionKey)
            pendingSelection = nil
            editingHighlightId = nil
            editingHighlightSource = nil
            defer { highlightSelectionsInFlight.remove(selectionKey) }

            if let existing = overlappingHighlight(start: sel.startOffset, end: sel.endOffset) {
                return highlightNoteDraft(for: existing)
            }

            let h = Highlight(
                bookId: book.id,
                cfiStart: EPUBBook.makeOffsetAnchor(href: href, offset: sel.startOffset),
                cfiEnd: EPUBBook.makeOffsetAnchor(href: href, offset: sel.endOffset),
                color: defaultColor,
                selectedText: sel.text
            )
            do {
                try await annotationRepository.insertHighlight(h)
            } catch {
                errorMessage = "Не удалось сохранить хайлайт"
                return nil
            }
            highlights.append(h)
            let js = hlJS(id: h.id, start: sel.startOffset, end: sel.endOffset, color: h.color.rawValue)
            webView?.evaluateJavaScript("window.__reader && window.__reader.addHighlight(\(js));", completionHandler: nil)
            highlight = h
        }

        pendingSelection = nil
        editingHighlightId = nil
        editingHighlightSource = nil
        return highlightNoteDraft(for: highlight)
    }

    func preparePageNoteDraft() async -> IPhoneTextNoteDraft? {
        let offset = await currentPageStartOffset()
        return IPhoneTextNoteDraft(
            kind: .page,
            highlightId: nil,
            cfiAnchor: EPUBBook.makeOffsetAnchor(href: currentChapterHref, offset: offset),
            selectedText: nil,
            renderStartOffset: offset,
            renderEndOffset: offset + 1
        )
    }

    func saveTextNote(body: String, draft: IPhoneTextNoteDraft) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let n = TextNote(
            bookId: book.id,
            highlightId: draft.highlightId,
            cfiAnchor: draft.cfiAnchor,
            selectedText: draft.selectedText,
            body: trimmed
        )
        do {
            try await annotationRepository.insertTextNote(n)
        } catch {
            errorMessage = "Не удалось сохранить заметку"
            return
        }
        textNotes.append(n)
        pendingSelection = nil

        let js = noteJS(id: n.id, start: draft.renderStartOffset, end: draft.renderEndOffset)
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
                let len = max(1, n.selectedText?.count ?? 1)
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
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty, let epub = epubBook else { return [] }

        var results: [EPUBSearchResult] = []
        for (chapterIndex, chapter) in epub.chapters.enumerated() {
            guard let html = try? String(contentsOf: chapter.fileURL, encoding: .utf8) else { continue }
            let text = EPUBBook.htmlBodyTextContent(html)
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(
                    of: needle,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchStart..<text.endIndex
                  ) {
                results.append(EPUBSearchResult(
                    chapterIndex: chapterIndex,
                    chapterTitle: chapterLabel(at: chapterIndex, in: epub),
                    chapterHref: EPUBBook.normalizeHref(chapter.href),
                    offset: range.lowerBound.utf16Offset(in: text),
                    length: needle.utf16.count,
                    snippet: EPUBBook.excerpt(in: text, around: range)
                ))
                searchStart = range.upperBound
            }
        }
        return results
    }

    func goToSearchResult(_ result: EPUBSearchResult) {
        goToOffset(chapterIndex: result.chapterIndex, offset: result.offset)
        isMenuVisible = false
    }

    func goToGlobalPage(_ page: Int) {
        guard let target = EPUBPageMapper.target(forValidGlobalPage: page, counts: chapterPageCounts) else { return }
        loadChapter(at: target.chapterIndex, restorePage: target.pageInChapter)
        isMenuVisible = false
    }

    // MARK: - Helpers

    func dismissMenu() {
        guard isMenuVisible else { return }
        isMenuVisible = false
    }

    func requestReaderDismiss() {
        guard pendingSelection == nil,
              editingHighlightId == nil,
              editingNoteId == nil else { return }
        requestDismiss = true
    }

    func cancelPageCalculation() {
        pageCalculator?.cancel()
    }

    func updateVisibleViewport(width: Int, height: Int, safeAreaTop: Int? = nil, safeAreaBottom: Int? = nil) {
        let normalizedWidth = max(0, width)
        let normalizedHeight = max(0, height)
        let normalizedSafeAreaTop = max(0, safeAreaTop ?? viewportSafeAreaTop)
        let normalizedSafeAreaBottom = max(0, safeAreaBottom ?? viewportSafeAreaBottom)
        guard normalizedWidth > 0, normalizedHeight > 0 else { return }
        guard normalizedWidth != viewportWidth
            || normalizedHeight != viewportHeight
            || normalizedSafeAreaTop != viewportSafeAreaTop
            || normalizedSafeAreaBottom != viewportSafeAreaBottom else { return }
        viewportWidth = normalizedWidth
        viewportHeight = normalizedHeight
        viewportSafeAreaTop = normalizedSafeAreaTop
        viewportSafeAreaBottom = normalizedSafeAreaBottom
        invalidatePageCountsAndRecalculate()
    }

    func dismissSelection() {
        pendingSelection = nil
        editingHighlightId = nil
        editingHighlightSource = nil
        editingNoteId = nil
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

    var pageCounterText: String {
        if let globalPage, let totalBookPages, totalBookPages > 0 {
            return "\(globalPage) из \(totalBookPages)"
        }
        return "\(pageInChapter + 1) из \(totalInChapter)"
    }

    var themeBackgroundColor: Color {
        switch readerTheme {
        case .light:
            return Color(red: 0xfa / 255.0, green: 0xf8 / 255.0, blue: 0xf4 / 255.0)
        case .sepia:
            return Color(red: 0xf5 / 255.0, green: 0xef / 255.0, blue: 0xe0 / 255.0)
        case .dark:
            return Color(red: 0x1a / 255.0, green: 0x1a / 255.0, blue: 0x1a / 255.0)
        case .auto:
            return Color(UIColor.systemBackground)
        }
    }

    // MARK: - Private helpers

    private func rectFromMessage(_ value: Any?) -> CGRect? {
        guard let r = value as? [String: Any] else { return nil }
        return CGRect(
            x: r["x"] as? Double ?? 0,
            y: r["y"] as? Double ?? 0,
            width: r["w"] as? Double ?? 0,
            height: r["h"] as? Double ?? 0
        )
    }

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

    private func normalizedRange(_ start: Int, _ end: Int) -> (start: Int, end: Int) {
        let lower = max(0, min(start, end))
        let upper = max(0, max(start, end))
        return (lower, upper)
    }

    private func overlappingHighlight(for selection: EPUBTextSelection) -> Highlight? {
        overlappingHighlight(start: selection.startOffset, end: selection.endOffset)
    }

    private func overlappingHighlight(start: Int, end: Int) -> Highlight? {
        let range = normalizedRange(start, end)
        guard range.end > range.start else { return nil }
        return highlights.first { h in
            guard isCurrentChapter(h.cfiStart),
                  isCurrentChapter(h.cfiEnd),
                  let existingStart = offsetFromCFI(h.cfiStart),
                  let existingEnd = offsetFromCFI(h.cfiEnd) else {
                return false
            }
            let existing = normalizedRange(existingStart, existingEnd)
            return existing.start < range.end && range.start < existing.end
        }
    }

    private func highlightSelectionKey(href: String, start: Int, end: Int) -> String {
        let range = normalizedRange(start, end)
        return "\(EPUBBook.normalizeHref(href)):\(range.start)-\(range.end)"
    }

    private func highlightNoteDraft(for h: Highlight) -> IPhoneTextNoteDraft? {
        guard let start = offsetFromCFI(h.cfiStart), let end = offsetFromCFI(h.cfiEnd) else { return nil }
        let range = normalizedRange(start, end)
        return IPhoneTextNoteDraft(
            kind: .highlight,
            highlightId: h.id,
            cfiAnchor: h.cfiStart,
            selectedText: h.selectedText,
            renderStartOffset: range.start,
            renderEndOffset: max(range.start + 1, range.end)
        )
    }

    private func currentPageStartOffset() async -> Int {
        guard let webView else { return 0 }
        let js = "window.__reader && window.__reader.currentPageStartOffset ? window.__reader.currentPageStartOffset() : 0;"
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(js) { result, _ in
                if let offset = result as? Int {
                    continuation.resume(returning: max(0, offset))
                } else if let offset = result as? Double {
                    continuation.resume(returning: max(0, Int(offset)))
                } else {
                    continuation.resume(returning: 0)
                }
            }
        }
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
        updateGlobalPage()
        pendingRestorePage = restorePage
        chapterTitle = chapterLabel(at: index, in: epub)
        chapterLoadToken += 1
        isChapterReady = false
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
        updateGlobalPage()
        saveProgress()
    }

    private func goToOffset(chapterIndex: Int, offset: Int) {
        guard let epub = epubBook, epub.chapters.indices.contains(chapterIndex) else { return }
        let normalizedOffset = max(0, offset)
        offsetNavigationToken += 1
        let token = offsetNavigationToken
        if chapterIndex == currentChapterIndex {
            pendingOffsetNavigation = nil
            evaluateGoToOffset(normalizedOffset, token: token)
        } else {
            pendingOffsetNavigation = (chapterIndex, normalizedOffset, token)
            loadChapter(at: chapterIndex, restorePage: nil)
        }
    }

    @discardableResult
    private func applyPendingOffsetNavigationIfNeeded() -> Bool {
        guard let pending = pendingOffsetNavigation,
              pending.chapterIndex == currentChapterIndex else { return false }
        pendingOffsetNavigation = nil
        evaluateGoToOffset(pending.offset, token: pending.token)
        return true
    }

    private func evaluateGoToOffset(_ offset: Int, token: Int) {
        let js = """
        (() => {
            window.__readerPendingOffsetToken = \(token);
            requestAnimationFrame(() => requestAnimationFrame(() => {
                setTimeout(() => {
                    if (window.__readerPendingOffsetToken !== \(token)) return;
                    if (window.__reader && typeof window.__reader.goToOffset === 'function') {
                        window.__reader.goToOffset(\(offset));
                    }
                }, 160);
            }));
        })();
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    private func scheduleChapterReady(token: Int, waitsForOffsetNavigation: Bool) {
        let delay: Duration = waitsForOffsetNavigation ? .milliseconds(360) : .milliseconds(180)
        Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }
            guard let self, self.chapterLoadToken == token else { return }
            self.isChapterReady = true
        }
    }

    private func isReadyForCurrentChapter(_ data: [String: Any]) -> Bool {
        guard let href = data["href"] as? String,
              let epub = epubBook,
              epub.chapters.indices.contains(currentChapterIndex) else {
            return true
        }
        return URL(string: href)?.standardizedFileURL == epub.chapters[currentChapterIndex].fileURL.standardizedFileURL
    }

    private func updateGlobalPage() {
        guard EPUBPageMapper.isValid(counts: chapterPageCounts, chapterCount: epubBook?.chapters.count ?? 0),
              let page = EPUBPageMapper.globalPage(
                chapterIndex: currentChapterIndex,
                pageInChapter: pageInChapter,
                counts: chapterPageCounts
              ) else {
            globalPage = nil
            totalBookPages = nil
            return
        }
        globalPage = page
        totalBookPages = chapterPageCounts.reduce(0, +)
    }

    private func invalidatePageCountsAndRecalculate() {
        chapterPageCounts = []
        globalPage = nil
        totalBookPages = nil
        pageCalculationState = .idle
        pageCalculator?.cancel()
        if let epub = epubBook {
            startPageCalculationIfPossible(for: epub)
        }
    }

    private func startPageCalculationIfPossible(for epub: any BookContentProvider) {
        guard !epub.chapters.isEmpty else { return }
        guard viewportWidth > 0, viewportHeight > 0 else { return }
        let layoutKey = BookPageLayoutKey(
            bookId: book.id,
            bookFileSignature: bookFileSignature(),
            fontSize: fontSize,
            lineHeight: lineHeight,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            safeAreaTop: viewportSafeAreaTop,
            safeAreaBottom: viewportSafeAreaBottom
        )
        guard pageCalculationKey != layoutKey || pageCalculationState != .calculating else { return }
        pageCalculationKey = layoutKey

        if let cached = pageCountCache.load(layoutKey: layoutKey, chapterCount: epub.chapters.count) {
            chapterPageCounts = cached
            pageCalculationState = .ready
            updateGlobalPage()
            return
        }

        pageCalculationState = .calculating
        let calculator = pageCalculator ?? BookPageCalculator()
        pageCalculator = calculator
        calculator.calculate(book: epub, layoutKey: layoutKey) { [weak self] counts in
            guard let self else { return }
            guard self.pageCalculationKey == layoutKey,
                  EPUBPageMapper.isValid(counts: counts, chapterCount: epub.chapters.count) else {
                self.pageCalculationState = .failed
                return
            }
            self.chapterPageCounts = counts
            self.pageCountCache.save(counts: counts, layoutKey: layoutKey, chapterCount: epub.chapters.count)
            self.pageCalculationState = .ready
            self.updateGlobalPage()
        }
    }

    private func bookFileSignature() -> String {
        let candidateURL = FileManager.default.fileExists(atPath: book.filePath)
            ? URL(fileURLWithPath: book.filePath)
            : bookURL
        guard let values = try? candidateURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else {
            return "unknown"
        }
        let size = values.fileSize ?? 0
        let modified = values.contentModificationDate?.timeIntervalSince1970 ?? 0
        return "\(size)-\(Int(modified.rounded()))"
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
