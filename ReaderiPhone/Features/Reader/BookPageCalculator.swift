import Foundation
import WebKit
import UIKit

struct BookPageLayoutKey: Codable, Equatable {
    let bookId: String
    let bookFileSignature: String
    let fontSize: Int
    let lineHeight: Double
    let textAlign: String
    let viewportWidth: Int
    let viewportHeight: Int
    let safeAreaTop: Int
    let safeAreaBottom: Int

    var debugSummary: String {
        "\(bookId) sig=\(bookFileSignature) fs=\(fontSize) lh=\(lineHeight) align=\(textAlign) viewport=\(viewportWidth)x\(viewportHeight) safe=\(safeAreaTop)/\(safeAreaBottom)"
    }
}

enum BookPageCalculationState: Equatable {
    case idle
    case calculating
    case ready
    case failed
}

final class BookPageCountCache {
    private struct Entry: Codable {
        let layoutKey: BookPageLayoutKey
        let chapterCount: Int
        let counts: [Int]
        let updatedAt: Date
    }

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.directory = base.appendingPathComponent("ReaderIPhonePageCounts", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func load(layoutKey: BookPageLayoutKey, chapterCount: Int) -> [Int]? {
        let url = cacheURL(for: layoutKey)
        guard let data = try? Data(contentsOf: url),
              let entry = try? decoder.decode(Entry.self, from: data),
              entry.layoutKey == layoutKey,
              entry.chapterCount == chapterCount,
              EPUBPageMapper.isValid(counts: entry.counts, chapterCount: chapterCount) else {
            pageCalculationLog("cache miss key=\(layoutKey.debugSummary) chapters=\(chapterCount)")
            return nil
        }
        pageCalculationLog("cache hit key=\(layoutKey.debugSummary) chapters=\(chapterCount) sum=\(entry.counts.reduce(0, +))")
        return entry.counts
    }

    func save(counts: [Int], layoutKey: BookPageLayoutKey, chapterCount: Int) {
        guard EPUBPageMapper.isValid(counts: counts, chapterCount: chapterCount) else {
            pageCalculationLog("skip cache save invalid counts=\(counts.count) chapters=\(chapterCount)")
            return
        }
        let entry = Entry(layoutKey: layoutKey, chapterCount: chapterCount, counts: counts, updatedAt: Date())
        guard let data = try? encoder.encode(entry) else { return }
        try? data.write(to: cacheURL(for: layoutKey), options: [.atomic])
        pageCalculationLog("cache save key=\(layoutKey.debugSummary) chapters=\(chapterCount) sum=\(counts.reduce(0, +))")
    }

    private func cacheURL(for key: BookPageLayoutKey) -> URL {
        let raw = "\(key.bookId)-\(key.bookFileSignature)-\(key.fontSize)-\(key.lineHeight)-align\(key.textAlign)-\(key.viewportWidth)x\(key.viewportHeight)-safe\(key.safeAreaTop)-\(key.safeAreaBottom)"
        let safe = raw.map { ch -> Character in
            ch.isLetter || ch.isNumber || ch == "-" || ch == "." ? ch : "_"
        }
        return directory.appendingPathComponent(String(safe)).appendingPathExtension("json")
    }
}

@MainActor
final class BookPageCalculator {
    private let webView: WKWebView
    private let handler: MessageHandler
    private var book: (any BookContentProvider)?
    private var layoutKey: BookPageLayoutKey?
    private var rootDir: URL?
    private var chapters: [EPUBChapter] = []
    private var counts: [Int] = []
    private var chapterIndex = -1
    private var completion: (([Int]) -> Void)?
    private var isActive = false
    private var generation = 0

