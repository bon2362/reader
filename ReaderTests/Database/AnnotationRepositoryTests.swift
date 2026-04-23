import Testing
import Foundation
@testable import Reader

@Suite("AnnotationRepository")
struct AnnotationRepositoryTests {

    private func makeSetup() async throws -> (AnnotationRepository, LibraryRepository, Book) {
        let db = try DatabaseManager.inMemory()
        let ann = AnnotationRepository(database: db)
        let lib = LibraryRepository(database: db)
        let book = Book(title: "T", filePath: "/x")
        try await lib.insert(book)
        return (ann, lib, book)
    }

    // MARK: - Highlights

    @Test func insertAndFetchHighlight() async throws {
        let (ann, _, book) = try await makeSetup()
        let h = Highlight(bookId: book.id, cfiStart: "s", cfiEnd: "e", color: .yellow)
        try await ann.insertHighlight(h)

        let list = try await ann.fetchHighlights(bookId: book.id)
        #expect(list.count == 1)
        #expect(list[0].color == .yellow)
    }

    @Test func updateHighlightChangesColor() async throws {
        let (ann, _, book) = try await makeSetup()
        var h = Highlight(bookId: book.id, cfiStart: "s", cfiEnd: "e", color: .yellow)
        try await ann.insertHighlight(h)

        h.color = .red
        try await ann.updateHighlight(h)

        let list = try await ann.fetchHighlights(bookId: book.id)
        #expect(list[0].color == .red)
    }

    @Test func updateHighlightPreservesExchangeId() async throws {
        let (ann, _, book) = try await makeSetup()
        let original = Highlight(bookId: book.id, cfiStart: "s", cfiEnd: "e", color: .yellow)
        try await ann.insertHighlight(original)

        var updated = original
        updated.color = .red
        try await ann.updateHighlight(updated)

        let list = try await ann.fetchHighlights(bookId: book.id)
        #expect(list[0].exchangeId == original.exchangeId)
    }

    @Test func deleteHighlight() async throws {
        let (ann, _, book) = try await makeSetup()
        let h = Highlight(bookId: book.id, cfiStart: "s", cfiEnd: "e", color: .green)
        try await ann.insertHighlight(h)
        try await ann.deleteHighlight(id: h.id)

        let list = try await ann.fetchHighlights(bookId: book.id)
        #expect(list.isEmpty)
    }

    @Test func fetchHighlightByExchangeIdFindsMatchingRecord() async throws {
        let (ann, _, book) = try await makeSetup()
        let highlight = Highlight(
            bookId: book.id,
            cfiStart: "start",
            cfiEnd: "end",
            color: .yellow,
            exchangeId: "highlight-exchange"
        )
        try await ann.insertHighlight(highlight)

        let fetched = try await ann.fetchHighlight(bookId: book.id, exchangeId: "highlight-exchange")

        #expect(fetched?.id == highlight.id)
    }

    @Test func fetchHighlightByExchangeIdIgnoresDifferentBook() async throws {
        let (ann, lib, book) = try await makeSetup()
        let otherBook = Book(title: "Other", filePath: "/other")
        try await lib.insert(otherBook)
        let highlight = Highlight(
            bookId: otherBook.id,
            cfiStart: "start",
            cfiEnd: "end",
            color: .yellow,
            exchangeId: "highlight-exchange"
        )
        try await ann.insertHighlight(highlight)

        let fetched = try await ann.fetchHighlight(bookId: book.id, exchangeId: "highlight-exchange")

        #expect(fetched == nil)
    }

    @Test func fetchHighlightByExchangeIdIgnoresDifferentExchangeId() async throws {
        let (ann, _, book) = try await makeSetup()
        try await ann.insertHighlight(
            Highlight(
                bookId: book.id,
                cfiStart: "start",
                cfiEnd: "end",
                color: .yellow,
                exchangeId: "highlight-exchange"
            )
        )

        let fetched = try await ann.fetchHighlight(bookId: book.id, exchangeId: "other-exchange")

        #expect(fetched == nil)
    }

