# Story 1.2: Shared Local Core Extraction for iPhone Reuse

**Epic:** 1 — iPhone Standalone Foundation  
**Status:** done  
**Created:** 2026-04-24  
**Dependencies:** Story 1.1

---

## Story

Как разработчик, я хочу выделить и адаптировать local shared core, нужный iPhone, чтобы macOS и iPhone могли переиспользовать local models, repositories и PDF primitives без смешивания platform-specific UI кода.

## Acceptance Criteria

- AC-1: `DatabaseManager`, local models, local repositories, `FileAccess` и PDF helper pieces остаются reusable и local-first
- AC-2: `PDFBookLoader` и/или `BookImporter` разделяются так, чтобы iPhone получил iOS-safe PDF path без AppKit-only import/cover logic
- AC-3: Shared extraction не ломает существующее macOS поведение

## Tasks / Subtasks

- [x] Task 1: Проанализировать shared/local pieces на `main`
  - [x] 1.1 Выделить reusable data layer
  - [x] 1.2 Выделить AppKit-only участки, которые нельзя тянуть в iPhone
  - [x] 1.3 Сопоставить с reusable pieces из donor branch

- [x] Task 2: Подготовить extraction для PDF/import foundation
  - [x] 2.1 Отделить cross-platform PDF metadata/import core
  - [x] 2.2 Оставить cover generation и macOS import UI platform-specific
  - [x] 2.3 Сохранить local-first API shape

- [x] Task 3: Подготовить shared contracts для iPhone
  - [x] 3.1 Проверить `LibraryRepository` и `AnnotationRepository`
  - [x] 3.2 Не допустить sync-expanded contracts
  - [x] 3.3 Убедиться, что shared layer не требует `Reader/Sync`

- [x] Task 4: Проверить regressions
  - [x] 4.1 Прогнать macOS build/relevant tests
  - [x] 4.2 Проверить, что extraction не меняет current main behavior

## Dev Notes

### Контекст

Эта story нужна до `1.3` и `2.x`, потому что import/read path на iPhone должен опираться на чистый local core, а не на macOS-only implementation details.

### Ключевые исходные файлы

- [DatabaseManager.swift](/Users/ekoshkin/reader/Reader/Database/DatabaseManager.swift)
- [Book.swift](/Users/ekoshkin/reader/Reader/Database/Models/Book.swift)
- [Highlight.swift](/Users/ekoshkin/reader/Reader/Database/Models/Highlight.swift)
- [LibraryRepository.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryRepository.swift)
- [AnnotationRepository.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/AnnotationRepository.swift)
- [BookImporter.swift](/Users/ekoshkin/reader/Reader/Features/Library/BookImporter.swift)
- [PDFBookLoader.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFBookLoader.swift)
- [PDFAnchor.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFAnchor.swift)
- [PDFMarkupGeometry.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFMarkupGeometry.swift)
- [FileAccess.swift](/Users/ekoshkin/reader/Reader/Shared/FileAccess.swift)

### Архитектурные guardrails

- Не переносить sync-specific schema changes и metadata из donor branch.
- Не менять shared contracts так, чтобы local CRUD стал зависеть от remote lifecycle.
- Не тянуть AppKit-only cover/import behavior в iPhone target.

### Previous Story Intelligence

Опираться на boundaries, созданные в [story 1.1](/Users/ekoshkin/reader/_bmad-output/stories/epic-1-iphone-standalone-foundation__story-1.1-iphone-target-from-main-and-local-only-app-shell.md): сначала отдельный iPhone shell, потом extraction shared core.

## Definition of Done

- Shared local core определен и пригоден для iPhone reuse
- AppKit-only код не попадает в reusable import/read path
- `LibraryRepository` и `AnnotationRepository` остаются local-first
- macOS app не получает regressions

---

## Dev Agent Record

### Implementation Plan

- За reusable local core приняты: `Reader/Database`, local models, `LibraryRepository`, `AnnotationRepository`, `FileAccess`, `BookFormat`, `PDFBookLoader`, `PDFAnchor`, `PDFMarkupGeometry`
- AppKit-only участки ограничены UI/bootstrap файлами и PDF/cover rendering, который не должен попадать в iPhone target напрямую
- Donor branch использована только как reference по идее iPhone target reuse, без переноса sync-expanded contracts

### Debug Log

- `PDFBookLoader` переведен на cross-platform image pipeline через новый `ImageDataTransformer`, чтобы убрать жесткую зависимость от `AppKit`
- `BookImporter` больше не использует `NSImage`; cover normalization теперь делается через `ImageIO`
- `ReaderiPhone` target расширен ровно до shared local pieces и package dependencies `GRDB`/`ZIPFoundation`, без подключения `Reader/Sync` и macOS UI групп

### Completion Notes

- Shared local core успешно собран для iPhone Simulator внутри `ReaderiPhone` target
- `LibraryRepository` и `AnnotationRepository` остались local-first и не получили sync-специфичных API
- PDF/import foundation теперь имеет iOS-safe path: metadata parsing, sandbox copy и cover normalization больше не требуют `AppKit`
- macOS regression check пройден: `BookImporterTests` и `PDFBookLoaderTests` проходят без изменения поведения

## File List

- project.yml
- Reader.xcodeproj/project.pbxproj
- Reader/Shared/ImageDataTransformer.swift
- Reader/Features/PDFReader/PDFBookLoader.swift
- Reader/Features/Library/BookImporter.swift

## Change Log

- 2026-04-24: Story 1.2 завершена. Shared local core подготовлен для iPhone reuse, `ReaderiPhone` собирается с reusable local layer, релевантные macOS tests проходят.
