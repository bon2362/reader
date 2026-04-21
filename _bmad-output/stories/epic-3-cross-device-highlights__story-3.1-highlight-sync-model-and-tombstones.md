# Story 3.1: Highlight Sync Model & Tombstones

**Epic:** 3 — Cross-Device Highlights  
**Status:** ready for review  
**Created:** 2026-04-21

---

## Story

Как разработчик, я хочу подготовить модель синхронизации highlights с `updatedAt` и `deletedAt`, чтобы создание, удаление и изменение подсветок было устойчивым и предсказуемым между устройствами.

## Acceptance Criteria

- AC-1: Для highlights существует отдельная sync-модель
- AC-2: Удаление highlights идёт через tombstone, а не через мгновенное исчезновение следов записи
- AC-3: Более новые изменения побеждают более старые
- AC-4: Remote-deleted highlight не “воскрешается” из локального кэша
- AC-5: Unit tests покрывают upsert/delete merge rules

## Tasks / Subtasks

- [x] Task 1: Ввести sync DTO для highlights
- [x] Task 2: Добавить `updatedAt` / `deletedAt` merge policy
- [x] Task 3: Реализовать apply remote upsert/delete в локальную БД
- [x] Task 4: Написать тесты на tombstones

## Dev Notes

- Локальная модель highlights уже существует в [Highlight.swift](/Users/ekoshkin/reader/Reader/Database/Models/Highlight.swift:1)
- Для MVP достаточно `last-write-wins` + tombstones

---

## Dev Agent Record

### Implemented

- Добавлены `SyncedHighlightRecord` и `CloudKitHighlightMapper`.
- Локальная модель `Highlight` и `AnnotationRepository` расширены полями `updatedAt`, `deletedAt`, `remoteRecordName`, `syncState`.
- Удаление highlight теперь идёт через tombstone, а remote upsert/delete применяются по `last-write-wins`.
- Локальные заметки, привязанные к highlight, отвязываются при удалении highlight, чтобы сохранить старое поведение UI.

### Tests

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme Reader -destination 'platform=macOS' -derivedDataPath /tmp/reader-derived-data -only-testing:ReaderTests/LibraryRepositoryTests -only-testing:ReaderTests/AnnotationRepositoryTests -only-testing:ReaderTests/PDFBookLoaderTests -only-testing:ReaderTests/CloudKitBookMapperTests -only-testing:ReaderTests/CloudKitHighlightMapperTests -only-testing:ReaderTests/SyncCoordinatorTests`

### File List

- /Users/ekoshkin/reader/Reader/Database/Migrations/Migration_007.swift
- /Users/ekoshkin/reader/Reader/Database/Models/Highlight.swift
- /Users/ekoshkin/reader/Reader/Features/Annotations/AnnotationRepository.swift
- /Users/ekoshkin/reader/Reader/Sync/CloudKitHighlightMapper.swift
- /Users/ekoshkin/reader/Reader/Sync/SyncedHighlightRecord.swift
- /Users/ekoshkin/reader/ReaderTests/Database/CloudKitHighlightMapperTests.swift
- /Users/ekoshkin/reader/ReaderTests/Database/AnnotationRepositoryTests.swift
