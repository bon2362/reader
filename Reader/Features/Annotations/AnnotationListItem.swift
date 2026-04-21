import Foundation

enum AnnotationKind: String, CaseIterable, Hashable {
    case highlight
    case note
    case sticky
}

struct AnnotationListItem: Identifiable, Hashable {
    let id: String
    let kind: AnnotationKind
    let preview: String
    let spineIndex: Int?
    let pageInChapter: Int?
    let globalPage: Int?
    let cfi: String?
    let color: HighlightColor?
    let chapterLabel: String?
    let createdAt: Date
}

enum AnnotationPanelTab: String, CaseIterable, Hashable {
    case all
    case highlights
    case notes
    case sticky

    var localizedTitle: String {
        switch self {
        case .all:        return "Все"
        case .highlights: return "Хайлайты"
        case .notes:      return "Заметки"
        case .sticky:     return "Sticky"
        }
    }

    func matches(_ kind: AnnotationKind) -> Bool {
        switch self {
        case .all:        return true
        case .highlights: return kind == .highlight
        case .notes:      return kind == .note
        case .sticky:     return kind == .sticky
        }
    }
}
