# Story 4.1: Schema Support for Exchange ID

**Epic:** 4 — Annotation Markdown Exchange  
**Status:** proposed  
**Created:** 2026-04-22

---

## Story

Как разработчик, я хочу добавить в локальные модели аннотаций постоянный `exchangeId`, чтобы экспорт в Markdown и повторный импорт могли надёжно сопоставлять одни и те же аннотации без создания дублей.

## Acceptance Criteria

- AC-1: В таблицы `highlights`, `text_notes` и `page_notes` добавлено nullable-поле `exchange_id`
- AC-2: В моделях [Highlight.swift](/Users/ekoshkin/reader/Reader/Database/Models/Highlight.swift), [TextNote.swift](/Users/ekoshkin/reader/Reader/Database/Models/TextNote.swift), [PageNote.swift](/Users/ekoshkin/reader/Reader/Database/Models/PageNote.swift) появилось поле `exchangeId`
- AC-3: Новые аннотации, создаваемые приложением, автоматически получают `exchangeId`
- AC-4: Существующие данные после миграции продолжают успешно читаться без обязательного немедленного backfill
- AC-5: Значение `exchangeId` стабильно сохраняется при update существующей аннотации и не перегенерируется
- AC-6: Unit tests покрывают миграцию модели и правило автоматической генерации `exchangeId` для новых записей

## Tasks / Subtasks

- [ ] Task 1: Добавить новую migration для `exchange_id`
  - [ ] 1.1 Создать `Migration_006`
  - [ ] 1.2 Добавить `exchange_id` в `highlights`
  - [ ] 1.3 Добавить `exchange_id` в `text_notes`
  - [ ] 1.4 Добавить `exchange_id` в `page_notes`
  - [ ] 1.5 Зарегистрировать migration в [DatabaseManager.swift](/Users/ekoshkin/reader/Reader/Database/DatabaseManager.swift)

- [ ] Task 2: Расширить локальные модели аннотаций
  - [ ] 2.1 Добавить `exchangeId: String?` в `Highlight`
  - [ ] 2.2 Добавить `exchangeId: String?` в `TextNote`
  - [ ] 2.3 Добавить `exchangeId: String?` в `PageNote`
  - [ ] 2.4 Обновить `CodingKeys` и `Columns`

- [ ] Task 3: Ввести правило автогенерации для новых сущностей
  - [ ] 3.1 Для новых локальных аннотаций без переданного значения автоматически назначать `exchangeId`
  - [ ] 3.2 Не генерировать новый `exchangeId`, если он уже был передан явно
  - [ ] 3.3 Не менять `exchangeId` при update

- [ ] Task 4: Проверить влияние на существующие create/update flows
  - [ ] 4.1 Highlights flow
  - [ ] 4.2 Text notes flow
  - [ ] 4.3 Sticky notes flow

- [ ] Task 5: Написать unit tests
  - [ ] 5.1 Тест на успешное чтение legacy-записей без `exchange_id`
  - [ ] 5.2 Тест на автоматическую генерацию `exchangeId` для новой сущности
  - [ ] 5.3 Тест на сохранение уже существующего `exchangeId`
  - [ ] 5.4 Тест на отсутствие регенерации `exchangeId` при update

## Dev Notes

### Зачем эта story идёт первой

Это фундамент всего annotation exchange контура.

Без стабильного внешнего идентификатора импорт будет пытаться угадывать совпадения по косвенным признакам:

- тип аннотации;
- книга;
- anchor;
- текст;
- timestamp.

Такой путь хрупкий и почти гарантированно приведёт к дублям или ложным совпадениям.

`exchangeId` решает это как первичный внешний ключ для export/import сценария.

### Что именно меняем

Нужно расширить только аннотации:

- `highlights`
- `text_notes`
- `page_notes`

Книги в этой story не трогаем.

Match книги по `contentHash` относится уже к последующим story import/export слоя и не входит в текущую реализацию.

### Текущая схема

Базовая схема аннотаций создаётся в [Migration_001.swift](/Users/ekoshkin/reader/Reader/Database/Migrations/Migration_001.swift).

Сейчас:

- `highlights` не содержит `exchange_id`
- `text_notes` не содержит `exchange_id`
- `page_notes` не содержит `exchange_id`

