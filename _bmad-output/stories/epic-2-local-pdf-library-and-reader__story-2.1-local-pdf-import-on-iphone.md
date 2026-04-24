# Story 2.1: Local PDF Import on iPhone

**Epic:** 2 — Local PDF Library and Reader  
**Status:** done  
**Created:** 2026-04-24  
**Dependencies:** Story 1.2, Story 1.3

---

## Story

Как пользователь iPhone, я хочу импортировать PDF из локальных файлов в приложение, чтобы начать чтение без Mac app и без любого sync pipeline.

## Acceptance Criteria

- AC-1: Из library screen открывается системный file picker для iPhone import
- AC-2: Выбранный валидный PDF копируется в app sandbox и создает локальную запись `Book`
- AC-3: После успешного импорта книга появляется в локальной библиотеке с PDF metadata
- AC-4: Невалидный или неподдерживаемый файл дает local import error и не создает broken record

## Tasks / Subtasks

- [x] Task 1: Подключить iPhone import entry point
  - [x] 1.1 Добавить import action в library flow
  - [x] 1.2 Подключить `UIDocumentPicker`
  - [x] 1.3 Обработать security-scoped/local file access по iOS-safe path

- [x] Task 2: Реализовать local PDF ingest
  - [x] 2.1 Скопировать файл в sandbox приложения
  - [x] 2.2 Прочитать PDF metadata
  - [x] 2.3 Создать локальный `Book`

- [x] Task 3: Реализовать error handling
  - [x] 3.1 Unsupported file type
  - [x] 3.2 Failed copy/read
  - [x] 3.3 Не создавать broken entries

- [x] Task 4: Обновить library reload path
  - [x] 4.1 Проверить, что после импорта книга видна в local list
  - [x] 4.2 Проверить повторный launch

## Dev Notes

### Контекст

Это первая story, которая дает реальную пользовательскую ценность в standalone track. Import должен быть полностью локальным и не может зависеть от macOS ingestion flow.

### Релевантные файлы

- [BookImporter.swift](/Users/ekoshkin/reader/Reader/Features/Library/BookImporter.swift)
- [PDFBookLoader.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFBookLoader.swift)
- [LibraryRepository.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryRepository.swift)
- [Book.swift](/Users/ekoshkin/reader/Reader/Database/Models/Book.swift)
- [BookFormat.swift](/Users/ekoshkin/reader/Reader/Shared/BookFormat.swift)
- [FileAccess.swift](/Users/ekoshkin/reader/Reader/Shared/FileAccess.swift)

### Guardrails

- Не использовать macOS import UI или AppKit-specific code path.
- Не поднимать CloudKit/hydration flows при импорте.
- Не сохранять sync metadata и remote record information в этой story.

### Previous Story Intelligence

Опираться на [story 1.2](/Users/ekoshkin/reader/_bmad-output/stories/epic-1-iphone-standalone-foundation__story-1.2-shared-local-core-extraction-for-iphone-reuse.md) и [story 1.3](/Users/ekoshkin/reader/_bmad-output/stories/epic-1-iphone-standalone-foundation__story-1.3-local-persistence-boot-for-iphone.md): import должен использовать уже подготовленный shared local core и local DB boot.

## Definition of Done

- Пользователь может выбрать PDF через iPhone file picker
- PDF копируется в sandbox
- Создается локальный `Book`
- Книга появляется в библиотеке после reload
- Ошибочный import не создает broken records

---

## Dev Agent Record

### Implementation Plan

- Добавить iPhone-specific import entry point прямо в `IPhoneLibraryView` через toolbar action и system document picker
- Оставить ingest в shared local core: picker только выбирает URL, а дальше `BookImporter.importBook` выполняет metadata read, sandbox copy и `Book` insert
- Усилить shared tests, чтобы отдельно зафиксировать успешный PDF import и защиту от broken records при невалидном PDF

### Debug Log

- Для прямого соответствия story добавлен отдельный `IPhonePDFDocumentPicker` на базе `UIDocumentPickerViewController`, а не generic macOS/library UI path
- `IPhoneLibraryStore` теперь сам управляет `securityScopedResource` lifecycle при импорте
- Новый PDF import test потребовал пометить вызов `TestPDFFactory.makeTextPDF` как `@MainActor`, потому что factory уже actor-isolated

### Completion Notes

- На library screen появился `Import PDF`, который открывает iPhone system file picker только для `UTType.pdf`
- После выбора PDF shared `BookImporter` копирует файл в app sandbox, читает PDF metadata и создает локальный `Book`
- После успешного импорта library store reload-ит локальный список книг; unsupported file type и invalid PDF показывают ошибку без создания broken entries
- Проверки пройдены: `ReaderiPhone` Simulator build успешен, `BookImporterTests` покрывают валидный PDF import и broken-record guardrail

## File List

- Reader.xcodeproj/project.pbxproj
- ReaderiPhone/Features/Library/IPhoneLibraryStore.swift
- ReaderiPhone/Features/Library/IPhoneLibraryView.swift
- ReaderiPhone/Features/Library/IPhonePDFDocumentPicker.swift
- ReaderTests/Features/BookImporterTests.swift

## Change Log

- 2026-04-24: Story 2.1 завершена. Добавлен iPhone PDF import flow через system picker, security-scoped ingest и shared local `BookImporter`, broken-record protection подтверждена тестами.
