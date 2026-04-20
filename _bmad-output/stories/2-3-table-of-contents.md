# Story 2.3: Table of Contents

**Epic:** 2 — Core Reading
**Status:** review
**Created:** 2026-04-18

---

## Story

Как пользователь, я хочу видеть оглавление книги в боковой панели и переходить к главам по клику, чтобы быстро ориентироваться в структуре книги.

## Acceptance Criteria

- AC-1: При открытии книги TOC автоматически загружается из EPUB metadata
- AC-2: `TOCView` отображает иерархический список глав с отступами по уровню
- AC-3: Клик по главе → переход через `bridge.goToCFI(href)`
- AC-4: Текущая глава подсвечена (основано на `currentSpineIndex`)
- AC-5: Панель TOC можно скрыть/показать через кнопку в тулбаре
- AC-6: Название текущей главы отображается в `ReaderToolbar`
- AC-7: Тесты для `TOCStore` и парсинга TOC

## Tasks / Subtasks

- [x] Task 1: TOCEntry + Bridge (getTOC command, tocLoaded message, getTOC protocol, bridgeDidLoadTOC, MockEPUBBridge.simulateTOCLoaded)
- [x] Task 2: reader.js — `flattenTOC`, автоэмит `tocLoaded` при loadBook + `getTOC` команда; `sectionHref` добавлен в `pageChanged`
- [x] Task 3: TOCStore (@Observable, setEntries, updateCurrentSection, toggleVisibility)
- [x] Task 4: TOCView (List, иерархия по level, подсветка currentEntryId)
- [x] Task 5: Интеграция — TOC-кнопка в ReaderToolbar, HStack c TOCView слева, chapterTitle в toolbar
- [x] Task 6: TOCStoreTests.swift — 11 тестов

## Dev Notes

### TOCEntry

```swift
struct TOCEntry: Identifiable, Hashable {
    let id: String      // stable id (uuid из JS или hash href)
    let label: String
    let href: String    // CFI или internal path
    let level: Int      // 0 — root, 1+ — подразделы
}
```

Хранить flat со level — так проще в SwiftUI List. Родительская связь не нужна для отображения.

### epub.js API

```js
book.loaded.navigation.then(nav => {
    // nav.toc — массив { id, href, label, subitems: [...] }
});
```

### Определение текущей главы

`spineIndex` из `pageChanged` → ищем в TOC entry с href соответствующим этому spine item. Упрощение: matching по `href` подстрокой.

---

## Dev Agent Record

### Implementation Plan

- TOC извлекается автоматически при `loadBook` в reader.js + `getTOC` команда доступна
- TOCEntry — flat struct с level; иерархия выражается отступом в List
- Определение текущей главы: добавили `sectionHref` в `pageChanged` (location.start.href в epub.js); matching по нормализованному href с предпочтением самого глубокого уровня
- TOCStore — отдельный @Observable, принадлежит ReaderStore (составная композиция)
- ReaderView использует HStack: TOCView слева (260pt) + readerPane; видимость через `tocStore.isVisible`

### Debug Log

- BridgeMessage.pageChanged расширено: добавлен `sectionHref: String?`
- EPUBBridgeDelegate.bridgeDidChangePage — подпись обновлена
- EPUBBridgeTests.parsesPageChanged — адаптирован под новую подпись

### Completion Notes

- 86/86 тестов проходят (было 75, добавлено 11)
- TOC панель скрыта по умолчанию, открывается по кнопке `list.bullet` в toolbar
- Название текущей главы показывается под названием книги в toolbar

---

## File List

- Reader/Features/Reader/TOCEntry.swift (new)
- Reader/Features/Reader/TOCStore.swift (new)
- Reader/Features/Reader/TOCView.swift (new)
- Reader/Bridge/BridgeCommand.swift (getTOC)
- Reader/Bridge/BridgeMessage.swift (tocLoaded, pageChanged.sectionHref)
- Reader/Bridge/EPUBBridgeProtocol.swift (getTOC, bridgeDidLoadTOC, sectionHref)
- Reader/Bridge/EPUBBridge.swift (routing)
- Reader/Features/Reader/ReaderStore.swift (tocStore, navigateToTOCEntry, currentSectionHref)
- Reader/Features/Reader/ReaderView.swift (HStack с TOC)
- Reader/Features/Reader/ReaderToolbar.swift (onToggleTOC)
- Reader/Resources/JS/reader.js (flattenTOC, sectionHref)
- ReaderTests/Bridge/MockEPUBBridge.swift (simulateTOCLoaded, sectionHref)
- ReaderTests/Bridge/EPUBBridgeTests.swift (pageChanged signature)
- ReaderTests/Features/TOCStoreTests.swift (new, 11 тестов)

---

## Change Log

- 2026-04-18: Story 2.3 завершена. TOC извлечение, панель, подсветка текущей главы, навигация. 86/86 тестов.
