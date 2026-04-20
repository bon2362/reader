# План: поддержка PDF-книг

**Дата:** 2026-04-20
**Автор:** Winston (architect)
**Исполнитель:** dev-агент
**Статус:** готов к реализации

---

## 1. Цель

Добавить в slow reader чтение PDF-книг с полным набором фич EPUB: библиотека, листание, TOC, поиск, highlights 5 цветов, text notes (type A), sticky notes (type B), единая панель аннотаций.

PDF перемещён из Фазы 3 в текущий MVP. Фаза 2 (поиск/экспорт аннотаций) откладывается.

---

## 2. Архитектурная стратегия

### 2.1 Разделение рендереров

Renderer-слой для PDF параллелен EPUB-реализации. Всё выше renderer-слоя — общее:

- **Общее (без изменений):** `LibraryStore`, `LibraryRepository`, `HighlightsStore`, `TextNotesStore`, `StickyNotesStore`, `AnnotationPanelStore`, `AnnotationRepository`, `ChapterHeaderBar`, `FloatingIconButton`, `HighlightColorPicker`, `NoteEditorView`, `TOCView`/`TOCStore`, `SearchView`/`SearchStore`, `FileAccess` (Security-Scoped Bookmarks), `DatabaseManager`, `ErrorHandler`.
- **PDF-специфичное (новое):** `NativePDFView`, `PDFBookLoader`, `PDFReaderView`, `PDFReaderStore`, `PDFAnchor` + маленький набор утилит координат.

Диспетчер в `ReaderView` выбирает EPUB- или PDF-подвьюху по `book.format`.

### 2.2 Технологический выбор

- **Рендеринг:** нативный `PDFKit` (входит в macOS SDK). `PDFView` в режиме `.singlePage`, `displayDirection: .horizontal`, `autoScales: true`.
- **Новых зависимостей нет.** `PDFKit` даёт из коробки: рендер, пагинацию, нативное выделение текста, `PDFOutline` (TOC), поиск через `findString`, `PDFAnnotation` для подсветки.
- **Никакого WKWebView и JS-моста для PDF не используется.** PDFKit отдаёт Swift API напрямую; bridge-протокол здесь не нужен.

### 2.3 Импорт файлов

- `BookImporter` расширяется: `.epub` → EPUB-ветка (существующая), `.pdf` → PDF-ветка.
- PDF копируется в app sandbox (как EPUB) + Security-Scoped Bookmark.
- Обложка: `PDFDocument.page(at: 0).thumbnail(of: CGSize(width: 400, height: 600), for: .cropBox)` → PNG → `books.cover_path`.
- Метаданные: `PDFDocument.documentAttributes` → `Title`, `Author`. Если отсутствуют — `title = filename` (без расширения), `author = ""`.

---

## 3. Схема БД: Migration_005

```sql
ALTER TABLE books ADD COLUMN format TEXT NOT NULL DEFAULT 'epub';
-- значения: 'epub' | 'pdf'
```

**Всё. Больше никаких структурных изменений.**

### 3.1 Как используются существующие колонки для PDF

| Колонка | EPUB | PDF |
|---|---|---|
| `books.file_path` | путь к .epub в sandbox | путь к .pdf в sandbox |
| `books.file_bookmark` | Security-Scoped Bookmark | то же |
| `books.chapter_page_counts` | JSON-массив из preflight | `NULL` (не используется — PDFKit знает страницы сразу) |
| `books.last_cfi` | `"href\|offset"` | `"pdf:<pageIndex>"` (для восстановления позиции достаточно номера страницы) |
| `books.total_pages` / `current_page` | считаются preflight-ом | `PDFDocument.pageCount` / `currentPage.index` |
| `highlights.cfi_start` / `cfi_end` | `"<href>\|<offset>"` | `"pdf:<pageIndex>\|<charOffset>"` (см. §4) |
| `text_notes.cfi_anchor` | то же | то же |
| `page_notes.spine_index` | индекс spine-item | индекс страницы PDF |
| `page_notes.page_in_chapter` | страница внутри главы | всегда `0` |

