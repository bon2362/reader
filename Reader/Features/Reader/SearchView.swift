import SwiftUI

struct SearchView: View {
    @Bindable var store: SearchStore
    let onSelect: (SearchResult) -> Void
    let onClose: () -> Void

    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Поиск по книге…", text: Binding(
                    get: { store.query },
                    set: { store.updateQuery($0) }
                ))
                .textFieldStyle(.plain)
                .focused($fieldFocused)
                .onSubmit {
                    if let first = store.results.first { select(first) }
                }

                if !store.query.isEmpty {
                    Button {
                        store.updateQuery("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .hoverLift()
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .hoverLift()
                .keyboardShortcut(.escape, modifiers: [])
                .help("Закрыть (Esc)")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            content
        }
        .frame(minWidth: 280)
        .background(.regularMaterial)
        .onAppear { fieldFocused = true }
    }

    @ViewBuilder
    private var content: some View {
        let trimmed = store.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            recentSection
        } else {
            statusLine
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            Divider()
            resultsList
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        if store.recent.isEmpty {
            Text("Начните вводить запрос")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack {
                Text("Недавние")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button("Очистить") { store.clearRecent() }
                    .font(.system(size: 10))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .hoverLift()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            List(store.recent, id: \.self) { value in
                Button { store.useRecent(value) } label: {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.system(size: 12))
                            .lineLimit(1)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if store.isSearching {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Поиск…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        } else if store.results.isEmpty {
            Text("Ничего не найдено")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else {
            Text("\(store.results.count) \(pluralResults(store.results.count))")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        if store.results.isEmpty {
            Color.clear.frame(maxHeight: .infinity)
        } else {
            List(store.results, id: \.cfi) { result in
                Button { select(result) } label: {
                    Text(highlight(excerpt: result.excerpt, query: store.query))
                        .font(.system(size: 12))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func select(_ result: SearchResult) {
        store.selectResult(result)
        onSelect(result)
    }

    private func highlight(excerpt: String, query: String) -> AttributedString {
        var attr = AttributedString(excerpt)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return attr }
        if let range = attr.range(of: trimmed, options: .caseInsensitive) {
            attr[range].foregroundColor = .accentColor
            attr[range].inlinePresentationIntent = .stronglyEmphasized
        }
        return attr
    }

    private func pluralResults(_ n: Int) -> String {
        let mod10 = n % 10
        let mod100 = n % 100
        if mod10 == 1 && mod100 != 11 { return "результат" }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return "результата" }
        return "результатов"
    }
}
