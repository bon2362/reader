import SwiftUI

struct BookCardView: View {
    let book: Book
    let onOpen: () -> Void
    let onOpenTest: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                coverImage
                    .frame(width: 140, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                if book.format == .pdf {
                    Image(systemName: "doc.richtext")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
                        .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let author = book.author, !author.isEmpty {
                    Text(author)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if book.progress > 0 {
                    ProgressView(value: book.progress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .padding(.top, 4)
                }
            }
            .frame(width: 140, alignment: .leading)
        }
        .onTapGesture(count: 2) { onOpen() }
        .contextMenu {
            Button("Открыть") { onOpen() }
            if book.format == .epub {
                Button("Открыть (тест)") { onOpenTest() }
            }
            Divider()
            Button("Удалить", role: .destructive) { onDelete() }
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        if let path = book.coverPath,
           let nsImage = NSImage(contentsOfFile: path) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Rectangle().fill(
                    LinearGradient(
                        colors: [.gray.opacity(0.3), .gray.opacity(0.5)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                VStack(spacing: 6) {
                    Image(systemName: book.format == .pdf ? "doc.richtext.fill" : "book.closed.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(book.title)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .lineLimit(3)
                }
            }
        }
    }
}