### 3.2 Отличия ветки `format == 'pdf'` в коде

- Preflight-механизм пропускается целиком: в `ReaderStore` для PDF `isPageCountReady = true` сразу после `PDFDocument` открылся.
- `AnnotationRepository` не меняется — anchor хранится как opaque TEXT. Логика парсинга anchor'а инкапсулирована в `PDFAnchor` / `EPUBAnchor` (для EPUB оставляем существующий код как есть).

---

## 4. Формат якоря для PDF

```
pdf:<pageIndex>|<charStart>-<charEnd>
```

- `pageIndex` — 0-based индекс страницы в `PDFDocument`.
- `charStart`, `charEnd` — смещения в `page.string` (plain-text страницы, UTF-16 units — тот же, что использует `NSRange` в PDFKit).

**Почему character offsets, а не `PDFSelection`/quadPoints:**
PDF иммутабелен (зафиксировано в PRD: «Изменения файлов не предполагаются»), `page.string` стабилен между запусками. Восстановление выделения:

```swift
let page = document.page(at: pageIndex)!
let selection = page.selection(for: NSRange(location: charStart, length: charEnd - charStart))
```

Для sticky notes (type B) якорь не нужен — они хранятся в `page_notes` по `spine_index = pageIndex`.

---

## 5. Детект сканированных PDF

При импорте: `document.string?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true` → помечаем книгу как image-only (добавляем поле в in-memory модель, в БД не сохраняем — можно перепроверить при открытии).

В UI для image-only PDF:
- Поиск отключён (пустая выдача).
- `HighlightColorPicker` не показывается (нет текста для выделения).
- Text notes (type A) недоступны.
- **Sticky notes (type B) работают** — они привязаны к странице, не к тексту.
- На карточке в библиотеке — маленький значок «image-only» (SF Symbol `photo`).

---

## 6. UI и взаимодействие

### 6.1 PDFReaderView — структура

Параллельна `EPUBReaderView`. Содержит:
- `ChapterHeaderBar` (существующий компонент) — название текущей «главы» (см. §6.3) или название книги.
- `NativePDFView` (новый NSViewRepresentable вокруг `PDFView`).
- Floating icon-кнопки по углам (те же `FloatingIconButton`): back-to-library, TOC, search, annotations panel, add-sticky-note.
- `PageIndicator` снизу — «стр. X из Y».
- Margin overlay справа — `MarginOverlayView` (существующий) для иконок type A и B.

### 6.2 Листание

- `PDFView.goToNextPage()` / `goToPreviousPage()`.
- SwiftUI `.onKeyPress(.leftArrow / .rightArrow / .space)` — как у EPUB.
- Клик по краям страницы (левая/правая четверть) — тоже листание. Обработчик на SwiftUI-обёртке поверх `PDFView`; PDFView получает события только в центральной зоне (для выделения текста).
- `PDFView.displayMode = .singlePage`, `displayDirection = .horizontal`, `autoScales = true`.

### 6.3 «Главы» (TOC)

- Если `PDFDocument.outlineRoot != nil` — рекурсивно разворачиваем в плоский/иерархический список `TOCItem` (как у EPUB). Для каждой главы: `label`, `destination` (`PDFDestination`), вложенные дети.
- Текущая «глава» вычисляется поиском: находим outline-элемент с наибольшим `destination.pageIndex <= currentPageIndex`.
- Если outline отсутствует — `ChapterHeaderBar` показывает название книги, `TOCView` показывает одну запись «Вся книга», либо просто пусто. Индикатор страницы тогда — чистый «стр. X из Y».

### 6.4 Поиск

- `PDFDocument.findString(query, withOptions: [.caseInsensitive, .diacriticInsensitive])` → `[PDFSelection]`.
- Debounce 300ms (реюзаем существующую логику из `SearchStore`).
- Сниппеты: `selection.extendForLineBoundaries(); selection.string` + форматирование. Для подсветки — `PDFView.highlightedSelections = [currentResult]`.
- Recent searches — общая история через существующий `UserDefaults`-ключ `reader.recentSearches`.

