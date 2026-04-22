# Story 4.5: Library-Wide Export Flow

**Epic:** 4 — Annotation Markdown Exchange  
**Status:** done  
**Created:** 2026-04-22

---

## Story

Как пользователь, я хочу массово экспортировать аннотации по всем книгам библиотеки, чтобы получить переносимый набор Markdown-файлов без ручного экспорта книги за книгой.

## Acceptance Criteria

- AC-1: Создан `AnnotationExportService`, который обходит библиотеку и экспортирует аннотации по одной книге в один `.md`
- AC-2: Экспорт пишет набор файлов в выбранную пользователем папку
- AC-3: Книги без аннотаций обрабатываются по заранее зафиксированному правилу
- AC-4: Ошибка экспорта одной книги не ломает экспорт остальных книг и попадает в итоговый отчёт
- AC-5: Пользователь получает итоговую summary-информацию: сколько книг экспортировано, сколько пропущено, сколько завершилось ошибкой
- AC-6: Integration tests покрывают сценарий экспорта нескольких книг

## Tasks / Subtasks

- [x] Task 1: Создать `AnnotationExportService`
  - [x] 1.1 Загрузка всех книг библиотеки
  - [x] 1.2 Загрузка аннотаций книги
  - [x] 1.3 Преобразование в exchange-document
  - [x] 1.4 Передача в `MarkdownAnnotationEncoder`

- [x] Task 2: Реализовать file output flow
  - [x] 2.1 Определить naming rule для файлов
  - [x] 2.2 Обработать slug/file-safe title
  - [x] 2.3 Записать `.md` на диск

- [x] Task 3: Зафиксировать поведение для книг без аннотаций
  - [x] 3.1 Либо пропускать
  - [x] 3.2 Либо экспортировать пустой файл по контракту

- [x] Task 4: Реализовать summary/report
  - [x] 4.1 exported count
  - [x] 4.2 skipped count
  - [x] 4.3 failed count

- [x] Task 5: Написать integration tests
  - [x] 5.1 Экспорт нескольких книг
  - [x] 5.2 Ошибка одной книги не валит пакет
  - [x] 5.3 Книга без аннотаций обрабатывается по выбранному правилу

## Dev Notes

### Эта story про orchestration, не про формат

К этому моменту у нас уже должны быть:

- exchange domain model;
- Markdown encoder.

Здесь задача другая: собрать всё вместе в массовый библиотечный workflow.

### Основные зависимости

Слой книг:

- [Book.swift](/Users/ekoshkin/reader/Reader/Database/Models/Book.swift)

Repository аннотаций:

- [AnnotationRepository.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/AnnotationRepository.swift)

Форматный контракт:

- [architecture-annotation-markdown-exchange.md](/Users/ekoshkin/reader/_bmad-output/project-docs/architecture-annotation-markdown-exchange.md)

### Один файл на одну книгу

Это уже зафиксировано архитектурно и не должно пересматриваться в реализации.

Экспорт результата должен давать набор файлов, а не один общий dump.

### Важное продуктовое правило

Нужно заранее зафиксировать поведение для книг без аннотаций.

Рекомендуемый pragmatic choice для MVP:

- книги без аннотаций пропускать;
- в summary писать количество пропущенных книг.

Это уменьшает визуальный мусор в export-папке.

### Naming rule

Нужен стабильный и безопасный filename.

Рекомендуемая схема:

- человекочитаемый slug по title;
- при коллизии добавлять часть `book.id` или `contentHash`.

Нельзя полагаться только на title:

- разные книги могут иметь одинаковое название;
- title может содержать файлово-небезопасные символы.

### Что не входит в эту story

- import preview;
- import apply;
- UI выбора файла для импорта.

Если будет UI-кнопка для экспорта, она должна быть максимально тонкой оболочкой вокруг сервиса.

### Test Guidance

Проверить:

- экспортируется несколько книг;
- книги без аннотаций не создают неожиданные файлы, если выбрана стратегия skip;
- ошибка одной книги попадает в report и не останавливает весь export;
- filenames стабильны и безопасны.

---

## Dev Agent Record

### Implementation Plan

- Собрать отдельный `AnnotationExportService`, который обходит книги, подтягивает аннотации и строит exchange-document
- Внедрить deterministic file naming и пакетную запись `.md` файлов в указанную папку
- Возвращать summary/result по каждой книге и проверить это integration-тестами с temp-directory

### Debug Log

- Зафиксировано MVP-правило: книги без аннотаций пропускаются и учитываются как `skipped`
- В процессе реализации учтён Swift 6 sendability для `FileManager`; сервис переведён на локальное использование `FileManager.default`
- Прогнан targeted test run: `xcodebuild test -only-testing:ReaderTests/AnnotationExportServiceTests`

### Completion Notes

- Добавлен `AnnotationExportService` с пакетным экспортом по одной книге в один Markdown-файл
- Сервис пишет безопасные slug-based filenames, считает `contentHash` по содержимому книги и продолжает пакет даже при ошибке одной книги
- Export mapping подтягивает `selectedText` для `TextNote`, если она привязана к existing highlight

---

## File List

- Reader/Features/Annotations/AnnotationExportService.swift
- ReaderTests/Features/AnnotationExportServiceTests.swift
- Reader.xcodeproj/project.pbxproj

---

## Change Log

- 2026-04-22: Создан story-файл для library-wide export flow
- 2026-04-22: Реализован export service с summary/report и integration tests
