# Story 3.2: Highlight Reloading, Rendering, and Deletion

**Epic:** 3 — Local Highlights and MVP Polish  
**Status:** done  
**Created:** 2026-04-24  
**Dependencies:** Story 3.1

---

## Story

Как пользователь iPhone, я хочу, чтобы ранее сохраненные highlights повторно появлялись и могли удаляться, чтобы локальные аннотации оставались согласованными со временем.

## Acceptance Criteria

- AC-1: При повторном открытии книги сохраненные локальные highlights загружаются и рендерятся в reader
- AC-2: Пользователь может удалить существующий highlight, и он исчезает и из local storage, и из visible rendering
- AC-3: После повторного открытия книги удаленные highlights не появляются снова

## Tasks / Subtasks

- [x] Task 1: Реализовать reload path для highlights
  - [x] 1.1 Загрузить highlights текущей книги из local storage
  - [x] 1.2 Преобразовать их в PDF rendering annotations
  - [x] 1.3 Проверить reopen flow

- [x] Task 2: Реализовать delete flow
  - [x] 2.1 Дать способ выбрать existing highlight
  - [x] 2.2 Удалить запись из local storage
  - [x] 2.3 Удалить highlight из visible rendering

- [x] Task 3: Проверить consistency
  - [x] 3.1 Reopen after create
  - [x] 3.2 Reopen after delete
  - [x] 3.3 Проверить, что deleted highlights не "воскресают"

## Dev Notes

### Контекст

`3.2` делает local highlight behavior завершенным для MVP: create, reload, delete. Это закрывает user-facing annotation slice без cross-device semantics.

### Релевантные файлы

- [AnnotationRepository.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/AnnotationRepository.swift)
- [PDFHighlightRenderer.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFHighlightRenderer.swift)
- [PDFAnchor.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFAnchor.swift)
- [Highlight.swift](/Users/ekoshkin/reader/Reader/Database/Models/Highlight.swift)

### Guardrails

- Delete/reload должны оставаться строго локальными.
- Нельзя добавлять tombstones, remote IDs или conflict rules в этой story.
- Нельзя завязывать consistency на future sync metadata.

### Previous Story Intelligence

Эта story строится строго поверх [story 3.1](/Users/ekoshkin/reader/_bmad-output/stories/epic-3-local-highlights-and-mvp-polish__story-3.1-local-highlight-creation-and-persistence.md), где уже должен существовать working local create path.

## Definition of Done

- Existing highlights загружаются при reopen
- Highlights можно удалить
- Deleted highlights не возвращаются после reopen
- Весь flow остается local-only

---

## Dev Agent Record

### Implementation Plan

- Достроить highlight lifecycle поверх `3.1`: загрузка существующих записей при open/reopen, selection existing highlight и delete flow
- Использовать тот же local renderer contract, чтобы creation/reload/delete шли через один и тот же `PDFHighlightRenderer`
- Проверить, что reopen не resurrects deleted annotations и не вводит sync semantics

### Debug Log

- `IPhonePDFReaderStore.startIfNeeded()` теперь грузит existing highlights для текущей книги и рендерит их в attach path
- В `IPhonePDFKitView` добавлен tap hit-testing по highlight annotations через marker IDs из `PDFHighlightRenderer`
- Active highlight можно recolor/delete через bottom picker; delete path удаляет и storage record, и visible PDF annotation

### Completion Notes

- Existing highlights поднимаются из local storage и повторно рендерятся при reopen книги
- Пользователь может выбрать existing highlight и удалить его; запись исчезает и из local DB, и из текущего PDF rendering
- Deleted highlights не возвращаются после reopen, потому что reload path читает текущее локальное состояние без tombstones/sync rules
- Проверки опираются на зелёные `HighlightsStoreTests`, `AnnotationRepositoryTests`, iPhone build и repeated simulator launch smoke

## File List

- Reader.xcodeproj/project.pbxproj
- Reader/Features/Annotations/HighlightsStore.swift
- Reader/Features/PDFReader/PDFHighlightRenderer.swift
- ReaderTests/Features/HighlightsStoreTests.swift
- ReaderiPhone/Features/Reader/IPhonePDFKitView.swift
- ReaderiPhone/Features/Reader/IPhonePDFReaderStore.swift
- ReaderiPhone/Features/Reader/IPhonePDFReaderView.swift

## Change Log

- 2026-04-24: Story 3.2 завершена. Добавлены highlight reload/render/delete flows для standalone iPhone reader.
