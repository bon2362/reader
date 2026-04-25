import Foundation

protocol BookContentProvider: AnyObject, Sendable {
    var rootDir: URL { get }
    var chapters: [EPUBChapter] { get }
    var toc: [EPUBTOCNode] { get }
    func chapterIndex(forHref href: String) -> Int?
    func search(query: String, limit: Int) -> [SearchResult]
}

extension BookContentProvider {
    func search(query: String, limit: Int) -> [SearchResult] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty, limit > 0 else { return [] }
        var results: [SearchResult] = []
        for chapter in chapters {
            guard let html = try? String(contentsOf: chapter.fileURL, encoding: .utf8) else { continue }
            let text = EPUBBook.htmlTextContent(html)
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(
                    of: needle,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchStart..<text.endIndex
                  ) {
                let offset = range.lowerBound.utf16Offset(in: text)
                let cfi = EPUBBook.makeOffsetAnchor(
                    href: EPUBBook.normalizeHref(chapter.href),
                    offset: offset
                )
                results.append(SearchResult(cfi: cfi, excerpt: EPUBBook.excerpt(in: text, around: range)))
                if results.count >= limit { return results }
                searchStart = range.upperBound
            }
        }
        return results
    }
}

enum BookContentLoaderError: LocalizedError {
    case unsupportedFormat

    var errorDescription: String? { "Формат файла не поддерживается" }
}

enum BookContentLoader {
    static func load(from url: URL) throws -> any BookContentProvider {
        switch url.pathExtension.lowercased() {
        case "epub": return try EPUBBookLoader.load(from: url)
        case "fb2":  return try FB2BookLoader.load(from: url)
        default:     throw BookContentLoaderError.unsupportedFormat
        }
    }
}
