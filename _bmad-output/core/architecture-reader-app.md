---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-04-18'
inputDocuments: ['prd-reader-app.md']
workflowType: 'architecture'
project_name: 'Reader App'
user_name: 'Koshkin'
date: '2026-04-18'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements (8):**
- F-01: Библиотека — импорт, хранение, прогресс чтения
- F-02: Reading View — постраничный EPUB, навигация, тулбар с названием книги/главы
- F-03: TOC — иерархия из EPUB metadata, навигация по клику
- F-04: Поиск по тексту — full-text, prev/next по всей книге (bridge-сценарий)
- F-05: Highlights — 5 цветов, CFI-якоря, CRUD
- F-06: Annotations — Type A (margin note, CFI-привязка, пересчёт при пагинации) + Type B (sticky note, page_index-привязка, не пересчитывается) — **два разных overlay-механизма**
- F-07: Панель аннотаций — All/Highlights/Notes/Stickies, переход по CFI-якорю (программная навигация через bridge)
- F-08: Хранение — SQLite, мгновенное сохранение, app sandbox, Security-Scoped Bookmarks

**Non-Functional Requirements:**
- macOS (Swift + SwiftUI), iPhone в будущем
- EPUB движок: Readium Swift Toolkit
- Локальная SQLite без sync в MVP
- Личное приложение — App Store не требуется
- Smooth reading experience (paginated, без лагов)

**Scale & Complexity:**
- Уровень: средний
- Домен: нативное macOS desktop
- Расчётное число архитектурных компонентов: 7

### Technical Constraints & Dependencies

- Readium Swift Toolkit рендерит через WKWebView — нативный overlay требует координации через Swift↔JS bridge
- CFI (Canonical Fragment Identifier) — стандарт EPUB для позиционирования аннотаций
- Security-Scoped Bookmarks — обязательны для долгосрочного доступа к файлам в sandbox
- Нет внешних сервисов в MVP (no network, no auth)
- `EPUBBridgeProtocol` — протокол-обёртка над JS-bridge обязателен с первого дня для testability

### Cross-Cutting Concerns (обогащено после Party Mode)

- **Swift↔JS Bridge**: выделение текста, CFI extraction, scroll position, поиск (F-04), программная навигация (F-07) — всё через WKWebView message passing. Race condition риск: страница ещё не загружена при отправке JS. Требует `EPUBBridgeProtocol` для мокирования в тестах.
- **Overlay — два механизма**: Type A (CFI → `getBoundingClientRect()` → пересчёт при каждом `readerDidChangePagination`), Type B (page_index → позиция фиксирована). Хранить `cfi_anchor`, не `y_position`.
- **Persistence**: SQLite WAL-mode как shared async service. Защита от потери данных при kill-9.
- **Security-Scoped Bookmarks**: explicit error state + user-facing recovery при недоступности файла.
- **Reactive State**: SwiftUI + async-await для обновления панелей при изменении аннотаций.

## Starter Template Evaluation

### Primary Technology Domain

Нативное macOS desktop приложение (Swift + SwiftUI)

### Starter Options Considered

| Вариант | Описание | Решение |
|---------|----------|---------|
| Readium Swift Toolkit | Промышленный EPUB toolkit | Отклонён: macOS поддержка вторична, ограниченный контроль над overlay |
| epub.js + WKWebView + Swift | JS EPUB движок в нативной обёртке | ✅ Выбран |
| Собственный EPUB парсер (Swift) | Полностью нативно | Отклонён: риск EPUB edge cases из разных источников |

### Selected Starter: macOS App (SwiftUI) + epub.js

**Rationale:** epub.js обеспечивает зрелую CFI-реализацию, предсказуемый рендеринг и battle-tested обработку EPUB quirks из разных источников. WKWebView работает идентично на macOS и iOS — сохраняет путь к iPhone без переписывания JS-слоя.

**Инициализация проекта:**
```bash
# Xcode → New Project → macOS → App (SwiftUI)
# Product Name: Reader
# Bundle ID: com.koshkin.reader
# Minimum Deployment: macOS 14.0
```

**Swift Package Dependencies (SPM):**
```
GRDB.swift v7.10.0
https://github.com/groue/GRDB.swift.git
```

**JS Bundle (встроить в app resources):**
```
epub.js v0.3.x   — EPUB рендеринг, CFI, pagination
jszip.js         — распаковка EPUB (зависимость epub.js)
reader.js        — кастомный bridge: выделение, CFI, overlay координаты
reader.css       — стили reading view + margin zone
```

