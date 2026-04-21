# Story 3.3: Conflict UX & Observability

**Epic:** 3 — Cross-Device Highlights  
**Status:** ready for review  
**Created:** 2026-04-21

---

## Story

Как пользователь и как команда разработки, мы хотим, чтобы параллельная работа на Mac и iPhone вела себя предсказуемо и была наблюдаемой, чтобы синхронизация не воспринималась как хаотичная.

## Acceptance Criteria

- AC-1: Конфликт прогресса не вызывает внезапный прыжок по книге
- AC-2: Появляется понятное состояние “есть более свежая позиция”
- AC-3: Sync layer пишет диагностические события для upload, pull, merge и conflicts
- AC-4: Основные конфликтные сценарии покрыты тестами

## Tasks / Subtasks

- [x] Task 1: Добавить диагностическое логирование sync pipeline
- [x] Task 2: Ввести состояние `pendingRemoteProgress` или эквивалент
- [x] Task 3: Покрыть тестами сценарии parallel read / remote progress / tombstone highlights
- [x] Task 4: Подготовить минимальные UX hooks для будущих подсказок пользователю

## Dev Notes

- Для MVP не нужно делать сложный conflict center
- Но архитектура уже должна поддерживать мягкое, объяснимое поведение вместо silent overrides

---

## Dev Agent Record

### Implemented

- Добавлен `SyncDiagnosticsLogger` с событиями upload/pull/conflict/error.
- `SyncCoordinator` хранит `pendingRemoteProgress` и exposes API для future UX hook без автотелепортации пользователя.
- Тестами покрыты сценарии активного чтения с более свежим remote progress и merge rules для highlight tombstones.
- Архитектура готова для будущей подсказки уровня “есть более свежая позиция, перейти?” без переработки sync substrate.

### Tests

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme Reader -destination 'platform=macOS' -derivedDataPath /tmp/reader-derived-data -only-testing:ReaderTests/LibraryRepositoryTests -only-testing:ReaderTests/AnnotationRepositoryTests -only-testing:ReaderTests/PDFBookLoaderTests -only-testing:ReaderTests/CloudKitBookMapperTests -only-testing:ReaderTests/CloudKitHighlightMapperTests -only-testing:ReaderTests/SyncCoordinatorTests`

### File List

- /Users/ekoshkin/reader/Reader/Sync/SyncCoordinator.swift
- /Users/ekoshkin/reader/Reader/Sync/SyncDiagnosticsLogger.swift
- /Users/ekoshkin/reader/ReaderTests/Database/CloudKitHighlightMapperTests.swift
- /Users/ekoshkin/reader/ReaderTests/Database/SyncCoordinatorTests.swift
