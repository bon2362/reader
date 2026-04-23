import Foundation
import WebKit

@MainActor
final class NativeEPUBBridge: NSObject, EPUBBridgeProtocol {
    weak var delegate: EPUBBridgeDelegate?
    private weak var webView: WKWebView?
    private weak var preflightView: WKWebView?

    private var book: EPUBBook?
    private var currentChapterIndex: Int = 0
    private var pageInChapter: Int = 0
    private var totalInChapter: Int = 1

    private var chapterPageCounts: [Int] = []
    private var preflightIndex: Int = -1
    private var preflightComplete: Bool = false
    private var cachedPageCounts: [Int] = []
    private var pendingInitialCFI: String?
    private var revealTask: Task<Void, Never>?
    private var isConcealingChapter: Bool = false

    // Stack of navigation sources for "back from link/footnote"
    private struct NavFrame { let chapterIndex: Int; let page: Int }
    private var navStack: [NavFrame] = []
    // When non-nil after a link navigation, apply after ready
    private var pendingAnchorId: String?
    private var pendingOffset: Int?

    // key: chapter href → list of [id, startOffset, endOffset, colorName]
    private var highlightsByChapter: [String: [StoredHighlight]] = [:]
    private var notesByChapter: [String: [StoredNote]] = [:]

    struct StoredHighlight {
        let id: String
        let startOffset: Int
        let endOffset: Int
        let color: String
    }

    struct StoredNote {
        let id: String
        let startOffset: Int
        let endOffset: Int
    }

    var pageInCurrentChapter: Int { pageInChapter }

    init(webView: WKWebView, preflightView: WKWebView? = nil) {
        self.webView = webView
        self.preflightView = preflightView
        super.init()
        webView.configuration.userContentController.add(
            MessageForwarder(owner: self, isPreflight: false),
            name: "native"
        )
        preflightView?.configuration.userContentController.add(
            MessageForwarder(owner: self, isPreflight: true),
            name: "native"
        )
    }

