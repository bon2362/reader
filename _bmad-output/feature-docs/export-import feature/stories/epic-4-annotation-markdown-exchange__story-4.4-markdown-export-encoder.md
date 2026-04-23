# Story 4.4: Markdown Export Encoder

**Epic:** 4 — Annotation Markdown Exchange  
**Status:** proposed  
**Created:** 2026-04-22

---

## Story

Как пользователь, я хочу экспортировать аннотации одной книги в Markdown, чтобы получить человекочитаемый и одновременно пригодный для последующего импорта файл.

## Acceptance Criteria

- AC-1: Создан `MarkdownAnnotationEncoder`, который формирует `.md` в формате `reader-annotations/v1`
- AC-2: В начале файла генерируется YAML front matter с metadata книги
- AC-3: В файле корректно формируются секции `Highlights`, `Text Notes`, `Sticky Notes`
- AC-4: Для каждой аннотации в Markdown присутствуют скрытые машинные metadata в HTML-комментарии
- AC-5: Результат остаётся удобочитаемым человеком и содержит видимый текст аннотаций
- AC-6: Unit tests покрывают генерацию Markdown для всех трёх типов аннотаций

## Tasks / Subtasks

- [ ] Task 1: Создать `MarkdownAnnotationEncoder`
  - [ ] 1.1 Генерация front matter
  - [ ] 1.2 Генерация заголовка документа
  - [ ] 1.3 Генерация секций по типам аннотаций

- [ ] Task 2: Реализовать item rendering
  - [ ] 2.1 Render `Highlight`
  - [ ] 2.2 Render `Text Note`
  - [ ] 2.3 Render `Sticky Note`

- [ ] Task 3: Реализовать metadata rendering
  - [ ] 3.1 HTML comment для item metadata
  - [ ] 3.2 Форматирование дат
  - [ ] 3.3 Escape / sanitation для текстовых значений

- [ ] Task 4: Проверить deterministic output
  - [ ] 4.1 Стабильный порядок секций
  - [ ] 4.2 Стабильный порядок аннотаций внутри секции

- [ ] Task 5: Написать unit tests
  - [ ] 5.1 Snapshot-like tests на generated Markdown
  - [ ] 5.2 Тесты на отсутствие обязательных полей
  - [ ] 5.3 Тесты на корректное отображение multiline note body

## Dev Notes

### Эта story только про encoder

Здесь не нужен UI и не нужен обход всей библиотеки.

Фокус узкий:

- есть exchange-document в памяти;
- на выходе нужен один корректный `.md`-текст.

### Источник контракта

Контракт формата описан в:

- [architecture-annotation-markdown-exchange.md](/Users/ekoshkin/reader/_bmad-output/project-docs/architecture-annotation-markdown-exchange.md)

Encoder должен следовать ему буквально, без “свободной интерпретации”.

### Важные свойства output

Markdown должен быть:

- читаемым;
- предсказуемым;
- достаточно строгим для последующего decoder.

Поэтому формат output должен быть deterministic.

Минимум:

- стабильный порядок секций;
- стабильный порядок полей в комментарии;
- единый формат дат;
- отсутствие случайных пробелов/разрывов, которые потом ломают parsing.

### Рекомендуемый порядок секций

1. `Highlights`
2. `Text Notes`
3. `Sticky Notes`

Если секция пуста, её можно опускать.

### Рекомендуемое правило порядка элементов

Внутри секции нужен стабильный порядок.

На этом этапе достаточно:

- сначала по `createdAt`,
- затем по `exchangeId`.

Позже export service сможет подать элементы уже в нужном порядке.

### Осторожно с escaping

Видимый пользовательский текст и скрытые metadata могут содержать:

- переносы строк;
- двоеточия;
- Markdown-символы;
- HTML comment edge cases.

Нужна аккуратная нормализация строк, чтобы:

- Markdown не ломался;
- decoder потом мог reliably вытащить metadata.

### Что не входит в эту story

- чтение из repository;
- запись файлов на диск;
- mass export;
- import decoder.

### Test Guidance

Нужны тесты хотя бы на:

- highlight с `selectedText`;
- text note с многострочным `body`;
- sticky note с `pageLabel`;
- документ без одной или двух секций;
- устойчивость к специальным символам в тексте.

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

- Reader/** encoder files as needed
- ReaderTests/* markdown encoder tests

---

## Change Log

- 2026-04-22: Создан story-файл для markdown export encoder
