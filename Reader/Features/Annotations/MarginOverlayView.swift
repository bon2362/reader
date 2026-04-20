import SwiftUI

struct MarginOverlayView: View {
    let positions: [AnnotationPosition]
    let notes: [TextNote]
    let expandedId: String?
    let onToggle: (String) -> Void
    let onEdit: (String) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                ForEach(positions, id: \.id) { pos in
                    marker(for: pos, containerHeight: geo.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private func marker(for pos: AnnotationPosition, containerHeight: CGFloat) -> some View {
        let y = max(0, min(containerHeight - 24, CGFloat(pos.y)))
        let note = notes.first { $0.id == pos.id }
        let isExpanded = expandedId == pos.id

        Button {
            onToggle(pos.id)
        } label: {
            Image(systemName: "note.text")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .offset(x: -6, y: y)
        .popover(isPresented: Binding(
            get: { isExpanded },
            set: { if !$0 { onToggle(pos.id) } }
        )) {
            if let note {
                notePopover(note)
            }
        }
    }

    private func notePopover(_ note: TextNote) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(note.body)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button {
                    onEdit(note.id)
                } label: {
                    Label("Изменить", systemImage: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(role: .destructive) {
                    onDelete(note.id)
                } label: {
                    Label("Удалить", systemImage: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}
