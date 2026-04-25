import Foundation
import ZIPFoundation

struct EPUBChapter: Sendable {
    let id: String          // spine idref
    let href: String        // relative to OPF dir (e.g. "Text/ch1.xhtml")
    let fileURL: URL        // absolute URL on disk
}

struct EPUBTOCNode: Sendable {
    let label: String
    let href: String
    let level: Int
}

final class EPUBBook: BookContentProvider, @unchecked Sendable {
    let rootDir: URL
    let opfDir: URL
    let chapters: [EPUBChapter]
    let toc: [EPUBTOCNode]

    init(rootDir: URL, opfDir: URL, chapters: [EPUBChapter], toc: [EPUBTOCNode]) {
        self.rootDir = rootDir
        self.opfDir = opfDir
        self.chapters = chapters
        self.toc = toc
    }

    deinit {
        try? FileManager.default.removeItem(at: rootDir)
    }

    func chapterIndex(forHref href: String) -> Int? {
        let normalized = EPUBBook.normalizeHref(href)
        return chapters.firstIndex { EPUBBook.normalizeHref($0.href) == normalized }
    }

    static func makePageAnchor(href: String, page: Int) -> String {
        "\(href)|p:\(page)"
    }

    static func makeOffsetAnchor(href: String, offset: Int) -> String {
        "\(href)|o:\(offset)"
    }

    static func normalizeHref(_ href: String) -> String {
        var s = href
        if let hashIdx = s.firstIndex(of: "#") { s = String(s[..<hashIdx]) }
        while s.hasPrefix("/") { s.removeFirst() }
        return s
    }

    static func htmlTextContent(_ html: String) -> String {
        var text = html.replacingOccurrences(
            of: #"(?is)<(script|style)\b[^>]*>.*?</\1>"#,
            with: "",
            options: .regularExpression
        )
        text = text.replacingOccurrences(of: #"(?s)<[^>]+>"#, with: "", options: .regularExpression)
        return decodeHTMLEntities(text)
    }

    static func excerpt(in text: String, around range: Range<String.Index>) -> String {
        let context = 80
        let lower = text.index(range.lowerBound, offsetBy: -context, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: context, limitedBy: text.endIndex) ?? text.endIndex
        var excerpt = String(text[lower..<upper])
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if lower > text.startIndex { excerpt = "…" + excerpt }
        if upper < text.endIndex { excerpt += "…" }
        return excerpt
    }

    private static func decodeHTMLEntities(_ text: String) -> String {
        var output = ""
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == "&", let end = text[index...].firstIndex(of: ";") {
                let entityStart = text.index(after: index)
                let entity = String(text[entityStart..<end])
                if let decoded = decodeEntity(entity) {
                    output.append(decoded)
                    index = text.index(after: end)
                    continue
                }
            }
            output.append(text[index])
            index = text.index(after: index)
        }

        return output
    }

    private static func decodeEntity(_ entity: String) -> Character? {
        switch entity {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "apos": return "'"
        case "nbsp": return " "
        default:
            if entity.hasPrefix("#x"),
               let scalar = UInt32(entity.dropFirst(2), radix: 16).flatMap(UnicodeScalar.init) {
                return Character(scalar)
            }
            if entity.hasPrefix("#"),
               let scalar = UInt32(entity.dropFirst(), radix: 10).flatMap(UnicodeScalar.init) {
                return Character(scalar)
            }
            return nil
        }
    }
}

enum EPUBBookError: LocalizedError {
    case cannotUnzip
    case missingContainer
    case missingOPF
    case missingSpine

    var errorDescription: String? {
        switch self {
        case .cannotUnzip:       return "Не удалось распаковать EPUB"
        case .missingContainer:  return "Повреждён EPUB: нет META-INF/container.xml"
        case .missingOPF:        return "Повреждён EPUB: нет .opf"
        case .missingSpine:      return "Повреждён EPUB: пустой spine"
        }
    }
}

enum EPUBBookLoader {

