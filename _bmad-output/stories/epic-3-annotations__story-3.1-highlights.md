# Story 3.1: Highlights

**Epic:** 3 — Annotations
**Status:** done
**Created:** 2026-04-18

---

## Story

Как пользователь, я хочу выделить текст и подсветить его одним из 5 цветов, чтобы отмечать важные места в книге. Клик по хайлайту должен позволить сменить цвет или удалить его.

## Acceptance Criteria

- AC-1: При выделении текста в reader → `bridge.textSelected` → Swift показывает панель выбора цвета (5 цветов)
- AC-2: Клик по цвету → создаётся `Highlight` (id, cfiStart, cfiEnd, color) → сохраняется в БД → `bridge.highlightRange(...)` отрисовывает
- AC-3: При открытии книги → `AnnotationRepository.fetchHighlights` → для каждого вызывается `bridge.highlightRange`
- AC-4: Клик по хайлайту в reader → `bridge.highlightTapped(id)` → Swift показывает меню (смена цвета, удаление)
- AC-5: Смена цвета → update в БД + remove/add через bridge
- AC-6: Удаление → `bridge.removeHighlight` + delete в БД
- AC-7: Текст `selectedText` сохраняется в highlight (для Annotation Panel в 3.4)
- AC-8: Тесты для `HighlightsStore` (CRUD + rendering)

## Tasks / Subtasks

- [x] Task 1: Migration_002 + selected_text колонка + обновлённая Highlight модель
- [x] Task 2: Bridge — highlightTapped message + delegate + mock
- [x] Task 3: reader.js — annotations.add с onClick → highlightTapped, карта highlightRanges для removeHighlight, сброс при loadBook
- [x] Task 4: HighlightsStore (@Observable) — pendingSelection, activeHighlightId, applyColor/changeActiveColor/deleteActive/loadAndRender/reset
- [x] Task 5: HighlightColorPicker — универсальный вид (create и edit режимы), плавающая панель внизу reader
- [x] Task 6: HighlightsStoreTests.swift — 11 тестов

## Dev Notes

### HighlightsStore структура

```swift
@MainActor @Observable
final class HighlightsStore {
    var highlights: [Highlight] = []
    var pendingSelection: SelectionInfo?
    var activeHighlightId: String?
    
    func applyColor(_ color: HighlightColor) { ... }
    func changeColor(_ color: HighlightColor) { ... }
    func deleteActive() { ... }
    func loadAndRender(bookId: String) async { ... }
}

struct SelectionInfo: Equatable {
    let cfiStart: String
    let cfiEnd: String
    let text: String
}
```

### Рендеринг

При `loadAndRender` для каждого highlight → `bridge.highlightRange(cfiStart, cfiEnd, color.rawValue, id)`.

### Смена цвета

Нужно сначала remove, потом add с новым цветом (иначе дублирование).

### Текст highlight

`selectedText` сохраняется в момент создания — используется Annotation Panel. Пока — колонка в БД + поле в модели.

---

## Dev Agent Record

### Implementation Plan

- HighlightsStore — отдельный Observable, принадлежит ReaderStore; bridge прокидывается через bindBridge
- На openBook: reset() + loadAndRender(bookId) — рендерим все хайлайты сразу после loadBook
- Selection → pendingSelection → плавающая панель выбора цвета
- Click на хайлайте → activeHighlightId → та же панель, но в edit-режиме (обведённый цвет + кнопка удаления)
- ReaderStore конструктор теперь требует annotationRepository — обновлены ContentView и все тесты

### Debug Log

- epub.js annotations.add принимает range CFI (не пару); cfiStart используется как полный range (соответствует `new ePub.CFI().fromRange(range)` в textSelected handler)
- JS хранит карту `highlightRanges[id] → cfiRange` для корректного `annotations.remove(cfiRange, 'highlight')`
- onClick колбэк в annotations.add отправляет highlightTapped с id
- Migration_002 добавляет selected_text с DEFAULT '' для совместимости

### Completion Notes

- 107/107 тестов (было 96, добавлено 11)
- 5 цветов через `HighlightColor.allCases` с прямым маппингом на SwiftUI Color
- Смена цвета: remove через bridge → update DB → add с новым цветом (избегаем дублирования SVG overlay)

---

## File List

- Reader/Database/Migrations/Migration_002.swift (new)
- Reader/Database/DatabaseManager.swift (register Migration_002)
- Reader/Database/Models/Highlight.swift (selectedText)
- Reader/Bridge/BridgeMessage.swift (highlightTapped)
- Reader/Bridge/EPUBBridgeProtocol.swift (bridgeDidTapHighlight)
- Reader/Bridge/EPUBBridge.swift (routing)
- Reader/Features/Annotations/HighlightsStore.swift (new)
- Reader/Features/Annotations/HighlightColorPicker.swift (new)
- Reader/Features/Reader/ReaderStore.swift (annotationRepository, highlightsStore, routing)
- Reader/Features/Reader/ReaderView.swift (color picker overlays)
- Reader/App/ContentView.swift (AnnotationRepository wiring)
- Reader/Resources/JS/reader.js (annotations.add onClick, highlightRanges map)
- ReaderTests/Bridge/MockEPUBBridge.swift (simulateHighlightTapped)
- ReaderTests/Features/ReaderStoreTests.swift (annotationRepository)
- ReaderTests/Features/TOCStoreTests.swift (annotationRepository)
- ReaderTests/Features/SearchStoreTests.swift (annotationRepository)
- ReaderTests/Features/HighlightsStoreTests.swift (new, 11 тестов)

---

## Change Log

- 2026-04-18: Story 3.1 завершена. Хайлайты 5 цветов: создание, смена, удаление, persist в SQLite. 107/107 тестов.
