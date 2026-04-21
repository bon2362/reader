import AppKit
import Foundation
import PDFKit

@MainActor
enum PDFTextNoteRenderer {
    private static let markerPrefix = "slow-reader-note:"
    private static let hoverMarkerPrefix = "slow-reader-note-hover:"
    private static let normalDashPattern: [NSNumber] = [2, 2]
    private static let hoveredDashPattern: [NSNumber] = [3, 2]

    static func sync(notes: [TextNote], in pdfView: PDFView) {
        removeStaleAnnotations(keeping: Set(notes.map(\.id)), in: pdfView)
        for note in notes {
            remove(noteID: note.id, in: pdfView)
            apply(note: note, in: pdfView)
        }
    }

    static func apply(note: TextNote, in pdfView: PDFView) {
        guard let document = pdfView.document,
              let anchor = PDFAnchor.parse(note.cfiAnchor),
              let range = anchor.range,
              let page = document.page(at: anchor.pageIndex),
              let selection = page.selection(for: range) else {
            return
        }

        for bounds in PDFMarkupGeometry.selectionLineBounds(for: selection, on: page) {
            let annotation = PDFAnnotation(bounds: bounds, forType: .underline, withProperties: nil)
            annotation.color = normalColor
            let border = PDFBorder()
            border.lineWidth = 1.5
            border.style = .dashed
            border.dashPattern = normalDashPattern
            annotation.border = border
            annotation.contents = markerPrefix + note.id
            page.addAnnotation(annotation)
        }
    }

    static func remove(noteID: String, in pdfView: PDFView) {
        guard let document = pdfView.document else { return }
        let idsToRemove = [markerPrefix + noteID, hoverMarkerPrefix + noteID]
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations where idsToRemove.contains(annotation.contents ?? "") {
                page.removeAnnotation(annotation)
            }
        }
    }

    static func noteID(for annotation: PDFAnnotation) -> String? {
        guard let contents = annotation.contents else { return nil }
        if contents.hasPrefix(markerPrefix) {
            return String(contents.dropFirst(markerPrefix.count))
        }
        if contents.hasPrefix(hoverMarkerPrefix) {
            return String(contents.dropFirst(hoverMarkerPrefix.count))
        }
        return nil
    }

    static func noteAnnotation(for annotation: PDFAnnotation, on page: PDFPage) -> PDFAnnotation? {
        guard let noteID = noteID(for: annotation) else { return nil }
        if annotation.contents == markerPrefix + noteID {
            return annotation
        }
        return page.annotations.first(where: { $0.contents == markerPrefix + noteID })
    }

    static func setHovered(_ isHovered: Bool, for annotation: PDFAnnotation) {
        guard let noteID = noteID(for: annotation),
              let page = annotation.page else {
            return
        }

        let border = annotation.border ?? PDFBorder()
        border.style = .dashed
        border.lineWidth = isHovered ? 2.5 : 1.5
        border.dashPattern = isHovered ? hoveredDashPattern : normalDashPattern
        annotation.border = border
        annotation.color = isHovered ? hoveredColor : normalColor

        if isHovered {
            addHoverDecoration(noteID: noteID, basedOn: annotation, page: page)
        } else {
            removeHoverDecoration(noteID: noteID, from: page)
        }
    }

    private static var normalColor: NSColor {
        NSColor.systemYellow.withAlphaComponent(0.95)
    }

    private static var hoveredColor: NSColor {
        NSColor.systemOrange.withAlphaComponent(0.98)
    }

    private static func addHoverDecoration(noteID: String, basedOn annotation: PDFAnnotation, page: PDFPage) {
        removeHoverDecoration(noteID: noteID, from: page)
        let hover = PDFAnnotation(bounds: annotation.bounds, forType: .highlight, withProperties: nil)
        hover.color = NSColor.systemYellow.withAlphaComponent(0.18)
        hover.contents = hoverMarkerPrefix + noteID
        page.addAnnotation(hover)
    }

    private static func removeHoverDecoration(noteID: String, from page: PDFPage) {
        let marker = hoverMarkerPrefix + noteID
        for annotation in page.annotations where annotation.contents == marker {
            page.removeAnnotation(annotation)
        }
    }

    private static func isManagedAnnotation(_ annotation: PDFAnnotation) -> Bool {
        guard let contents = annotation.contents else { return false }
        return contents.hasPrefix(markerPrefix) || contents.hasPrefix(hoverMarkerPrefix)
    }

    private static func removeStaleAnnotations(keeping noteIDs: Set<String>, in pdfView: PDFView) {
        guard let document = pdfView.document else { return }
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            for annotation in page.annotations where isManagedAnnotation(annotation) {
                guard let noteID = noteID(for: annotation),
                      !noteIDs.contains(noteID) else {
                    continue
                }
                page.removeAnnotation(annotation)
            }
        }
    }
}