    @Test func fetchHighlightByExchangeIdReturnsNilForLegacyRow() async throws {
        let (ann, _, book) = try await makeSetup()
        let legacyHighlight = Highlight(
            bookId: book.id,
            cfiStart: "start",
            cfiEnd: "end",
            color: .yellow,
            exchangeId: "legacy-placeholder"
        )
        try await ann.insertHighlight(legacyHighlight)
        try await ann.updateHighlight(
            Highlight(
                id: legacyHighlight.id,
                bookId: legacyHighlight.bookId,
                cfiStart: legacyHighlight.cfiStart,
                cfiEnd: legacyHighlight.cfiEnd,
                color: legacyHighlight.color,
                selectedText: legacyHighlight.selectedText,
                exchangeId: nil,
                createdAt: legacyHighlight.createdAt,
                updatedAt: legacyHighlight.updatedAt
            )
        )

        let fetched = try await ann.fetchHighlight(bookId: book.id, exchangeId: "legacy-placeholder")

        #expect(fetched == nil)
    }

    // MARK: - Text Notes

    @Test func insertAndFetchTextNote() async throws {
        let (ann, _, book) = try await makeSetup()
        let n = TextNote(bookId: book.id, cfiAnchor: "cfi", selectedText: "quote", body: "hello")
        try await ann.insertTextNote(n)

        let list = try await ann.fetchTextNotes(bookId: book.id)
        #expect(list.count == 1)
        #expect(list[0].body == "hello")
        #expect(list[0].selectedText == "quote")
    }

    @Test func textNoteLinkedToHighlight() async throws {
        let (ann, _, book) = try await makeSetup()
        let h = Highlight(bookId: book.id, cfiStart: "s", cfiEnd: "e", color: .blue)
        try await ann.insertHighlight(h)
        let n = TextNote(bookId: book.id, highlightId: h.id, cfiAnchor: "s", body: "note")
        try await ann.insertTextNote(n)

        let list = try await ann.fetchTextNotes(bookId: book.id)
        #expect(list[0].highlightId == h.id)
    }

    @Test func textNoteHighlightIdNilOnHighlightDelete() async throws {
        let (ann, _, book) = try await makeSetup()
        let h = Highlight(bookId: book.id, cfiStart: "s", cfiEnd: "e", color: .blue)
        try await ann.insertHighlight(h)
        let n = TextNote(bookId: book.id, highlightId: h.id, cfiAnchor: "s", body: "note")
        try await ann.insertTextNote(n)

        try await ann.deleteHighlight(id: h.id)

        let list = try await ann.fetchTextNotes(bookId: book.id)
        #expect(list.count == 1)
        #expect(list[0].highlightId == nil) // SET NULL cascade
    }

    @Test func updateTextNoteBody() async throws {
        let (ann, _, book) = try await makeSetup()
        var n = TextNote(bookId: book.id, cfiAnchor: "cfi", body: "old")
        try await ann.insertTextNote(n)

        n.body = "new"
        try await ann.updateTextNote(n)

        let list = try await ann.fetchTextNotes(bookId: book.id)
        #expect(list[0].body == "new")
    }

    @Test func updateTextNotePreservesExchangeId() async throws {
        let (ann, _, book) = try await makeSetup()
        let original = TextNote(bookId: book.id, cfiAnchor: "cfi", body: "old")
        try await ann.insertTextNote(original)

        var updated = original
        updated.body = "new"
        try await ann.updateTextNote(updated)

        let list = try await ann.fetchTextNotes(bookId: book.id)
        #expect(list[0].exchangeId == original.exchangeId)
    }

    @Test func deleteTextNote() async throws {
        let (ann, _, book) = try await makeSetup()
        let n = TextNote(bookId: book.id, cfiAnchor: "cfi", body: "x")
        try await ann.insertTextNote(n)
        try await ann.deleteTextNote(id: n.id)

        let list = try await ann.fetchTextNotes(bookId: book.id)
        #expect(list.isEmpty)
    }

    @Test func fetchTextNoteByExchangeIdFindsMatchingRecord() async throws {
        let (ann, _, book) = try await makeSetup()
        let note = TextNote(
            bookId: book.id,
            cfiAnchor: "anchor",
            body: "body",
            exchangeId: "text-note-exchange"
        )
        try await ann.insertTextNote(note)

        let fetched = try await ann.fetchTextNote(bookId: book.id, exchangeId: "text-note-exchange")

        #expect(fetched?.id == note.id)
    }

