# Story 1.2: macOS Book Catalog & Asset Sync

**Epic:** 1 — Sync Foundation  
**Status:** ready for review  
**Created:** 2026-04-21

---

## Story

Как пользователь macOS, я хочу, чтобы импортированная PDF-книга публиковалась в облако вместе с метаданными и файлом, чтобы она потом могла появиться на iPhone без повторного ручного импорта.

## Acceptance Criteria

- AC-1: После импорта PDF книга попадает в очередь синхронизации
- AC-2: В CloudKit создаётся `Book` record с метаданными книги и `CKAsset` файла
- AC-3: При следующем запуске или refresh macOS-клиент умеет получить remote changes и применить их в локальную БД
- AC-4: Повторная синхронизация той же книги не создаёт дубль
- AC-5: Sync ошибки логируются и не ломают локальный import flow

## Tasks / Subtasks

- [x] Task 1: Создать `CloudKitSyncService` для `Book` records
- [x] Task 2: Создать `SyncCoordinator` для запуска upload/pull
- [x] Task 3: Интегрировать sync enqueue в `BookImporter`
- [x] Task 4: Реализовать pull remote changes на macOS
- [x] Task 5: Добавить базовое логирование и тесты на apply remote upsert

## Dev Notes

- Импорт PDF сейчас идёт через [BookImporter.swift](/Users/ekoshkin/reader/Reader/Features/Library/BookImporter.swift:1)
- Не нужно синкать `reader.sqlite` целиком; синкаются только сущности книги и прогресса
- Для MVP допустим manual refresh + sync on launch; сложный background scheduling можно отложить

---

## Dev Agent Record

### Implemented

- Добавлены `CloudKitSyncService`, `SyncCoordinator`, `SyncDiagnosticsLogger` и `SyncServiceProtocol`.
- macOS app теперь поднимает sync coordinator через `AppContainer`, делает `syncOnLaunch()` и не падает в тестовом окружении благодаря `DisabledSyncService`.
- После import/delete книги `LibraryStore` ставит книгу в sync pipeline; `SyncCoordinator` публикует `Book` record и умеет подтягивать remote changes обратно в локальную БД.
- Реализована hydration логика для `CKAsset`: при наличии remote asset локальная копия PDF сохраняется в sandbox через `FileAccess`.

### Tests

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme Reader -destination 'platform=macOS' -derivedDataPath /tmp/reader-derived-data -only-testing:ReaderTests/LibraryRepositoryTests -only-testing:ReaderTests/AnnotationRepositoryTests -only-testing:ReaderTests/PDFBookLoaderTests -only-testing:ReaderTests/CloudKitBookMapperTests -only-testing:ReaderTests/CloudKitHighlightMapperTests -only-testing:ReaderTests/SyncCoordinatorTests`

### File List

- /Users/ekoshkin/reader/Reader/App/AppContainer.swift
- /Users/ekoshkin/reader/Reader/App/ContentView.swift
- /Users/ekoshkin/reader/Reader/Features/Library/LibraryStore.swift
- /Users/ekoshkin/reader/Reader/Sync/CloudKitSyncService.swift
- /Users/ekoshkin/reader/Reader/Sync/DisabledSyncService.swift
- /Users/ekoshkin/reader/Reader/Sync/SyncCoordinator.swift
- /Users/ekoshkin/reader/Reader/Sync/SyncDiagnosticsLogger.swift
- /Users/ekoshkin/reader/Reader/Sync/SyncServiceProtocol.swift
- /Users/ekoshkin/reader/Reader/Sync/SyncClock.swift
- /Users/ekoshkin/reader/ReaderTests/Database/SyncCoordinatorTests.swift
