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

    @Test func deleteHighlight() async throws {
        let (ann, _, book) = try await makeSetup()
        let h = Highlight(bookId: book.id, cfiStart: "s", cfiEnd: "e", color: .green)
        try await ann.insertHighlight(h)
        try await ann.deleteHighlight(id: h.id)

        let list = try await ann.fetchHighlights(bookId: book.id)
        #expect(list.isEmpty)
    }

    @Test func deleteHighlightLeavesTombstoneForSync() async throws {
        let (ann, _, book) = try await makeSetup()
        let h = Highlight(bookId: book.id, cfiStart: "s", cfiEnd: "e", color: .green)
        try await ann.insertHighlight(h)
        try await ann.deleteHighlight(id: h.id)

        let stored = try await ann.fetchHighlight(id: h.id, includeDeleted: true)
        #expect(stored?.deletedAt != nil)
        #expect(stored?.syncState == Highlight.SyncState.pendingDelete.rawValue)
    }

    @Test func applyRemoteHighlightUpsertMergesByRemoteRecordName() async throws {
        let (ann, _, book) = try await makeSetup()
        let original = Highlight(
            id: "h-1",
            bookId: book.id,
            cfiStart: "pdf:1",
            cfiEnd: "pdf:1",
            color: .yellow,
            remoteRecordName: "remote-h-1",
            syncState: Highlight.SyncState.synced.rawValue
        )
        try await ann.insertHighlight(original)
        try await ann.markHighlightSynced(
            id: original.id,
            remoteRecordName: "remote-h-1",
            updatedAt: original.updatedAt,
            deletedAt: nil
        )

        try await ann.applyRemoteHighlightUpsert(
            SyncedHighlightRecord(
                highlightID: "h-1",
                bookID: book.id,
                anchor: "pdf:2",
                color: .red,
                selectedText: "updated",
                remoteRecordName: "remote-h-1",
                updatedAt: original.updatedAt.addingTimeInterval(30),
                deletedAt: nil
            )
        )

        let stored = try await ann.fetchHighlight(id: "h-1", includeDeleted: true)
        #expect(stored?.color == .red)
        #expect(stored?.cfiStart == "pdf:2")
        #expect(stored?.selectedText == "updated")
    }

    @Test func applyRemoteHighlightTombstoneHidesHighlight() async throws {
        let (ann, _, book) = try await makeSetup()
        let original = Highlight(
            id: "h-2",
            bookId: book.id,
            cfiStart: "pdf:1",
            cfiEnd: "pdf:1",
            color: .yellow,
            remoteRecordName: "remote-h-2",
            syncState: Highlight.SyncState.synced.rawValue
        )
        try await ann.insertHighlight(original)
        try await ann.markHighlightSynced(
            id: original.id,
            remoteRecordName: "remote-h-2",
            updatedAt: original.updatedAt,
            deletedAt: nil
        )

        try await ann.applyRemoteHighlightTombstone(
            SyncedHighlightRecord(
                highlightID: "h-2",
                bookID: book.id,
                anchor: "pdf:1",
                color: .yellow,
                selectedText: "",
                remoteRecordName: "remote-h-2",
                updatedAt: original.updatedAt.addingTimeInterval(10),
                deletedAt: original.updatedAt.addingTimeInterval(10)
            )
        )

        let visible = try await ann.fetchHighlights(bookId: book.id)
        let stored = try await ann.fetchHighlight(id: "h-2", includeDeleted: true)
        #expect(visible.isEmpty)
        #expect(stored?.deletedAt != nil)
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