    @Test func fetchTextNoteByExchangeIdIgnoresDifferentBook() async throws {
        let (ann, lib, book) = try await makeSetup()
        let otherBook = Book(title: "Other", filePath: "/other")
        try await lib.insert(otherBook)
        let note = TextNote(
            bookId: otherBook.id,
            cfiAnchor: "anchor",
            body: "body",
            exchangeId: "text-note-exchange"
        )
        try await ann.insertTextNote(note)

        let fetched = try await ann.fetchTextNote(bookId: book.id, exchangeId: "text-note-exchange")

        #expect(fetched == nil)
    }

    @Test func fetchTextNoteByExchangeIdIgnoresDifferentExchangeId() async throws {
        let (ann, _, book) = try await makeSetup()
        try await ann.insertTextNote(
            TextNote(
                bookId: book.id,
                cfiAnchor: "anchor",
                body: "body",
                exchangeId: "text-note-exchange"
            )
        )

        let fetched = try await ann.fetchTextNote(bookId: book.id, exchangeId: "other-exchange")

        #expect(fetched == nil)
    }

    @Test func fetchTextNoteByExchangeIdReturnsNilForLegacyRow() async throws {
        let (ann, _, book) = try await makeSetup()
        let legacyNote = TextNote(
            bookId: book.id,
            cfiAnchor: "anchor",
            body: "body",
            exchangeId: "legacy-text-note"
        )
        try await ann.insertTextNote(legacyNote)
        try await ann.updateTextNote(
            TextNote(
                id: legacyNote.id,
                bookId: legacyNote.bookId,
                highlightId: legacyNote.highlightId,
                cfiAnchor: legacyNote.cfiAnchor,
                body: legacyNote.body,
                exchangeId: nil,
                createdAt: legacyNote.createdAt,
                updatedAt: legacyNote.updatedAt
            )
        )

        let fetched = try await ann.fetchTextNote(bookId: book.id, exchangeId: "legacy-text-note")

        #expect(fetched == nil)
    }

    // MARK: - Page Notes

    @Test func insertAndFetchPageNote() async throws {
        let (ann, _, book) = try await makeSetup()
        let n = PageNote(bookId: book.id, spineIndex: 3, body: "sticky")
        try await ann.insertPageNote(n)

        let list = try await ann.fetchPageNotes(bookId: book.id)
        #expect(list.count == 1)
        #expect(list[0].spineIndex == 3)
    }

    @Test func pageNotesOrderedBySpineIndex() async throws {
        let (ann, _, book) = try await makeSetup()
        try await ann.insertPageNote(PageNote(bookId: book.id, spineIndex: 5, body: "b"))
        try await ann.insertPageNote(PageNote(bookId: book.id, spineIndex: 1, body: "a"))
        try await ann.insertPageNote(PageNote(bookId: book.id, spineIndex: 3, body: "c"))

        let list = try await ann.fetchPageNotes(bookId: book.id)
        #expect(list.map(\.spineIndex) == [1, 3, 5])
    }

    @Test func updatePageNote() async throws {
        let (ann, _, book) = try await makeSetup()
        var n = PageNote(bookId: book.id, spineIndex: 0, body: "old")
        try await ann.insertPageNote(n)

        n.body = "new"
        try await ann.updatePageNote(n)

        let list = try await ann.fetchPageNotes(bookId: book.id)
        #expect(list[0].body == "new")
    }

    @Test func updatePageNotePreservesExchangeId() async throws {
        let (ann, _, book) = try await makeSetup()
        let original = PageNote(bookId: book.id, spineIndex: 0, body: "old")
        try await ann.insertPageNote(original)

        var updated = original
        updated.body = "new"
        try await ann.updatePageNote(updated)

        let list = try await ann.fetchPageNotes(bookId: book.id)
        #expect(list[0].exchangeId == original.exchangeId)
    }

    @Test func deletePageNote() async throws {
        let (ann, _, book) = try await makeSetup()
        let n = PageNote(bookId: book.id, spineIndex: 0, body: "x")
        try await ann.insertPageNote(n)
        try await ann.deletePageNote(id: n.id)

        let list = try await ann.fetchPageNotes(bookId: book.id)
        #expect(list.isEmpty)
    }

