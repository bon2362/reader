import Foundation
import Observation

@MainActor
@Observable
final class TOCStore {
    var entries: [TOCEntry] = []
    var currentEntryId: String?
    var isVisible: Bool = false

    var currentEntry: TOCEntry? {
        guard let id = currentEntryId else { return nil }
        return entries.first { $0.id == id }
    }

    func setEntries(_ entries: [TOCEntry]) {
        self.entries = entries
        if currentEntryId == nil, let first = entries.first {
            currentEntryId = first.id
        }
    }

    func updateCurrentSection(href: String?) {
        guard let href, !href.isEmpty else { return }
        let normalized = normalize(href)
        let matches = entries.filter { normalize($0.href).hasPrefix(normalized) || normalized.hasPrefix(normalize($0.href)) }
        if let best = matches.max(by: { $0.level < $1.level }) {
            currentEntryId = best.id
        }
    }

    func toggleVisibility() { isVisible.toggle() }

    private func normalize(_ href: String) -> String {
        var s = href
        if let hashIdx = s.firstIndex(of: "#") { s = String(s[..<hashIdx]) }
        while s.hasPrefix("/") { s.removeFirst() }
        return s
    }
}
