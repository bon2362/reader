import SwiftUI

struct IPhoneReaderSearchView: View {
    let store: IPhoneEPUBReaderStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [EPUBSearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Поиск в текущей главе...", text: $query)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .onSubmit { performSearch() }
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                            results = []
                            hasSearched = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding()

                Divider()

                // Results
                if isSearching {
                    Spacer()
                    ProgressView("Поиск...")
                    Spacer()
                } else if results.isEmpty && hasSearched {
                    Spacer()
                    ContentUnavailableView(
                        "Ничего не найдено",
                        systemImage: "magnifyingglass",
                        description: Text("По запросу «\(query)» в текущей главе ничего не найдено.")
                    )
                    Spacer()
                } else if !results.isEmpty {
                    List {
                        Section("\(results.count) совпадений") {
                            ForEach(results) { result in
                                Button {
                                    store.goToSearchResult(offset: result.offset)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        highlightedSnippet(result.snippet, query: query)
                                            .font(.body)
                                            .lineLimit(3)
                                    }
                                    .padding(.vertical, 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listStyle(.plain)
                } else {
                    Spacer()
                    Text("Введите запрос и нажмите «Поиск»")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
            }
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Найти") { performSearch() }
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        hasSearched = true
        Task {
            results = await store.search(query: query)
            isSearching = false
        }
    }

    private func highlightedSnippet(_ snippet: String, query: String) -> Text {
        let lower = snippet.lowercased()
        let lowerQuery = query.lowercased()
        guard !lowerQuery.isEmpty else { return Text(snippet) }

        var result = Text("")
        var searchFrom = lower.startIndex

        while searchFrom < lower.endIndex,
              let matchRange = lower.range(of: lowerQuery, range: searchFrom..<lower.endIndex) {
            // Text before match
            let before = String(snippet[searchFrom..<matchRange.lowerBound])
            if !before.isEmpty { result = result + Text(before) }
            // Matched text
            let match = String(snippet[matchRange])
            result = result + Text(match).bold().foregroundStyle(Color.accentColor)
            searchFrom = matchRange.upperBound
        }
        // Remaining text after last match
        let tail = String(snippet[searchFrom...])
        if !tail.isEmpty { result = result + Text(tail) }
        return result
    }
}
