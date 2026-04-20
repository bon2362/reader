import SwiftUI

struct TextNotePopoverOverlay: View {
    let tappedId: String?
    let point: CGPoint
    let notes: [TextNote]
    let onEdit: (String) -> Void
    let onDelete: (String) -> Void
    let onDismiss: () -> Void

    private let width: CGFloat = 280

    var body: some View {
        GeometryReader { geo in
            if let id = tappedId, let note = notes.first(where: { $0.id == id }) {
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture { onDismiss() }

                    card(note: note)
                        .frame(width: width)
                        .offset(
                            x: clampedX(geo.size.width),
                            y: clampedY(geo.size.height)
                        )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.12), value: tappedId)
    }

    private func clampedX(_ maxW: CGFloat) -> CGFloat {
        let raw = point.x - width / 2
        return max(8, min(maxW - width - 8, raw))
    }

    private func clampedY(_ maxH: CGFloat) -> CGFloat {
        let raw = point.y + 6
        return max(8, min(maxH - 120, raw))
    }

    private func card(note: TextNote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.body)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button {
                    onEdit(note.id)
                    onDismiss()
                } label: {
                    Label("Изменить", systemImage: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(role: .destructive) {
                    onDelete(note.id)
                    onDismiss()
                } label: {
                    Label("Удалить", systemImage: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }
}
