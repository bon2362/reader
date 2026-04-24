# Story 3.1: Local Highlight Creation and Persistence

**Epic:** 3 — Local Highlights and MVP Polish  
**Status:** done  
**Created:** 2026-04-24  
**Dependencies:** Story 2.3

---

## Story

Как пользователь iPhone, я хочу выделять текст в PDF и сохранять highlight локально, чтобы отмечать важные места без какой-либо sync dependency.

## Acceptance Criteria

- AC-1: Выделение текста в iPhone PDF reader позволяет создать локальный highlight с PDF anchor
- AC-2: Новый highlight сохраняется через local annotation repository
- AC-3: После создания highlight отображается в текущем PDF view
- AC-4: Highlight creation не публикует изменения ни в sync coordinator, ни в remote service

## Tasks / Subtasks

- [x] Task 1: Подключить text selection -> highlight action
  - [x] 1.1 Отследить selection в iPhone PDF view
  - [x] 1.2 Подключить highlight action UI
  - [x] 1.3 Преобразовать selection в anchor

- [x] Task 2: Реализовать local persistence
  - [x] 2.1 Сохранить highlight через `AnnotationRepository`
  - [x] 2.2 Проверить связку с current book/page
  - [x] 2.3 Обработать basic failure path

- [x] Task 3: Отрисовать highlight сразу после создания
  - [x] 3.1 Render in current PDF session
  - [x] 3.2 Проверить визуальную согласованность

- [x] Task 4: Проверить отсутствие sync semantics
  - [x] 4.1 Нет remote publication
  - [x] 4.2 Нет sync metadata expansion

## Dev Notes

### Контекст

Эта story добавляет первый annotation value поверх уже рабочего read/resume loop. Она должна оставаться локальной и не затрагивать cross-device semantics.

### Релевантные файлы

- [AnnotationRepository.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/AnnotationRepository.swift)
- [HighlightsStore.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/HighlightsStore.swift)
- [HighlightColorPicker.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/HighlightColorPicker.swift)
- [PDFHighlightRenderer.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFHighlightRenderer.swift)
- [PDFAnchor.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFAnchor.swift)
- [Highlight.swift](/Users/ekoshkin/reader/Reader/Database/Models/Highlight.swift)

### Guardrails

- Не расширять модель sync-specific metadata.
- Не проектировать create flow вокруг будущего sync pipeline.
- Для MVP достаточно одной локальной semantics: create + render + persist.

### Previous Story Intelligence

Опираться на [story 2.3](/Users/ekoshkin/reader/_bmad-output/stories/epic-2-local-pdf-library-and-reader__story-2.3-iphone-pdf-reader-and-resume.md): highlights допустимы только после того, как local reader/resume уже стабилен.

## Definition of Done

- Пользователь может создать highlight из text selection
- Highlight сохраняется локально
- Highlight сразу виден в open PDF view
- Create flow не зависит от sync

---

## Dev Agent Record

### Implementation Plan

- Подключить shared `HighlightsStore` к iPhone reader через external renderer path вместо EPUB bridge semantics
- Добавить selection handling и lightweight iPhone highlight picker без macOS-only hover/UI assumptions
- Оставить persistence и rendering strictly local: `AnnotationRepository` + `PDFHighlightRenderer`, без sync metadata и remote hooks

### Debug Log

- `HighlightsStore` адаптирован для cross-platform reuse: EPUB bridge path ограничен macOS, external renderer path доступен iPhone target
- `IPhonePDFKitView` расширен selection callback и tap detection по существующим highlight annotations
- `IPhonePDFReaderStore` теперь создаёт highlight anchors, сохраняет highlights локально и немедленно рендерит их в текущем `PDFView`
- Добавлен `IPhoneHighlightColorPicker`; selection -> color -> persist flow встроен в iPhone reader overlay

### Completion Notes

- Text selection в iPhone PDF reader создаёт локальный highlight с `PDFAnchor`
- Новый highlight сохраняется через local `AnnotationRepository` и сразу отображается в текущей PDF session
- Create flow не содержит `SyncCoordinator`, remote publication или sync-expanded metadata
- Проверки пройдены: `ReaderiPhone` simulator build успешен, `HighlightsStoreTests` получили coverage для external renderer path, `AnnotationRepositoryTests` зелёные

## File List

- Reader.xcodeproj/project.pbxproj
- Reader/Features/Annotations/HighlightsStore.swift
- Reader/Features/PDFReader/PDFHighlightRenderer.swift
- ReaderTests/Features/HighlightsStoreTests.swift
- ReaderiPhone/Features/Library/IPhoneLibraryStore.swift
- ReaderiPhone/Features/Reader/IPhoneHighlightColorPicker.swift
- ReaderiPhone/Features/Reader/IPhonePDFKitView.swift
- ReaderiPhone/Features/Reader/IPhonePDFReaderStore.swift
- ReaderiPhone/Features/Reader/IPhonePDFReaderView.swift

## Change Log

- 2026-04-24: Story 3.1 завершена. Добавлены local highlight creation, persistence и immediate rendering в standalone iPhone reader.
