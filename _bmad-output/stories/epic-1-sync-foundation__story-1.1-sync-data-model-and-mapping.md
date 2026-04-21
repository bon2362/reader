# Story 1.1: Sync Data Model & Mapping

**Epic:** 1 — Sync Foundation  
**Status:** ready for review  
**Created:** 2026-04-21

---

## Story

Как разработчик, я хочу ввести отдельный sync-слой данных и маппинг в CloudKit, чтобы книги и прогресс можно было синхронизировать как отдельные записи, не передавая между устройствами весь файл `reader.sqlite`.

## Acceptance Criteria

- AC-1: В локальной модели `Book` появляются поля sync metadata (`contentHash`, `updatedAt`, `deletedAt`, `remoteRecordName` и связанные timestamps)
- AC-2: Созданы sync-neutral DTO для книги и прогресса, не завязанные напрямую на GRDB
- AC-3: CloudKit mapper умеет преобразовывать локальную книгу в `CKRecord` и обратно
- AC-4: Дедупликация одного и того же PDF выполняется по `contentHash`
- AC-5: Repository-слой умеет читать и обновлять новые sync metadata
- AC-6: Unit tests покрывают mapping и dedup logic

## Tasks / Subtasks

- [x] Task 1: Добавить migration для sync metadata в `books`
- [x] Task 2: Расширить `Book` модель и repository API
- [x] Task 3: Создать sync DTO (`SyncedBookRecord`, `SyncedProgressRecord`)
- [x] Task 4: Реализовать `CloudKitBookMapper`
- [x] Task 5: Написать unit tests на mapping и deduplication

## Dev Notes

- Текущая локальная модель книги находится в [Book.swift](/Users/ekoshkin/reader/Reader/Database/Models/Book.swift:4)
- Текущий repository слой находится в [LibraryRepository.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryRepository.swift:4)
- `filePath` и `fileBookmark` остаются локальными полями устройства и не считаются sync truth
- `contentHash` должен вычисляться по содержимому PDF, а не по пути к файлу

## Dev Agent Record

### Implemented

- Добавлена migration `006_books_sync_metadata` с новыми sync metadata полями и индексом по `content_hash`.
- `Book` расширен sync metadata полями, а `LibraryRepository` получил API для чтения по `contentHash` и обновления sync metadata.
- Добавлены `SyncedBookRecord`, `SyncedProgressRecord` и `CloudKitBookMapper` для преобразования `Book`/progress в `CKRecord` и обратно.
- Импорт PDF теперь вычисляет `contentHash` по содержимому файла и дедуплицирует повторный импорт по хэшу до копирования в sandbox.
- Добавлен потоковый SHA-256 helper `FileHash` и покрывающие тесты на repository persistence, CloudKit mapping и deduplication.

### Tests

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme Reader -destination 'platform=macOS' -derivedDataPath /tmp/reader-derived-data -only-testing:ReaderTests/LibraryRepositoryTests -only-testing:ReaderTests/PDFBookLoaderTests -only-testing:ReaderTests/CloudKitBookMapperTests`

### Decisions

- Для существующих локальных записей `updated_at` backfill-ится из `added_at`, чтобы migration была совместима с ограничениями SQLite на `ALTER TABLE`.
- Дедупликация одного и того же PDF выполняется на этапе import flow через `fetchByContentHash`, чтобы не создавать лишние sandbox-копии файла.

## File List

- /Users/ekoshkin/reader/Reader/Database/DatabaseManager.swift
- /Users/ekoshkin/reader/Reader/Database/Migrations/Migration_006.swift
- /Users/ekoshkin/reader/Reader/Database/Models/Book.swift
- /Users/ekoshkin/reader/Reader/Features/Library/BookImporter.swift
- /Users/ekoshkin/reader/Reader/Features/Library/LibraryRepository.swift
- /Users/ekoshkin/reader/Reader/Features/PDFReader/PDFBookLoader.swift
- /Users/ekoshkin/reader/Reader/Shared/FileHash.swift
- /Users/ekoshkin/reader/Reader/Sync/CloudKitBookMapper.swift
- /Users/ekoshkin/reader/Reader/Sync/SyncedBookRecord.swift
- /Users/ekoshkin/reader/Reader/Sync/SyncedProgressRecord.swift
- /Users/ekoshkin/reader/Reader.xcodeproj/project.pbxproj
- /Users/ekoshkin/reader/ReaderTests/Database/CloudKitBookMapperTests.swift
- /Users/ekoshkin/reader/ReaderTests/Database/LibraryRepositoryTests.swift
- /Users/ekoshkin/reader/ReaderTests/Features/PDFBookLoaderTests.swift
