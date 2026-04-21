import Foundation
import Observation

@MainActor
@Observable
final class AnnotationPanelStore {
    var isVisible: Bool = false
    var selectedTab: AnnotationPanelTab = .all

    private let highlightsStore: HighlightsStore
    private let textNotesStore: TextNotesStore
    private let stickyNotesStore: StickyNotesStore
    private let tocStore: TOCStore
    private var chapterPageCounts: [Int] = []

    init(
        highlightsStore: HighlightsStore,
        textNotesStore: TextNotesStore,
        stickyNotesStore: StickyNotesStore,
        tocStore: TOCStore
    ) {
        self.highlightsStore = highlightsStore
        self.textNotesStore = textNotesStore
        self.stickyNotesStore = stickyNotesStore
        self.tocStore = tocStore
    }

    func toggleVisibility() { isVisible.toggle() }
    func show() { isVisible = true }
    func hide() { isVisible = false }
    func updateChapterPageCounts(_ counts: [Int]) { chapterPageCounts = counts }

    var allItems: [AnnotationListItem] {
        var items: [AnnotationListItem] = []

        for h in highlightsStore.highlights {
            items.append(AnnotationListItem(
                id: h.id,
                kind: .highlight,
                preview: h.selectedText,
                spineIndex: nil,
                pageInChapter: nil,
                globalPage: nil,
                cfi: h.cfiStart,
                color: h.color,
                chapterLabel: nil,
                createdAt: h.createdAt
            ))
        }

        for n in textNotesStore.notes {
            items.append(AnnotationListItem(
                id: n.id,
                kind: .note,
                preview: n.body,
                spineIndex: nil,
                pageInChapter: nil,
                globalPage: nil,
                cfi: n.cfiAnchor,
                color: nil,
                chapterLabel: nil,
                createdAt: n.createdAt
            ))
        }

        for s in stickyNotesStore.notes {
            items.append(AnnotationListItem(
                id: s.id,
                kind: .sticky,
                preview: s.body,
                spineIndex: s.spineIndex,
                pageInChapter: s.pageInChapter,
                globalPage: globalPage(spineIndex: s.spineIndex, pageInChapter: s.pageInChapter),
                cfi: nil,
                color: nil,
                chapterLabel: nil,
                createdAt: s.createdAt
            ))
        }

        return items.sorted { lhs, rhs in
            let l = sortKey(lhs)
            let r = sortKey(rhs)
            if l != r { return l < r }
            return lhs.createdAt < rhs.createdAt
        }
    }

    var filteredItems: [AnnotationListItem] {
        allItems.filter { selectedTab.matches($0.kind) }
    }

    func count(for tab: AnnotationPanelTab) -> Int {
        allItems.filter { tab.matches($0.kind) }.count
    }

    private func sortKey(_ item: AnnotationListItem) -> String {
        if let spine = item.spineIndex {
            return String(format: "s%08d:%08d", spine, item.pageInChapter ?? 0)
        }
        if let cfi = item.cfi {
            return "c\(cfi)"
        }
        return "z"
    }

    private func globalPage(spineIndex: Int, pageInChapter: Int) -> Int? {
        if chapterPageCounts.isEmpty, pageInChapter == 0 {
            return spineIndex + 1
        }
        guard spineIndex >= 0,
              spineIndex < chapterPageCounts.count,
              chapterPageCounts.prefix(spineIndex).allSatisfy({ $0 > 0 }) else {
            return nil
        }
        return chapterPageCounts.prefix(spineIndex).reduce(0, +) + pageInChapter + 1
    }
}