### 6.5 Выделение текста, highlights, text notes

**Выделение:**
- Подписка на `.PDFViewSelectionChanged`. Читаем `pdfView.currentSelection`.
- Координаты пикера цвета: `selection.bounds(for: page)` → перевод в координаты `PDFView` через `pdfView.convert(_:from:)`. Тот же `HighlightColorPicker` с клампингом к viewport (существующий код).
- Снятие выделения: отсутствие `currentSelection` или `selectionChanged` с пустым selection → `HighlightsStore.onSelectionCleared()`.

**Применение highlight:**
- Создаём `PDFAnnotation` типа `.highlight` с `quadrilateralPoints` из `selection.selectionsByLine()` для каждой строки. `annotation.color = NSColor(...)` из палитры.
- `annotation.setValue("slow reader", forAnnotationKey: .contents)` (или используем user-defined key) — чтобы отличать наши аннотации от встроенных в PDF.
- Одновременно сохраняем в БД через `AnnotationRepository.saveHighlight` с anchor `pdf:<page>|<start>-<end>`.

**Загрузка при открытии книги:**
- Читаем все highlights текущей книги из БД → для каждого парсим anchor → восстанавливаем `PDFSelection` → добавляем `PDFAnnotation` на соответствующую `PDFPage`.

**Встроенные в PDF аннотации (от автора файла):**
- Рендерятся PDFKit-ом по умолчанию (мы их не трогаем). В нашу БД не попадают. Отличаем по отсутствию нашего маркера в user-defined key.

**Text notes (type A):**
- Тот же highlight + запись в `text_notes`. Визуально: поверх highlight-а — пунктирное подчёркивание. Реализуется как отдельный `PDFAnnotation` типа `.underline` с dashed style (`annotation.border = PDFBorder(); border.style = .dashed; border.dashPattern = [2, 2]`) либо — если PDFKit не отрисует пунктир корректно — через `MarginOverlayView`-иконку на полях с popover (существующий `TextNotePopoverOverlay`).
- Клик по аннотации: `.PDFViewAnnotationHit` → находим соответствующий `TextNote` по anchor → показываем popover.

### 6.6 Sticky notes (type B)

- `Cmd+Shift+N` или кнопка в углу → создаём `PageNote` с `spine_index = pdfView.currentPage.index`, `page_in_chapter = 0`.
- Иконка в margin overlay — реюзаем `StickyNoteView`. Позиция — фиксированная в правом поле.
- Label в списке аннотаций: «Стр. Y» (для PDF без глав) или «<название главы> · стр. Y» (если есть outline).

### 6.7 Панель аннотаций

`AnnotationPanelView` уже работает через `AnnotationRepository` — кода менять не нужно. Только при клике по записи для перехода — диспетчер по `book.format`:
- EPUB: существующий флоу через bridge.
- PDF: `pdfView.go(to: PDFDestination(page: page, at: point))`, затем (для highlights/text notes) подсветка результирующего selection на короткое время.

### 6.8 Внутренние ссылки, сноски, navStack

- PDF link annotations обрабатываются `PDFView` автоматически. Перехватываем через `.PDFViewAnnotationHit`:
  - Если это `.link` annotation → сохраняем текущую позицию (`currentPage.index`) в общий `navStack` (используем уже существующий из EPUB-флоу, расширяем enum позиции: `.epub(cfi)` | `.pdf(pageIndex)`).
  - Даём PDFView обработать переход.
  - Показываем floating-кнопку «назад» (та же, что для EPUB-сносок).
- При pop из navStack с `.pdf(pageIndex)` → `pdfView.go(to: document.page(at: pageIndex)!)`.

### 6.9 Индикатор страницы

- `current = pdfView.currentPage.pageRef.pageNumber` — 1-based PDF page number (с учётом PDF-переопределений нумерации, если они есть).
- Если `pageRef.pageNumber` == 0 (нестандартный PDF) — fallback на `currentPage.index + 1`.
- `total = document.pageCount`.

### 6.10 Resize окна

