import SwiftUI

struct NoteEditorView: View {
    let selectedText: String?
    let initialBody: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(
        selectedText: String?,
        initialBody: String = "",
        onSave: @escaping (String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.selectedText = selectedText
        self.initialBody = initialBody
        self.onSave = onSave
        self.onCancel = onCancel
        _text = State(initialValue: initialBody)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedText, !selectedText.isEmpty {
                Text("«\(selectedText)»")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }

            TextEditor(text: $text)
                .focused($focused)
                .font(.system(size: 13))
                .frame(minHeight: 140)
                .padding(6)
                .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                .onSubmit { save() }

            HStack {
                Spacer()
                Button("Отмена", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Сохранить") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onAppear { focused = true }
    }

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
    }
}
