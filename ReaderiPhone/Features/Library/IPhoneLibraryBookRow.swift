import SwiftUI

private enum IPhoneLibraryBookRowLayout {
    static let coverWidth: CGFloat = 56
    static let coverHeight: CGFloat = 78
}

private struct IPhoneBookCoverView: View {
    let coverPath: String?
    let title: String

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.teal.opacity(0.22), .blue.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .task(id: coverPath) {
            image = coverPath.flatMap(UIImage.init(contentsOfFile:))
        }
    }
}

struct IPhoneLibraryBookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: 14) {
            IPhoneBookCoverView(coverPath: book.coverPath, title: book.title)
                .frame(
                    width: IPhoneLibraryBookRowLayout.coverWidth,
                    height: IPhoneLibraryBookRowLayout.coverHeight
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(book.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let author = book.author, author.isEmpty == false {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Text(book.format.badgeTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.12), in: Capsule())

                    if book.progress > 0 {
                        Text("\(Int((book.progress * 100).rounded()))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if book.progress > 0 {
                    ProgressView(value: book.progress)
                        .progressViewStyle(.linear)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
