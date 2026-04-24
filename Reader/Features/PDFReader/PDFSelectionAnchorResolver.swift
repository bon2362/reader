import CoreGraphics
import Foundation
import PDFKit

enum PDFSelectionAnchorResolver {
    static func makeAnchor(for selection: PDFSelection, on page: PDFPage, pageIndex: Int) -> PDFAnchor? {
        guard let pageText = page.string,
              let rawSelectedText = selection.string,
              rawSelectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        let nsText = pageText as NSString
        let targetBounds = selection.bounds(for: page)
        let candidates = selectionQueries(from: rawSelectedText)

        var bestRange: NSRange?
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for query in candidates {
            for range in allRanges(of: query, in: nsText) {
                guard let candidateSelection = page.selection(for: range) else { continue }
                let bounds = candidateSelection.bounds(for: page)
                let distance = hypot(bounds.midX - targetBounds.midX, bounds.midY - targetBounds.midY)
                if distance < bestDistance {
                    bestDistance = distance
                    bestRange = range
                }
            }
            if bestRange != nil {
                break
            }
        }

        guard let bestRange else { return nil }
        return PDFAnchor(
            pageIndex: pageIndex,
            charStart: bestRange.location,
            charEnd: bestRange.location + bestRange.length
        )
    }

    private static func selectionQueries(from rawSelectedText: String) -> [String] {
        var queries: [String] = []
        let raw = rawSelectedText
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedWhitespace = trimmed.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )

        for query in [raw, trimmed, normalizedWhitespace] {
            guard query.isEmpty == false, queries.contains(query) == false else { continue }
            queries.append(query)
        }
        return queries
    }

    private static func allRanges(of needle: String, in haystack: NSString) -> [NSRange] {
        guard needle.isEmpty == false else { return [] }
        var result: [NSRange] = []
        var searchRange = NSRange(location: 0, length: haystack.length)

        while true {
            let found = haystack.range(of: needle, options: [], range: searchRange)
            guard found.location != NSNotFound else { break }
            result.append(found)
            let nextLocation = found.location + max(found.length, 1)
            guard nextLocation < haystack.length else { break }
            searchRange = NSRange(location: nextLocation, length: haystack.length - nextLocation)
        }

        return result
    }
}
