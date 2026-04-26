import SwiftUI

struct IPhoneAnnotationsView: View {
    let store: IPhoneEPUBReaderStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Тип", selection: $selectedTab) {
                    Text("Хайлайты").tag(0)
                    Text("Заметки").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    highlightsList
                } else {
                    notesList
                }
            }
            .navigationTitle("Аннотации")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    // MARK: - Highlights tab

    private var highlightsList: some View {
        Group {
            if store.highlights.isEmpty {
                ContentUnavailableView(
                    "Нет хайлайтов",
                    systemImage: "highlighter",
                    description: Text("Выделите текст в книге, чтобы добавить хайлайт.")
                )
            } else {
                List {
                    ForEach(store.highlights) { highlight in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(swatchColor(for: highlight.color))
                                    .frame(width: 10, height: 10)
                                Text(highlight.selectedText)
                                    .font(.body)
                                    .lineLimit(3)
                            }
                            Text(highlight.createdAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await store.deleteHighlight(id: highlight.id) }
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Notes tab

    private var notesList: some View {
        Group {
            if store.textNotes.isEmpty {
                ContentUnavailableView(
                    "Нет заметок",
                    systemImage: "note.text",
                    description: Text("Заметки к выделениям появятся здесь.")
                )
            } else {
                List {
                    ForEach(store.textNotes) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            if let selected = note.selectedText, !selected.isEmpty {
                                Text(selected)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Text(note.body)
                                .font(.body)
                                .lineLimit(4)
                            Text(note.createdAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await store.deleteTextNote(id: note.id) }
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func swatchColor(for color: HighlightColor) -> Color {
        switch color {
        case .yellow: return .yellow
        case .red:    return .red
        case .green:  return .green
        case .blue:   return .blue
        case .purple: return .purple
        }
    }
}
