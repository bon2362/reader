import Foundation
import GRDB

struct PageNote: Identifiable, Codable, Hashable {
    var id: String
    var bookId: String
    var spineIndex: Int
    var pageInChapter: Int
    var body: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        bookId: String,
        spineIndex: Int,
        pageInChapter: Int = 0,
        body: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.bookId = bookId
        self.spineIndex = spineIndex
        self.pageInChapter = pageInChapter
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension PageNote: FetchableRecord, PersistableRecord {
    static let databaseTableName = "page_notes"

    enum Columns {
        static let id             = Column(CodingKeys.id)
        static let bookId         = Column(CodingKeys.bookId)
        static let spineIndex     = Column(CodingKeys.spineIndex)
        static let pageInChapter  = Column(CodingKeys.pageInChapter)
        static let body           = Column(CodingKeys.body)
        static let createdAt      = Column(CodingKeys.createdAt)
        static let updatedAt      = Column(CodingKeys.updatedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case bookId         = "book_id"
        case spineIndex     = "spine_index"
        case pageInChapter  = "page_in_chapter"
        case body
        case createdAt      = "created_at"
        case updatedAt      = "updated_at"
    }
}
