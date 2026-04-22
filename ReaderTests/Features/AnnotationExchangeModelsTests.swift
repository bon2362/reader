import Foundation
import Testing
@testable import Reader

@Suite("Annotation Exchange Models")
struct AnnotationExchangeModelsTests {

    @Test func documentRoundTripsWithAllAnnotationTypes() throws {
        let document = makeDocument()

        let encoded = try makeEncoder().encode(document)
        let decoded = try JSONDecoder().decode(AnnotationExchangeDocument.self, from: encoded)

        #expect(decoded == document)
        #expect(decoded.highlights.count == 1)
        #expect(decoded.textNotes.count == 1)
        #expect(decoded.stickyNotes.count == 1)
    }

    @Test func encodingKeepsStableDateAndAnchorValues() throws {
        let exportedAt = Date(timeIntervalSince1970: 1_745_323_200)
        let createdAt = Date(timeIntervalSince1970: 1_745_319_600)
        let updatedAt = Date(timeIntervalSince1970: 1_745_319_900)
        let document = AnnotationExchangeDocument(
            exportedAt: exportedAt,
            book: AnnotationExchangeBook(
                id: "book-1",
                title: "Example Book",
                author: "Jane Doe",
                format: .pdf,
                contentHash: "hash-123"
            ),
            items: [
                AnnotationExchangeItem(
                    exchangeId: "exp-01",
                    type: .textNote,
                    anchor: AnnotationExchangeAnchor(
                        scheme: .pdfAnchor,
                        value: "pdf:3|12-20"
                    ),
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    selectedText: "Important quote",
                    body: "My comment"
                )
            ]
        )

        let encoded = try makeEncoder().encode(document)
        let json = try #require(String(data: encoded, encoding: .utf8))

        #expect(json.contains("\"format\":\"reader-annotations\\/v1\""))
        #expect(json.contains("\"exportedAt\":\"2025-04-22T12:00:00Z\""))
        #expect(json.contains("\"createdAt\":\"2025-04-22T11:00:00Z\""))
        #expect(json.contains("\"updatedAt\":\"2025-04-22T11:05:00Z\""))
        #expect(json.contains("\"scheme\":\"pdf-anchor\""))
        #expect(json.contains("\"value\":\"pdf:3|12-20\""))
        #expect(json.contains("\"type\":\"text_note\""))
        #expect(json.contains("\"exchangeId\":\"exp-01\""))
    }

    @Test func modelsStayIndependentFromPersistenceAnnotations() throws {
        let item = AnnotationExchangeItem(
            exchangeId: "sticky-1",
            type: .stickyNote,
            anchor: AnnotationExchangeAnchor(
                scheme: .page,
                value: "17"
            ),
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 20),
            body: "Remember this section",
            pageLabel: "Chapter 2 · Page 4"
        )

        #expect(item.type == .stickyNote)
        #expect(item.color == nil)
        #expect(item.anchor.scheme == .page)
        #expect(item.pageLabel == "Chapter 2 · Page 4")
    }

    private func makeDocument() -> AnnotationExchangeDocument {
        AnnotationExchangeDocument(
            exportedAt: Date(timeIntervalSince1970: 1_745_318_400),
            book: AnnotationExchangeBook(
                id: "book-1",
                title: "Example Book",
                author: "Jane Doe",
                format: .epub,
                contentHash: "hash-123"
            ),
            items: [
                AnnotationExchangeItem(
                    exchangeId: "highlight-1",
                    type: .highlight,
                    anchor: AnnotationExchangeAnchor(
                        scheme: .cfi,
                        value: "/6/2[chapter1]!/4/2,/1:10,/1:24"
                    ),
                    createdAt: Date(timeIntervalSince1970: 1_745_314_800),
                    updatedAt: Date(timeIntervalSince1970: 1_745_315_100),
                    selectedText: "Important quoted text",
                    color: .yellow
                ),
                AnnotationExchangeItem(
                    exchangeId: "text-note-1",
                    type: .textNote,
                    anchor: AnnotationExchangeAnchor(
                        scheme: .pdfAnchor,
                        value: "pdf:3|12-20"
                    ),
                    createdAt: Date(timeIntervalSince1970: 1_745_315_200),
                    updatedAt: Date(timeIntervalSince1970: 1_745_315_260),
                    selectedText: "Important quoted text",
                    body: "My comment here."
                ),
                AnnotationExchangeItem(
                    exchangeId: "sticky-note-1",
                    type: .stickyNote,
                    anchor: AnnotationExchangeAnchor(
                        scheme: .page,
                        value: "17"
                    ),
                    createdAt: Date(timeIntervalSince1970: 1_745_315_300),
                    updatedAt: Date(timeIntervalSince1970: 1_745_315_300),
                    body: "Remember this section.",
                    pageLabel: "Chapter 2 · Page 4"
                )
            ]
        )
    }

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