    static func load(from epubURL: URL) throws -> EPUBBook {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("epub-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        do {
            try fm.unzipItem(at: epubURL, to: root)

            let containerURL = root.appendingPathComponent("META-INF/container.xml")
            guard let containerData = try? Data(contentsOf: containerURL),
                  let opfRel = firstCapture(in: String(data: containerData, encoding: .utf8) ?? "",
                                             pattern: #"<rootfile[^>]*full-path=\"([^\"]+)\""#) else {
                throw EPUBBookError.missingContainer
            }

            let opfURL = root.appendingPathComponent(opfRel)
            guard let opfData = try? Data(contentsOf: opfURL),
                  let opfStr = String(data: opfData, encoding: .utf8) else {
                throw EPUBBookError.missingOPF
            }
            let opfDir = opfURL.deletingLastPathComponent()

            // Manifest: id → href
            var manifest: [String: String] = [:]
            enumerate(in: opfStr, pattern: #"<item\b[^>]*?>"#) { tag in
                guard let id = firstCapture(in: tag, pattern: #"id=\"([^\"]+)\""#),
                      let href = firstCapture(in: tag, pattern: #"href=\"([^\"]+)\""#) else { return }
                manifest[id] = href
            }

            // Spine: ordered idrefs
            var spineIds: [String] = []
            enumerate(in: opfStr, pattern: #"<itemref\b[^>]*?>"#) { tag in
                if let idref = firstCapture(in: tag, pattern: #"idref=\"([^\"]+)\""#) {
                    spineIds.append(idref)
                }
            }

            let chapters: [EPUBChapter] = spineIds.compactMap { id in
                guard let href = manifest[id] else { return nil }
                let url = opfDir.appendingPathComponent(href).standardizedFileURL
                guard FileManager.default.fileExists(atPath: url.path) else { return nil }
                return EPUBChapter(id: id, href: href, fileURL: url)
            }
            guard !chapters.isEmpty else { throw EPUBBookError.missingSpine }

            // TOC: try nav.xhtml (EPUB 3) first, then NCX (EPUB 2), fallback to spine
            let toc = loadTOC(opfDir: opfDir, opfText: opfStr, manifest: manifest, chapters: chapters)

            return EPUBBook(rootDir: root, opfDir: opfDir, chapters: chapters, toc: toc)
        } catch let error as EPUBBookError {
            try? fm.removeItem(at: root)
            throw error
        } catch {
            try? fm.removeItem(at: root)
            throw EPUBBookError.cannotUnzip
        }
    }

    // MARK: - TOC

    private static func loadTOC(
        opfDir: URL,
        opfText: String,
        manifest: [String: String],
        chapters: [EPUBChapter]
    ) -> [EPUBTOCNode] {
        // EPUB 3 nav
        if let navTag = firstMatch(in: opfText, pattern: #"<item[^>]*properties=\"[^\"]*nav[^\"]*\"[^>]*/>"#),
           let navHref = firstCapture(in: navTag, pattern: #"href=\"([^\"]+)\""#) {
            let navURL = opfDir.appendingPathComponent(navHref).standardizedFileURL
            if let data = try? Data(contentsOf: navURL),
               let str = String(data: data, encoding: .utf8),
               let nav = parseNav(str) {
                return nav
            }
        }
        // EPUB 2 NCX
        if let spineOpen = firstMatch(in: opfText, pattern: #"<spine[^>]*>"#),
           let ncxId = firstCapture(in: spineOpen, pattern: #"toc=\"([^\"]+)\""#),
           let ncxHref = manifest[ncxId] {
            let ncxURL = opfDir.appendingPathComponent(ncxHref).standardizedFileURL
            if let data = try? Data(contentsOf: ncxURL),
               let str = String(data: data, encoding: .utf8) {
                return parseNCX(str)
            }
        }
        // Fallback: chapters as flat TOC
        return chapters.enumerated().map { idx, ch in
            EPUBTOCNode(label: "Глава \(idx + 1)", href: ch.href, level: 0)
        }
    }

    private static func parseNav(_ str: String) -> [EPUBTOCNode]? {
        guard let navBlock = firstMatch(in: str, pattern: #"<nav[^>]*epub:type=\"toc\"[^>]*>[\s\S]*?</nav>"#)
              ?? firstMatch(in: str, pattern: #"<nav[^>]*>[\s\S]*?</nav>"#) else {
            return nil
        }
        var out: [EPUBTOCNode] = []
        let anchorRegex = try? NSRegularExpression(pattern: #"<a[^>]*href=\"([^\"]+)\"[^>]*>([\s\S]*?)</a>"#, options: [])
        let range = NSRange(navBlock.startIndex..., in: navBlock)
        anchorRegex?.enumerateMatches(in: navBlock, range: range) { m, _, _ in
            guard let m, m.numberOfRanges >= 3,
                  let hRange = Range(m.range(at: 1), in: navBlock),
                  let lRange = Range(m.range(at: 2), in: navBlock) else { return }
            let href = String(navBlock[hRange])
            let label = stripTags(String(navBlock[lRange])).trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty { out.append(EPUBTOCNode(label: label, href: href, level: 0)) }
        }
        return out.isEmpty ? nil : out
    }

    private static func parseNCX(_ str: String) -> [EPUBTOCNode] {
        var out: [EPUBTOCNode] = []
        let pattern = #"<navPoint[\s\S]*?<text>([\s\S]*?)</text>[\s\S]*?<content[^>]*src=\"([^\"]+)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let range = NSRange(str.startIndex..., in: str)
        regex.enumerateMatches(in: str, range: range) { m, _, _ in
            guard let m, m.numberOfRanges >= 3,
                  let tRange = Range(m.range(at: 1), in: str),
                  let sRange = Range(m.range(at: 2), in: str) else { return }
            let label = stripTags(String(str[tRange])).trimmingCharacters(in: .whitespacesAndNewlines)
            let href = String(str[sRange])
            if !label.isEmpty { out.append(EPUBTOCNode(label: label, href: href, level: 0)) }
        }
        return out
    }

    // MARK: - Regex helpers

    private static func firstCapture(in string: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range), match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: string) else { return nil }
        return String(string[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstMatch(in string: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range),
              let matchRange = Range(match.range, in: string) else { return nil }
        return String(string[matchRange])
    }

    private static func enumerate(in string: String, pattern: String, body: (String) -> Void) {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return }
        let range = NSRange(string.startIndex..., in: string)
        regex.enumerateMatches(in: string, range: range) { m, _, _ in
            guard let m, let r = Range(m.range, in: string) else { return }
            body(String(string[r]))
        }
    }

    private static func stripTags(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
