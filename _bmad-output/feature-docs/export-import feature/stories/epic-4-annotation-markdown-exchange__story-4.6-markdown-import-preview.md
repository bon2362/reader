# Story 4.6: Markdown Import Preview

**Epic:** 4 — Annotation Markdown Exchange  
**Status:** proposed  
**Created:** 2026-04-22

---

## Story

Как пользователь, я хочу сначала увидеть preview результата импорта Markdown-аннотаций, чтобы понять, какие книги и записи будут созданы, обновлены или пропущены, до фактической записи в базу.

## Acceptance Criteria

- AC-1: Создан `MarkdownAnnotationDecoder`, который читает `.md` в формате `reader-annotations/v1`
- AC-2: Создан `AnnotationImportPreviewService`, который валидирует документ и строит preview без записи в БД
- AC-3: Preview ищет книгу по `contentHash`
- AC-4: Preview отдельно считает `create`, `update`, `skip`, `invalid`
- AC-5: Документы с неподдерживаемой версией формата или повреждённой структурой помечаются как invalid
- AC-6: Unit tests покрывают valid, missing-book, malformed и duplicate-like scenarios

## Tasks / Subtasks

- [ ] Task 1: Создать `MarkdownAnnotationDecoder`
  - [ ] 1.1 Parse front matter
  - [ ] 1.2 Parse sections
  - [ ] 1.3 Parse HTML comment metadata
  - [ ] 1.4 Собрать exchange-document

- [ ] Task 2: Создать `AnnotationImportPreviewService`
  - [ ] 2.1 Проверка версии формата
  - [ ] 2.2 Match книги по `contentHash`
  - [ ] 2.3 Lookup существующих записей по `exchangeId`
  - [ ] 2.4 Подсчёт preview outcome

- [ ] Task 3: Описать preview result model
  - [ ] 3.1 per-file status
  - [ ] 3.2 per-book summary
  - [ ] 3.3 aggregate counters

- [ ] Task 4: Написать unit tests
  - [ ] 4.1 Валидный файл
  - [ ] 4.2 Книга не найдена
  - [ ] 4.3 Повреждённый front matter
  - [ ] 4.4 Неподдерживаемая версия формата
  - [ ] 4.5 Существующая запись распознаётся как update/skip path

## Dev Notes

### Эта story принципиально без записи в базу

Импорт preview должен быть безопасным.

Он:

- читает файл;
- валидирует формат;
- ищет соответствующую книгу;
- проверяет, существуют ли уже такие записи;
- сообщает ожидаемый результат.

Но не делает `insert/update`.

### Основные зависимости

Repository lookup support:

- [AnnotationRepository.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/AnnotationRepository.swift)

Форматный контракт:

- [architecture-annotation-markdown-exchange.md](/Users/ekoshkin/reader/_bmad-output/project-docs/architecture-annotation-markdown-exchange.md)

### Match книги

Книга ищется по `contentHash`.

Если книга не найдена:

- весь файл идёт в статус `skipped` или `unmatched` по выбранной result model;
- аннотации не рассматриваются как create candidates.

Не нужно в этой story:

- пытаться создать книгу по `.md`;
- делать fuzzy-match по title/author;
- придумывать fallback heuristics.

### Preview result semantics

Нужен понятный итог:

- сколько новых записей будет создано;
- сколько существующих будет обновлено;
- сколько уже совпадает и может быть пропущено;
- сколько файлов невалидны.

Можно выбрать точную модель результата на усмотрение реализации, но она должна быть пригодна для будущего UI.

### Parsing strategy

Не стоит писать хрупкий парсер “по красивым кускам текста”.

Надёжный путь:

- front matter отдельно;
- metadata аннотаций отдельно;
- видимый Markdown-контент использовать только как human-readable payload;
- критические импортные поля брать только из структурных блоков.

### Что не входит в эту story

- применение импорта;
- транзакции;
- conflict resolution beyond preview classification.

### Test Guidance

Нужны тесты на:

- корректный файл со всеми типами аннотаций;
- файл с неизвестным `format`;
- файл без `contentHash`;
- файл с одной существующей и одной новой аннотацией;
- malformed metadata block.

---

## Dev Agent Record

### Implementation Plan

_Заполняется агентом_

### Debug Log

_Заполняется агентом_

### Completion Notes

_Заполняется агентом_

---

## File List

- Reader/** decoder/preview service files as needed
- ReaderTests/* import preview tests

---

## Change Log

- 2026-04-22: Создан story-файл для markdown import preview
