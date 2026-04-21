# Story 3.2: iPhone Highlight Creation & Deletion

**Epic:** 3 — Cross-Device Highlights  
**Status:** ready for review  
**Created:** 2026-04-21

---

## Story

Как пользователь iPhone, я хочу создавать и удалять highlights в PDF, чтобы мобильное чтение было не только для просмотра, но и для выделения важных мест.

## Acceptance Criteria

- AC-1: На iPhone можно выделить текст в PDF и создать highlight
- AC-2: Highlight локально сохраняется и сразу отображается
- AC-3: Удаление highlight доступно на iPhone
- AC-4: Создание и удаление уходят в sync pipeline
- AC-5: После синхронизации эти highlights корректно видны на macOS

## Tasks / Subtasks

- [x] Task 1: Реализовать text selection -> create highlight flow на iPhone
- [x] Task 2: Реализовать delete highlight flow
- [x] Task 3: Подключить local persistence
- [x] Task 4: Подключить sync enqueue

## Dev Notes

- Для MVP на iPhone достаточно create/delete; смену цвета можно отложить
- Это уменьшает объём UX и делает поведение проще для тестирования

---

## Dev Agent Record

### Implemented

- В `IPhonePDFReaderView` selection из `PDFView` конвертируется в `PDFAnchor` и передаётся в `HighlightsStore`.
- Создание highlight локально сохраняется через shared `AnnotationRepository`, сразу рендерится в `PDFView` и публикуется в sync pipeline.
- Удаление active highlight доступно из toolbar и тоже уходит в sync pipeline.
- Для iPhone MVP intentionally оставлен только create/delete flow без color edit UX.

### Verification

- Create/delete flow входит в успешно собранный `ReaderiPhone` target.
- Merge/tombstone поведение проверяется macOS unit tests на shared repository/sync layer.

### File List

- /Users/ekoshkin/reader/Reader/Features/Annotations/HighlightsStore.swift
- /Users/ekoshkin/reader/ReaderiPhone/Features/IPhonePDFReaderView.swift
