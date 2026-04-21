import PDFKit
import SwiftUI

struct IPhonePDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let onReady: (PDFView) -> Void
    let onPageChanged: (PDFView) -> Void
    let onSelectionChanged: (PDFView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPageChanged: onPageChanged, onSelectionChanged: onSelectionChanged)
    }

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = document
        context.coordinator.attach(to: view)
        DispatchQueue.main.async {
            onReady(view)
        }
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
            context.coordinator.attach(to: uiView)
        }
    }

    final class Coordinator: NSObject {
        private let onPageChanged: (PDFView) -> Void
        private let onSelectionChanged: (PDFView) -> Void

        init(onPageChanged: @escaping (PDFView) -> Void, onSelectionChanged: @escaping (PDFView) -> Void) {
            self.onPageChanged = onPageChanged
            self.onSelectionChanged = onSelectionChanged
        }

        func attach(to pdfView: PDFView) {
            let center = NotificationCenter.default
            center.removeObserver(self)
            center.addObserver(self, selector: #selector(pageChanged(_:)), name: .PDFViewPageChanged, object: pdfView)
            center.addObserver(self, selector: #selector(selectionChanged(_:)), name: .PDFViewSelectionChanged, object: pdfView)
        }

        @objc private func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            onPageChanged(pdfView)
        }

        @objc private func selectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView else { return }
            onSelectionChanged(pdfView)
        }
    }
}
