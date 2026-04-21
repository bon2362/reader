# Epics — Reader App MVP

## Epic 1: Foundation

Инициализация Xcode проекта, подключение GRDB.swift, встройка epub.js bundle, базовый Swift↔JS bridge.

### Story 1.1: Project Initialization

Создать Xcode проект (macOS App, SwiftUI), подключить GRDB.swift через SPM, встроить epub.js/jszip.js в Resources/JS, реализовать базовый WKWebView с EPUBBridgeProtocol (ping/pong тест).

### Story 1.2: Database Schema

Реализовать DatabaseManager (SQLite WAL), Migration_001 с таблицами books/highlights/text_notes/page_notes, GRDB-модели с Codable, базовые Repository-заглушки.

---

## Epic 2: Core Reading

Открытие EPUB, постраничный рендеринг, навигация, библиотека, TOC, поиск.

### Story 2.1: EPUB Rendering & Navigation

EPUBWebView загружает EPUB через epub.js, постраничный режим, навигация стрелками/клавишами/кликом по краям, pageChanged события, ReaderToolbar (название книги/главы), PageIndicator (стр. X из Y).

### Story 2.2: Library

Импорт EPUB через file picker (копирование в sandbox + Security-Scoped Bookmark), LibraryView со списком книг (обложка, название, автор, прогресс), восстановление последней позиции, удаление книги.

### Story 2.3: Table of Contents

TOCView с иерархическим содержанием из EPUB metadata, переход к главе по клику, подсветка текущей главы.

### Story 2.4: Text Search

Cmd+F → SearchView, поиск по всей книге через bridge, подсветка вхождений, навигация prev/next.

---

## Epic 3: Annotations

Highlights, текстовые заметки, стикеры, панель аннотаций.

### Story 3.1: Highlights

Выделение текста → контекстное меню → выбор цвета (5 цветов), отрисовка highlight через JS, хранение в SQLite (CFI + цвет), клик → меню изменить/удалить.

### Story 3.2: Text Notes (Type A)

Выделить текст → "Add note" → NoteEditorView, иконка-маркер в правом margin через MarginOverlayView, клик → разворачивает/сворачивает заметку, пересчёт позиций при pageChanged, хранение (cfi_anchor, highlight_id NULLABLE).

### Story 3.3: Sticky Notes (Type B)

Cmd+Shift+N или кнопка в тулбаре → StickyNoteView в правом margin, привязка к spine_index (не CFI), клик → разворачивает/сворачивает, хранение в page_notes.

### Story 3.4: Annotation Panel

AnnotationPanelView с 4 вкладками (All / Highlights / Notes / Sticky Notes), превью цитаты/текста, глава и страница, клик → переход к позиции через bridge, сортировка по порядку в книге.