    init() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        let viewportScript = WKUserScript(
            source: """
            (function() {
                var existing = document.querySelector('meta[name="viewport"]');
                var content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
                if (existing) {
                    existing.setAttribute('content', content);
                } else {
                    var meta = document.createElement('meta');
                    meta.name = 'viewport';
                    meta.content = content;
                    var head = document.head || document.documentElement;
                    if (head) head.insertBefore(meta, head.firstChild);
                }
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(viewportScript)
        config.userContentController.addUserScript(WKUserScript(
            source: IPhoneEPUBWebView.readerJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))

        self.handler = MessageHandler()
        config.userContentController.add(handler, name: "native")
        self.webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        self.webView.alpha = 0.01
        self.webView.scrollView.isScrollEnabled = false
        handler.owner = self
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "native")
    }

    func calculate(
        book: any BookContentProvider,
        layoutKey: BookPageLayoutKey,
        completion: @escaping ([Int]) -> Void
    ) {
        cancel()
        generation += 1
        let session = generation
        isActive = true
        self.book = book
        self.layoutKey = layoutKey
        self.rootDir = book.rootDir
        self.chapters = book.chapters
        self.counts = Array(repeating: 0, count: book.chapters.count)
        self.chapterIndex = -1
        self.completion = completion
        webView.frame = CGRect(
            x: 0,
            y: 0,
            width: CGFloat(max(1, layoutKey.viewportWidth)),
            height: CGFloat(max(1, layoutKey.viewportHeight))
        )
        pageCalculationLog("calculator start key=\(layoutKey.debugSummary) chapters=\(book.chapters.count)")
        measureNextChapter(session: session)
    }

    func cancel() {
        generation += 1
        isActive = false
        completion = nil
        chapterIndex = -1
        counts = []
        webView.stopLoading()
    }

    private func measureNextChapter(session: Int) {
        guard isActive, generation == session, let rootDir else { return }
        chapterIndex += 1
        if chapterIndex >= chapters.count {
            let result = counts.map { max(1, $0) }
            let finish = completion
            completion = nil
            isActive = false
            pageCalculationLog("calculator complete counts=\(result.count) sum=\(result.reduce(0, +))")
            finish?(result)
            return
        }
        pageCalculationLog("measure chapter \(chapterIndex + 1)/\(chapters.count) href=\(chapters[chapterIndex].href)")
        webView.loadFileURL(chapters[chapterIndex].fileURL, allowingReadAccessTo: rootDir)
    }

    private func handleMessage(_ body: Any) {
        guard isActive,
              let dict = body as? [String: Any],
              let type = dict["type"] as? String else { return }

        if type == "ready" {
            guard chapters.indices.contains(chapterIndex) else { return }
            if let href = dict["href"] as? String,
               URL(string: href)?.standardizedFileURL != chapters[chapterIndex].fileURL.standardizedFileURL {
                pageCalculationLog("ready href mismatch href=\(href) expected=\(chapters[chapterIndex].fileURL.absoluteString)")
                return
            }
            applyLayoutAndReadTotal(session: generation, measuredChapterIndex: chapterIndex)
        }
    }

    private func applyLayoutAndReadTotal(session: Int, measuredChapterIndex: Int) {
        guard let layoutKey else { return }
        let js = """
        (() => {
            if (!window.__reader) return 1;
            document.documentElement.style.setProperty('--reader-safe-area-top', '\(layoutKey.safeAreaTop)px');
            document.documentElement.style.setProperty('--reader-safe-area-bottom', '\(layoutKey.safeAreaBottom)px');
            if (typeof window.__reader.setFontSize === 'function') window.__reader.setFontSize(\(layoutKey.fontSize));
            if (typeof window.__reader.setLineHeight === 'function') window.__reader.setLineHeight(\(layoutKey.lineHeight));
            if (typeof window.__reader.setTextAlign === 'function') window.__reader.setTextAlign('\(layoutKey.textAlign)');
            return new Promise(resolve => {
                requestAnimationFrame(() => requestAnimationFrame(() => {
                    setTimeout(() => resolve(
                        window.__reader && typeof window.__reader.totalPages === 'function'
                            ? window.__reader.totalPages()
                            : 1
                    ), 150);
                }));
            });
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            Task { @MainActor [weak self] in
                guard let self,
                      self.isActive,
                      self.generation == session,
                      self.chapterIndex == measuredChapterIndex else { return }
                let total: Int
                if let intValue = result as? Int {
                    total = intValue
                } else if let doubleValue = result as? Double {
                    total = Int(doubleValue)
                } else {
                    total = 1
                }
                if self.counts.indices.contains(self.chapterIndex), self.counts[self.chapterIndex] == 0 {
                    self.counts[self.chapterIndex] = max(1, total)
                }
                pageCalculationLog("measured chapter \(self.chapterIndex + 1) pages=\(max(1, total))")
                self.measureNextChapter(session: session)
            }
        }
    }

    private final class MessageHandler: NSObject, WKScriptMessageHandler {
        weak var owner: BookPageCalculator?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            let body = message.body
            Task { @MainActor [weak self] in
                self?.owner?.handleMessage(body)
            }
        }
    }
}

func pageCalculationLog(_ message: String) {
#if DEBUG
    NSLog("[IPhoneEPUBReader][PageCalc] %@", message)
#endif
}