Последняя зарегистрированная migration сейчас — [Migration_005.swift](/Users/ekoshkin/reader/Reader/Database/Migrations/Migration_005.swift), поэтому новая должна идти как `Migration_006`.

### Где находятся модели

- [Highlight.swift](/Users/ekoshkin/reader/Reader/Database/Models/Highlight.swift)
- [TextNote.swift](/Users/ekoshkin/reader/Reader/Database/Models/TextNote.swift)
- [PageNote.swift](/Users/ekoshkin/reader/Reader/Database/Models/PageNote.swift)

### Где проходят create/update операции

Основной repository для аннотаций:

- [AnnotationRepository.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/AnnotationRepository.swift)

Важно: в этом story repository API можно не расширять новыми lookup-методами. Но нужно убедиться, что текущие `insert/update` корректно сохраняют `exchangeId` и не затирают его случайно.

### Рекомендуемое правило генерации

Для новых локальных аннотаций:

- если `exchangeId == nil`, сгенерировать `UUID().uuidString`
- если `exchangeId != nil`, сохранить как есть

Это правило лучше держать близко к модели/созданию сущности, а не размазывать по UI.

Практически безопасный путь:

- генерировать в `init(...)` моделей аннотаций через параметр `exchangeId: String? = nil`
- внутри инициализатора делать `self.exchangeId = exchangeId ?? UUID().uuidString`

Почему это хорошо:

- любое новое локальное создание сразу получает внешний id;
- импорт позже сможет создавать сущность с уже известным `exchangeId`;
- не придётся надеяться, что каждый caller не забудет сгенерировать значение вручную.

### Важная граница

Для legacy-строк в базе `exchange_id` останется `NULL`, пока запись не будет пересоздана или пока отдельная story не введёт backfill/update policy.

Это допустимо и соответствует Acceptance Criteria.

Не нужно в этой story:

- запускать массовый backfill всей существующей базы;
- пытаться пройтись по всем аннотациям и дописать им `exchange_id`;
- проектировать import preview;
- добавлять Markdown encoder/decoder.

### Осторожно с update semantics

Сейчас repository update-методы в [AnnotationRepository.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/AnnotationRepository.swift) копируют модель и проставляют новый `updatedAt = Date()`.

Нужно сохранить текущее поведение, но проследить, чтобы:

- `exchangeId` не терялся;
- он не перегенерировался при каждом update.

Иначе импорт потом не сможет сопоставлять записи стабильно.

### Предлагаемые файлы изменений

- [DatabaseManager.swift](/Users/ekoshkin/reader/Reader/Database/DatabaseManager.swift)
- [Migration_006.swift](/Users/ekoshkin/reader/Reader/Database/Migrations/Migration_006.swift) (new)
- [Highlight.swift](/Users/ekoshkin/reader/Reader/Database/Models/Highlight.swift)
- [TextNote.swift](/Users/ekoshkin/reader/Reader/Database/Models/TextNote.swift)
- [PageNote.swift](/Users/ekoshkin/reader/Reader/Database/Models/PageNote.swift)
- связанные unit tests для моделей/репозитория/миграций

### Test Guidance

Минимальный набор проверок:

- migration успешно применяется к существующей базе;
- чтение legacy-записей с `NULL exchange_id` не падает;
- новая `Highlight` без `exchangeId` получает непустой id;
- новая `TextNote` без `exchangeId` получает непустой id;
- новая `PageNote` без `exchangeId` получает непустой id;
- модель с заранее заданным `exchangeId` сохраняет именно его;
- update существующей записи не меняет `exchangeId`.

### Связанный архитектурный контекст

Основной контракт обмена аннотациями описан в:

- [architecture-annotation-markdown-exchange.md](/Users/ekoshkin/reader/_bmad-output/project-docs/architecture-annotation-markdown-exchange.md)

Текущая story реализует только первый технический фундамент из этого документа.

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

- Reader/Database/DatabaseManager.swift
- Reader/Database/Migrations/Migration_006.swift
- Reader/Database/Models/Highlight.swift
- Reader/Database/Models/TextNote.swift
- Reader/Database/Models/PageNote.swift
- ReaderTests/* (migration/model/repository tests as needed)

---

## Change Log

- 2026-04-22: Создан story-файл для первой implementation story annotation markdown exchange
