import Foundation

struct PDFAnchor: Equatable, Hashable, Sendable {
    let pageIndex: Int
    let charStart: Int?
    let charEnd: Int?

    init(pageIndex: Int, charStart: Int? = nil, charEnd: Int? = nil) {
        self.pageIndex = pageIndex
        self.charStart = charStart
        self.charEnd = charEnd
    }

    var pageOnlyString: String {
        "pdf:\(pageIndex)"
    }

    var stringValue: String {
        guard let charStart, let charEnd else {
            return pageOnlyString
        }
        return "pdf:\(pageIndex)|\(charStart)-\(charEnd)"
    }

    var range: NSRange? {
        guard let charStart, let charEnd, charEnd >= charStart else { return nil }
        return NSRange(location: charStart, length: charEnd - charStart)
    }

    static func encode(pageIndex: Int, charStart: Int, charEnd: Int) -> String {
        PDFAnchor(pageIndex: pageIndex, charStart: charStart, charEnd: charEnd).stringValue
    }

    static func encodePage(_ pageIndex: Int) -> String {
        PDFAnchor(pageIndex: pageIndex).pageOnlyString
    }

    static func parse(_ raw: String) -> PDFAnchor? {
        guard raw.hasPrefix("pdf:") else { return nil }
        let body = String(raw.dropFirst(4))
        let parts = body.split(separator: "|", maxSplits: 1).map(String.init)
        guard let pageIndex = Int(parts[0]), pageIndex >= 0 else { return nil }
        guard parts.count == 2 else {
            return PDFAnchor(pageIndex: pageIndex)
        }

        let rangeParts = parts[1].split(separator: "-", maxSplits: 1).map(String.init)
        guard rangeParts.count == 2,
              let start = Int(rangeParts[0]),
              let end = Int(rangeParts[1]),
              start >= 0,
              end >= start else {
            return nil
        }
        return PDFAnchor(pageIndex: pageIndex, charStart: start, charEnd: end)
    }
}
