import SwiftUI

/// Thin always-visible header strip at the top of the reader. Not an overlay —
/// it participates in layout so the webview content is pushed below it.
struct ChapterHeaderBar: View {
    let chapterTitle: String?

    var body: some View {
        HStack {
            Spacer()
            Text(chapterTitle?.isEmpty == false ? chapterTitle! : " ")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(height: 24)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.4)
        }
    }
}
