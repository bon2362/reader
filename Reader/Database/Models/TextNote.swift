import Foundation
import GRDB

struct TextNote: Identifiable, Codable, Hashable {
    var id: String
    var bookId: String
    var highlightId: String?
    var cfiAnchor: String
    var selectedText: String?
    var body: String
    var exchangeId: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        bookId: String,
        highlightId: String? = nil,
        cfiAnchor: String,
        selectedText: String? = nil,
        body: String,
        exchangeId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bookId = bookId
        self.highlightId = highlightId
        self.cfiAnchor = cfiAnchor
        self.selectedText = selectedText
        self.body = body
        self.exchangeId = exchangeId ?? UUID().uuidString
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension TextNote: FetchableRecord, PersistableRecord {
    static let databaseTableName = "text_notes"

    enum Columns {
        static let id          = Column(CodingKeys.id)
        static let bookId      = Column(CodingKeys.bookId)
        static let highlightId = Column(CodingKeys.highlightId)
        static let cfiAnchor   = Column(CodingKeys.cfiAnchor)
        static let selectedText = Column(CodingKeys.selectedText)
        static let body        = Column(CodingKeys.body)
        static let exchangeId  = Column(CodingKeys.exchangeId)
        static let createdAt   = Column(CodingKeys.createdAt)
        static let updatedAt   = Column(CodingKeys.updatedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case bookId      = "book_id"
        case highlightId = "highlight_id"
        case cfiAnchor   = "cfi_anchor"
        case selectedText = "selected_text"
        case body
        case exchangeId  = "exchange_id"
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
    }
}
