# Story 2.4: Text Search

**Epic:** 2 — Core Reading
**Status:** done
**Created:** 2026-04-18

---

## Story

Как пользователь, я хочу искать текст по всей книге по Cmd+F, видеть список результатов с контекстом и переходить между ними, чтобы быстро находить нужные фрагменты.

## Acceptance Criteria

- AC-1: Cmd+F открывает `SearchView` (боковая панель или overlay в reader)
- AC-2: Ввод запроса → debounce 300ms → `bridge.search(query)`
- AC-3: reader.js проходит по всем spine items, находит вхождения (case-insensitive), возвращает массив `{cfi, excerpt}`
- AC-4: `SearchView` отображает список результатов: excerpt c выделенным термином + номер главы
- AC-5: Клик по результату → `bridge.goToCFI(cfi)` + закрытие панели (опционально)
- AC-6: Esc закрывает поиск
- AC-7: Показывается "N результатов" или "Ничего не найдено"
- AC-8: Состояние загрузки во время поиска
- AC-9: Тесты для `SearchStore` (debounce, результаты, навигация)

## Tasks / Subtasks

- [x] Task 1: SearchStore (@Observable — query, results, isSearching, isVisible + debounce 300ms + selectResult)
- [x] Task 2: SearchView (TextField + подсветка вхождения в excerpt через AttributedString, статус поиска, плюрализация)
- [x] Task 3: Интеграция — Cmd+F keyboardShortcut, Esc закрывает, панель справа (300pt)
- [x] Task 4: reader.js — TreeWalker по текстовым узлам, все вхождения, CFI через `item.cfiFromRange(range)`, лимит 50 на spine
- [x] Task 5: SearchStoreTests.swift — 10 тестов (включая ReaderStore routing)

## Dev Notes

### SearchStore

```swift
@MainActor
@Observable
final class SearchStore {
    var query: String = ""
    var results: [SearchResult] = []
    var isSearching: Bool = false
    var isVisible: Bool = false
    private weak var bridge: EPUBBridgeProtocol?
    private var searchTask: Task<Void, Never>?

    func performSearch(_ q: String) { /* debounce через Task.sleep */ }
    func selectResult(_ r: SearchResult) { bridge?.goToCFI(r.cfi) }
}
```

### Debounce

Через `Task.sleep(300ms)` + cancel предыдущей задачи при каждом вводе.

### AttributedString подсветка

```swift
var attr = AttributedString(excerpt)
if let range = attr.range(of: query, options: .caseInsensitive) {
    attr[range].foregroundColor = .accentColor
    attr[range].inlinePresentationIntent = .stronglyEmphasized
}
```

### reader.js

Текущий search возвращает только первое вхождение на spine item. Улучшение: использовать regex для всех вхождений + корректный CFI для каждого.

Однако epub.js API для получения CFI от произвольной позиции в тексте ограничен — используем `item.find(query)` если есть, иначе — минимальная версия: одно вхождение на spine (итеративно улучшим в Phase 2).

---

## Dev Agent Record

### Implementation Plan

- SearchStore держит debounceTask (`Task { @MainActor ... }`) и отменяет предыдущую при каждом `updateQuery`
- Пустой/whitespace запрос очищает результаты и не дергает bridge
- ReaderStore владеет SearchStore, в `bindBridge` пробрасывает bridge в searchStore
- `bridgeDidReceiveSearchResults` → `searchStore.handleResults`
- reader.js: TreeWalker по SHOW_TEXT узлам, `item.cfiFromRange(range)` даёт точный CFI на позицию вхождения

### Debug Log

- Для корректной отмены задачи при вводе использован `debounceTask?.cancel()` + `Task.isCancelled` проверка
- Плюрализация "результат/результата/результатов" по русским правилам
- `keyboardShortcut("f", modifiers: .command)` повешен на скрытый Button через `.background` — работает глобально в reader

### Completion Notes

- 96/96 тестов (было 86, добавлено 10)
- Поиск открывается по Cmd+F, закрывается Esc или крестиком
- Клик по результату → bridge.goToCFI (панель остаётся открытой)

---

## File List

- Reader/Features/Reader/SearchStore.swift (new)
- Reader/Features/Reader/SearchView.swift (new)
- Reader/Features/Reader/ReaderStore.swift (searchStore, bindBridge, handleResults)
- Reader/Features/Reader/ReaderView.swift (SearchView panel + Cmd+F shortcut)
- Reader/Resources/JS/reader.js (TreeWalker search, findMatchesInDocument)
- ReaderTests/Features/SearchStoreTests.swift (new, 10 тестов)

---

## Change Log

- 2026-04-18: Story 2.4 завершена. Cmd+F поиск с debounce, подсветка в excerpt, навигация к результату. 96/96 тестов.
