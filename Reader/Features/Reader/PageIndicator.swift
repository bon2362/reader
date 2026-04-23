import SwiftUI

struct PageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    var isReady: Bool = true
    var onSubmitPage: ((Int) -> Void)? = nil
    var onFinishEditing: (() -> Void)? = nil

    @State private var isEditing = false
    @State private var pageText = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        Group {
            if isReady, totalPages > 0 {
                if isEditing {
                    HStack(spacing: 6) {
                        TextField("", text: $pageText)
                            .textFieldStyle(.plain)
                            .frame(width: inputWidth)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputFocused)
                            .onSubmit(commitPageSelection)

                        Text("из \(totalPages)")
                            .foregroundStyle(.secondary)
                    }
                    .onAppear {
                        pageText = String(currentPage)
                        isInputFocused = true
                    }
                    .onExitCommand {
                        finishEditing()
                    }
                } else {
                    Button(action: beginEditing) {
                        Text("стр. \(currentPage) из \(totalPages)")
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("считаем страницы…")
                }
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var inputWidth: CGFloat {
        let digits = max(String(totalPages).count, 2)
        return CGFloat(digits) * 9 + 10
    }

    private func beginEditing() {
        guard onSubmitPage != nil else { return }
        pageText = String(currentPage)
        isEditing = true
    }

    private func commitPageSelection() {
        guard let onSubmitPage,
              let pageNumber = Int(pageText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            finishEditing()
            return
        }

        onSubmitPage(min(max(pageNumber, 1), totalPages))
        finishEditing()
    }

    private func finishEditing() {
        isInputFocused = false
        isEditing = false
        onFinishEditing?()
    }
}
