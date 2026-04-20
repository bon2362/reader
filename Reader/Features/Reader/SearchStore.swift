import Foundation
import Observation

@MainActor
@Observable
final class SearchStore {
    var query: String = ""
    var results: [SearchResult] = []
    var isSearching: Bool = false
    var isVisible: Bool = false
    var recent: [String] = []

    private weak var bridge: EPUBBridgeProtocol?
    private var debounceTask: Task<Void, Never>?

    static let debounceNanos: UInt64 = 300_000_000
    private static let recentKey = "reader.recentSearches"
    private static let recentLimit = 10

    init() {
        loadRecent()
    }

    func bindBridge(_ bridge: EPUBBridgeProtocol) {
        self.bridge = bridge
    }

    func show() {
        isVisible = true
    }

    func hide() {
        isVisible = false
        debounceTask?.cancel()
        isSearching = false
    }

    func toggleVisibility() {
        if isVisible { hide() } else { show() }
    }

    func updateQuery(_ newValue: String) {
        query = newValue
        debounceTask?.cancel()

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: SearchStore.debounceNanos)
            guard !Task.isCancelled else { return }
            self?.dispatchSearch(trimmed)
        }
    }

    private func dispatchSearch(_ query: String) {
        bridge?.search(query: query)
    }

    func handleResults(_ results: [SearchResult]) {
        self.results = results
        isSearching = false
    }

    func selectResult(_ result: SearchResult) {
        bridge?.goToCFI(result.cfi)
        commitRecent(query)
    }

    // MARK: - Recent

    func useRecent(_ value: String) {
        updateQuery(value)
    }

    func clearRecent() {
        recent = []
        persistRecent()
    }

    private func commitRecent(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recent.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recent.insert(trimmed, at: 0)
        if recent.count > SearchStore.recentLimit {
            recent = Array(recent.prefix(SearchStore.recentLimit))
        }
        persistRecent()
    }

    private func loadRecent() {
        recent = UserDefaults.standard.stringArray(forKey: SearchStore.recentKey) ?? []
    }

    private func persistRecent() {
        UserDefaults.standard.set(recent, forKey: SearchStore.recentKey)
    }
}
