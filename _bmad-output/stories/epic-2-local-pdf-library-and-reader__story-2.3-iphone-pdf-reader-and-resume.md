# Story 2.3: iPhone PDF Reader and Resume

**Epic:** 2 — Local PDF Library and Reader  
**Status:** done  
**Created:** 2026-04-24  
**Dependencies:** Story 1.2, Story 1.3, Story 2.1, Story 2.2

---

## Story

Как пользователь iPhone, я хочу открыть PDF и вернуться туда, где остановился, чтобы чтение ощущалось непрерывным между relaunch на одном устройстве.

## Acceptance Criteria

- AC-1: Локальный PDF открывается в iPhone PDF reader через UIKit-compatible PDF view integration
- AC-2: При смене страницы/позиции чтения progress сохраняется локально через existing local repository path
- AC-3: При повторном открытии книги reader восстанавливает последнюю локально сохраненную позицию
- AC-4: В reader path отсутствует публикация progress в sync services

## Tasks / Subtasks

- [x] Task 1: Подключить iPhone PDF reader screen
  - [x] 1.1 Добавить iPhone-specific PDF view wrapper
  - [x] 1.2 Реализовать reader screen/navigation
  - [x] 1.3 Подключить open flow из library

- [x] Task 2: Реализовать local progress persistence
  - [x] 2.1 Отслеживать page/anchor changes
  - [x] 2.2 Сохранять progress локально
  - [x] 2.3 Восстанавливать progress при reopen

- [x] Task 3: Проверить базовую навигацию
  - [x] 3.1 Open first page
  - [x] 3.2 Navigate forward/back
  - [x] 3.3 Relaunch and resume

- [x] Task 4: Проверить отсутствие sync leakage
  - [x] 4.1 Нет progress publish hooks
  - [x] 4.2 Нет remote hydration dependencies

## Dev Notes

### Контекст

Это завершающая story первого runnable slice. После нее должна существовать первая настоящая validation нового направления: import -> library -> open/read -> resume.

### Релевантные файлы

- [PDFReaderView.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFReaderView.swift)
- [PDFReaderStore.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFReaderStore.swift)
- [NativePDFView.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/NativePDFView.swift)
- [PDFAnchor.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFAnchor.swift)
- [LibraryRepository.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryRepository.swift)
- [PageIndicator.swift](/Users/ekoshkin/reader/Reader/Features/Reader/PageIndicator.swift)

### Guardrails

- Не публиковать progress в `SyncCoordinator` или любые remote services.
- Не делать open path зависимым от remote asset availability.
- Для MVP не тянуть TOC/search/annotation panel, если они не нужны для core read/resume loop.

### Previous Story Intelligence

- [story 2.1](/Users/ekoshkin/reader/_bmad-output/stories/epic-2-local-pdf-library-and-reader__story-2.1-local-pdf-import-on-iphone.md) должна уже давать working local book record.
- [story 2.2](/Users/ekoshkin/reader/_bmad-output/stories/epic-2-local-pdf-library-and-reader__story-2.2-local-library-ux-for-standalone-iphone-use.md) должна уже давать working open action из library.

## Definition of Done

- Локальный PDF открывается на iPhone
- Пользователь может листать страницы
- Progress сохраняется локально
- После reopen/relaunch книга открывается на последней позиции
- Reader path не содержит sync publication

---

## Dev Agent Record

### Implementation Plan

- Заменить placeholder handoff из `2.2` на настоящий iPhone PDF reader с `PDFKit` wrapper без macOS-only UI layers
- Вынести resume/persist вычисления в lightweight shared helper, чтобы local progress path можно было тестировать отдельно от iPhone UI
- Сохранить implementation строго local-first: только `LibraryRepository.updateReadingProgress`, без `SyncCoordinator`, remote hydration или cloud hooks

### Debug Log

- Добавлен `IPhonePDFKitView` как UIKit-compatible `PDFView` wrapper с безопасным initial display callback для restore позиции
- Реализованы `IPhonePDFReaderStore` и `IPhonePDFReaderView`: open PDF, page controls, local progress persistence и restore на reopen
- Общая логика page clamping / anchor encoding вынесена в `PDFReadingProgress`; для неё добавлен unit test suite
- Placeholder reader route из `2.2` удалён, library navigation теперь ведёт прямо в рабочий iPhone PDF reader

### Completion Notes

- Локальный PDF теперь открывается в iPhone app через native `PDFKit` integration и позволяет листать страницы вперёд/назад
- Progress сохраняется только через существующий local repository path и восстанавливается при повторном открытии книги
- Reader path intentionally не содержит progress publish hooks, sync coordinator wiring или remote asset dependencies
- Проверки пройдены: `ReaderiPhone` simulator build успешен, `PDFReadingProgressTests` и `LibraryRepositoryTests` зелёные

## File List

- Reader.xcodeproj/project.pbxproj
- Reader/Features/PDFReader/PDFReadingProgress.swift
- ReaderTests/Features/PDFReadingProgressTests.swift
- ReaderiPhone/App/IPhoneCompositionRoot.swift
- ReaderiPhone/Features/Library/IPhoneLibraryStore.swift
- ReaderiPhone/Features/Library/IPhoneLibraryView.swift
- ReaderiPhone/Features/Reader/IPhonePDFKitView.swift
- ReaderiPhone/Features/Reader/IPhonePDFReaderStore.swift
- ReaderiPhone/Features/Reader/IPhonePDFReaderView.swift

## Change Log

- 2026-04-24: Story 2.3 завершена. Добавлены iPhone PDF reader, local progress persistence/resume и shared helper/test coverage без sync leakage.