Подписка на `NSView.frameDidChangeNotification` на обёртке `PDFView` → триггерим пересчёт координат margin-иконок (вызов существующего механизма обновления позиций в `MarginOverlayView`).

---

## 7. Структура файлов

Новые файлы:

```
Reader/Features/PDFReader/
├── PDFReaderView.swift           -- главная SwiftUI-вьюха
├── PDFReaderStore.swift          -- @Observable @MainActor, текущая страница, currentSelection
├── NativePDFView.swift           -- NSViewRepresentable вокруг PDFView + нотификации
├── PDFBookLoader.swift           -- импорт, метаданные, обложка, детект image-only
├── PDFAnchor.swift               -- кодирование/декодирование anchor-строки
├── PDFHighlightRenderer.swift    -- создание PDFAnnotation из Highlight, загрузка при открытии
└── PDFNavigationCoordinator.swift-- перехват link annotations, navStack-интеграция

Reader/Database/Migrations/
└── Migration_005.swift           -- ADD COLUMN books.format

ReaderTests/Features/
├── PDFBookLoaderTests.swift
├── PDFAnchorTests.swift
└── PDFReaderStoreTests.swift
```

Изменённые файлы:

```
Reader/Features/Library/BookImporter.swift   -- ветка для .pdf
Reader/Database/Models/Book.swift            -- поле format: BookFormat
Reader/Features/Reader/ReaderView.swift      -- диспетчер EPUB/PDF по format
Reader/Shared/BookFormat.swift               -- новый enum (epub, pdf)
Reader/Features/Annotations/AnnotationPanelStore.swift
  -- диспетчер перехода по anchor для PDF (если логика была завязана на EPUB-bridge)
Reader/Features/TOC/TOCStore.swift           -- построение TOC из PDFOutline
Reader/Features/Search/SearchStore.swift     -- ветка поиска для PDF
```

Существующий EPUB-код остаётся без изменений, кроме case'ов в диспетчерах.

---

## 8. Последовательность реализации

Каждый пункт — отдельная story, имеет ясный acceptance criterion (AC). Story сдаётся, когда AC выполняется руками в запущенном приложении.

### Story 1. Фундамент: `BookFormat`, Migration_005, диспетчер

- Создать `BookFormat` enum (`epub`, `pdf`).
- `Migration_005`: `ALTER TABLE books ADD COLUMN format TEXT NOT NULL DEFAULT 'epub'`.
- Обновить `Book` модель и `LibraryRepository` — читать/писать `format`.
- Обновить `BookImporter`: определять формат по расширению, падать с понятной ошибкой для неподдерживаемых.
- `ReaderView` умеет ветвиться по `format`, но PDF-ветка пока — заглушка «PDF reader coming soon».
- **AC:** существующие EPUB-книги открываются как раньше; попытка импорта PDF кладёт запись в БД с `format='pdf'` и показывает заглушку.

### Story 2. Открытие PDF, листание, обложка, метаданные

- `PDFBookLoader`: открывает PDF, извлекает title/author/cover, детектит image-only. Копирует файл в sandbox с Security-Scoped Bookmark.
- `NativePDFView`: NSViewRepresentable, режим `.singlePage` + `.horizontal` + `autoScales`. Загружает документ из файла книги.
- `PDFReaderView`: обёртка вокруг `NativePDFView`, листание стрелками / пробелом / кликами по краям, `ChapterHeaderBar` с названием книги (пока без TOC), `PageIndicator` «стр. X из Y».
- Сохранение/восстановление последней страницы через `books.last_cfi = "pdf:<pageIndex>"`.
- **AC:** импорт PDF → в библиотеке карточка с обложкой и метаданными; открытие → видно первую страницу; листание работает всеми способами; закрыть и снова открыть → то же место.

### Story 3. TOC

- Парсер `PDFOutline` → `[TOCItem]` (реюзаем существующую модель).
- `TOCStore` ветвится по `book.format`.
- Текущая глава: поиск наибольшего `destination.pageIndex <= currentPage.index` в плоском списке.
- `ChapterHeaderBar` показывает текущую главу (если есть outline) или название книги.
- Переход по клику: `pdfView.go(to: destination)`.
- Fallback: PDF без outline → TOC-панель показывает состояние «оглавление недоступно», header показывает название книги.
- **AC:** PDF с outline — видно главы, клик переходит, заголовок обновляется при листании. PDF без outline — пустой TOC без падений.

