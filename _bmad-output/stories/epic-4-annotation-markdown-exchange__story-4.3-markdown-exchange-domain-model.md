# Story 4.3: Markdown Exchange Domain Model

**Epic:** 4 — Annotation Markdown Exchange  
**Status:** done  
**Created:** 2026-04-22

---

## Story

Как разработчик, я хочу ввести отдельную exchange-модель Markdown-аннотаций, чтобы экспорт и импорт работали через стабильный платформенно-нейтральный контракт, не завязанный напрямую на GRDB и UI-сторы.

## Acceptance Criteria

- AC-1: Созданы структуры exchange-документа для книги и аннотаций
- AC-2: Exchange-модель покрывает `highlight`, `text_note`, `sticky_note`
- AC-3: Exchange-модель хранит metadata книги: `format`, `exportedAt`, `contentHash`, `title`, `author`, `book format`
- AC-4: Exchange-модель хранит metadata аннотаций: `exchangeId`, `type`, `anchor`, `createdAt`, `updatedAt`
- AC-5: Exchange-модель не зависит от SwiftUI, GRDB и concrete repository implementation
- AC-6: Unit tests покрывают создание и кодирование/декодирование базовых exchange-структур

## Tasks / Subtasks

- [x] Task 1: Создать exchange-модели документа
  - [x] 1.1 `AnnotationExchangeDocument`
  - [x] 1.2 `AnnotationExchangeBook`
  - [x] 1.3 `AnnotationExchangeItem`

- [x] Task 2: Описать типы аннотаций
  - [x] 2.1 `highlight`
  - [x] 2.2 `text_note`
  - [x] 2.3 `sticky_note`

- [x] Task 3: Описать контракт anchors
  - [x] 3.1 EPUB anchor
  - [x] 3.2 PDF text anchor
  - [x] 3.3 PDF page-based anchor

- [x] Task 4: Подготовить Codable-friendly representation
  - [x] 4.1 Поля для front matter уровня книги
  - [x] 4.2 Поля для item metadata
  - [x] 4.3 Поля для human-readable content

- [x] Task 5: Написать unit tests
  - [x] 5.1 На создание документа с несколькими типами аннотаций
  - [x] 5.2 На стабильное кодирование дат / id / anchor values
  - [x] 5.3 На отсутствие зависимости от GRDB-моделей

## Dev Notes

### Зачем нужен отдельный exchange layer

Экспорт и импорт не должны работать напрямую на локальных GRDB-моделях:

- `Highlight`, `TextNote`, `PageNote` — это локальные persistence-модели;
- Markdown exchange — внешний контракт;
- UI-сторы вообще не должны знать про формат `.md`.

Отдельная exchange-модель делает систему проще:

- encoder/decoder работают на одном стабильном наборе структур;
- import preview можно тестировать отдельно от БД;
- формат легче версионировать.

### Связанный архитектурный контракт

Полный контракт описан в:

- [architecture-annotation-markdown-exchange.md](/Users/ekoshkin/reader/_bmad-output/project-docs/architecture-annotation-markdown-exchange.md)

Эта story должна реализовать именно внутреннее представление этого контракта в коде.

### Рекомендуемая форма моделей

Примерно такого уровня:

```swift
struct AnnotationExchangeDocument
struct AnnotationExchangeBook
struct AnnotationExchangeItem
enum AnnotationExchangeItemType
struct AnnotationExchangeAnchor
```

Важно: точные имена можно подстроить под стиль проекта, но семантика должна остаться.

### Что должно быть в модели книги

- версия формата (`reader-annotations/v1`)
- `exportedAt`
- `book title`
- `book author`
- `book format`
- `contentHash`
- опционально local `book.id` как informational field

### Что должно быть в item-модели

- `exchangeId`
- `type`
- `anchor`
- `createdAt`
- `updatedAt`
- `selectedText` для highlight/text-note, где применимо
- `body` для notes
- `color` для highlight
- `pageLabel` для sticky-note, где применимо

### Важная граница

В этой story ещё не надо:

- генерировать Markdown-строку;
- парсить Markdown;
- ходить в репозиторий;
- писать UI.

Это именно story на внутренние модели обмена.

### Anchor policy

Exchange-модель не должна придумывать новые нормализованные anchor-алгоритмы.

Она должна хранить:

- `scheme`
- `value`

А значение должно быть сериализованной версией уже существующего внутреннего anchor приложения.

### Test Guidance

Проверить:

- документ с тремя типами аннотаций собирается валидно;
- все обязательные metadata поля присутствуют;
- Codable/serialization не теряет `exchangeId`, `anchor`, `timestamps`;
- модель можно использовать без подключения persistence layer.

---

## Dev Agent Record

### Implementation Plan

- Ввести отдельные exchange-структуры документа, книги, item-а и anchor-а без зависимостей на GRDB / SwiftUI
- Зафиксировать transport enum-ы для `format`, `type`, `scheme` и `color`, чтобы encoder/import слой работал на стабильном контракте
- Покрыть `Codable` roundtrip и стабильное ISO8601-кодирование unit tests

### Debug Log

- Поднят архитектурный контракт из `architecture-annotation-markdown-exchange.md` для полей front matter и item metadata
- Во время TDD-прогона исправлена Swift 6 concurrency-safe проблема со static `ISO8601DateFormatter`: код переведён на локальные formatter instances
- Прогнан targeted test run: `xcodebuild test -only-testing:ReaderTests/AnnotationExchangeModelsTests`

### Completion Notes

- Добавлены `AnnotationExchangeDocument`, `AnnotationExchangeBook`, `AnnotationExchangeItem`, `AnnotationExchangeAnchor` и transport enum-ы
- Даты в exchange-контракте кодируются и декодируются как ISO8601-строки, удобные для следующего Markdown encoder слоя
- Модель остаётся отдельной от persistence-аннотаций и готова для следующих story export/import

---

## File List

- Reader/Features/Annotations/AnnotationExchangeModels.swift
- ReaderTests/Features/AnnotationExchangeModelsTests.swift
- Reader.xcodeproj/project.pbxproj

---

## Change Log

- 2026-04-22: Создан story-файл для exchange domain model
- 2026-04-22: Добавлены exchange-модели документа и unit tests на Codable roundtrip / stable encoding
