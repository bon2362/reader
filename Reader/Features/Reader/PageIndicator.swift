import SwiftUI

struct PageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    var isReady: Bool = true

    var body: some View {
        Group {
            if isReady, totalPages > 0 {
                Text("стр. \(currentPage) из \(totalPages)")
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
}