**Architectural Decisions:**
- Language: Swift 6 + SwiftUI / JavaScript (EPUB движок, инкапсулирован в WebView)
- EPUB Engine: epub.js v0.3.x внутри WKWebView
- Database: GRDB.swift + SQLite (WAL mode)
- Bridge: WKWebView ↔ Swift через WKScriptMessageHandler + EPUBBridgeProtocol
- Minimum OS: macOS 14.0 (Sonoma)
- Architecture pattern: MVVM + Repository

**Note:** Первая implementation story — инициализация проекта, подключение GRDB.swift, встройка epub.js bundle, базовый WKWebView + Swift bridge (ping/pong тест).

## Core Architectural Decisions

### Data Architecture

**Схема базы данных:**

```sql
books (
  id, title, author, cover_path, file_path,
  file_bookmark,        -- Security-Scoped Bookmark для sandbox доступа
  added_at, last_opened_at,
  last_cfi,             -- позиция для восстановления чтения
  total_pages, current_page  -- для отображения "стр. 47 из 312"
)

highlights (
  id, book_id, cfi_start, cfi_end, color, created_at, updated_at
)

text_notes (
  id, book_id,
  highlight_id NULLABLE,  -- может существовать без highlight
  cfi_anchor, body, created_at, updated_at
)

page_notes (
  id, book_id, spine_index, body, created_at, updated_at
)
```

**Прогресс чтения:** отображается как "страница 47 из 312". Хранится как CFI последней позиции + номер страницы (epub.js предоставляет оба).

**Миграции:** GRDB migrations — версионированные, накопительным образом.

### UI Navigation & Layout

**Окно:** одно окно, `NavigationSplitView` — sidebar слева (библиотека / TOC / аннотации), reader справа.

**Скрытие элементов:**
- Sidebar: сворачивается кнопкой или жестом
- Toolbar: скрывается при чтении, появляется по движению мыши (уже решено в PRD)
- Fullscreen: поддерживается через стандартный macOS fullscreen, все панели скрываются

**Margin overlay:** SwiftUI `.overlay` поверх `WKWebViewRepresentable`. Иконки аннотаций пересчитывают позицию при `pageChanged` событии из JS — небольшая задержка при смене шрифта/размера допустима.

### State Management

**@Observable** (macOS 14.0+) — современный Swift подход, минимум boilerplate.

Ключевые observable объекты:
- `LibraryStore` — список книг, текущая книга
- `ReaderStore` — текущая страница, CFI, прогресс
- `AnnotationStore` — highlights, notes для текущей книги

### JS Bridge Protocol

**Swift → JS (команды):**
```
loadBook(url)
goToCFI(cfi)
search(query)
highlightRange(cfiStart, cfiEnd, color, id)
removeHighlight(id)
scrollToAnnotation(cfi)
getAnnotationPositions()
```

**JS → Swift (события):**
```
pageChanged(cfi, spineIndex, currentPage, totalPages)
textSelected(cfiStart, cfiEnd, text)
pageTap(x, y)
searchResults([{cfi, excerpt}])
annotationPositions([{id, x, y, type}])
```

**EPUBBridgeProtocol** — Swift протокол-обёртка над `WKScriptMessageHandler` для мокирования в тестах. Обязателен с первого дня.

### Decision Impact Analysis

**Последовательность реализации (определяется зависимостями):**
1. Xcode проект + GRDB + epub.js bundle + базовый bridge
2. Открытие EPUB, базовый рендеринг, навигация по страницам
3. Библиотека (импорт, список, прогресс)
4. TOC + поиск
5. Highlights (CFI + цвет + хранение)
6. Text notes (margin overlay Type A)
7. Sticky notes (margin overlay Type B)
8. Панель аннотаций (All / Highlights / Notes / Stickies)

**Ключевые зависимости:**
- Bridge protocol должен быть готов до любой фичи аннотаций
- GRDB schema должна быть готова до библиотеки
- Overlay positioning зависит от стабильного `pageChanged` события

## Implementation Patterns & Consistency Rules

### Naming Patterns

**База данных (snake_case):**
```
Таблицы:  books, highlights, text_notes, page_notes
Колонки:  book_id, cfi_start, cfi_end, spine_index, created_at
```

**Swift код (стандартные Swift-конвенции):**
```
Типы/классы:   LibraryStore, AnnotationRepository, EPUBBridgeProtocol
Переменные:    currentPage, highlightColor, cfiAnchor
Функции:       loadBook(), saveHighlight(), deleteNote()
```

**JS Bridge сообщения (camelCase):**
```
Swift → JS:  loadBook, goToCFI, highlightRange, removeHighlight
JS → Swift:  pageChanged, textSelected, annotationPositions
```

