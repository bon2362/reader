import SwiftUI
import WebKit

struct EPUBTestView: View {
    let epubURL: URL
    let onClose: () -> Void

    @State private var status: String = "Распаковываю..."
    @State private var unpacked: EPUBTestUnpacked?
    @State private var chapterIndex: Int = 0
    @State private var selectedText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("← Назад") { onClose() }
                Spacer()
                if let unpacked {
                    Button("◀") { chapterIndex = max(0, chapterIndex - 1); selectedText = "" }
                        .disabled(chapterIndex == 0)
                    Text("Глава \(chapterIndex + 1) / \(unpacked.chapterURLs.count)")
                        .font(.system(size: 12))
                        .monospacedDigit()
                    Button("▶") { chapterIndex = min(unpacked.chapterURLs.count - 1, chapterIndex + 1); selectedText = "" }
                        .disabled(chapterIndex >= unpacked.chapterURLs.count - 1)
                }
                Spacer()
                Text(selectedText.isEmpty ? "нет выделения" : "✓ \(selectedText.prefix(40))")
                    .font(.system(size: 11))
                    .foregroundStyle(selectedText.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.green))
                    .frame(maxWidth: 300, alignment: .trailing)
                    .lineLimit(1)
            }
            .padding(12)
            .background(.bar)

            Divider()

            if let unpacked {
                EPUBTestWebView(
                    rootDir: unpacked.rootDir,
                    chapterURL: unpacked.chapterURLs[chapterIndex],
                    onSelectionChanged: { selectedText = $0 }
                )
                .id(chapterIndex)
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                    Text(status).font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            do {
                let u = try EPUBTestLoader.unpack(from: epubURL)
                await MainActor.run {
                    self.unpacked = u
                    self.chapterIndex = min(2, u.chapterURLs.count - 1)
                }
            } catch {
                await MainActor.run { self.status = "Ошибка: \(error.localizedDescription)" }
            }
        }
    }
}

private struct EPUBTestWebView: NSViewRepresentable {
    let rootDir: URL
    let chapterURL: URL
    let onSelectionChanged: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectionChanged: onSelectionChanged)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        let js = """
        (function() {
            function post(obj) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.selectionBridge) {
                    window.webkit.messageHandlers.selectionBridge.postMessage(obj);
                }
            }
            document.addEventListener('selectionchange', function() {
                var sel = window.getSelection();
                var text = sel ? sel.toString() : '';
                post({ text: text });
            }, true);
            post({ text: '', debug: 'listener installed' });
        })();
        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(userScript)
        config.userContentController.add(context.coordinator, name: "selectionBridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        if #available(macOS 13.3, *) { webView.isInspectable = true }
        webView.loadFileURL(chapterURL, allowingReadAccessTo: rootDir)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler {
        let onSelectionChanged: (String) -> Void
        init(onSelectionChanged: @escaping (String) -> Void) {
            self.onSelectionChanged = onSelectionChanged
        }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any] else { return }
            let text = (dict["text"] as? String) ?? ""
            onSelectionChanged(text)
        }
    }
}
