# Story 1.2: Database Schema

**Epic:** 1 — Foundation
**Status:** review
**Created:** 2026-04-18

---

## Story

Как разработчик, я хочу иметь полную SQLite-схему с моделями и репозиториями, чтобы все последующие фичи могли сохранять данные мгновенно и безопасно.

## Acceptance Criteria

- AC-1: `DatabaseManager` инициализирует SQLite через GRDB с WAL режимом
- AC-2: `Migration_001` создаёт таблицы `books`, `highlights`, `text_notes`, `page_notes` с полями по архитектуре
- AC-3: GRDB-модели (`Book`, `Highlight`, `TextNote`, `PageNote`) реализованы как `Codable` + `FetchableRecord` + `PersistableRecord`
- AC-4: CFI хранится как TEXT, не парсится
- AC-5: `BookRepository`, `HighlightRepository`, `NoteRepository` реализованы с CRUD (insert / fetch / update / delete)
- AC-6: База хранится в `Application Support/Reader/reader.sqlite`
- AC-7: Тесты для всех репозиториев с in-memory БД (GRDB `DatabaseQueue` in-memory)

## Tasks / Subtasks

- [x] Task 1: Модели GRDB (Codable + FetchableRecord + PersistableRecord)
  - [x] 1.1 `Book.swift` с computed `progress`
  - [x] 1.2 `Highlight.swift` с `HighlightColor` enum
  - [x] 1.3 `TextNote.swift` с NULLABLE `highlightId`
  - [x] 1.4 `PageNote.swift`

- [x] Task 2: DatabaseManager
  - [x] 2.1 `DatabaseManager.swift` с `DatabasePool` (WAL) и путём в Application Support
  - [x] 2.2 Фабрика `inMemory()` через `DatabaseQueue`
  - [x] 2.3 Ошибки через `AppError` (databaseSetup, migrationFailed)
  - [x] 2.4 `PRAGMA foreign_keys = ON` в prepareDatabase

- [x] Task 3: Migrations
  - [x] 3.1 `Migration_001.swift` — 4 таблицы, 3 индекса, FK с ON DELETE CASCADE/SET NULL

- [x] Task 4: Repositories
  - [x] 4.1 `LibraryRepository.swift` с async CRUD + updateReadingProgress
  - [x] 4.2 `AnnotationRepository.swift` с CRUD для всех 3 типов аннотаций

- [x] Task 5: Shared
  - [x] 5.1 `AppError.swift` — 9 кейсов с русской локализацией

- [x] Task 6: Тесты
  - [x] 6.1 `LibraryRepositoryTests.swift` — 9 тестов
  - [x] 6.2 `AnnotationRepositoryTests.swift` — 14 тестов (CRUD + cascade + SET NULL + scope by book)

## Dev Notes

### Схема (из architecture.md)

```sql
books(id, title, author, cover_path, file_path, file_bookmark, added_at, last_opened_at, last_cfi, total_pages, current_page)
highlights(id, book_id, cfi_start, cfi_end, color, created_at, updated_at)
text_notes(id, book_id, highlight_id?, cfi_anchor, body, created_at, updated_at)
page_notes(id, book_id, spine_index, body, created_at, updated_at)
```

### Правила

- CFI — TEXT, никогда не парсить
- snake_case в БД, camelCase в Swift через GRDB CodingKeys
- Сохранение мгновенное, в `Task.detached` — но API репозиториев async
- In-memory БД для тестов через `DatabaseQueue()` без пути
- UUID strings для id (не auto-increment)

---

## Dev Agent Record

### Implementation Plan

- Singleton-подхода нет: `DatabaseManager` передаётся через конструктор (проще для тестов)
- Репозитории не owned — держат `any DatabaseWriter` (GRDB-протокол)
- `updateReadingProgress` — отдельный метод вместо полного update, чтобы не конфликтовать с параллельными правками модели

### Debug Log

- FK cascades работают только при `PRAGMA foreign_keys = ON` — включено в `prepareDatabase`
- GRDB требует `Codable` + `CodingKeys` для snake_case маппинга — реализовано для всех моделей

### Completion Notes

- Полная схема БД развёрнута: 4 таблицы + 3 индекса + FK
- WAL mode через DatabasePool на диске, DatabaseQueue для тестов
- `HighlightColor` сохраняется как raw string (yellow/red/green/blue/purple)
- Каскадное удаление: удаление книги → удаление всех highlights/text_notes/page_notes
- SET NULL для `text_notes.highlight_id` при удалении highlight
- 53/53 тестов проходят (29 из 1.1 + 24 новых)

---

## File List

- Reader/Database/DatabaseManager.swift
- Reader/Database/Migrations/Migration_001.swift
- Reader/Database/Models/Book.swift
- Reader/Database/Models/Highlight.swift
- Reader/Database/Models/TextNote.swift
- Reader/Database/Models/PageNote.swift
- Reader/Features/Library/LibraryRepository.swift
- Reader/Features/Annotations/AnnotationRepository.swift
- Reader/Shared/AppError.swift
- ReaderTests/Database/LibraryRepositoryTests.swift
- ReaderTests/Database/AnnotationRepositoryTests.swift

---

## Change Log

- 2026-04-18: Story 1.2 завершена. SQLite schema + GRDB модели + репозитории + 24 новых теста. Всего 53/53 тестов проходят.
