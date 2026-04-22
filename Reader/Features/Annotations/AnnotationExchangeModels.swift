import Foundation

enum AnnotationExchangeDocumentFormat: String, Codable, Hashable, Sendable {
    case readerAnnotationsV1 = "reader-annotations/v1"
}

enum AnnotationExchangeItemType: String, Codable, Hashable, Sendable {
    case highlight
    case textNote = "text_note"
    case stickyNote = "sticky_note"
}

enum AnnotationExchangeAnchorScheme: String, Codable, Hashable, Sendable {
    case cfi
    case pdfAnchor = "pdf-anchor"
    case page
}

enum AnnotationExchangeHighlightColor: String, Codable, Hashable, Sendable {
    case yellow
    case red
    case green
    case blue
    case purple
}

struct AnnotationExchangeAnchor: Codable, Hashable, Sendable {
    var scheme: AnnotationExchangeAnchorScheme
    var value: String
}

struct AnnotationExchangeBook: Codable, Hashable, Sendable {
    var id: String?
    var title: String
    var author: String?
    var format: BookFormat
    var contentHash: String
}

struct AnnotationExchangeItem: Codable, Hashable, Sendable {
    var exchangeId: String
    var type: AnnotationExchangeItemType
    var anchor: AnnotationExchangeAnchor
    var createdAt: Date
    var updatedAt: Date
    var selectedText: String?
    var body: String?
    var color: AnnotationExchangeHighlightColor?
    var pageLabel: String?

    enum CodingKeys: String, CodingKey {
        case exchangeId
        case type
        case anchor
        case createdAt
        case updatedAt
        case selectedText
        case body
        case color
        case pageLabel
    }

    init(
        exchangeId: String,
        type: AnnotationExchangeItemType,
        anchor: AnnotationExchangeAnchor,
        createdAt: Date,
        updatedAt: Date,
        selectedText: String? = nil,
        body: String? = nil,
        color: AnnotationExchangeHighlightColor? = nil,
        pageLabel: String? = nil
    ) {
        self.exchangeId = exchangeId
        self.type = type
        self.anchor = anchor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.selectedText = selectedText
        self.body = body
        self.color = color
        self.pageLabel = pageLabel
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        exchangeId = try container.decode(String.self, forKey: .exchangeId)
        type = try container.decode(AnnotationExchangeItemType.self, forKey: .type)
        anchor = try container.decode(AnnotationExchangeAnchor.self, forKey: .anchor)
        createdAt = try AnnotationExchangeDateCoder.decode(from: container, forKey: .createdAt)
        updatedAt = try AnnotationExchangeDateCoder.decode(from: container, forKey: .updatedAt)
        selectedText = try container.decodeIfPresent(String.self, forKey: .selectedText)
        body = try container.decodeIfPresent(String.self, forKey: .body)
        color = try container.decodeIfPresent(AnnotationExchangeHighlightColor.self, forKey: .color)
        pageLabel = try container.decodeIfPresent(String.self, forKey: .pageLabel)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(exchangeId, forKey: .exchangeId)
        try container.encode(type, forKey: .type)
        try container.encode(anchor, forKey: .anchor)
        try AnnotationExchangeDateCoder.encode(createdAt, to: &container, forKey: .createdAt)
        try AnnotationExchangeDateCoder.encode(updatedAt, to: &container, forKey: .updatedAt)
        try container.encodeIfPresent(selectedText, forKey: .selectedText)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(pageLabel, forKey: .pageLabel)
    }
}

struct AnnotationExchangeDocument: Codable, Hashable, Sendable {
    var format: AnnotationExchangeDocumentFormat
    var exportedAt: Date
    var book: AnnotationExchangeBook
    var items: [AnnotationExchangeItem]

    enum CodingKeys: String, CodingKey {
        case format
        case exportedAt
        case book
        case items
    }

    init(
        format: AnnotationExchangeDocumentFormat = .readerAnnotationsV1,
        exportedAt: Date,
        book: AnnotationExchangeBook,
        items: [AnnotationExchangeItem]
    ) {
        self.format = format
        self.exportedAt = exportedAt
        self.book = book
        self.items = items
    }

    var highlights: [AnnotationExchangeItem] {
        items.filter { $0.type == .highlight }
    }

    var textNotes: [AnnotationExchangeItem] {
        items.filter { $0.type == .textNote }
    }

    var stickyNotes: [AnnotationExchangeItem] {
        items.filter { $0.type == .stickyNote }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        format = try container.decode(AnnotationExchangeDocumentFormat.self, forKey: .format)
        exportedAt = try AnnotationExchangeDateCoder.decode(from: container, forKey: .exportedAt)
        book = try container.decode(AnnotationExchangeBook.self, forKey: .book)
        items = try container.decode([AnnotationExchangeItem].self, forKey: .items)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        try AnnotationExchangeDateCoder.encode(exportedAt, to: &container, forKey: .exportedAt)
        try container.encode(book, forKey: .book)
        try container.encode(items, forKey: .items)
    }
}

private enum AnnotationExchangeDateCoder {
    private static func makePrimaryFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    private static func makeFallbackFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    static func encode<Key: CodingKey>(
        _ value: Date,
        to container: inout KeyedEncodingContainer<Key>,
        forKey key: Key
    ) throws {
        let formatter = makePrimaryFormatter()

        try container.encode(formatter.string(from: value), forKey: key)
    }

    static func decode<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> Date {
        let rawValue = try container.decode(String.self, forKey: key)
        let primaryFormatter = makePrimaryFormatter()
        let fallbackFormatter = makeFallbackFormatter()

        if let date = primaryFormatter.date(from: rawValue) ?? fallbackFormatter.date(from: rawValue) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: container,
            debugDescription: "Invalid ISO8601 date string: \(rawValue)"
        )
    }

}