    @Test func fetchPageNoteByExchangeIdFindsMatchingRecord() async throws {
        let (ann, _, book) = try await makeSetup()
        let note = PageNote(
            bookId: book.id,
            spineIndex: 1,
            body: "body",
            exchangeId: "page-note-exchange"
        )
        try await ann.insertPageNote(note)

        let fetched = try await ann.fetchPageNote(bookId: book.id, exchangeId: "page-note-exchange")

        #expect(fetched?.id == note.id)
    }

    @Test func fetchPageNoteByExchangeIdIgnoresDifferentBook() async throws {
        let (ann, lib, book) = try await makeSetup()
        let otherBook = Book(title: "Other", filePath: "/other")
        try await lib.insert(otherBook)
        let note = PageNote(
            bookId: otherBook.id,
            spineIndex: 1,
            body: "body",
            exchangeId: "page-note-exchange"
        )
        try await ann.insertPageNote(note)

        let fetched = try await ann.fetchPageNote(bookId: book.id, exchangeId: "page-note-exchange")

        #expect(fetched == nil)
    }

    @Test func fetchPageNoteByExchangeIdIgnoresDifferentExchangeId() async throws {
        let (ann, _, book) = try await makeSetup()
        try await ann.insertPageNote(
            PageNote(
                bookId: book.id,
                spineIndex: 1,
                body: "body",
                exchangeId: "page-note-exchange"
            )
        )

        let fetched = try await ann.fetchPageNote(bookId: book.id, exchangeId: "other-exchange")

        #expect(fetched == nil)
    }

    @Test func fetchPageNoteByExchangeIdReturnsNilForLegacyRow() async throws {
        let (ann, _, book) = try await makeSetup()
        let legacyNote = PageNote(
            bookId: book.id,
            spineIndex: 1,
            body: "body",
            exchangeId: "legacy-page-note"
        )
        try await ann.insertPageNote(legacyNote)
        try await ann.updatePageNote(
            PageNote(
                id: legacyNote.id,
                bookId: legacyNote.bookId,
                spineIndex: legacyNote.spineIndex,
                pageInChapter: legacyNote.pageInChapter,
                body: legacyNote.body,
                exchangeId: nil,
                createdAt: legacyNote.createdAt,
                updatedAt: legacyNote.updatedAt
            )
        )

        let fetched = try await ann.fetchPageNote(bookId: book.id, exchangeId: "legacy-page-note")

        #expect(fetched == nil)
    }

    // MARK: - Cascade

    @Test func deletingBookCascadesToAllAnnotations() async throws {
        let (ann, lib, book) = try await makeSetup()
        try await ann.insertHighlight(Highlight(bookId: book.id, cfiStart: "s", cfiEnd: "e", color: .yellow))
        try await ann.insertTextNote(TextNote(bookId: book.id, cfiAnchor: "c", body: "n"))
        try await ann.insertPageNote(PageNote(bookId: book.id, spineIndex: 0, body: "s"))

        try await lib.delete(id: book.id)

        #expect(try await ann.fetchHighlights(bookId: book.id).isEmpty)
        #expect(try await ann.fetchTextNotes(bookId: book.id).isEmpty)
        #expect(try await ann.fetchPageNotes(bookId: book.id).isEmpty)
    }

    // MARK: - Fetch filters by book

    @Test func fetchHighlightsScopedByBook() async throws {
        let (ann, lib, book) = try await makeSetup()
        let otherBook = Book(title: "Other", filePath: "/o")
        try await lib.insert(otherBook)

        try await ann.insertHighlight(Highlight(bookId: book.id, cfiStart: "s", cfiEnd: "e", color: .yellow))
        try await ann.insertHighlight(Highlight(bookId: otherBook.id, cfiStart: "s", cfiEnd: "e", color: .red))

        let first = try await ann.fetchHighlights(bookId: book.id)
        let second = try await ann.fetchHighlights(bookId: otherBook.id)
        #expect(first.count == 1)
        #expect(second.count == 1)
        #expect(first[0].color == .yellow)
        #expect(second[0].color == .red)
    }
}
