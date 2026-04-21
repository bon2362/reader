# Story 1.3: Predictable Progress Sync

**Epic:** 1 — Sync Foundation  
**Status:** proposed  
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

- [ ] Task 1: Ввести `SyncedProgressRecord`
- [ ] Task 2: Разделить локальное сохранение progress и отправку progress в sync pipeline
- [ ] Task 3: Реализовать merge по `progressUpdatedAt`
- [ ] Task 4: Добавить `pendingRemoteProgress` или эквивалентное состояние
- [ ] Task 5: Написать unit tests на non-jumping behavior

## Dev Notes

- Текущая запись прогресса есть в [LibraryRepository.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryRepository.swift:61) и [PDFReaderStore.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFReaderStore.swift:275)
- Для MVP правило должно быть простым: локальное чтение не прерывается автоматически внешним апдейтом
