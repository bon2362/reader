# Story 2.3: iPhone PDF Reader & Resume

**Epic:** 2 — iPhone Reader Client  
**Status:** ready for review  
**Created:** 2026-04-21

---

## Story

Как пользователь iPhone, я хочу открыть PDF-книгу, листать страницы и вернуться ровно туда, где остановился, чтобы мобильное чтение было полезным уже в первой версии.

## Acceptance Criteria

- AC-1: На iPhone открывается PDF-книга из локальной копии
- AC-2: Работает базовая навигация по страницам
- AC-3: Последняя сохранённая позиция корректно восстанавливается при reopen
- AC-4: Локальные изменения прогресса попадают в sync pipeline
- AC-5: Приложение корректно обрабатывает книгу, которая ещё не скачана локально

## Tasks / Subtasks

- [x] Task 1: Выбрать iOS-совместимый PDF rendering path
- [x] Task 2: Реализовать iPhone reader screen
- [x] Task 3: Подключить restore progress
- [x] Task 4: Подключить publish progress

## Dev Notes

- В macOS уже есть отдельный PDF reading path, но он сильно опирается на `AppKit`
- MVP не требует TOC, поиска и сложных панелей на iPhone

---

## Dev Agent Record

### Implemented

- Для iPhone выбран `PDFKit` через `UIViewRepresentable` (`IPhonePDFKitView`).
- Реализован `IPhonePDFReaderView` с открытием локального PDF, page change tracking и restore последней позиции через `PDFAnchor`.
- Локальные изменения прогресса сохраняются в shared `LibraryRepository` и публикуются в sync pipeline.
- На iPhone добавлен базовый create/delete highlight flow поверх PDF selection.

### Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -quiet -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme ReaderiPhone -destination 'generic/platform=iOS' -derivedDataPath /tmp/reader-derived-data-ios CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM=''`

### File List

- /Users/ekoshkin/reader/ReaderiPhone/Features/IPhonePDFKitView.swift
- /Users/ekoshkin/reader/ReaderiPhone/Features/IPhonePDFReaderView.swift
