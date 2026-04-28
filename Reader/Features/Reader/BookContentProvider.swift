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
            let text = EPUBBook.htmlBodyTextContent(html)
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

enum EPUBPageMapper {
    static func isValid(counts: [Int], chapterCount: Int) -> Bool {
        counts.count == chapterCount && counts.allSatisfy { $0 > 0 }
    }

    static func globalPage(chapterIndex: Int, pageInChapter: Int, counts: [Int]) -> Int? {
        guard counts.indices.contains(chapterIndex),
              counts.prefix(chapterIndex).allSatisfy({ $0 > 0 }),
              counts[chapterIndex] > 0 else {
            return nil
        }
        let localPage = min(max(0, pageInChapter), counts[chapterIndex] - 1)
        return counts.prefix(chapterIndex).reduce(0, +) + localPage + 1
    }

    static func target(forGlobalPage page: Int, counts: [Int]) -> (chapterIndex: Int, pageInChapter: Int)? {
        guard !counts.isEmpty, counts.allSatisfy({ $0 > 0 }) else { return nil }
        let capped = min(max(1, page), counts.reduce(0, +)) - 1
        var running = 0
        for (index, count) in counts.enumerated() {
            let next = running + count
            if capped < next {
                return (index, capped - running)
            }
            running = next
        }
        return (counts.count - 1, max(0, counts.last! - 1))
    }

    static func target(forValidGlobalPage page: Int, counts: [Int]) -> (chapterIndex: Int, pageInChapter: Int)? {
        guard !counts.isEmpty, counts.allSatisfy({ $0 > 0 }) else { return nil }
        let total = counts.reduce(0, +)
        guard (1...total).contains(page) else { return nil }
        return target(forGlobalPage: page, counts: counts)
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