    func tearDown() {
        revealTask?.cancel()
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "native")
        preflightView?.configuration.userContentController.removeScriptMessageHandler(forName: "native")
    }

    // MARK: - Protocol

    func ping() {}

    func loadBook(url: URL) {
        Task { @MainActor in
            do {
                let loaded = try EPUBBookLoader.load(from: url)
                self.book = loaded
                self.currentChapterIndex = 0
                self.pageInChapter = 0
                self.totalInChapter = 1
                self.highlightsByChapter = [:]
                self.notesByChapter = [:]
                self.preflightStarted = false
                self.navStack = []
                self.preflightComplete = false
                self.pendingAnchorId = nil
                self.pendingOffset = nil

                // Use cached page counts if they match this book's chapter count.
                if self.cachedPageCounts.count == loaded.chapters.count, !self.cachedPageCounts.isEmpty {
                    self.chapterPageCounts = self.cachedPageCounts
                    self.preflightComplete = true
                    self.preflightStarted = true // skip preflight entirely
                    NSLog("[Preflight] using cached counts, total=\(self.chapterPageCounts.reduce(0, +))")
                    self.delegate?.bridgeDidFinishPageCountPreflight(counts: self.chapterPageCounts)
                }
                self.delegate?.bridgeDidUpdateLinkBackAvailability(canGoBack: false)

                // TOC
                let entries = loaded.toc.enumerated().map { idx, node in
                    TOCEntry(
                        id: "toc-\(idx)",
                        label: node.label,
                        href: node.href,
                        level: node.level
                    )
                }
                delegate?.bridgeDidLoadTOC(entries)
                delegate?.bridgeDidLoadBook(chapterCount: loaded.chapters.count)

                // Resolve saved reading position, if any.
                var initialChapter = 0
                var initialPage: Int? = nil
                if let cfi = self.pendingInitialCFI, !cfi.isEmpty,
                   let parsed = self.parseAnchor(cfi, defaultKind: .page),
                   let idx = loaded.chapterIndex(forHref: parsed.href) {
                    initialChapter = idx
                    switch parsed.kind {
                    case .page:
                        initialPage = parsed.value
                    case .offset:
                        self.pendingOffset = parsed.value
                    }
                }
                self.pendingInitialCFI = nil
                loadChapter(at: initialChapter, restorePage: initialPage)
                // Preflight starts after the main webview reports its first `ready`
                // (see handleReady) so we know it's laid out.
            } catch {
                NSLog("[NativeEPUBBridge] Load failed: \(error.localizedDescription)")
                self.delegate?.bridgeDidFailToLoadBook(message: error.localizedDescription)
            }
        }
    }

    func goToCFI(_ cfi: String) {
        guard let book else { return }
        let target = cfi.components(separatedBy: "||").first ?? cfi
        guard let parsed = parseAnchor(target, defaultKind: .offset) else {
            let href = EPUBBook.normalizeHref(target)
            guard !href.isEmpty, let idx = book.chapterIndex(forHref: href) else { return }
            loadChapter(at: idx, restorePage: 0)
            return
        }
        guard let idx = book.chapterIndex(forHref: parsed.href) else { return }
        switch parsed.kind {
        case .page:
            loadChapter(at: idx, restorePage: parsed.value)
        case .offset:
            if idx == currentChapterIndex {
                goToOffset(parsed.value)
            } else {
                pendingOffset = parsed.value
                loadChapter(at: idx, restorePage: 0)
            }
        }
    }

    func nextPage() {
        Task { @MainActor in
            guard let book else { return }
            if let result = await performPageTurn("window.__reader && window.__reader.nextPage();"),
               result.didMove {
                syncCurrentChapterPage(page: result.after, totalPages: result.totalPages)
                return
            }
            guard currentChapterIndex < book.chapters.count - 1 else { return }
            loadChapter(at: currentChapterIndex + 1, restorePage: 0)
        }
    }

    func prevPage() {
        Task { @MainActor in
            if let result = await performPageTurn("window.__reader && window.__reader.prevPage();"),
               result.didMove {
                syncCurrentChapterPage(page: result.after, totalPages: result.totalPages)
                return
            }
            guard currentChapterIndex > 0 else { return }
            loadChapter(at: currentChapterIndex - 1, restorePage: -1) // -1 = last page
        }
    }

    func search(query: String) {
        guard let book else {
            delegate?.bridgeDidReceiveSearchResults([])
            return
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            delegate?.bridgeDidReceiveSearchResults([])
            return
        }
        Task { @MainActor [weak self, book] in
            let results = await Task.detached {
                book.search(query: trimmed, limit: 100)
            }.value
            self?.delegate?.bridgeDidReceiveSearchResults(results)
        }
    }

    func highlightRange(cfiStart: String, cfiEnd: String, color: HighlightColor, id: String) {
        guard let parsedStart = parseAnchor(cfiStart, defaultKind: .offset),
              let parsedEnd = parseAnchor(cfiEnd, defaultKind: .offset),
              parsedStart.href == parsedEnd.href else { return }
        let href = EPUBBook.normalizeHref(parsedStart.href)
        let stored = StoredHighlight(id: id, startOffset: parsedStart.value, endOffset: parsedEnd.value, color: color.rawValue)
        var list = highlightsByChapter[href] ?? []
        list.removeAll { $0.id == id }
        list.append(stored)
        highlightsByChapter[href] = list

        if currentChapterHref() == href {
            evaluate(applyOneJS(stored))
        }
    }

    func removeHighlight(id: String) {
        for (k, v) in highlightsByChapter {
            highlightsByChapter[k] = v.filter { $0.id != id }
        }
        let esc = id.replacingOccurrences(of: "'", with: "\\'")
        evaluate("window.__reader && window.__reader.removeHighlight('\(esc)');")
    }

    func getAnnotationPositions() {
        delegate?.bridgeDidReceiveAnnotationPositions([])
    }

    func scrollToAnnotation(cfi: String) { goToCFI(cfi) }

    func getTOC() {
        guard let book else { return }
        let entries = book.toc.enumerated().map { idx, node in
            TOCEntry(id: "toc-\(idx)", label: node.label, href: node.href, level: node.level)
        }
        delegate?.bridgeDidLoadTOC(entries)
    }

    func setAnnotations(_ anchors: [AnnotationAnchor]) {
        var newNotes: [String: [StoredNote]] = [:]
        for a in anchors where a.type == "note" {
            let parts = a.cfi.components(separatedBy: "||")
            guard parts.count == 2,
                  let start = parseAnchor(parts[0], defaultKind: .offset),
                  let end = parseAnchor(parts[1], defaultKind: .offset),
                  start.href == end.href else { continue }
            let href = EPUBBook.normalizeHref(start.href)
            let note = StoredNote(id: a.id, startOffset: start.value, endOffset: end.value)
            newNotes[href, default: []].append(note)
        }
        notesByChapter = newNotes
        if let href = currentChapterHref() {
            let list = notesByChapter[href] ?? []
            evaluate(applyNotesJS(list))
        }
        delegate?.bridgeDidReceiveAnnotationPositions([])
    }

    func goToSpine(index: Int) {
        goToSpine(index: index, pageInChapter: 0)
    }

    func goToSpine(index: Int, pageInChapter: Int) {
        guard let book, index >= 0, index < book.chapters.count else { return }
        loadChapter(at: index, restorePage: max(0, pageInChapter))
    }

    func setCachedChapterPageCounts(_ counts: [Int]) {
        cachedPageCounts = counts
    }

    func setPendingInitialCFI(_ cfi: String?) {
        pendingInitialCFI = cfi
    }

    func goBackFromLink() {
        guard let frame = navStack.popLast() else { return }
        loadChapter(at: frame.chapterIndex, restorePage: frame.page)
        delegate?.bridgeDidUpdateLinkBackAvailability(canGoBack: !navStack.isEmpty)
    }

    // MARK: - Chapter loading

    private func loadChapter(at index: Int, restorePage: Int?) {
        guard let book, let webView else { return }
        guard index >= 0, index < book.chapters.count else { return }
        let chapter = book.chapters[index]
        currentChapterIndex = index
        pageInChapter = 0
        totalInChapter = 1
        pendingRestorePage = restorePage
        revealTask?.cancel()
        isConcealingChapter = true
        webView.alphaValue = 0

        webView.loadFileURL(chapter.fileURL, allowingReadAccessTo: book.rootDir)
    }

    private var pendingRestorePage: Int?

    private func currentChapterHref() -> String? {
        guard let book, currentChapterIndex < book.chapters.count else { return nil }
        return EPUBBook.normalizeHref(book.chapters[currentChapterIndex].href)
    }

    // MARK: - JS helpers

    private func evaluate(_ js: String) {
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }

    private func evaluateForResult(_ js: String) async -> PageTurnResult? {
        guard let webView else { return nil }
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(js) { result, error in
                if let error {
                    NSLog("[NativeEPUBBridge] JS eval failed: %@", error.localizedDescription)
                }
                continuation.resume(returning: Self.parsePageTurnResult(result))
            }
        }
    }

    private func performPageTurn(_ js: String) async -> PageTurnResult? {
        await evaluateForResult("""
        (() => {
            if (!window.__reader) {
                return null;
            }
            const before = window.__reader.currentPage();
            \(js)
            return {
                before,
                after: window.__reader.currentPage(),
                totalPages: window.__reader.totalPages()
            };
        })();
        """)
    }

    private func syncCurrentChapterPage(page: Int, totalPages: Int) {
        pageInChapter = page
        totalInChapter = max(1, totalPages)
        reportPageChanged()
    }

    private func applyOneJS(_ h: StoredHighlight) -> String {
        "window.__reader && window.__reader.addHighlight(\(highlightJSON(h)));"
    }

    private func applyAllJS(_ hs: [StoredHighlight]) -> String {
        let items = hs.map { highlightJSON($0) }.joined(separator: ",")
        return "window.__reader && window.__reader.applyHighlights([\(items)]);"
    }

    private func applyNotesJS(_ ns: [StoredNote]) -> String {
        let items = ns.map { n -> String in
            let idEsc = n.id.replacingOccurrences(of: "\"", with: "\\\"")
            return "{\"id\":\"\(idEsc)\",\"startOffset\":\(n.startOffset),\"endOffset\":\(n.endOffset)}"
        }.joined(separator: ",")
        return "window.__reader && window.__reader.applyNotes([\(items)]);"
    }

    private func highlightJSON(_ h: StoredHighlight) -> String {
        let idEsc = h.id.replacingOccurrences(of: "\"", with: "\\\"")
        let colorEsc = h.color.replacingOccurrences(of: "\"", with: "\\\"")
        return "{\"id\":\"\(idEsc)\",\"startOffset\":\(h.startOffset),\"endOffset\":\(h.endOffset),\"color\":\"\(colorEsc)\"}"
    }

    struct PageTurnResult: Equatable {
        let before: Int
        let after: Int
        let totalPages: Int

        var didMove: Bool { before != after }
    }

    nonisolated static func parsePageTurnResult(_ value: Any?) -> PageTurnResult? {
        guard let dict = value as? [String: Any],
              let before = dict["before"] as? Int,
              let after = dict["after"] as? Int,
              let totalPages = dict["totalPages"] as? Int else {
            return nil
        }
        return PageTurnResult(before: before, after: after, totalPages: totalPages)
    }

    // MARK: - Anchor parsing

    enum AnchorKind {
        case page
        case offset
    }

    struct ParsedAnchor {
        let href: String
        let value: Int
        let kind: AnchorKind
    }

    nonisolated static func makePageAnchor(href: String, page: Int) -> String {
        "\(href)|p:\(page)"
    }

    nonisolated static func makeOffsetAnchor(href: String, offset: Int) -> String {
        "\(href)|o:\(offset)"
    }

    nonisolated static func makeAnchor(href: String, offset: Int) -> String {
        makeOffsetAnchor(href: href, offset: offset)
    }

    private func parseAnchor(_ s: String, defaultKind: AnchorKind) -> ParsedAnchor? {
        let parts = s.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let rawValue = String(parts[1])
        if rawValue.hasPrefix("p:"), let page = Int(rawValue.dropFirst(2)) {
            return ParsedAnchor(href: String(parts[0]), value: page, kind: .page)
        }
        if rawValue.hasPrefix("o:"), let offset = Int(rawValue.dropFirst(2)) {
            return ParsedAnchor(href: String(parts[0]), value: offset, kind: .offset)
        }
        guard let value = Int(rawValue) else { return nil }
        return ParsedAnchor(href: String(parts[0]), value: value, kind: defaultKind)
    }

    // MARK: - Incoming messages

    func handle(_ body: Any) {
        guard let dict = body as? [String: Any], let type = dict["type"] as? String else { return }

        switch type {
        case "ready":
            handleReady()
        case "pageChanged":
            if let page = dict["page"] as? Int, let total = dict["totalPages"] as? Int {
                pageInChapter = page
                totalInChapter = max(1, total)
                guard !shouldDeferPageChangedReport else { return }
                reportPageChanged()
            }
        case "textSelected":
            guard let startOffset = dict["startOffset"] as? Int,
                  let endOffset = dict["endOffset"] as? Int,
                  let text = dict["text"] as? String,
                  let href = currentChapterHref() else { return }
            let cfiStart = NativeEPUBBridge.makeOffsetAnchor(href: href, offset: startOffset)
            let cfiEnd = NativeEPUBBridge.makeOffsetAnchor(href: href, offset: endOffset)
            delegate?.bridgeDidSelectText(cfiStart: cfiStart, cfiEnd: cfiEnd, text: text)
            if let rectDict = dict["rect"] as? [String: Any],
               let x = rectDict["x"] as? Double, let y = rectDict["y"] as? Double,
               let w = rectDict["w"] as? Double, let h = rectDict["h"] as? Double {
                delegate?.bridgeDidUpdateSelectionRect(CGRect(x: x, y: y, width: w, height: h))
            } else {
                delegate?.bridgeDidUpdateSelectionRect(nil)
            }
        case "selectionCleared":
            delegate?.bridgeDidClearSelection()
        case "linkTapped":
            handleLinkTapped(dict)
        case "highlightTapped":
            if let id = dict["id"] as? String {
                delegate?.bridgeDidTapHighlight(id: id)
            }
        case "noteTapped":
            if let id = dict["id"] as? String {
                let x = (dict["x"] as? Double) ?? 0
                let y = (dict["y"] as? Double) ?? 0
                delegate?.bridgeDidTapNote(id: id, x: x, y: y)
            }
        case "jsError":
            let msg = dict["msg"] as? String ?? ""
            NSLog("[JS] %@", msg)
        default:
            break
        }
    }

    private var preflightStarted = false
    private var shouldDeferPageChangedReport: Bool {
        if isConcealingChapter {
            return true
        }
        if let restorePage = pendingRestorePage, restorePage != 0 {
            return true
        }
        return pendingAnchorId != nil || pendingOffset != nil
    }

    private func handleReady() {
        // Once main is ready we know the container has a real size — kick off preflight.
        if !preflightStarted {
            preflightStarted = true
            startPreflight()
        }
        guard let href = currentChapterHref() else { return }
        // Apply highlights for this chapter
        if let list = highlightsByChapter[href], !list.isEmpty {
            evaluate(applyAllJS(list))
        }
        // Apply note underlines for this chapter
        let notes = notesByChapter[href] ?? []
        evaluate(applyNotesJS(notes))
        // Restore page position
        if let page = pendingRestorePage {
            if page < 0 {
                evaluate("window.__reader && window.__reader.goToLastPage();")
            } else if page > 0 {
                evaluate("window.__reader && window.__reader.goToPage(\(page));")
            }
            pendingRestorePage = nil
        }
        // Scroll to pending anchor (footnote target)
        if let anchor = pendingAnchorId {
            let esc = anchor.replacingOccurrences(of: "'", with: "\\'")
            evaluate("window.__reader && window.__reader.goToAnchor('\(esc)');")
            pendingAnchorId = nil
        }
        if let offset = pendingOffset {
            goToOffset(offset)
            pendingOffset = nil
        }
        scheduleReveal()
    }

    private func scheduleReveal() {
        revealTask?.cancel()
        guard let webView else { return }
        revealTask = Task { @MainActor [weak webView] in
            // Let the initial restored page paint before revealing the chapter.
            try? await Task.sleep(nanoseconds: 60_000_000)
            guard !Task.isCancelled else { return }
            isConcealingChapter = false
            webView?.alphaValue = 1
            reportPageChanged()
        }
    }

    // MARK: - Link / footnote navigation

    private func handleLinkTapped(_ dict: [String: Any]) {
        guard let href = dict["href"] as? String, !href.isEmpty else { return }
        // Save current position before navigating
        let frame = NavFrame(chapterIndex: currentChapterIndex, page: pageInChapter)

        // Same-chapter hash anchor
        if href.hasPrefix("#") {
            let anchor = String(href.dropFirst())
            navStack.append(frame)
            delegate?.bridgeDidUpdateLinkBackAvailability(canGoBack: true)
            let esc = anchor.replacingOccurrences(of: "'", with: "\\'")
            evaluate("window.__reader && window.__reader.goToAnchor('\(esc)');")
            return
        }

        // Cross-chapter: "path/to/chapter.html#anchor" or absolute
        guard let book, let curHref = currentChapterHref() else { return }
        // Build a resolved path
        let parts = href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        let pathPart = String(parts[0])
        let anchorPart = parts.count > 1 ? String(parts[1]) : nil

        // Resolve pathPart relative to current chapter href
        let resolved = resolveRelativeHref(pathPart, from: curHref)
        guard let idx = book.chapterIndex(forHref: resolved) else { return }
        navStack.append(frame)
        delegate?.bridgeDidUpdateLinkBackAvailability(canGoBack: true)
        pendingAnchorId = anchorPart
        loadChapter(at: idx, restorePage: 0)
    }

    private func resolveRelativeHref(_ href: String, from baseHref: String) -> String {
        // If href is absolute-like (contains /), treat as full path relative to epub root
        let norm = href.replacingOccurrences(of: "\\", with: "/")
        if norm.hasPrefix("/") {
            return EPUBBook.normalizeHref(String(norm.dropFirst()))
        }
        // Resolve relative to baseHref's directory
        var comps = baseHref.split(separator: "/").map(String.init)
        if !comps.isEmpty { comps.removeLast() } // drop filename
        for piece in norm.split(separator: "/") {
            if piece == "." { continue }
            if piece == ".." { if !comps.isEmpty { comps.removeLast() }; continue }
            comps.append(String(piece))
        }
        return EPUBBook.normalizeHref(comps.joined(separator: "/"))
    }

    private func reportPageChanged() {
        guard let book, currentChapterIndex < book.chapters.count else { return }
        let chapter = book.chapters[currentChapterIndex]
        let href = EPUBBook.normalizeHref(chapter.href)
        let cfi = NativeEPUBBridge.makePageAnchor(href: href, page: pageInChapter)

        let current: Int
        let total: Int
        let priorMeasured = chapterPageCounts.prefix(currentChapterIndex).allSatisfy { $0 > 0 }
        if chapterPageCounts.count == book.chapters.count, priorMeasured, preflightComplete {
            let prefix = chapterPageCounts.prefix(currentChapterIndex).reduce(0, +)
            current = prefix + pageInChapter + 1
            total = chapterPageCounts.reduce(0, +)
        } else {
            current = pageInChapter + 1
            total = totalInChapter
        }

        delegate?.bridgeDidChangePage(
            cfi: cfi,
            spineIndex: currentChapterIndex,
            currentPage: current,
            totalPages: total,
            sectionHref: chapter.href
        )
    }

    private func goToOffset(_ offset: Int) {
        evaluate("window.__reader && window.__reader.goToOffset(\(max(0, offset)));")
    }

    // MARK: - Preflight (measure page counts for all chapters)

    private func startPreflight() {
        guard let book, preflightView != nil, !book.chapters.isEmpty else { return }
        chapterPageCounts = Array(repeating: 0, count: book.chapters.count)
        preflightIndex = -1
        preflightComplete = false
        NSLog("[Preflight] start, chapters=\(book.chapters.count)")
        measureNextChapter()
    }

    private func measureNextChapter() {
        guard let book, let v = preflightView else { return }
        preflightIndex += 1
        if preflightIndex >= book.chapters.count {
            preflightComplete = true
            NSLog("[Preflight] complete, total=\(chapterPageCounts.reduce(0, +))")
            // Clear preflight webview so no residual content can bleed through.
            v.loadHTMLString("<html><body style=\"background:transparent\"></body></html>", baseURL: nil)
            delegate?.bridgeDidFinishPageCountPreflight(counts: chapterPageCounts)
            reportPageChanged()
            return
        }
        v.loadFileURL(book.chapters[preflightIndex].fileURL, allowingReadAccessTo: book.rootDir)
    }

    fileprivate func handlePreflight(_ body: Any) {
        guard let dict = body as? [String: Any], let type = dict["type"] as? String else { return }
        if type == "jsError" {
            NSLog("[Preflight JS] %@", (dict["msg"] as? String) ?? "")
            return
        }
        guard type == "pageChanged" else { return }
        let total = (dict["totalPages"] as? Int) ?? 1
        if preflightIndex >= 0, preflightIndex < chapterPageCounts.count,
           chapterPageCounts[preflightIndex] == 0 {
            chapterPageCounts[preflightIndex] = max(1, total)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 30_000_000)
                self.measureNextChapter()
            }
        }
    }
}

private final class MessageForwarder: NSObject, WKScriptMessageHandler, @unchecked Sendable {
    weak var owner: NativeEPUBBridge?
    let isPreflight: Bool
    init(owner: NativeEPUBBridge, isPreflight: Bool) {
        self.owner = owner
        self.isPreflight = isPreflight
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let body = message.body
        let preflight = isPreflight
        Task { @MainActor [weak self] in
            if preflight {
                self?.owner?.handlePreflight(body)
            } else {
                self?.owner?.handle(body)
            }
        }
    }
}
