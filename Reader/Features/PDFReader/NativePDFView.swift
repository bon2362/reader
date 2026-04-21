import PDFKit
import SwiftUI

struct NativePDFView: NSViewRepresentable {
    let document: PDFDocument
    let onViewReady: (PDFView) -> Void
    let onDisplayReady: (PDFView) -> Void
    let onPageChanged: (PDFView) -> Void
    let onSelectionChanged: (PDFView) -> Void
    let onHistoryChanged: (PDFView) -> Void
    let onNoteAnnotationTap: (String, CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onDisplayReady: onDisplayReady,
            onPageChanged: onPageChanged,
            onSelectionChanged: onSelectionChanged,
            onHistoryChanged: onHistoryChanged
        )
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = InteractivePDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = true
        pdfView.document = document
        pdfView.onNoteAnnotationTap = onNoteAnnotationTap
        pdfView.onPresentationChanged = { [weak coordinator = context.coordinator] pdfView in
            coordinator?.notifyDisplayReadyIfPossible(for: pdfView)
        }
        context.coordinator.attach(to: pdfView)

        DispatchQueue.main.async {
            onViewReady(pdfView)
        }

        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
            context.coordinator.resetDisplayReadiness()
        }
        if let pdfView = pdfView as? InteractivePDFView {
            pdfView.onNoteAnnotationTap = onNoteAnnotationTap
            pdfView.onPresentationChanged = { [weak coordinator = context.coordinator] pdfView in
                coordinator?.notifyDisplayReadyIfPossible(for: pdfView)
            }
        }
        context.coordinator.onDisplayReady = onDisplayReady
        context.coordinator.onPageChanged = onPageChanged
        context.coordinator.onSelectionChanged = onSelectionChanged
        context.coordinator.onHistoryChanged = onHistoryChanged
        context.coordinator.notifyDisplayReadyIfPossible()
    }

    final class InteractivePDFView: PDFView {
        var onNoteAnnotationTap: ((String, CGPoint) -> Void)?
        var onPresentationChanged: ((PDFView) -> Void)?
        private var trackingAreaRef: NSTrackingArea?
        private weak var hoveredAnnotation: PDFAnnotation?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.acceptsMouseMovedEvents = true
            notifyPresentationChanged()
        }

        override func layout() {
            super.layout()
            notifyPresentationChanged()
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingAreaRef {
                removeTrackingArea(trackingAreaRef)
            }
            let trackingArea = NSTrackingArea(
                rect: .zero,
                options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(trackingArea)
            trackingAreaRef = trackingArea
        }

        override func mouseDown(with event: NSEvent) {
            let viewPoint = convert(event.locationInWindow, from: nil)
            if let page = page(for: viewPoint, nearest: true) {
                let pagePoint = convert(viewPoint, to: page)
                if let annotation = page.annotation(at: pagePoint),
                   let noteID = PDFTextNoteRenderer.noteID(for: annotation) {
                    onNoteAnnotationTap?(noteID, viewPoint)
                    return
                }
            }
            super.mouseDown(with: event)
        }

        override func mouseMoved(with event: NSEvent) {
            updateHover(at: convert(event.locationInWindow, from: nil))
            super.mouseMoved(with: event)
        }

        override func mouseExited(with event: NSEvent) {
            clearHoveredAnnotation()
            NSCursor.arrow.set()
            super.mouseExited(with: event)
        }

        private func updateHover(at viewPoint: CGPoint) {
            guard let page = page(for: viewPoint, nearest: false) else {
                clearHoveredAnnotation()
                NSCursor.arrow.set()
                return
            }

            let pagePoint = convert(viewPoint, to: page)
            guard let hitAnnotation = page.annotation(at: pagePoint),
                  let annotation = PDFTextNoteRenderer.noteAnnotation(for: hitAnnotation, on: page) else {
                clearHoveredAnnotation()
                NSCursor.arrow.set()
                return
            }

            if hoveredAnnotation !== annotation {
                clearHoveredAnnotation()
                PDFTextNoteRenderer.setHovered(true, for: annotation)
                hoveredAnnotation = annotation
                annotationsChanged(on: page)
            }
            NSCursor.pointingHand.set()
        }

        private func clearHoveredAnnotation() {
            guard let hoveredAnnotation else { return }
            PDFTextNoteRenderer.setHovered(false, for: hoveredAnnotation)
            if let page = hoveredAnnotation.page {
                annotationsChanged(on: page)
            }
            self.hoveredAnnotation = nil
        }

        private func notifyPresentationChanged() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onPresentationChanged?(self)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onDisplayReady: (PDFView) -> Void
        var onPageChanged: (PDFView) -> Void
        var onSelectionChanged: (PDFView) -> Void
        var onHistoryChanged: (PDFView) -> Void
        private weak var pdfView: PDFView?
        private var hasReportedDisplayReady = false

        init(
            onDisplayReady: @escaping (PDFView) -> Void,
            onPageChanged: @escaping (PDFView) -> Void,
            onSelectionChanged: @escaping (PDFView) -> Void,
            onHistoryChanged: @escaping (PDFView) -> Void
        ) {
            self.onDisplayReady = onDisplayReady
            self.onPageChanged = onPageChanged
            self.onSelectionChanged = onSelectionChanged
            self.onHistoryChanged = onHistoryChanged
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func attach(to pdfView: PDFView) {
            self.pdfView = pdfView
            hasReportedDisplayReady = false
            let center = NotificationCenter.default
            center.removeObserver(self)
            center.addObserver(
                self,
                selector: #selector(handlePageChanged),
                name: .PDFViewPageChanged,
                object: pdfView
            )
            center.addObserver(
                self,
                selector: #selector(handleSelectionChanged),
                name: .PDFViewSelectionChanged,
                object: pdfView
            )
            center.addObserver(
                self,
                selector: #selector(handleHistoryChanged),
                name: .PDFViewChangedHistory,
                object: pdfView
            )
            center.addObserver(
                self,
                selector: #selector(handleVisiblePagesChanged),
                name: .PDFViewVisiblePagesChanged,
                object: pdfView
            )
            center.addObserver(
                self,
                selector: #selector(handleScaleChanged),
                name: .PDFViewScaleChanged,
                object: pdfView
            )

            DispatchQueue.main.async { [weak self] in
                self?.notifyDisplayReadyIfPossible()
            }
        }

        func resetDisplayReadiness() {
            hasReportedDisplayReady = false
            DispatchQueue.main.async { [weak self] in
                self?.notifyDisplayReadyIfPossible()
            }
        }

        func notifyDisplayReadyIfPossible() {
            guard let pdfView else { return }
            notifyDisplayReadyIfPossible(for: pdfView)
        }

        func notifyDisplayReadyIfPossible(for pdfView: PDFView) {
            guard self.pdfView === pdfView,
                  !hasReportedDisplayReady else { return }
            guard pdfView.document != nil,
                  pdfView.window != nil,
                  !pdfView.bounds.isEmpty else {
                return
            }

            hasReportedDisplayReady = true
            onDisplayReady(pdfView)
        }

        @objc private func handlePageChanged() {
            guard let pdfView else { return }
            onPageChanged(pdfView)
        }

        @objc private func handleSelectionChanged() {
            guard let pdfView else { return }
            onSelectionChanged(pdfView)
        }

        @objc private func handleHistoryChanged() {
            guard let pdfView else { return }
            onHistoryChanged(pdfView)
        }

        @objc private func handleVisiblePagesChanged() {
            notifyDisplayReadyIfPossible()
        }

        @objc private func handleScaleChanged() {
            notifyDisplayReadyIfPossible()
        }
    }
}
