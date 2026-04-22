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

    // MARK: - Text Notes

    @Test func insertAndFetchTextNote() async throws {
        let (ann, _, book) = try await makeSetup()
        let n = TextNote(bookId: book.id, cfiAnchor: "cfi", body: "hello")
        try await ann.insertTextNote(n)

        let list = try await ann.fetchTextNotes(bookId: book.id)
        #expect(list.count == 1)
        #expect(list[0].body == "hello")
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