### Story 4. Поиск

- `SearchStore` ветвится по `book.format`.
- PDF-ветка: `PDFDocument.findString` + debounce 300ms + recent searches (общий ключ UserDefaults).
- Список результатов с сниппетами (строка вокруг совпадения).
- Клик по результату → переход + временная подсветка через `pdfView.highlightedSelections`.
- Для image-only PDF — пустая выдача с подписью «в этом PDF нет текстового слоя».
- **AC:** поиск по PDF работает как по EPUB — выдача, сниппеты, переход, recent, подсветка текущего результата.

### Story 5. Highlights

- `PDFAnchor`: encode/decode `pdf:<page>|<start>-<end>`, тесты отдельной test-suite'ой.
- `PDFHighlightRenderer`:
  - `apply(highlight:, in: pdfView)` — создаёт `PDFAnnotation` типа `.highlight` с quadrilateralPoints на нужных строках, маркирует user-defined key'ом.
  - `restoreAll(for: book, in: pdfView)` — загружает все highlights из БД при открытии.
  - `remove(highlight:, in: pdfView)` — находит и удаляет `PDFAnnotation`.
- `HighlightsStore` ветвится: получение `textSelected` из `.PDFViewSelectionChanged`, координаты пикера из `selection.bounds(for:).convert(_:from:)`.
- `HighlightColorPicker` — переиспользуется как есть, позиционирование через существующий механизм.
- **AC:** выделил текст в PDF → пикер на правильном месте → выбрал цвет → подсветка применилась; переоткрыл книгу → highlight на месте; клик по highlight'у → меню изменить цвет/удалить; работает корректно вместе с существующими highlight'ами EPUB-книг.

### Story 6. Text notes (type A)

- `TextNotesStore` ветвится по формату.
- PDF-ветка: поверх highlight создаётся запись в `text_notes`. Визуально:
  - Основной вариант: margin-иконка на уровне `selection.bounds.midY` в правом поле, popover с текстом при клике (реюзаем `TextNotePopoverOverlay`).
  - Опционально, если выглядит хорошо: дополнительный `PDFAnnotation` типа `.underline` с dashed border для визуального отличия. Если PDFKit отрисовывает плохо — оставляем только margin-иконку.
- Клик по margin-иконке — popover с текстом. Редактирование/удаление через те же контролы, что в EPUB.
- **AC:** выделил текст → «заметка» → ввёл текст → иконка в margin; клик → popover с заметкой; редактирование и удаление работают; после переоткрытия — всё на месте.

### Story 7. Sticky notes (type B)

- `StickyNotesStore` ветвится по формату.
- PDF-ветка: `Cmd+Shift+N` / кнопка → создаём `PageNote` с `spine_index = currentPage.index`, `page_in_chapter = 0`.
- Margin-иконка на правом поле текущей страницы — позиция фиксированная (существующий механизм).
- Label в списках: «<название главы> · стр. Y» если есть outline, иначе «Стр. Y».
- **AC:** Cmd+Shift+N на любой странице PDF создаёт sticky; иконка в правом поле; клик — popover; переход к sticky из панели аннотаций — на нужную страницу.

### Story 8. Панель аннотаций, навигация

- `AnnotationPanelStore` — обеспечить корректный переход по anchor для PDF:
  - highlight/text note → парсим `PDFAnchor` → `pdfView.go(to: PDFDestination(page: page, at: bounds.origin))` + временная подсветка.
  - sticky note → `pdfView.go(to: page)`.
- Список, вкладки All/Highlights/Notes/Stickies — работают без изменений (данные единообразны в БД).
- `navStack` расширить: `enum ReaderPosition { case epub(cfi: String), case pdf(pageIndex: Int) }`. Push при переходе, pop по кнопке «назад».
- Обработка link annotations в PDF: перехват `.PDFViewAnnotationHit`, push текущей позиции в navStack, даём PDFView сделать переход, показываем кнопку возврата.
- **AC:** панель аннотаций показывает всё по книге; клик переводит корректно; сноски и внутренние ссылки в PDF работают с кнопкой возврата так же, как в EPUB.

