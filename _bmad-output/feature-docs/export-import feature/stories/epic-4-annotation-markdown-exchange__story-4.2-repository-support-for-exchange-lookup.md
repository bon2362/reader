# Story 4.2: Repository Support for Exchange Lookup

**Epic:** 4 — Annotation Markdown Exchange  
**Status:** proposed  
**Created:** 2026-04-22

---

## Story

Как разработчик, я хочу расширить repository-слой аннотаций поиском по `exchangeId`, чтобы import-сервис мог надёжно находить уже существующие записи и выполнять update вместо создания дублей.

## Acceptance Criteria

- AC-1: `AnnotationRepositoryProtocol` умеет искать `Highlight` по `bookId + exchangeId`
- AC-2: `AnnotationRepositoryProtocol` умеет искать `TextNote` по `bookId + exchangeId`
- AC-3: `AnnotationRepositoryProtocol` умеет искать `PageNote` по `bookId + exchangeId`
- AC-4: Реализация repository корректно работает с `NULL exchange_id` у legacy-данных
- AC-5: Текущие `insert` / `update` flow продолжают работать без поведенческой регрессии
- AC-6: Unit tests покрывают positive/negative lookup cases для всех трёх типов аннотаций

## Tasks / Subtasks

- [ ] Task 1: Расширить `AnnotationRepositoryProtocol`
  - [ ] 1.1 Добавить lookup для `Highlight`
  - [ ] 1.2 Добавить lookup для `TextNote`
  - [ ] 1.3 Добавить lookup для `PageNote`

- [ ] Task 2: Реализовать lookup в `AnnotationRepository`
  - [ ] 2.1 Реализовать поиск `Highlight` по `book_id` и `exchange_id`
  - [ ] 2.2 Реализовать поиск `TextNote` по `book_id` и `exchange_id`
  - [ ] 2.3 Реализовать поиск `PageNote` по `book_id` и `exchange_id`

- [ ] Task 3: Проверить влияние на existing code paths
  - [ ] 3.1 Убедиться, что новые методы не ломают существующие mock/stub-реализации
  - [ ] 3.2 При необходимости обновить тестовые doubles

- [ ] Task 4: Написать unit tests
  - [ ] 4.1 Находится запись с совпадающим `exchangeId`
  - [ ] 4.2 Не находится запись при другом `bookId`
  - [ ] 4.3 Не находится запись при другом `exchangeId`
  - [ ] 4.4 Legacy-записи с `NULL exchange_id` не вызывают ошибок

## Dev Notes

### Зачем нужна отдельная story

В story 4.1 мы только добавляем возможность хранить `exchangeId`.

Но import-слою нужен надёжный способ спросить у базы:

- “Есть ли уже у этой книги highlight с таким `exchangeId`?”
- “Есть ли text note с этим внешним id?”
- “Есть ли sticky note с этим внешним id?”

Эта логика должна жить в repository, а не в UI и не в import decoder.

### Где менять код

Основная точка входа:

- [AnnotationRepository.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/AnnotationRepository.swift)

Модели, на которые опирается lookup:

- [Highlight.swift](/Users/ekoshkin/reader/Reader/Database/Models/Highlight.swift)
- [TextNote.swift](/Users/ekoshkin/reader/Reader/Database/Models/TextNote.swift)
- [PageNote.swift](/Users/ekoshkin/reader/Reader/Database/Models/PageNote.swift)

### Рекомендуемые методы

Имена можно адаптировать к стилю проекта, но смысл нужен именно такой:

```swift
func fetchHighlight(bookId: String, exchangeId: String) async throws -> Highlight?
func fetchTextNote(bookId: String, exchangeId: String) async throws -> TextNote?
func fetchPageNote(bookId: String, exchangeId: String) async throws -> PageNote?
```

### Почему lookup обязательно включает `bookId`

Голый поиск только по `exchangeId` слишком рискованный:

- теоретически можно столкнуться с ошибочным reuse id;
- import-семантика у нас книжно-ориентированная;
- transaction boundary потом тоже будет на уровне книги.

Поэтому правильный запрос: `book + exchangeId`.

### Что не входит в эту story

- upsert logic импорта;
- fallback lookup по anchor;
- parsing Markdown;
- import preview;
- apply import.

Это намеренно узкая story: подготовить repository boundary для следующих шагов.

### Legacy behavior

После story 4.1 в базе всё ещё могут жить старые записи с `exchange_id = NULL`.

Repository должен:

- нормально читать такие записи;
- возвращать `nil` при lookup по `exchangeId`;
- не считать это ошибкой.

### Test Guidance

Проверить минимум такие случаи:

- запись с нужным `bookId + exchangeId` находится;
- запись с тем же `exchangeId`, но другим `bookId`, не находится;
- запись с другим `exchangeId` не находится;
- lookup для legacy-строки с `NULL exchange_id` просто возвращает `nil`;
- существующие fetch-all методы продолжают работать как раньше.

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

- Reader/Features/Annotations/AnnotationRepository.swift
- ReaderTests/* (repository tests / mocks as needed)

---

## Change Log

- 2026-04-22: Создан story-файл для repository support under annotation markdown exchange
