import AppKit
import Foundation
import PDFKit

@MainActor
enum PDFHighlightRenderer {
    private static let markerPrefix = "slow-reader:"

    static func apply(highlight: Highlight, in pdfView: PDFView) {
        guard let document = pdfView.document,
              let anchor = PDFAnchor.parse(highlight.cfiStart),
              let range = anchor.range,
              let page = document.page(at: anchor.pageIndex),
              let selection = page.selection(for: range),
              let markup = PDFMarkupGeometry.markup(for: selection, on: page) else {
            return
        }

        remove(highlightID: highlight.id, in: pdfView)
        let annotation = PDFAnnotation(bounds: markup.bounds, forType: .highlight, withProperties: nil)
        annotation.color = nsColor(for: highlight.color).withAlphaComponent(0.35)
        annotation.contents = markerPrefix + highlight.id
        _ = annotation.setValue(markup.quadPoints, forAnnotationKey: PDFAnnotationKey.quadPoints)
        page.addAnnotation(annotation)
    }

    static func remove(highlightID: String, in pdfView: PDFView) {
        guard let document = pdfView.document else { return }
        let marker = markerPrefix + highlightID
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations where annotation.contents == marker {
                page.removeAnnotation(annotation)
            }
        }
    }

    private static func nsColor(for color: HighlightColor) -> NSColor {
        switch color {
        case .yellow: return .systemYellow
        case .red: return .systemRed
        case .green: return .systemGreen
        case .blue: return .systemBlue
        case .purple: return .systemPurple
        }
    }
}