### Structure Patterns

**Структура папок Xcode проекта:**
```
Reader/
  App/                  -- точка входа, конфигурация
  Features/
    Library/            -- полка книг, импорт
    Reader/             -- reading view, WKWebView
    Annotations/        -- панель, overlay, список
    Search/             -- поиск по тексту
  Database/             -- GRDB схема, репозитории, миграции
  Bridge/               -- EPUBBridgeProtocol, WKScriptMessageHandler
  Resources/
    JS/                 -- epub.js, jszip.js, reader.js, reader.css
  Shared/               -- общие модели, утилиты
ReaderTests/            -- все тесты в отдельном target
```

**Каждая фича содержит:**
```
FeatureView.swift       -- SwiftUI view
FeatureStore.swift      -- @Observable store
FeatureRepository.swift -- работа с БД (если нужна)
```

### Process Patterns

**Состояния загрузки** — каждый экран моделирует:
```swift
enum ViewState { case idle, loading, loaded, error(String) }
```

**Сохранение аннотаций:** мгновенное, в фоновом потоке (`Task.detached`), без индикатора — пользователь не ждёт.

**Обработка ошибок:** все ошибки показываются как диалоговое окно (`Alert`) с кнопкой OK. Разделение:
- Пользовательские ошибки (файл не найден, книга повреждена) → понятный текст на русском
- Внутренние ошибки (сбой БД, bridge timeout) → логируются + Alert с общим сообщением

**Bridge timeout:** если JS не ответил за 5 секунд → ошибка + Alert.

**Security-Scoped Bookmarks:** `startAccessingSecurityScopedResource()` вызывается явно, результат проверяется, при `false` → Alert с предложением переоткрыть файл вручную.

### All AI Agents MUST

- Использовать `EPUBBridgeProtocol` — никогда не обращаться к `WKWebView` напрямую из бизнес-логики
- Сохранять в БД через репозиторий, не напрямую через GRDB в view/store
- Показывать ошибки через Alert, не через print/console
- Писать тесты в `ReaderTests/`, именовать `FeatureNameTests.swift`
- Хранить CFI как строку (`TEXT`), не парсить и не конвертировать

## Project Structure & Boundaries

### Complete Project Directory Structure

```
Reader/
├── Reader.xcodeproj
├── Reader/
│   ├── App/
│   │   ├── ReaderApp.swift          -- точка входа @main
│   │   └── AppDelegate.swift        -- NSApplicationDelegate
│   │
│   ├── Features/
│   │   ├── Library/
│   │   │   ├── LibraryView.swift
│   │   │   ├── LibraryStore.swift
│   │   │   ├── BookImporter.swift
│   │   │   ├── BookCardView.swift
│   │   │   └── LibraryRepository.swift
│   │   │
│   │   ├── Reader/
│   │   │   ├── ReaderView.swift
│   │   │   ├── ReaderStore.swift
│   │   │   ├── EPUBWebView.swift    -- WKWebView + NSViewRepresentable
│   │   │   ├── ReaderToolbar.swift
│   │   │   ├── PageIndicator.swift  -- "стр. 47 из 312"
│   │   │   └── ReaderRepository.swift
│   │   │
│   │   ├── Annotations/
│   │   │   ├── AnnotationPanelView.swift
│   │   │   ├── AnnotationStore.swift
│   │   │   ├── MarginOverlayView.swift  -- SwiftUI overlay с иконками
│   │   │   ├── MarginNoteView.swift     -- Type A: привязана к тексту
│   │   │   ├── StickyNoteView.swift     -- Type B: привязана к странице
│   │   │   ├── NoteEditorView.swift
│   │   │   ├── HighlightListView.swift
│   │   │   └── AnnotationRepository.swift
│   │   │
│   │   ├── TOC/
│   │   │   ├── TOCView.swift
│   │   │   └── TOCStore.swift
│   │   │
│   │   └── Search/
│   │       ├── SearchView.swift
│   │       └── SearchStore.swift
│   │
│   ├── Bridge/
│   │   ├── EPUBBridgeProtocol.swift  -- мокируется в тестах
│   │   ├── EPUBBridge.swift          -- реализация
│   │   ├── BridgeMessage.swift       -- входящие события (enum)
│   │   └── BridgeCommand.swift       -- исходящие команды (enum)
│   │
│   ├── Database/
│   │   ├── DatabaseManager.swift     -- GRDB setup, WAL mode
│   │   ├── Migrations/
│   │   │   └── Migration_001.swift
│   │   └── Models/
│   │       ├── Book.swift
│   │       ├── Highlight.swift
│   │       ├── TextNote.swift
│   │       └── PageNote.swift
│   │
│   ├── Shared/
│   │   ├── Extensions/
│   │   │   └── View+ErrorAlert.swift
│   │   ├── FileAccess.swift          -- Security-Scoped Bookmarks
│   │   └── ErrorHandler.swift        -- AppError enum + локализация
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       └── JS/
│           ├── epub.js
│           ├── jszip.js
│           ├── reader.js             -- кастомный bridge-код
│           └── reader.css
│
└── ReaderTests/
    ├── Bridge/
    │   ├── MockEPUBBridge.swift
    │   └── EPUBBridgeTests.swift
    ├── Database/
    │   ├── AnnotationRepositoryTests.swift
    │   └── LibraryRepositoryTests.swift
    └── Features/
        ├── LibraryStoreTests.swift
        └── ReaderStoreTests.swift
```

