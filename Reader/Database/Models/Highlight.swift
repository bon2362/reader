import Foundation
import GRDB

enum HighlightColor: String, CaseIterable, Codable {
    case yellow
    case red
    case green
    case blue
    case purple
}

struct Highlight: Identifiable, Codable, Hashable {
    var id: String
    var bookId: String
    var cfiStart: String
    var cfiEnd: String
    var color: HighlightColor
    var selectedText: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        bookId: String,
        cfiStart: String,
        cfiEnd: String,
        color: HighlightColor,
        selectedText: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bookId = bookId
        self.cfiStart = cfiStart
        self.cfiEnd = cfiEnd
        self.color = color
        self.selectedText = selectedText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Highlight: FetchableRecord, PersistableRecord {
    static let databaseTableName = "highlights"

    enum Columns {
        static let id        = Column(CodingKeys.id)
        static let bookId    = Column(CodingKeys.bookId)
        static let cfiStart  = Column(CodingKeys.cfiStart)
        static let cfiEnd    = Column(CodingKeys.cfiEnd)
        static let color     = Column(CodingKeys.color)
        static let selectedText = Column(CodingKeys.selectedText)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case bookId    = "book_id"
        case cfiStart  = "cfi_start"
        case cfiEnd    = "cfi_end"
        case color
        case selectedText = "selected_text"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
