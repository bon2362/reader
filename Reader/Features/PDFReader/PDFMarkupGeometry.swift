import Foundation
import PDFKit

enum PDFMarkupGeometry {
    struct Markup {
        let bounds: CGRect
        let quadPoints: [NSNumber]
    }

    static func markup(for selection: PDFSelection, on page: PDFPage) -> Markup? {
        let lineBounds = selectionLineBounds(for: selection, on: page)
        let bounds = lineBounds.reduce(CGRect?.none) { partial, rect in
            guard let partial else { return rect }
            return partial.union(rect)
        }
        guard let bounds else {
            return nil
        }

        let quadPoints = lineBounds.flatMap(quadPoints(for:))
        guard !quadPoints.isEmpty else { return nil }
        return Markup(bounds: bounds, quadPoints: quadPoints)
    }

    static func selectionLineBounds(for selection: PDFSelection, on page: PDFPage) -> [CGRect] {
        let lineSelections = selection.selectionsByLine().filter { lineSelection in
            lineSelection.pages.contains { $0 === page }
        }
        let sourceSelections = lineSelections.isEmpty ? [selection] : lineSelections
        return sourceSelections
            .map { $0.bounds(for: page) }
            .filter { !$0.isEmpty }
    }

    private static func quadPoints(for bounds: CGRect) -> [NSNumber] {
        [
            NSNumber(value: bounds.minX),
            NSNumber(value: bounds.maxY),
            NSNumber(value: bounds.maxX),
            NSNumber(value: bounds.maxY),
            NSNumber(value: bounds.minX),
            NSNumber(value: bounds.minY),
            NSNumber(value: bounds.maxX),
            NSNumber(value: bounds.minY)
        ]
    }
}