### Requirements to Structure Mapping

| Требование | Файлы |
|-----------|-------|
| F-01 Библиотека | `Features/Library/`, `Database/Models/Book.swift` |
| F-02 Reading View | `Features/Reader/`, `Bridge/` |
| F-03 TOC | `Features/TOC/`, `Bridge/BridgeMessage.swift` |
| F-04 Поиск | `Features/Search/`, `Bridge/BridgeCommand.swift` |
| F-05 Highlights | `Features/Annotations/`, `Database/Models/Highlight.swift` |
| F-06 Аннотации | `MarginOverlayView`, `MarginNoteView`, `StickyNoteView` |
| F-07 Панель | `Features/Annotations/AnnotationPanelView.swift` |
| F-08 Хранение | `Database/`, `Shared/FileAccess.swift` |

### Architectural Boundaries

**Bridge Boundary:** единственная точка взаимодействия Swift ↔ epub.js. Вся логика по обе стороны изолирована за `EPUBBridgeProtocol`.

**Database Boundary:** все обращения к SQLite только через Repository классы. Store-ы не знают о GRDB напрямую.

**JS Resources Boundary:** epub.js, jszip.js — сторонние библиотеки, не модифицируются. reader.js и reader.css — кастомный код, вся кастомизация только здесь.

### Data Flow

```
Пользователь выделяет текст
  → JS: textSelected(cfiStart, cfiEnd, text)
  → EPUBBridge → AnnotationStore
  → NoteEditorView (Alert для ввода текста)
  → AnnotationRepository.saveTextNote()
  → DatabaseManager (SQLite WAL)
  → AnnotationStore обновляется
  → MarginOverlayView запрашивает позиции: getAnnotationPositions()
  → JS: annotationPositions([{id, x, y}])
  → MarginNoteView появляется на поле
```

## Architecture Validation Results

### Coherence ✅
Все технологии совместимы. Swift 6 + SwiftUI + macOS 14.0 + GRDB 7.10.0 + epub.js + WKWebView — проверенная, бесконфликтная связка. @Observable и NavigationSplitView доступны с macOS 14.0.

### Requirements Coverage ✅
Все 8 функциональных требований имеют архитектурную поддержку. F-06 корректно разделён на два независимых overlay-механизма (Type A — CFI, Type B — page_index).

### Gaps Addressed

**reader.js — обязанности:**
- Перехват выделения текста → textSelected(cfiStart, cfiEnd, text)
- Генерация CFI для выделенного диапазона
- Вычисление координат аннотаций через getBoundingClientRect → annotationPositions
- Отрисовка highlight-ов поверх текста по команде Swift
- Обработка событий пагинации → pageChanged

**Обложки:** BookImporter извлекает обложку через epub.js при импорте, сохраняет PNG в sandbox, путь → books.cover_path.

**Fullscreen:** macOS автоматически скрывает sidebar через NSWindowStyleMask.fullScreen.

### Architecture Completeness Checklist

- [x] Контекст проекта и требования проанализированы
- [x] Стартовый шаблон выбран с обоснованием
- [x] Все критические архитектурные решения задокументированы
- [x] Схема базы данных определена
- [x] Паттерны именования и структуры зафиксированы
- [x] Обработка ошибок стандартизирована (Alert + OK)
- [x] Полная структура проекта определена
- [x] Все требования замаплены на файлы
- [x] Bridge protocol и типы сообщений специфицированы
- [x] Gaps найдены и закрыты

### Readiness: ГОТОВО К РЕАЛИЗАЦИИ

**Первая story для Amelia:** инициализация Xcode проекта + GRDB.swift + epub.js bundle + базовый WKWebView bridge (ping/pong тест).
