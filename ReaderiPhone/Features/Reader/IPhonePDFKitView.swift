import PDFKit
import SwiftUI

struct IPhonePDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let onReady: (PDFView) -> Void
    let onDisplayReady: (PDFView) -> Void
    let onPageChanged: (PDFView) -> Void
    let onSelectionChanged: (PDFView) -> Void
    let onHighlightTapped: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onDisplayReady: onDisplayReady,
            onPageChanged: onPageChanged,
            onSelectionChanged: onSelectionChanged,
            onHighlightTapped: onHighlightTapped
        )
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = InteractivePDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(true, withViewOptions: nil)
        pdfView.document = document
        pdfView.onHighlightTapped = onHighlightTapped
        context.coordinator.attach(to: pdfView)

        DispatchQueue.main.async {
            onReady(pdfView)
        }

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
            context.coordinator.resetDisplayReadiness()
        }

        if let pdfView = pdfView as? InteractivePDFView {
            pdfView.onHighlightTapped = onHighlightTapped
        }

        context.coordinator.onDisplayReady = onDisplayReady
        context.coordinator.onPageChanged = onPageChanged
        context.coordinator.onSelectionChanged = onSelectionChanged
        context.coordinator.onHighlightTapped = onHighlightTapped
        context.coordinator.notifyDisplayReadyIfPossible()
    }

    final class InteractivePDFView: PDFView {
        var onHighlightTapped: ((String) -> Void)?
        private var highlightTapRecognizer: UITapGestureRecognizer?

        override func didMoveToWindow() {
            super.didMoveToWindow()

            if highlightTapRecognizer == nil {
                let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleHighlightTap(_:)))
                recognizer.cancelsTouchesInView = false
                addGestureRecognizer(recognizer)
                highlightTapRecognizer = recognizer
            }
        }

        @objc private func handleHighlightTap(_ recognizer: UITapGestureRecognizer) {
            let viewPoint = recognizer.location(in: self)
            guard let page = page(for: viewPoint, nearest: true) else { return }

            let pagePoint = convert(viewPoint, to: page)
            guard let annotation = page.annotation(at: pagePoint),
                  let highlightID = PDFHighlightRenderer.highlightID(for: annotation) else {
                return
            }

            onHighlightTapped?(highlightID)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        var onDisplayReady: (PDFView) -> Void
        var onPageChanged: (PDFView) -> Void
        var onSelectionChanged: (PDFView) -> Void
        var onHighlightTapped: (String) -> Void

        private weak var pdfView: PDFView?
        private var hasReportedDisplayReady = false

        init(
            onDisplayReady: @escaping (PDFView) -> Void,
            onPageChanged: @escaping (PDFView) -> Void,
            onSelectionChanged: @escaping (PDFView) -> Void,
            onHighlightTapped: @escaping (String) -> Void
        ) {
            self.onDisplayReady = onDisplayReady
            self.onPageChanged = onPageChanged
            self.onSelectionChanged = onSelectionChanged
            self.onHighlightTapped = onHighlightTapped
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
                  !hasReportedDisplayReady,
                  pdfView.document != nil,
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

        @objc private func handleVisiblePagesChanged() {
            notifyDisplayReadyIfPossible()
        }

        @objc private func handleScaleChanged() {
            notifyDisplayReadyIfPossible()
        }
    }
}
