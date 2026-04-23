import SwiftUI

private enum LibraryCardLayout {
    static let coverWidth: CGFloat = 140
    static let coverHeight: CGFloat = 200
}
private struct BookCoverImageView: View {
    let coverPath: String?
    let title: String
    let format: BookFormat

    @State private var nsImage: NSImage?

    var body: some View {
        Group {
            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderCover
            }
        }
        .task(id: coverPath) {
            nsImage = coverPath.flatMap(NSImage.init(contentsOfFile:))
        }
    }

    private var placeholderCover: some View {
        ZStack {
            Rectangle().fill(
                LinearGradient(
                    colors: [.gray.opacity(0.3), .gray.opacity(0.5)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            VStack(spacing: 6) {
                Image(systemName: format == .pdf ? "doc.richtext.fill" : "book.closed.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.7))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .lineLimit(3)
            }
        }
    }
}

struct BookCardView: View {
    let book: Book
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onOpenTest: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                coverImage
                    .frame(width: LibraryCardLayout.coverWidth, height: LibraryCardLayout.coverHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                HStack(spacing: 6) {
                    if isSelected {
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.primary.opacity(0.82))
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.72))
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary.opacity(0.28), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.14), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                        .help("Удалить книгу")
                    }
                }
                .padding(6)
            }

            VStack(alignment: .leading, spacing: 4) {
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

                formatBadge
                    .padding(.top, 2)
            }
            .frame(width: LibraryCardLayout.coverWidth, alignment: .leading)
        }
        .padding(10)
        .background(cardBackground)
        .overlay(cardBorder)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: shadowColor, radius: 6, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onHover { hovered in
            isHovered = hovered
        }
        .onTapGesture { onSelect() }
        // Keep double-click open behavior without forcing single-click selection
        // to wait for the double-click recognition timeout.
        .simultaneousGesture(
            TapGesture(count: 2).onEnded { onOpen() }
        )
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .animation(.easeInOut(duration: 0.14), value: isSelected)
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
        BookCoverImageView(
            coverPath: book.coverPath,
            title: book.title,
            format: book.format
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(backgroundFill)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
    }

    private var backgroundFill: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        if isHovered {
            return Color.primary.opacity(0.05)
        }
        return Color.clear
    }

    private var borderColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.9)
        }
        if isHovered {
            return Color.primary.opacity(0.16)
        }
        return Color.primary.opacity(0.08)
    }

    private var shadowColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.18)
        }
        return Color.black.opacity(isHovered ? 0.14 : 0.08)
    }

    private var formatBadge: some View {
        Text(book.format.badgeTitle)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.primary.opacity(0.08), in: Capsule())
            .fixedSize()
    }
}

struct AddBookCardView: View {
    let onAdd: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(
                                    Color.accentColor.opacity(isHovered ? 0.55 : 0.32),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 6])
                                )
                        )
                        .frame(width: LibraryCardLayout.coverWidth, height: LibraryCardLayout.coverHeight)

                    VStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.accentColor)

                        Text("Добавить книгу")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("EPUB или PDF")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Импорт")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Text("Новая книга")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text("БИБЛИОТЕКА")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                        .fixedSize()
                        .padding(.top, 2)
                }
                .frame(width: LibraryCardLayout.coverWidth, alignment: .leading)
            }
            .padding(10)
            .background(cardBackground)
            .overlay(cardBorder)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .shadow(color: Color.black.opacity(isHovered ? 0.12 : 0.06), radius: 6, x: 0, y: 4)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            isHovered = hovered
        }
        .animation(.easeInOut(duration: 0.14), value: isHovered)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isHovered ? Color.accentColor.opacity(0.06) : Color.clear)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(
                isHovered ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.08),
                lineWidth: 1
            )
    }
}
