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
        guard let currentEntryId,
              entries.contains(where: { $0.id == currentEntryId }) else {
            self.currentEntryId = entries.first?.id
            return
        }
        self.currentEntryId = currentEntryId
    }

    func updateCurrentSection(href: String?) {
        guard let href, !href.isEmpty else { return }
        let normalized = normalize(href)
        let matches = entries.filter { normalize($0.href).hasPrefix(normalized) || normalized.hasPrefix(normalize($0.href)) }
        if let best = matches.max(by: { $0.level < $1.level }) {
            currentEntryId = best.id
        }
    }

    func updateCurrentPDFPage(_ pageIndex: Int) {
        let matches = entries.compactMap { entry -> (TOCEntry, Int)? in
            guard let anchor = PDFAnchor.parse(entry.href) else { return nil }
            return (entry, anchor.pageIndex)
        }
        guard let best = matches
            .filter({ $0.1 <= pageIndex })
            .max(by: { $0.1 < $1.1 }) else {
            return
        }
        currentEntryId = best.0.id
    }

    func toggleVisibility() { isVisible.toggle() }

    private func normalize(_ href: String) -> String {
        var s = href
        if let hashIdx = s.firstIndex(of: "#") { s = String(s[..<hashIdx]) }
        while s.hasPrefix("/") { s.removeFirst() }
        return s
    }
}
