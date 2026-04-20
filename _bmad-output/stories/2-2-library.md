# Story 2.2: Library

**Epic:** 2 — Core Reading
**Status:** review
**Created:** 2026-04-18

---

## Story

Как пользователь, я хочу импортировать EPUB файлы и видеть свою библиотеку с обложками и прогрессом чтения, чтобы быстро находить и открывать нужные книги.

## Acceptance Criteria

- AC-1: Кнопка "Импорт" открывает `NSOpenPanel` (фильтр .epub)
- AC-2: При импорте EPUB-файл копируется в `Application Support/Reader/Books/{uuid}.epub`
- AC-3: `BookImporter` извлекает title, author, cover (если есть) из EPUB metadata
- AC-4: Обложка сохраняется как PNG в `Application Support/Reader/Covers/{book_id}.png`
- AC-5: `LibraryStore` (@Observable) управляет списком книг через `LibraryRepository`
- AC-6: `LibraryView` отображает сетку книг: обложка, название, автор, прогресс-бар
- AC-7: Удаление книги через контекстное меню (файл + обложка + запись в БД)
- AC-8: Клик по книге → переход в `ReaderView`
- AC-9: `FileAccess.swift` управляет Security-Scoped Bookmarks
- AC-10: Тесты для `BookImporter` (парсинг metadata) и `LibraryStore`

## Tasks / Subtasks

- [x] Task 1: FileAccess (applicationSupport, booksDir, coversDir, copy, delete)
- [x] Task 2: BookImporter (ZIPFoundation, regex-based OPF parsing, cover extraction EPUB 2/3)
- [x] Task 3: LibraryStore (@Observable, load/import/delete, resolveBookURL)
- [x] Task 4: LibraryView (LazyVGrid + fileImporter) + BookCardView (обложка/прогресс/контекстное меню)
- [x] Task 5: ContentView — NavigationStack с переключением Library ↔ Reader
- [x] Task 6: Тесты — 11 новых (BookImporter: 5, LibraryStore: 6), общий `EPUBTestFactory`

## Dev Notes

### Структура директорий

```
Application Support/Reader/
  reader.sqlite                -- БД
  Books/{book_id}.epub         -- копии EPUB
  Covers/{book_id}.png         -- обложки
```

### EPUB parsing

EPUB = ZIP с `META-INF/container.xml` → указатель на `.opf` файл.
OPF содержит `<metadata>` (dc:title, dc:creator) и `<manifest>` (items + properties="cover-image").

Используем `ZIPFoundation` или Foundation's `NSFileCoordinator` + `Archive`. Чтобы не добавлять ещё одну зависимость, напишем минимальный ZIP reader через `Process` с `unzip` — слишком хрупко. Добавим **ZIPFoundation** через SPM.

### Security-Scoped Bookmarks

Для sandboxed app нужны bookmarks к оригинальному файлу. Но раз мы **копируем** файл в Application Support — он уже доступен приложению напрямую без bookmark. Поэтому `file_bookmark` в БД пока будет nil, а `file_path` — путь к копии в sandbox.

### Обложки

Обложка извлекается как есть (jpeg/png) и сохраняется как PNG через `NSImage`. Fallback — первая страница EPUB (но это сложно, отложим до Phase 2).

### Тесты

Реальный EPUB файл для тестов можно сгенерировать на лету — minimal valid EPUB: mimetype + META-INF/container.xml + content.opf + одна XHTML страница.

---

## Dev Agent Record

### Implementation Plan

- ZIPFoundation 0.9.20 добавлен через SPM (Reader + ReaderTests targets)
- EPUB парсинг через regex вместо XMLParser — 60 строк vs сотни, для нашего использования достаточно
- Cover extraction поддерживает EPUB 3 (`properties="cover-image"`) и EPUB 2 (`<meta name="cover">`)
- EPUB файлы копируются в `Application Support/Reader/Books/{uuid}.epub`, обложки в `Covers/{uuid}.png`

### Debug Log

- Security-Scoped Bookmarks для импорта: `startAccessingSecurityScopedResource` вызывается на source URL во время копирования, но к копии уже не нужен (она в нашем sandbox)
- `@Bindable` для @Observable store в SwiftUI view
- ContentUnavailableView нативный macOS 14+

### Completion Notes

- Импорт: fileImporter → BookImporter парсит metadata → копирует EPUB → сохраняет cover → вставляет в БД
- LibraryView с LazyVGrid, адаптивные колонки 160-200pt
- BookCardView с обложкой/placeholder (градиент + название), прогресс-баром, двойной клик → открытие
- ContentView переключает между LibraryView и ReaderView через NavigationStack
- 11 новых тестов, всего 75/75 проходят

---

## File List

- Reader/Shared/FileAccess.swift
- Reader/Features/Library/BookImporter.swift
- Reader/Features/Library/LibraryStore.swift
- Reader/Features/Library/LibraryView.swift
- Reader/Features/Library/BookCardView.swift
- Reader/App/ContentView.swift (переработан)
- ReaderTests/Features/EPUBTestFactory.swift
- ReaderTests/Features/BookImporterTests.swift
- ReaderTests/Features/LibraryStoreTests.swift
- project.yml (добавлен ZIPFoundation)

---

## Change Log

- 2026-04-18: Story 2.2 завершена. Импорт EPUB, библиотека, удаление, роутинг. 75/75 тестов.
