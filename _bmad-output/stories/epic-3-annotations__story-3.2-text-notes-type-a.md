# Story 3.2: Text Notes (Type A)

**Epic:** 3 — Annotations
**Status:** done
**Created:** 2026-04-18

---

## Story

Как пользователь, я хочу добавить текстовую заметку к выделенному тексту, видеть маркер-иконку в правом margin напротив заметки и разворачивать/сворачивать её содержимое по клику.

## Acceptance Criteria

- AC-1: В панели выделения есть кнопка "Заметка" → открывается `NoteEditorView` с TextEditor
- AC-2: Сохранение → `TextNote` в БД (cfi_anchor, body, highlight_id NULLABLE)
- AC-3: На каждом `pageChanged` Swift отправляет CFI-якоря заметок в JS (`setAnnotations`)
- AC-4: reader.js resolves каждый CFI → bounding rect → emits `annotationPositions` с Y-координатами
- AC-5: `MarginOverlayView` отрисовывает маркеры в правом margin на переданных Y-позициях
- AC-6: Клик по маркеру → разворачивает превью с возможностью редактирования/удаления
- AC-7: Тесты для `TextNotesStore` (CRUD, фильтрация по current page через received positions)

## Tasks / Subtasks

- [x] Task 1: Bridge — setAnnotations команда
  - [x] 1.1 `BridgeCommand.setAnnotations([AnnotationAnchor])` с JSON-encoded payload
  - [x] 1.2 `AnnotationAnchor` struct (id, cfi, type)
  - [x] 1.3 `EPUBBridgeProtocol.setAnnotations(_:)`
  - [x] 1.4 MockEPUBBridge.setAnnotationsCalls

- [x] Task 2: reader.js
  - [x] 2.1 Хранит currentAnnotations = [{id, cfi, type}]
  - [x] 2.2 `setAnnotations` сохраняет список + recompute
  - [x] 2.3 recomputePositions: для каждого аннотации `contents.range(cfi).getBoundingClientRect()` → emit annotationPositions
  - [x] 2.4 Автопересчёт на каждом `relocated`

- [x] Task 3: TextNotesStore
  - [x] 3.1 @Observable — notes, positions, expandedNoteId, draft state
  - [x] 3.2 `loadForBook`, `addNote(selection, body, highlightId?)`, `updateNote`, `deleteNote`
  - [x] 3.3 `handlePositions([AnnotationPosition])` → отфильтровать по type="note"
  - [x] 3.4 `syncAnnotationsToBridge` — отправляет текущий список при pageChanged

- [x] Task 4: UI
  - [x] 4.1 Кнопка "Заметка" в `HighlightColorPicker` (при pendingSelection)
  - [x] 4.2 `NoteEditorView` — sheet с TextEditor, Сохранить/Отмена
  - [x] 4.3 `MarginOverlayView` — ZStack маркеров по Y
  - [x] 4.4 Inline expand — popover у маркера с body + кнопки

- [x] Task 5: Интеграция
  - [x] 5.1 ReaderStore.openBook → textNotesStore.loadForBook
  - [x] 5.2 pageChanged → syncAnnotationsToBridge
  - [x] 5.3 annotationPositions delegate → textNotesStore.handlePositions
  - [x] 5.4 MarginOverlayView в правом margin ReaderView

- [x] Task 6: Тесты
  - [x] 6.1 `TextNotesStoreTests.swift` — CRUD, position handling, bridge sync

## Dev Notes

### AnnotationAnchor и JSON

```swift
struct AnnotationAnchor: Codable, Hashable {
    let id: String
    let cfi: String
    let type: String   // "note" | "highlight"
}
```

Bridge command сериализует через JSONEncoder → передаёт как `setAnnotations('[{...}]')`.

### MarginOverlayView

Маркер — SwiftUI Button с Image(systemName: "note.text") на правой кромке ZStack в ReaderView. Y позиция — из AnnotationPosition. При превышении ширины — просто клэмпим.

### Expand/collapse

`expandedNoteId: String?` — при нажатии на маркер store.expandedNoteId = id. Popover у маркера показывает body + actions.

### Текст в NoteEditorView

NoteEditorView принимает SelectionInfo + существующий TextNote (nil для create). TextEditor с автофокусом, Cmd+Return сохраняет.

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

- Reader/Bridge/AnnotationAnchor.swift (new)
- Reader/Bridge/BridgeCommand.swift (setAnnotations case)
- Reader/Bridge/EPUBBridge.swift (setAnnotations)
- Reader/Bridge/EPUBBridgeProtocol.swift (setAnnotations)
- Reader/Resources/JS/reader.js (currentAnnotations + setAnnotations + recomputePositions)
- Reader/Features/Annotations/TextNotesStore.swift (new)
- Reader/Features/Annotations/NoteEditorView.swift (new)
- Reader/Features/Annotations/MarginOverlayView.swift (new)
- Reader/Features/Annotations/HighlightColorPicker.swift (onNote button)
- Reader/Features/Reader/ReaderStore.swift (textNotesStore wiring)
- Reader/Features/Reader/ReaderView.swift (overlay, sheet, Note button)
- ReaderTests/Bridge/MockEPUBBridge.swift (setAnnotationsCalls)
- ReaderTests/Bridge/EPUBBridgeTests.swift (setAnnotations JS tests)
- ReaderTests/Features/TextNotesStoreTests.swift (new, 12 tests)

---

## Change Log

_Заполняется агентом_
