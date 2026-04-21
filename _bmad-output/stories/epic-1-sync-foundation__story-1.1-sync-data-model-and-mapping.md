# Story 1.1: Sync Data Model & Mapping

**Epic:** 1 — Sync Foundation  
**Status:** proposed  
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

- [ ] Task 1: Добавить migration для sync metadata в `books`
- [ ] Task 2: Расширить `Book` модель и repository API
- [ ] Task 3: Создать sync DTO (`SyncedBookRecord`, `SyncedProgressRecord`)
- [ ] Task 4: Реализовать `CloudKitBookMapper`
- [ ] Task 5: Написать unit tests на mapping и deduplication

## Dev Notes

- Текущая локальная модель книги находится в [Book.swift](/Users/ekoshkin/reader/Reader/Database/Models/Book.swift:4)
- Текущий repository слой находится в [LibraryRepository.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryRepository.swift:4)
- `filePath` и `fileBookmark` остаются локальными полями устройства и не считаются sync truth
- `contentHash` должен вычисляться по содержимому PDF, а не по пути к файлу
