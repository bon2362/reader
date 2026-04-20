# Story 3.3: Sticky Notes (Type B)

**Epic:** 3 — Annotations
**Status:** review
**Created:** 2026-04-18

---

## Story

Как пользователь, я хочу добавить sticky-заметку к текущей странице (не к выделенному тексту) через кнопку в тулбаре или Cmd+Shift+N, видеть её в правом margin привязанной к spine-разделу и разворачивать/сворачивать по клику.

## Acceptance Criteria

- AC-1: В `ReaderToolbar` есть кнопка «Sticky» (иконка `note.text.badge.plus`) → создаёт новую sticky с пустым body для текущего spineIndex
- AC-2: Cmd+Shift+N — тот же shortcut
- AC-3: Sticky сохраняется в `page_notes` (spineIndex + body), `StickyNotesStore` @Observable управляет CRUD
- AC-4: `StickyNotesOverlayView` в правом margin ReaderView показывает только sticky для `currentSpineIndex`
- AC-5: Клик по sticky-иконке → разворачивает popover с TextEditor (edit inline) + кнопкой удаления
- AC-6: Не зависит от CFI / pagination — позиция фиксирована на странице (margin, вертикально распределены)
- AC-7: Тесты для `StickyNotesStore` (CRUD, фильтр по spine)

## Tasks / Subtasks

- [x] Task 1: StickyNotesStore
  - [x] 1.1 @Observable — notes, expandedId, draftId
  - [x] 1.2 `loadForBook(bookId:)`
  - [x] 1.3 `createAt(spineIndex:)` — вставка пустой заметки + expandedId=new.id
  - [x] 1.4 `updateBody(id:, body:)`
  - [x] 1.5 `delete(id:)`
  - [x] 1.6 `notesForSpine(_:)` — фильтр
  - [x] 1.7 `reset()`

- [x] Task 2: UI — StickyNotesOverlayView
  - [x] 2.1 GeometryReader + VStack стикеров в правом margin
  - [x] 2.2 Каждый stiker — Button с Image(`note.text`), popover при expandedId==id
  - [x] 2.3 Popover: TextEditor с autosave onChange, кнопка удаления
  - [x] 2.4 Индекс по позиции (i*44 pt) с clamp

- [x] Task 3: Toolbar + shortcut
  - [x] 3.1 Кнопка «Sticky» в ReaderToolbar (onAddSticky callback)
  - [x] 3.2 Cmd+Shift+N — hidden Button в ReaderView

- [x] Task 4: Интеграция
  - [x] 4.1 ReaderStore.stickyNotesStore
  - [x] 4.2 openBook → loadForBook, reset
  - [x] 4.3 ReaderView — оверлей с фильтром по currentSpineIndex

- [x] Task 5: Тесты
  - [x] 5.1 StickyNotesStoreTests — CRUD, filter by spine

## Dev Notes

### StickyNotesStore API

```swift
@MainActor @Observable
final class StickyNotesStore {
    var notes: [PageNote] = []
    var expandedId: String?

    func loadForBook(bookId: String) async
    func reset()
    func createAt(spineIndex: Int) async
    func updateBody(id: String, body: String) async
    func delete(id: String) async
    func notesForSpine(_ spineIndex: Int) -> [PageNote]
    func toggleExpand(id: String)
}
```

### UI заметка

Стикеры — маленькие круглые иконки на правой кромке. Popover ~260pt.  TextEditor обновляет body — autosave через `.onChange(of:)` дебаунс не обязателен (небольшой текст, пишем каждое изменение).

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

- Reader/Features/Annotations/StickyNotesStore.swift (new)
- Reader/Features/Annotations/StickyNotesOverlayView.swift (new)
- Reader/Features/Reader/ReaderToolbar.swift (onAddSticky)
- Reader/Features/Reader/ReaderStore.swift (stickyNotesStore + addStickyNoteForCurrentPage)
- Reader/Features/Reader/ReaderView.swift (overlay, toolbar callback, Cmd+Shift+N shortcut)
- ReaderTests/Features/StickyNotesStoreTests.swift (new, 9 tests)

---

## Change Log

_Заполняется агентом_
