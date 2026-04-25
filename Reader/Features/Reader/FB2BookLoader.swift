import Foundation

enum FB2BookError: LocalizedError {
    case cannotReadFile
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .cannotReadFile:       return "Не удалось прочитать FB2 файл"
        case .parseError(let msg): return "Ошибка парсинга FB2: \(msg)"
        }
    }
}

enum FB2BookLoader {

    static func load(from fb2URL: URL) throws -> FB2Book {
        let data: Data
        do { data = try Data(contentsOf: fb2URL) }
        catch { throw FB2BookError.cannotReadFile }

        let parser = FB2Parser(data: data)
        try parser.parse()

        let fm = FileManager.default
        let rootDir = fm.temporaryDirectory.appendingPathComponent("fb2-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: rootDir, withIntermediateDirectories: true)

        var chapters: [EPUBChapter] = []
        var tocNodes: [EPUBTOCNode] = []

        let sections = parser.sections
        for (idx, section) in sections.enumerated() {
            let filename = "section-\(String(format: "%04d", idx)).html"
            let fileURL = rootDir.appendingPathComponent(filename)
            let html = buildHTML(section: section, binaries: parser.binaries)
            do {
                try html.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                try? fm.removeItem(at: rootDir)
                throw error
            }
            let chapter = EPUBChapter(id: "s\(idx)", href: filename, fileURL: fileURL)
            chapters.append(chapter)
            if !section.title.isEmpty {
                tocNodes.append(EPUBTOCNode(label: section.title, href: filename, level: 0))
            }
        }

        if chapters.isEmpty {
            try? fm.removeItem(at: rootDir)
            throw FB2BookError.parseError("Книга не содержит секций")
        }

        // If no TOC entries were produced (no titled sections), use chapter numbers
        if tocNodes.isEmpty {
            tocNodes = chapters.enumerated().map { idx, ch in
                EPUBTOCNode(label: "Глава \(idx + 1)", href: ch.href, level: 0)
            }
        }

        return FB2Book(rootDir: rootDir, chapters: chapters, toc: tocNodes)
    }

    // MARK: - HTML builder

    private static func buildHTML(section: FB2Section, binaries: [String: Data]) -> String {
        var body = ""
        if !section.title.isEmpty {
            body += "<h2>\(escapeHTML(section.title))</h2>\n"
        }
        body += renderNodes(section.nodes, binaries: binaries)
        return """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8"></head>
        <body>\(body)</body></html>
        """
    }

    private static func renderNodes(_ nodes: [FB2Node], binaries: [String: Data]) -> String {
        nodes.map { renderNode($0, binaries: binaries) }.joined()
    }

    private static func renderNode(_ node: FB2Node, binaries: [String: Data]) -> String {
        switch node {
        case .text(let s):
            return escapeHTML(s)

        case .element(let tag, let attrs, let children):
            let inner = renderNodes(children, binaries: binaries)
            switch tag {
            case "p":
                return "<p>\(inner)</p>\n"
            case "emphasis":
                return "<em>\(inner)</em>"
            case "strong":
                return "<strong>\(inner)</strong>"
            case "strikethrough":
                return "<s>\(inner)</s>"
            case "code":
                return "<code>\(inner)</code>"
            case "sup":
                return "<sup>\(inner)</sup>"
            case "sub":
                return "<sub>\(inner)</sub>"
            case "title":
                return "<h3>\(inner)</h3>\n"
            case "subtitle":
                return "<h4>\(inner)</h4>\n"
            case "epigraph":
                return "<blockquote class=\"epigraph\">\(inner)</blockquote>\n"
            case "poem":
                return "<div class=\"poem\">\(inner)</div>\n"
            case "stanza":
                return "<div class=\"stanza\">\(inner)</div>\n"
            case "v":
                return "<p class=\"verse\">\(inner)</p>\n"
            case "cite":
                return "<blockquote>\(inner)</blockquote>\n"
            case "table":
                return "<table>\(inner)</table>\n"
            case "tr":
                return "<tr>\(inner)</tr>\n"
            case "th":
                return "<th>\(inner)</th>"
            case "td":
                return "<td>\(inner)</td>"
            case "a":
                let href = attrs["l:href"] ?? attrs["xlink:href"] ?? attrs["href"] ?? "#"
                return "<a href=\"\(escapeHTML(href))\">\(inner)</a>"
            case "image":
                let ref = (attrs["l:href"] ?? attrs["xlink:href"] ?? "").trimmingCharacters(in: .init(charactersIn: "#"))
                if let imgData = binaries[ref] {
                    let mime = mimeType(for: ref)
                    let b64 = imgData.base64EncodedString()
                    return "<img src=\"data:\(mime);base64,\(b64)\" style=\"max-width:100%;height:auto\">\n"
                }
                return ""
            case "empty-line":
                return "<br>\n"
            case "section":
                // nested section
                return "<div class=\"section\">\(inner)</div>\n"
            default:
                return inner.isEmpty ? "" : "<span>\(inner)</span>"
            }

        case .empty:
            return ""
        }
    }

    private static func mimeType(for ref: String) -> String {
        let ext = (ref as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png":         return "image/png"
        case "gif":         return "image/gif"
        case "webp":        return "image/webp"
        default:            return "application/octet-stream"
        }
    }

    private static func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - FB2 data model

struct FB2Section {
    var title: String = ""
    var nodes: [FB2Node] = []
}

indirect enum FB2Node {
    case text(String)
    case element(tag: String, attrs: [String: String], children: [FB2Node])
    case empty
}

// MARK: - SAX parser

private final class FB2Parser: NSObject, XMLParserDelegate {

    let data: Data
    private(set) var sections: [FB2Section] = []
    private(set) var binaries: [String: Data] = [:]

    // Parsing state
    private var inDescription = false
    private var inBody = false
    private var inBinary = false
    private var binaryId = ""
    private var binaryText = ""

    // Stack-based section/node building
    private var sectionDepth = 0          // depth within <body>
    private var currentSection: FB2Section?
    private var nodeStack: [[FB2Node]] = []  // stack of child-lists
    private var tagStack: [(tag: String, attrs: [String: String])] = []
    private var inTitle = false            // inside top-level <section><title>
    private var titleText = ""

    private var error: Error?

    init(data: Data) {
        self.data = data
    }

    func parse() throws {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = true
        parser.parse()
        if let error { throw error }
    }

    // MARK: XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        let tag = localName(qName ?? elementName)

        if tag == "description" { inDescription = true; return }
        if inDescription { return }

        if tag == "binary" {
            inBinary = true
            binaryId = attributeDict["id"] ?? ""
            binaryText = ""
            return
        }

        if tag == "body" {
            inBody = true
            sectionDepth = 0
            return
        }
        guard inBody else { return }

        if tag == "section" {
            sectionDepth += 1
            if sectionDepth == 1 {
                currentSection = FB2Section()
                nodeStack = [[]]
                tagStack = []
            } else {
                // nested section: push a new child list
                pushElement(tag: "section", attrs: attributeDict)
            }
            return
        }

        if tag == "title" && sectionDepth == 1 {
            inTitle = true
            titleText = ""
            return
        }

        if inTitle { return }
        pushElement(tag: tag, attrs: attributeDict)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let tag = localName(qName ?? elementName)

        if tag == "description" { inDescription = false; return }
        if inDescription { return }

        if tag == "binary" {
            if !binaryId.isEmpty, let decoded = Data(base64Encoded: binaryText, options: .ignoreUnknownCharacters) {
                binaries[binaryId] = decoded
            }
            inBinary = false
            binaryId = ""
            binaryText = ""
            return
        }

        if tag == "body" { inBody = false; return }
        guard inBody else { return }

        if tag == "title" && sectionDepth == 1 {
            inTitle = false
            currentSection?.title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
            return
        }

        if tag == "section" {
            if sectionDepth == 1 {
                if var section = currentSection {
                    section.nodes = nodeStack.last ?? []
                    sections.append(section)
                }
                currentSection = nil
                nodeStack = []
                tagStack = []
            } else {
                popElement(tag: tag)
            }
            sectionDepth -= 1
            return
        }

        popElement(tag: tag)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inBinary { binaryText += string; return }
        if inDescription { return }
        guard inBody, sectionDepth >= 1 else { return }

        if inTitle { titleText += string; return }

        if nodeStack.isEmpty { return }
        nodeStack[nodeStack.count - 1].append(.text(string))
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        error = FB2BookError.parseError(parseError.localizedDescription)
    }

    // MARK: - Stack helpers

    private func pushElement(tag: String, attrs: [String: String]) {
        guard !nodeStack.isEmpty else { return }
        // self-closing tags
        if tag == "empty-line" || tag == "image" {
            nodeStack[nodeStack.count - 1].append(.element(tag: tag, attrs: attrs, children: []))
            return
        }
        tagStack.append((tag: tag, attrs: attrs))
        nodeStack.append([])
    }

    private func popElement(tag: String) {
        guard !tagStack.isEmpty, !nodeStack.isEmpty, tagStack.last?.tag == tag else {
            // Mismatched close tag: flush accumulated text as-is to parent if possible
            if !nodeStack.isEmpty, nodeStack.count > 1 {
                let orphans = nodeStack.removeLast()
                _ = tagStack.popLast()
                nodeStack[nodeStack.count - 1].append(contentsOf: orphans)
            }
            return
        }
        let children = nodeStack.removeLast()
        let info = tagStack.removeLast()
        let node = FB2Node.element(tag: info.tag, attrs: info.attrs, children: children)
        if nodeStack.isEmpty { return }
        nodeStack[nodeStack.count - 1].append(node)
    }

    private func localName(_ qName: String) -> String {
        if let colon = qName.lastIndex(of: ":") {
            return String(qName[qName.index(after: colon)...])
        }
        return qName
    }
}
