import SwiftUI

struct StickyNotesOverlayView: View {
    let notes: [PageNote]
    let expandedId: String?
    let onToggle: (String) -> Void
    let onUpdate: (String, String) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(notes.enumerated()), id: \.element.id) { _, note in
                marker(note: note)
            }
            Spacer()
        }
        .padding(.top, 80)
        .padding(.trailing, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .allowsHitTesting(true)
    }

    @ViewBuilder
    private func marker(note: PageNote) -> some View {
        let isExpanded = expandedId == note.id
        Button {
            onToggle(note.id)
        } label: {
            Image(systemName: note.body.isEmpty ? "note.text.badge.plus" : "note.text")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(Color.yellow.opacity(0.55), in: Circle())
                .overlay(Circle().stroke(Color.primary.opacity(0.18), lineWidth: 1))
                .shadow(radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .popover(isPresented: Binding(
            get: { isExpanded },
            set: { if !$0 { onToggle(note.id) } }
        )) {
            StickyNotePopover(
                note: note,
                onUpdate: { onUpdate(note.id, $0) },
                onDelete: { onDelete(note.id) }
            )
        }
    }
}

private struct StickyNotePopover: View {
    let note: PageNote
    let onUpdate: (String) -> Void
    let onDelete: () -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(note: PageNote, onUpdate: @escaping (String) -> Void, onDelete: @escaping () -> Void) {
        self.note = note
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        _text = State(initialValue: note.body)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $text)
                .focused($focused)
                .font(.system(size: 13))
                .frame(minHeight: 140)
                .padding(6)
                .background(Color.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                .onChange(of: text) { _, newValue in
                    onUpdate(newValue)
                }

            HStack {
                Text("Гл. \(note.spineIndex + 1) · стр. \(note.pageInChapter + 1)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Label("Удалить", systemImage: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 280)
        .onAppear { focused = true }
    }
}
