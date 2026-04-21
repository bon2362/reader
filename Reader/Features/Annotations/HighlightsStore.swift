import Foundation
import CoreGraphics
import Observation

struct SelectionInfo: Equatable, Hashable {
    let cfiStart: String
    let cfiEnd: String
    let text: String
    var rect: CGRect? = nil
}

@MainActor
@Observable
final class HighlightsStore {
    var highlights: [Highlight] = []
    var pendingSelection: SelectionInfo?
    var activeHighlightId: String?
    var errorMessage: String?

    private let repository: AnnotationRepositoryProtocol
    private let syncCoordinator: HighlightSyncing?
    private weak var bridge: EPUBBridgeProtocol?
    private var bookId: String?
    private var externalRender: (@MainActor (Highlight) -> Void)?
    private var externalRemove: (@MainActor (String) -> Void)?

    init(repository: AnnotationRepositoryProtocol, syncCoordinator: HighlightSyncing? = nil) {
        self.repository = repository
        self.syncCoordinator = syncCoordinator
    }

    func bindBridge(_ bridge: EPUBBridgeProtocol) {
        self.bridge = bridge
        externalRender = nil
        externalRemove = nil
    }

    func bindExternalRenderer(
        render: @escaping @MainActor (Highlight) -> Void,
        remove: @escaping @MainActor (String) -> Void
    ) {
        bridge = nil
        externalRender = render
        externalRemove = remove
    }

    // MARK: - Lifecycle

    func loadAndRender(bookId: String) async {
        self.bookId = bookId
        do {
            let loaded = try await repository.fetchHighlights(bookId: bookId)
            highlights = loaded
            for h in loaded {
                renderOnBridge(h)
            }
        } catch {
            errorMessage = "Не удалось загрузить хайлайты"
        }
    }

    func reset() {
        highlights = []
        pendingSelection = nil
        activeHighlightId = nil
        bookId = nil
        externalRender = nil
        externalRemove = nil
    }

    // MARK: - Selection flow

    func onTextSelected(cfiStart: String, cfiEnd: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let existingRect = pendingSelection?.rect
        pendingSelection = SelectionInfo(cfiStart: cfiStart, cfiEnd: cfiEnd, text: trimmed, rect: existingRect)
        activeHighlightId = nil
    }

    func updateSelectionRect(_ rect: CGRect?) {
        guard var current = pendingSelection else { return }
        current = SelectionInfo(cfiStart: current.cfiStart, cfiEnd: current.cfiEnd, text: current.text, rect: rect)
        pendingSelection = current
    }

    func onSelectionCleared() {
        pendingSelection = nil
    }

    func cancelPendingSelection() { pendingSelection = nil }

    func applyColor(_ color: HighlightColor) async {
        guard let selection = pendingSelection, let bookId else { return }
        let highlight = Highlight(
            bookId: bookId,
            cfiStart: selection.cfiStart,
            cfiEnd: selection.cfiEnd,
            color: color,
            selectedText: selection.text
        )
        do {
            try await repository.insertHighlight(highlight)
            highlights.append(highlight)
            renderOnBridge(highlight)
            pendingSelection = nil
            await syncCoordinator?.publishHighlightChange(id: highlight.id)
        } catch {
            errorMessage = "Не удалось сохранить хайлайт"
        }
    }

    // MARK: - Tap on existing

    func onHighlightTapped(id: String) {
        activeHighlightId = id
        pendingSelection = nil
    }

    func dismissActiveHighlight() { activeHighlightId = nil }

    func changeActiveColor(_ color: HighlightColor) async {
        guard let id = activeHighlightId,
              let idx = highlights.firstIndex(where: { $0.id == id }) else { return }
        var updated = highlights[idx]
        updated.color = color
        do {
            try await repository.updateHighlight(updated)
            highlights[idx] = updated
            bridge?.removeHighlight(id: id)
            externalRemove?(id)
            renderOnBridge(updated)
            await syncCoordinator?.publishHighlightChange(id: id)
        } catch {
            errorMessage = "Не удалось обновить хайлайт"
        }
    }

    func deleteActive() async {
        guard let id = activeHighlightId else { return }
        do {
            try await repository.deleteHighlight(id: id)
            highlights.removeAll { $0.id == id }
            bridge?.removeHighlight(id: id)
            externalRemove?(id)
            activeHighlightId = nil
            await syncCoordinator?.publishHighlightDeletion(id: id)
        } catch {
            errorMessage = "Не удалось удалить хайлайт"
        }
    }

    // MARK: - Helpers

    var activeHighlight: Highlight? {
        guard let id = activeHighlightId else { return nil }
        return highlights.first { $0.id == id }
    }

    private func renderOnBridge(_ h: Highlight) {
        bridge?.highlightRange(cfiStart: h.cfiStart, cfiEnd: h.cfiEnd, color: h.color, id: h.id)
        externalRender?(h)
    }
}
