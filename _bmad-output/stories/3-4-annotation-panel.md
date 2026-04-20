# Story 3.4: Annotation Panel

**Epic:** 3 — Annotations
**Status:** review
**Created:** 2026-04-19

---

## Story

Как пользователь, я хочу видеть панель со всеми моими аннотациями (хайлайты, text notes, sticky notes) с вкладками фильтрации и кликом переходить к нужной позиции в книге.

## Acceptance Criteria

- AC-1: Кнопка «Аннотации» в `ReaderToolbar` (иконка `bookmark`) → открывает/закрывает `AnnotationPanelView` справа (по аналогии с SearchView)
- AC-2: Панель содержит 4 вкладки через `Picker(.segmented)`: Все / Хайлайты / Заметки / Sticky
- AC-3: Каждая запись показывает: иконку (цвет хайлайта / note.text / note.text.badge.plus), превью (цитата или body, truncated), № главы, № страницы
- AC-4: Клик по записи → навигация: highlight/text-note → `bridge.goToCFI(cfiAnchor)`; sticky → `bridge.goToCFI(spine href через TOC)` либо при отсутствии — спец-команда spine jump
- AC-5: Сортировка внутри вкладки по позиции в книге (spineIndex asc; внутри spine — по cfi/createdAt)
- AC-6: Счётчик в заголовке вкладки (например, «Хайлайты 5»)
- AC-7: Тесты для `AnnotationPanelStore` (агрегация, фильтрация по tab, сортировка)

## Tasks / Subtasks

- [x] Task 1: Модель AnnotationListItem + AnnotationPanelStore
  - [x] 1.1 `enum AnnotationKind` — highlight / note / sticky
  - [x] 1.2 `struct AnnotationListItem` — id, kind, preview, spineIndex, cfi, chapterLabel
  - [x] 1.3 `@Observable AnnotationPanelStore` — isVisible, selectedTab, build items из HighlightsStore/TextNotesStore/StickyNotesStore/TOCStore
  - [x] 1.4 Сортировка по spineIndex

- [x] Task 2: UI — AnnotationPanelView
  - [x] 2.1 Picker вкладок с счётчиками
  - [x] 2.2 List с AnnotationRowView (иконка + превью + chapter + page)
  - [x] 2.3 Empty state для пустой вкладки
  - [x] 2.4 Клик → onSelect(item)

- [x] Task 3: Bridge — spine navigation (для sticky)
  - [x] 3.1 Для sticky используем TOC.href ближайшей главы из spineIndex, либо `goToCFI(spineIndex)` через epub.js spine → `book.spine.get(index).href`
  - [x] 3.2 Добавить `BridgeCommand.goToSpine(index:)` + JS handler

- [x] Task 4: Интеграция в ReaderView
  - [x] 4.1 Toolbar кнопка → `annotationPanelStore.toggleVisibility()`
  - [x] 4.2 AnnotationPanelView справа (вместо/рядом со SearchView)
  - [x] 4.3 onSelect → bridge navigation + скрыть панель (опц.)

- [x] Task 5: Тесты
  - [x] 5.1 AnnotationPanelStoreTests — агрегация, tab-фильтр, сортировка, счётчики

## Dev Notes

### Items build

```swift
func rebuildItems() {
    var items: [AnnotationListItem] = []
    // highlights
    for h in highlightsStore.highlights {
        items.append(.init(
            id: h.id, kind: .highlight,
            preview: h.selectedText,
            spineIndex: nil,   // spine unknown at this layer — use 0 or parse
            cfi: h.cfiStart,
            color: h.color
        ))
    }
    // ...
}
```

Для spineIndex у highlight/note можно сохранить spineIndex при создании (TODO: сейчас не хранится). Для MVP: сортируем по `cfi` лексикографически (не идеально, но приемлемо), sticky — по spineIndex.

### spineIndex поле в Highlight/TextNote

Проще в этом спринте не вводить — сортировать по cfi (строковое сравнение epubcfi) + для sticky по spineIndex. Chapter label — обычно надо резолвить через TOC (можно позже).

### Bridge goToSpine

```swift
case goToSpine(Int)  // "window.readerBridge.goToSpine(3);"
```

JS:
```js
goToSpine: function(index) {
    if (!book) return;
    var item = book.spine.get(index);
    if (item && rendition) rendition.display(item.href);
}
```

---

## Dev Agent Record

### Implementation Plan

_Заполняется агентом_

### Debug Log

_Заполняется агентом_

### Completion Notes

_Заполняется агентом_

---

## File List

- Reader/Features/Annotations/AnnotationListItem.swift (new)
- Reader/Features/Annotations/AnnotationPanelStore.swift (new)
- Reader/Features/Annotations/AnnotationPanelView.swift (new)
- Reader/Bridge/BridgeCommand.swift (goToSpine case)
- Reader/Bridge/EPUBBridge.swift (goToSpine)
- Reader/Bridge/EPUBBridgeProtocol.swift (goToSpine)
- Reader/Resources/JS/reader.js (goToSpine handler)
- Reader/Features/Reader/ReaderStore.swift (annotationPanelStore + navigateToAnnotation)
- Reader/Features/Reader/ReaderToolbar.swift (onToggleAnnotations button)
- Reader/Features/Reader/ReaderView.swift (panel on the right)
- ReaderTests/Bridge/MockEPUBBridge.swift (goToSpineCalls)
- ReaderTests/Features/AnnotationPanelStoreTests.swift (new, 8 tests)

---

## Change Log

_Заполняется агентом_
