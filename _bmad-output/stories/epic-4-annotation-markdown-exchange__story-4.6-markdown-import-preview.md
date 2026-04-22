# Story 4.6: Markdown Import Preview

**Epic:** 4 — Annotation Markdown Exchange  
**Status:** done  
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

- [x] Task 1: Создать `MarkdownAnnotationDecoder`
  - [x] 1.1 Parse front matter
  - [x] 1.2 Parse sections
  - [x] 1.3 Parse HTML comment metadata
  - [x] 1.4 Собрать exchange-document

- [x] Task 2: Создать `AnnotationImportPreviewService`
  - [x] 2.1 Проверка версии формата
  - [x] 2.2 Match книги по `contentHash`
  - [x] 2.3 Lookup существующих записей по `exchangeId`
  - [x] 2.4 Подсчёт preview outcome

- [x] Task 3: Описать preview result model
  - [x] 3.1 per-file status
  - [x] 3.2 per-book summary
  - [x] 3.3 aggregate counters

- [x] Task 4: Написать unit tests
  - [x] 4.1 Валидный файл
  - [x] 4.2 Книга не найдена
  - [x] 4.3 Повреждённый front matter
  - [x] 4.4 Неподдерживаемая версия формата
  - [x] 4.5 Существующая запись распознаётся как update/skip path

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

- Реализовать декодер markdown-экспортов `reader-annotations/v1` с разбором front matter, структурных metadata blocks и секций контента.
- Построить preview-сервис без записи в БД, который матчится на локальную книгу по `contentHash` и классифицирует записи как `create`, `update`, `skip` или `invalid`.
- Зафиксировать поведение тестами на валидный импорт, unmatched book, malformed/unsupported документы и mixed existing/new scenarios.

### Debug Log

- Исправлен helper тестов `sampleMarkdown(...)` после добавления обязательного `contentHash`.
- Проверена классификация `update/skip`; найден и исправлен тестовый timestamp, который ошибочно делал импорт "новее" существующей записи.
- Прогон целевого набора `AnnotationImportPreviewServiceTests` завершён успешно.

### Completion Notes

- Добавлен `MarkdownAnnotationDecoder`, который валидирует формат и собирает `AnnotationExchangeDocument` из markdown-файла.
- Добавлен `AnnotationImportPreviewService` с aggregate/per-file counters и match по `contentHash`.
- Preview опирается на exchange lookup в repository и не выполняет `insert/update`, как и требовалось по story.

---

## File List

- Reader/** decoder/preview service files as needed
- ReaderTests/* import preview tests
- [MarkdownAnnotationDecoder.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/MarkdownAnnotationDecoder.swift)
- [AnnotationImportPreviewService.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/AnnotationImportPreviewService.swift)
- [AnnotationImportPreviewServiceTests.swift](/Users/ekoshkin/reader/ReaderTests/Features/AnnotationImportPreviewServiceTests.swift)
- [project.pbxproj](/Users/ekoshkin/reader/Reader.xcodeproj/project.pbxproj)

---

## Change Log

- 2026-04-22: Создан story-файл для markdown import preview
- 2026-04-22: Реализованы decoder и preview service для markdown import preview, добавлены unit tests
