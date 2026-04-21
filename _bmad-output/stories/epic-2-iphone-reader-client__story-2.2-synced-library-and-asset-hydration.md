# Story 2.2: Synced Library & Asset Hydration on iPhone

**Epic:** 2 — iPhone Reader Client  
**Status:** ready for review  
**Created:** 2026-04-21

---

## Story

Как пользователь iPhone, я хочу видеть свою библиотеку из облака и получать локальную копию нужной PDF-книги, чтобы можно было открыть её на телефоне без повторного импорта.

## Acceptance Criteria

- AC-1: iPhone-клиент показывает синхронизированную библиотеку PDF-книг
- AC-2: Если локальной копии файла нет, приложение умеет скачать `CKAsset` и сохранить его в sandbox
- AC-3: В UI есть понятные состояния: доступна, скачивается, ошибка, готова к чтению
- AC-4: Повторное открытие книги использует уже скачанную локальную копию

## Tasks / Subtasks

- [x] Task 1: Реализовать pull библиотеки из CloudKit на iPhone
- [x] Task 2: Реализовать asset hydration и локальное сохранение PDF
- [x] Task 3: Добавить статусы availability в library UI
- [x] Task 4: Написать тесты/интеграционные проверки на повторное открытие

## Dev Notes

- Для MVP import остаётся только на macOS
- На iPhone библиотека должна быть читабельной даже до полной реализации аннотаций

---

## Dev Agent Record

### Implemented

- iPhone library screen делает `syncOnLaunch()` и отображает PDF-only библиотеку из shared repository.
- Для каждой книги введены availability states: `cloudOnly`, `downloading`, `ready`, `failed`.
- При отсутствии локального файла `SyncCoordinator.hydrateAssetIfNeeded(for:)` скачивает remote asset и сохраняет PDF в sandbox.
- Повторное открытие использует уже существующую локальную копию файла.

### Verification

- iPhone target собирается с hydration/library flow в составе `ReaderiPhone`.
- Базовая sync/hydration логика покрыта test slice вокруг repository/sync coordinator.

### File List

- /Users/ekoshkin/reader/Reader/Sync/SyncCoordinator.swift
- /Users/ekoshkin/reader/ReaderiPhone/Features/IPhoneLibraryView.swift
- /Users/ekoshkin/reader/ReaderiPhone/Features/IPhoneLibraryViewModel.swift
