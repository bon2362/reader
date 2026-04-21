import Foundation
import GRDB

struct Book: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var author: String?
    var coverPath: String?
    var filePath: String
    var fileBookmark: Data?
    var addedAt: Date
    var lastOpenedAt: Date?
    var lastCFI: String?
    var totalPages: Int?
    var currentPage: Int?
    var chapterPageCountsJSON: String?
    var format: BookFormat

    init(
        id: String = UUID().uuidString,
        title: String,
        author: String? = nil,
        coverPath: String? = nil,
        filePath: String,
        fileBookmark: Data? = nil,
        addedAt: Date = Date(),
        lastOpenedAt: Date? = nil,
        lastCFI: String? = nil,
        totalPages: Int? = nil,
        currentPage: Int? = nil,
        chapterPageCountsJSON: String? = nil,
        format: BookFormat = .epub
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.coverPath = coverPath
        self.filePath = filePath
        self.fileBookmark = fileBookmark
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
        self.lastCFI = lastCFI
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.chapterPageCountsJSON = chapterPageCountsJSON
        self.format = format
    }

    var progress: Double {
        guard let total = totalPages, total > 0, let current = currentPage else { return 0 }
        return min(1.0, Double(current) / Double(total))
    }

    var chapterPageCounts: [Int]? {
        guard let json = chapterPageCountsJSON,
              let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([Int].self, from: data) else { return nil }
        return arr
    }

    static func encodeChapterPageCounts(_ counts: [Int]) -> String? {
        guard let data = try? JSONEncoder().encode(counts),
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }
}

extension Book: FetchableRecord, PersistableRecord {
    static let databaseTableName = "books"

    enum Columns {
        static let id           = Column(CodingKeys.id)
        static let title        = Column(CodingKeys.title)
        static let author       = Column(CodingKeys.author)
        static let coverPath    = Column(CodingKeys.coverPath)
        static let filePath     = Column(CodingKeys.filePath)
        static let fileBookmark = Column(CodingKeys.fileBookmark)
        static let addedAt      = Column(CodingKeys.addedAt)
        static let lastOpenedAt = Column(CodingKeys.lastOpenedAt)
        static let lastCFI      = Column(CodingKeys.lastCFI)
        static let totalPages   = Column(CodingKeys.totalPages)
        static let currentPage  = Column(CodingKeys.currentPage)
        static let chapterPageCountsJSON = Column(CodingKeys.chapterPageCountsJSON)
        static let format       = Column(CodingKeys.format)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case coverPath    = "cover_path"
        case filePath     = "file_path"
        case fileBookmark = "file_bookmark"
        case addedAt      = "added_at"
        case lastOpenedAt = "last_opened_at"
        case lastCFI      = "last_cfi"
        case totalPages   = "total_pages"
        case currentPage  = "current_page"
        case chapterPageCountsJSON = "chapter_page_counts"
        case format
    }
}
