# Story 1.2: macOS Book Catalog & Asset Sync

**Epic:** 1 — Sync Foundation  
**Status:** proposed  
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

- [ ] Task 1: Создать `CloudKitSyncService` для `Book` records
- [ ] Task 2: Создать `SyncCoordinator` для запуска upload/pull
- [ ] Task 3: Интегрировать sync enqueue в `BookImporter`
- [ ] Task 4: Реализовать pull remote changes на macOS
- [ ] Task 5: Добавить базовое логирование и тесты на apply remote upsert

## Dev Notes

- Импорт PDF сейчас идёт через [BookImporter.swift](/Users/ekoshkin/reader/Reader/Features/Library/BookImporter.swift:1)
- Не нужно синкать `reader.sqlite` целиком; синкаются только сущности книги и прогресса
- Для MVP допустим manual refresh + sync on launch; сложный background scheduling можно отложить
