# Story 1.3: Predictable Progress Sync

**Epic:** 1 — Sync Foundation  
**Status:** ready for review  
**Created:** 2026-04-21

---

## Story

Как пользователь, я хочу, чтобы приложение запоминало последнюю позицию чтения предсказуемо, без хаотических скачков между устройствами, чтобы я доверял синхронизации.

## Acceptance Criteria

- AC-1: Прогресс чтения хранится и синхронизируется отдельной сущностью `ReadingProgress`
- AC-2: Запись прогресса происходит только в стабильные моменты: pause, background, close, reopen, либо после короткой задержки стабилизации
- AC-3: Более старый progress не затирает более новый
- AC-4: Если книга уже открыта, remote progress не телепортирует пользователя автоматически
- AC-5: Доступен API/состояние для future UI “Есть более свежая позиция, перейти?”
- AC-6: Unit tests покрывают merge rules для progress

## Tasks / Subtasks

- [x] Task 1: Ввести `SyncedProgressRecord`
- [x] Task 2: Разделить локальное сохранение progress и отправку progress в sync pipeline
- [x] Task 3: Реализовать merge по `progressUpdatedAt`
- [x] Task 4: Добавить `pendingRemoteProgress` или эквивалентное состояние
- [x] Task 5: Написать unit tests на non-jumping behavior

## Dev Notes

- Текущая запись прогресса есть в [LibraryRepository.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryRepository.swift:61) и [PDFReaderStore.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFReaderStore.swift:275)
- Для MVP правило должно быть простым: локальное чтение не прерывается автоматически внешним апдейтом

---

## Dev Agent Record

### Implemented

- Прогресс синхронизируется отдельной сущностью `SyncedProgressRecord`, а публикация вынесена в `ProgressSyncing`/`SyncCoordinator`.
- `ReaderStore`, `PDFReaderStore` и iPhone PDF reader локально сохраняют позицию и отдельно публикуют стабильный progress в sync pipeline.
- В `SyncCoordinator` реализован merge по `progressUpdatedAt`: более старый remote progress игнорируется.
- Для открытой книги remote progress не применяется автоматически, а складывается в `pendingRemoteProgress`.

### Tests

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme Reader -destination 'platform=macOS' -derivedDataPath /tmp/reader-derived-data -only-testing:ReaderTests/LibraryRepositoryTests -only-testing:ReaderTests/AnnotationRepositoryTests -only-testing:ReaderTests/PDFBookLoaderTests -only-testing:ReaderTests/CloudKitBookMapperTests -only-testing:ReaderTests/CloudKitHighlightMapperTests -only-testing:ReaderTests/SyncCoordinatorTests`

### File List

- /Users/ekoshkin/reader/Reader/Features/PDFReader/PDFReaderStore.swift
- /Users/ekoshkin/reader/Reader/Features/Reader/ReaderStore.swift
- /Users/ekoshkin/reader/Reader/Sync/SyncedProgressRecord.swift
- /Users/ekoshkin/reader/Reader/Sync/SyncCoordinator.swift
- /Users/ekoshkin/reader/ReaderTests/Database/SyncCoordinatorTests.swift
