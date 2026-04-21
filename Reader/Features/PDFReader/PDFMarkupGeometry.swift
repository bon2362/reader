import Foundation
import PDFKit

enum PDFMarkupGeometry {
    static func selectionLineBounds(for selection: PDFSelection, on page: PDFPage) -> [CGRect] {
        let lineSelections = selection.selectionsByLine().filter { lineSelection in
            lineSelection.pages.contains { $0 === page }
        }
        let sourceSelections = lineSelections.isEmpty ? [selection] : lineSelections
        return sourceSelections
            .map { $0.bounds(for: page) }
            .filter { !$0.isEmpty }
    }
}
