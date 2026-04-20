import Foundation
import GRDB

struct TextNote: Identifiable, Codable, Hashable {
    var id: String
    var bookId: String
    var highlightId: String?
    var cfiAnchor: String
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        bookId: String,
        highlightId: String? = nil,
        cfiAnchor: String,
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bookId = bookId
        self.highlightId = highlightId
        self.cfiAnchor = cfiAnchor
        self.body = body
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
        static let body        = Column(CodingKeys.body)
        static let createdAt   = Column(CodingKeys.createdAt)
        static let updatedAt   = Column(CodingKeys.updatedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case bookId      = "book_id"
        case highlightId = "highlight_id"
        case cfiAnchor   = "cfi_anchor"
        case body
        case createdAt   = "created_at"
        case updatedAt   = "updated_at"
    }
}
