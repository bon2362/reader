import Foundation
import Observation

@MainActor
@Observable
final class StickyNotesStore {
    var notes: [PageNote] = []
    var expandedId: String?
    var errorMessage: String?

    private let repository: AnnotationRepositoryProtocol
    private var bookId: String?

    init(repository: AnnotationRepositoryProtocol) {
        self.repository = repository
    }

    func loadForBook(bookId: String) async {
        self.bookId = bookId
        do {
            notes = try await repository.fetchPageNotes(bookId: bookId)
        } catch {
            errorMessage = "Не удалось загрузить sticky-заметки"
        }
    }

    func reset() {
        notes = []
        expandedId = nil
        bookId = nil
    }

    func createAt(spineIndex: Int, pageInChapter: Int = 0) async {
        guard let bookId else { return }
        let note = PageNote(bookId: bookId, spineIndex: spineIndex, pageInChapter: pageInChapter, body: "")
        do {
            try await repository.insertPageNote(note)
            notes.append(note)
            expandedId = note.id
        } catch {
            errorMessage = "Не удалось создать sticky-заметку"
        }
    }

    func updateBody(id: String, body: String) async {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        var updated = notes[idx]
        updated.body = body
        do {
            try await repository.updatePageNote(updated)
            notes[idx] = updated
        } catch {
            errorMessage = "Не удалось обновить sticky-заметку"
        }
    }

    func delete(id: String) async {
        do {
            try await repository.deletePageNote(id: id)
            notes.removeAll { $0.id == id }
            if expandedId == id { expandedId = nil }
        } catch {
            errorMessage = "Не удалось удалить sticky-заметку"
        }
    }

    func notesForSpine(_ spineIndex: Int) -> [PageNote] {
        notes.filter { $0.spineIndex == spineIndex }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func notesForPage(spineIndex: Int, pageInChapter: Int) -> [PageNote] {
        notes.filter { $0.spineIndex == spineIndex && $0.pageInChapter == pageInChapter }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func toggleExpand(id: String) {
        expandedId = (expandedId == id) ? nil : id
    }

    func collapse() { expandedId = nil }
}
