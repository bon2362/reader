import Foundation
import Testing
@testable import Reader

@Suite("Markdown Annotation Encoder")
struct MarkdownAnnotationEncoderTests {
    private let encoder = MarkdownAnnotationEncoder()

    @Test func encodesDocumentWithAllAnnotationTypes() throws {
        let markdown = try encoder.encode(makeDocument())

        #expect(markdown == """
        ---
        format: "reader-annotations/v1"
        exportedAt: "2025-04-22T12:00:00Z"
        book:
          id: "book-1"
          title: "Example Book"
          author: "Jane Doe"
          format: "epub"
          contentHash: "hash-123"
        ---

        # Annotations

        ## Highlights

        ### Highlight
        <!--
        id: "highlight-1"
        type: "highlight"
        anchor:
          scheme: "cfi"
          value: "/6/2[chapter1]!/4/2,/1:10,/1:24"
        createdAt: "2025-04-22T11:00:00Z"
        updatedAt: "2025-04-22T11:05:00Z"
        color: "yellow"
        selectedText: "Important quoted text"
        -->

        > Important quoted text

        ## Text Notes

        ### Text Note
        <!--
        id: "text-note-1"
        type: "text_note"
        anchor:
          scheme: "pdf-anchor"
          value: "pdf:3|12-20"
        createdAt: "2025-04-22T11:10:00Z"
        updatedAt: "2025-04-22T11:11:00Z"
        selectedText: "Important quoted text"
        -->

        **Selected text**

        Important quoted text

        **Note**

        My comment here.

        ## Sticky Notes

        ### Sticky Note
        <!--
        id: "sticky-note-1"
        type: "sticky_note"
        anchor:
          scheme: "page"
          value: "17"
        createdAt: "2025-04-22T11:15:00Z"
        updatedAt: "2025-04-22T11:15:00Z"
        pageLabel: "Chapter 2 · Page 4"
        -->

        **Location**

        Chapter 2 · Page 4

        **Note**

        Remember this section.
        """
        + "\n")
    }

    @Test func omitsEmptySectionsAndSortsItemsDeterministically() throws {
        let first = AnnotationExchangeItem(
            exchangeId: "b-item",
            type: .highlight,
            anchor: AnnotationExchangeAnchor(scheme: .cfi, value: "b"),
            createdAt: Date(timeIntervalSince1970: 20),
            updatedAt: Date(timeIntervalSince1970: 20),
            selectedText: "Second chronologically",
            color: .blue
        )
        let second = AnnotationExchangeItem(
            exchangeId: "a-item",
            type: .highlight,
            anchor: AnnotationExchangeAnchor(scheme: .cfi, value: "a"),
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10),
            selectedText: "First chronologically",
            color: .red
        )
        let markdown = try encoder.encode(
            AnnotationExchangeDocument(
                exportedAt: Date(timeIntervalSince1970: 30),
                book: AnnotationExchangeBook(
                    id: nil,
                    title: "Book",
                    author: nil,
                    format: .pdf,
                    contentHash: "hash"
                ),
                items: [first, second]
            )
        )

        #expect(markdown.contains("## Highlights"))
        #expect(!markdown.contains("## Text Notes"))
        #expect(!markdown.contains("## Sticky Notes"))
        #expect(markdown.firstRange(of: "id: \"a-item\"")!.lowerBound < markdown.firstRange(of: "id: \"b-item\"")!.lowerBound)
    }

    @Test func preservesMultilineBodyAndSanitizesCommentMetadata() throws {
        let markdown = try encoder.encode(
            AnnotationExchangeDocument(
                exportedAt: Date(timeIntervalSince1970: 1_745_323_200),
                book: AnnotationExchangeBook(
                    id: "book-1",
                    title: "Example: Book",
                    author: "Jane Doe",
                    format: .pdf,
                    contentHash: "hash-123"
                ),
                items: [
                    AnnotationExchangeItem(
                        exchangeId: "text-note-1",
                        type: .textNote,
                        anchor: AnnotationExchangeAnchor(
                            scheme: .pdfAnchor,
                            value: "pdf:3|12-20"
                        ),
                        createdAt: Date(timeIntervalSince1970: 1_745_319_600),
                        updatedAt: Date(timeIntervalSince1970: 1_745_319_900),
                        selectedText: "Line 1 --> line 2",
                        body: "First line\n\nSecond: line"
                    )
                ]
            )
        )

        #expect(markdown.contains("selectedText: \"Line 1 --\\\\> line 2\""))
        #expect(markdown.contains("First line\n\nSecond: line"))
    }

    @Test func throwsForMissingRequiredFields() {
        let missingTitle = AnnotationExchangeDocument(
            exportedAt: Date(),
            book: AnnotationExchangeBook(
                id: "book-1",
                title: "",
                author: "Jane Doe",
                format: .epub,
                contentHash: "hash-123"
            ),
            items: []
        )
        let missingExchangeId = AnnotationExchangeDocument(
            exportedAt: Date(),
            book: AnnotationExchangeBook(
                id: "book-1",
                title: "Title",
                author: "Jane Doe",
                format: .epub,
                contentHash: "hash-123"
            ),
            items: [
                AnnotationExchangeItem(
                    exchangeId: "",
                    type: .textNote,
                    anchor: AnnotationExchangeAnchor(scheme: .cfi, value: "anchor"),
                    createdAt: Date(),
                    updatedAt: Date(),
                    body: "Body"
                )
            ]
        )

        #expect(throws: MarkdownAnnotationEncodingError.missingBookTitle) {
            try encoder.encode(missingTitle)
        }
        #expect(throws: MarkdownAnnotationEncodingError.missingExchangeId) {
            try encoder.encode(missingExchangeId)
        }
    }

    private func makeDocument() -> AnnotationExchangeDocument {
        AnnotationExchangeDocument(
            exportedAt: Date(timeIntervalSince1970: 1_745_323_200),
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
                    createdAt: Date(timeIntervalSince1970: 1_745_319_600),
                    updatedAt: Date(timeIntervalSince1970: 1_745_319_900),
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
                    createdAt: Date(timeIntervalSince1970: 1_745_320_200),
                    updatedAt: Date(timeIntervalSince1970: 1_745_320_260),
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
                    createdAt: Date(timeIntervalSince1970: 1_745_320_500),
                    updatedAt: Date(timeIntervalSince1970: 1_745_320_500),
                    body: "Remember this section.",
                    pageLabel: "Chapter 2 · Page 4"
                )
            ]
        )
    }
}
