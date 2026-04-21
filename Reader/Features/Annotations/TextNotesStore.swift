import Foundation
import Observation
import CoreGraphics

@MainActor
@Observable
final class TextNotesStore {
    var notes: [TextNote] = []
    var positions: [AnnotationPosition] = []
    var expandedNoteId: String?
    var draftSelection: SelectionInfo?
    var draftEditingNote: TextNote?
    var isEditorPresented: Bool = false
    var errorMessage: String?

    var tappedNoteId: String?
    var tappedNotePoint: CGPoint = .zero

    private let repository: AnnotationRepositoryProtocol
    private weak var bridge: EPUBBridgeProtocol?
    private var bookId: String?

    init(repository: AnnotationRepositoryProtocol) {
        self.repository = repository
    }

    func bindBridge(_ bridge: EPUBBridgeProtocol) {
        self.bridge = bridge
    }

    // MARK: - Lifecycle

    func loadForBook(bookId: String) async {
        self.bookId = bookId
        do {
            let loaded = try await repository.fetchTextNotes(bookId: bookId)
            notes = loaded
            syncAnnotationsToBridge()
        } catch {
            errorMessage = "Не удалось загрузить заметки"
        }
    }

    func reset() {
        notes = []
        positions = []
        expandedNoteId = nil
        draftSelection = nil
        draftEditingNote = nil
        isEditorPresented = false
        tappedNoteId = nil
        tappedNotePoint = .zero
        bookId = nil
    }

    func onNoteTapped(id: String, at point: CGPoint) {
        tappedNoteId = id
        tappedNotePoint = point
    }

    func dismissTappedNote() {
        tappedNoteId = nil
    }

    // MARK: - Draft / editor

    func beginNote(for selection: SelectionInfo, highlightId: String? = nil) {
        draftSelection = selection
        draftEditingNote = nil
        isEditorPresented = true
    }

    func beginEdit(noteId: String) {
        guard let note = notes.first(where: { $0.id == noteId }) else { return }
        draftEditingNote = note
        draftSelection = nil
        isEditorPresented = true
    }

    func cancelEditor() {
        draftSelection = nil
        draftEditingNote = nil
        isEditorPresented = false
    }

    // MARK: - CRUD

    func addNote(body: String, highlightId: String? = nil) async {
        guard let selection = draftSelection, let bookId else { return }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let note = TextNote(
            bookId: bookId,
            highlightId: highlightId,
            cfiAnchor: selection.cfiStart.hasPrefix("pdf:") ? selection.cfiStart : "\(selection.cfiStart)||\(selection.cfiEnd)",
            body: trimmed
        )
        do {
            try await repository.insertTextNote(note)
            notes.append(note)
            draftSelection = nil
            isEditorPresented = false
            syncAnnotationsToBridge()
        } catch {
            errorMessage = "Не удалось сохранить заметку"
        }
    }

    func updateNote(body: String) async {
        guard let editing = draftEditingNote,
              let idx = notes.firstIndex(where: { $0.id == editing.id }) else { return }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var updated = notes[idx]
        updated.body = trimmed
        do {
            try await repository.updateTextNote(updated)
            notes[idx] = updated
            draftEditingNote = nil
            isEditorPresented = false
        } catch {
            errorMessage = "Не удалось обновить заметку"
        }
    }

    func deleteNote(id: String) async {
        do {
            try await repository.deleteTextNote(id: id)
            notes.removeAll { $0.id == id }
            if expandedNoteId == id { expandedNoteId = nil }
            syncAnnotationsToBridge()
        } catch {
            errorMessage = "Не удалось удалить заметку"
        }
    }

    // MARK: - Expand

    func toggleExpand(id: String) {
        expandedNoteId = (expandedNoteId == id) ? nil : id
    }

    func collapse() { expandedNoteId = nil }

    // MARK: - Positions

    func handlePositions(_ incoming: [AnnotationPosition]) {
        let noteIds = Set(notes.map { $0.id })
        positions = incoming.filter { $0.type == "note" && noteIds.contains($0.id) }
    }

    var visiblePositions: [AnnotationPosition] { positions }

    // MARK: - Bridge sync

    func syncAnnotationsToBridge() {
        let anchors = notes.map { AnnotationAnchor(id: $0.id, cfi: $0.cfiAnchor, type: "note") }
        bridge?.setAnnotations(anchors)
    }
}
