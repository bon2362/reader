# Story 2.2: Local Library UX for Standalone iPhone Use

**Epic:** 2 — Local PDF Library and Reader  
**Status:** done  
**Created:** 2026-04-24  
**Dependencies:** Story 1.3, Story 2.1

---

## Story

Как пользователь iPhone, я хочу library screen, спроектированный под standalone local reading, чтобы ясно видеть импортированные PDF и открывать их без sync-related confusion.

## Acceptance Criteria

- AC-1: Empty state объясняет local PDF import на iPhone и не ссылается на Mac import или CloudKit sync
- AC-2: Library screen показывает импортированные PDF с title, optional author/cover и reading progress при наличии
- AC-3: Tapping a book открывает локальный file URL и ведет прямо в reader
- AC-4: Missing/unreadable local file дает local recovery error, а не remote hydration attempt

## Tasks / Subtasks

- [x] Task 1: Подготовить standalone library presentation
  - [x] 1.1 Определить empty state copy и actions
  - [x] 1.2 Показать список импортированных PDF
  - [x] 1.3 Отобразить базовые metadata/progress

- [x] Task 2: Подключить open flow
  - [x] 2.1 Разрешить open action из карточки/списка
  - [x] 2.2 Разрешить local file resolution
  - [x] 2.3 Подготовить navigation to reader

- [x] Task 3: Обработать local error paths
  - [x] 3.1 Missing file
  - [x] 3.2 Unreadable file
  - [x] 3.3 Library refresh after failed open

- [x] Task 4: Проверить baseline UX
  - [x] 4.1 Empty library
  - [x] 4.2 One imported PDF
  - [x] 4.3 Несколько PDF и progress visibility

## Dev Notes

### Контекст

`2.2` не должна превращаться в large polish story. Для MVP достаточно ясного local-first library UX: пустой state, список, open action, базовый error state.

### Релевантные файлы

- [LibraryView.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryView.swift)
- [LibraryStore.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryStore.swift)
- [BookCardView.swift](/Users/ekoshkin/reader/Reader/Features/Library/BookCardView.swift)
- [LibraryRepository.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryRepository.swift)

### Guardrails

- Не использовать wording вида "import on Mac" или "wait for sync".
- Не добавлять remote asset state в local open flow.
- Не затягивать в story крупный polish beyond MVP.

### Previous Story Intelligence

- [story 2.1](/Users/ekoshkin/reader/_bmad-output/stories/epic-2-local-pdf-library-and-reader__story-2.1-local-pdf-import-on-iphone.md) уже должна дать working import pipeline.
- `2.2` строится поверх local DB/library foundation из [story 1.3](/Users/ekoshkin/reader/_bmad-output/stories/epic-1-iphone-standalone-foundation__story-1.3-local-persistence-boot-for-iphone.md).

## Definition of Done

- Empty state local-first
- Imported PDFs отображаются в library screen
- Из library можно открыть локальную книгу
- Missing/unreadable file обрабатывается как local error

---

## Dev Agent Record

### Implementation Plan

- Перевести iPhone library screen из технического списка в local-first presentation с cover, metadata, PDF badge и progress
- Добавить open flow из tap по книге с локальной проверкой file existence/readability до перехода в reader route
- Оставить navigation lightweight: `2.2` готовит reader handoff, а полный PDF rendering/resume завершается в `2.3`

### Debug Log

- Добавлен `IPhoneLibraryBookRow` c local cover preview через `UIImage(contentsOfFile:)`, progress bar и chevron affordance
- Open flow вынесен в `IPhoneLibraryStore.prepareOpenBook`, чтобы missing/unreadable file обрабатывались как local recovery error с reload списка
- Для минимального непрерывного UX добавлен `IPhoneReaderPlaceholderView`, который подтверждает успешный local handoff до полной reader integration следующей story

### Completion Notes

- Empty state и import CTA теперь полностью local-first и не содержат Mac/sync wording
- Library screen показывает импортированные PDF с title, optional author, cover thumbnail и reading progress when available
- Tapping a book ведет в reader route только после local file resolution; missing/unreadable file дает local error без remote hydration attempt
- Проверки пройдены: `ReaderiPhone` Simulator build успешен, `LibraryRepositoryTests` остаются зелеными

## File List

- Reader.xcodeproj/project.pbxproj
- ReaderiPhone/Features/Library/IPhoneLibraryStore.swift
- ReaderiPhone/Features/Library/IPhoneLibraryView.swift
- ReaderiPhone/Features/Library/IPhoneLibraryBookRow.swift
- ReaderiPhone/Features/Reader/IPhoneReaderPlaceholderView.swift

## Change Log

- 2026-04-24: Story 2.2 завершена. Добавлен standalone local-first iPhone library UX, local file open checks и navigation handoff в reader route.