### Story 9. Edge cases и доводка

- Image-only PDF: проверить отключение поиска / пикера / text notes; sticky работают.
- PDF с переопределённой нумерацией страниц (`pageRef.pageNumber`) — индикатор корректен.
- Resize окна: margin-иконки пересчитывают позицию.
- Большой PDF (>300 страниц, >100MB) — открытие не блокирует UI; highlights подгружаются без видимых лагов (при необходимости — batched apply в `Task.detached`).
- Undo/Redo-сценарии для аннотаций — проверить, что запись PDFAnnotation в `PDFView` и запись в БД не расходятся при быстрых действиях.
- Карточка image-only в библиотеке — значок.
- **AC:** все пункты выше проверены руками на 3 тестовых PDF (обычный с outline, без outline, scanned).

---

## 9. Тестирование

- Unit-тесты: `PDFAnchorTests` (парсинг граничных случаев), `PDFBookLoaderTests` (через фикстуры PDF в bundle), `PDFReaderStoreTests` (моки `PDFView` через тонкий протокол `PDFViewing` если понадобится изолировать).
- Интеграционных тестов PDFKit-а не пишем — полагаемся на ручное тестирование по AC каждой story.
- Тестовые фикстуры: положить в `ReaderTests/Resources/`:
  - `sample-with-outline.pdf` — короткий PDF с outline.
  - `sample-no-outline.pdf` — PDF без outline.
  - `sample-scanned.pdf` — image-only PDF (1-2 страницы).

---

## 10. Out of scope

Не делаем в этой итерации:
- Редактирование PDF (поворот, извлечение страниц).
- Заполнение PDF-форм, подписи.
- OCR сканированных PDF.
- Sidebar с thumbnail'ами страниц.
- Двойная страница / `.twoUp` режимы.
- Экспорт аннотаций в Markdown/JSON (это была Фаза 2, теперь откладывается дальше).
- Горячие клавиши для смены цвета highlight, темы, кастомные шрифты.
- iCloud sync, iPhone-версия.

---

## 11. Правила для dev-агента

- Существующий EPUB-код не модифицируется, кроме добавления `case .pdf` в местах диспетчеризации. Регрессии в EPUB недопустимы.
- БД — только через Repository, не напрямую через GRDB из Store/View.
- Ошибки — через `Alert` (существующий `ErrorHandler` / `View+ErrorAlert`).
- Все новые сторы — `@Observable @MainActor`, как существующие.
- Repository-методы — `async`, типы `Sendable`.
- Все anchor-строки в БД — opaque TEXT, парсинг только в `PDFAnchor` / `EPUBAnchor`.
- `PDFAnnotation` в документе и запись в БД должны быть консистентны: при любом изменении — сначала БД, потом UI (либо обёртка, гарантирующая откат).
- Именование: `PDFReader...`, `PDFBookLoader`, `PDFAnchor` — без аббревиатуры `Pdf`.
- Тесты — в `ReaderTests/`, именование `<Subject>Tests.swift`.

---

## 12. Контрольный список готовности

- [ ] Migration_005 применена, существующие книги не сломаны.
- [ ] Импорт PDF работает, обложка/метаданные корректны, image-only детектится.
- [ ] Листание, TOC, индикатор страницы, поиск — работают.
- [ ] Highlights 5 цветов: создание, отображение, изменение, удаление, персистентность.
- [ ] Text notes (type A): создание, редактирование, popover, персистентность.
- [ ] Sticky notes (type B): создание, отображение, переход из панели.
- [ ] Панель аннотаций: все вкладки, переход работает.
- [ ] navStack для PDF-ссылок, кнопка «назад».
- [ ] Resize окна не ломает overlay.
- [ ] Все AC по stories 1-9 подтверждены на трёх тестовых PDF.
