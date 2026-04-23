# Story 4.3: Markdown Exchange Domain Model

**Epic:** 4 — Annotation Markdown Exchange  
**Status:** proposed  
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

- [ ] Task 1: Создать exchange-модели документа
  - [ ] 1.1 `AnnotationExchangeDocument`
  - [ ] 1.2 `AnnotationExchangeBook`
  - [ ] 1.3 `AnnotationExchangeItem`

- [ ] Task 2: Описать типы аннотаций
  - [ ] 2.1 `highlight`
  - [ ] 2.2 `text_note`
  - [ ] 2.3 `sticky_note`

- [ ] Task 3: Описать контракт anchors
  - [ ] 3.1 EPUB anchor
  - [ ] 3.2 PDF text anchor
  - [ ] 3.3 PDF page-based anchor

- [ ] Task 4: Подготовить Codable-friendly representation
  - [ ] 4.1 Поля для front matter уровня книги
  - [ ] 4.2 Поля для item metadata
  - [ ] 4.3 Поля для human-readable content

- [ ] Task 5: Написать unit tests
  - [ ] 5.1 На создание документа с несколькими типами аннотаций
  - [ ] 5.2 На стабильное кодирование дат / id / anchor values
  - [ ] 5.3 На отсутствие зависимости от GRDB-моделей

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

_Заполняется агентом_

### Debug Log

_Заполняется агентом_

### Completion Notes

_Заполняется агентом_

---

## File List

- Reader/** new exchange model files as needed
- ReaderTests/* exchange model tests

---

## Change Log

- 2026-04-22: Создан story-файл для exchange domain model
