# Source Inventory For Reader Product Overview

## 1. Цель инвентаризации

Этот инвентарь собран для подготовки одного актуального user-facing обзора продукта `Reader`. Цель документа не в том, чтобы описать архитектуру или backlog, а в том, чтобы зафиксировать:

- что пользователь уже может делать в приложении сейчас;
- какие части поведения подтверждены кодом, тестами и свежими merged commits;
- какие документы можно использовать только как фон или источник будущих направлений;
- где остаются белые пятна, которые нужно перепроверять через git history и текущий UI-код.

## 2. Иерархия источников и уровень доверия

| Уровень | Источник | Сила | Как использовать |
|---|---|---|---|
| 1 | Код в `main`: `Reader/`, `ReaderTests/`, текущее UI-поведение, модели, сторы, репозитории | `strong` | Главный источник истины для shipped behavior |
| 1 | Свежие merged commits в `main` | `strong` | Подтверждают недавно добавленные пользовательские функции, которые могли не попасть в старые документы |
| 2 | Git history и diff-ы по recent commits | `strong` / `medium` | Хорошо подходит для выявления свежих фич и различения shipped vs planned |
| 3 | Документы в `_bmad-output/project-docs` и `_bmad-output/feature-docs` | `medium` / `weak` | Подходят для контекста, терминологии и planned directions, но не для утверждений о текущем состоянии без сверки с кодом |
| 4 | GitHub Project `bon2362/3` | `weak` | Только cross-check для пропущенных фич и направлений развития, не источник истины о shipped behavior |

## 3. Основные файлы и каталоги, подтверждающие shipped behavior

### Базовый пользовательский поток

- `README.md`
  Подтверждает позиционирование продукта как macOS-приложения для EPUB/PDF, локального хранения, аннотаций и библиотеки.
- `Reader/App/ContentView.swift`
  Подтверждает пользовательскую структуру приложения: библиотека -> чтение книги -> отдельный EPUB test flow.

### Библиотека и импорт книг

- `Reader/Features/Library/LibraryView.swift`
  Подтверждает экран библиотеки, поиск по названию и автору, drag-and-drop импорт книг, удаление, массовый экспорт аннотаций, импорт аннотаций с preview.
- `Reader/Features/Library/LibraryStore.swift`
  Подтверждает бизнес-логику библиотеки: загрузка книг, множественный импорт, выделение книги, feedback по частичному импорту, подготовка preview перед импортом аннотаций.
- `Reader/Features/Library/BookImporter.swift`
  Подтверждает поддерживаемые форматы импорта книг: `EPUB` и `PDF`.
- `Reader/Features/Library/BookCardView.swift`
  Подтверждает карточки книг с обложкой, прогрессом, badge формата, hover/select/open/delete.
- `ReaderTests/Features/LibraryStoreTests.swift`
  Подтверждает поведение поиска, drag-and-drop импорта, preview импорта аннотаций и feedback по библиотеке.
- `ReaderTests/Features/BookImporterTests.swift`
  Подтверждает распознавание формата и ограничения импортера.

### EPUB-чтение

- `Reader/Features/Reader/ReaderView.swift`
  Подтверждает пользовательский UI чтения EPUB: оглавление, поиск, панель аннотаций, sticky note, переход по номеру страницы.
- `Reader/Features/Reader/ReaderStore.swift`
  Подтверждает открытие EPUB, восстановление позиции, навигацию, экспорт аннотаций текущей книги, связь с поиском, TOC и аннотациями.
- `Reader/Bridge/NativeEPUBBridge.swift`
  Подтверждает загрузку EPUB, TOC, поиск, переходы по внутренним ссылкам, возврат назад, пагинацию и работу хайлайтов поверх EPUB.
- `Reader/Features/Reader/SearchStore.swift`
  Подтверждает поиск по книге, debounce, список недавних запросов.
- `Reader/Features/Reader/TOCView.swift`
  Подтверждает боковую панель оглавления и подсветку текущего раздела.
- `Reader/Features/Reader/PageIndicator.swift`
  Подтверждает отображение текущей страницы и переход к введённому номеру страницы.
- `ReaderTests/Features/ReaderStoreTests.swift`
  Подтверждает открытие книг, экспорт аннотаций, sticky note labels, восстановление PDF/EPUB state.
- `ReaderTests/Bridge/NativeEPUBBridgeTests.swift`
  Подтверждает часть bridge-поведения EPUB.
- `ReaderTests/Features/SearchStoreTests.swift`
  Подтверждает поиск и recent searches.
- `ReaderTests/Features/TOCStoreTests.swift`
  Подтверждает логику оглавления.

### PDF-чтение

- `Reader/Features/PDFReader/PDFReaderView.swift`
  Подтверждает отдельный пользовательский поток чтения PDF.
- `Reader/Features/PDFReader/PDFReaderStore.swift`
  Подтверждает восстановление позиции, поиск по PDF с текстовым слоем, TOC из outline, переход по странице, навигацию по аннотациям, sticky notes в PDF.
- `Reader/Features/PDFReader/PDFBookLoader.swift`
  Подтверждает загрузку PDF и различение документов без текстового слоя.
- `Reader/Features/PDFReader/PDFHighlightRenderer.swift`
  Подтверждает highlight-оверлеи в PDF.
- `Reader/Features/PDFReader/PDFTextNoteRenderer.swift`
  Подтверждает визуализацию текстовых заметок в PDF.
- `ReaderTests/Features/PDFBookLoaderTests.swift`
  Подтверждает импорт/загрузку PDF.
- `ReaderTests/Features/PDFReaderStoreTests.swift`
  Подтверждает восстановление позиции, TOC, page jump, поиск, highlight/navigation поведение в PDF.
- `ReaderTests/Features/PDFAnchorTests.swift`
  Подтверждает схему якорей PDF.

### Аннотации и заметки

- `Reader/Features/Annotations/HighlightsStore.swift`
  Подтверждает создание, перекраску и удаление highlight.
- `Reader/Features/Annotations/TextNotesStore.swift`
  Подтверждает заметки к выделенному тексту.
- `Reader/Features/Annotations/StickyNotesStore.swift`
  Подтверждает sticky notes, привязанные к странице.
- `Reader/Features/Annotations/AnnotationPanelView.swift`
  Подтверждает панель аннотаций с вкладками и переходом к выбранной записи.
- `Reader/Features/Annotations/AnnotationPanelStore.swift`
  Подтверждает состав элементов панели и пользовательские метки локации.
- `Reader/Features/Annotations/HighlightColorPicker.swift`
  Подтверждает доступные действия рядом с выделением: выбор цвета, добавление заметки, удаление у активного highlight.
- `Reader/Features/Annotations/NoteEditorView.swift`
  Подтверждает редактирование текстовых заметок.
- `ReaderTests/Features/HighlightsStoreTests.swift`
- `ReaderTests/Features/TextNotesStoreTests.swift`
- `ReaderTests/Features/StickyNotesStoreTests.swift`
- `ReaderTests/Features/AnnotationPanelStoreTests.swift`
  Эти тесты вместе подтверждают shipped behavior вокруг highlights, text notes, sticky notes и аннотационной панели.

### Импорт и экспорт аннотаций

- `Reader/Features/Annotations/AnnotationExportService.swift`
  Подтверждает экспорт аннотаций в Markdown-файлы по книге или по всей библиотеке.
- `Reader/Features/Annotations/MarkdownAnnotationEncoder.swift`
  Подтверждает существование переносимого Markdown exchange format.
- `Reader/Features/Annotations/AnnotationImportPreviewService.swift`
  Подтверждает preview импорта с подсчётом create/update/skip.
- `Reader/Features/Annotations/AnnotationImportService.swift`
  Подтверждает применение импорта с per-book grouping и обновлением существующих аннотаций.
- `Reader/Features/Annotations/MarkdownAnnotationDecoder.swift`
  Подтверждает чтение exchange Markdown.
- `ReaderTests/Features/AnnotationExportServiceTests.swift`
- `ReaderTests/Features/AnnotationImportPreviewServiceTests.swift`
- `ReaderTests/Features/AnnotationImportServiceTests.swift`
- `ReaderTests/Features/MarkdownAnnotationEncoderTests.swift`
- `ReaderTests/Database/AnnotationExchangeIdTests.swift`
  Подтверждают транспортный формат, preview, import apply и устойчивые exchange IDs.

### Локальное хранение и состояние

- `Reader/Database/DatabaseManager.swift`
- `Reader/Features/Library/LibraryRepository.swift`
- `Reader/Features/Annotations/AnnotationRepository.swift`
- `Reader/Database/Models/Book.swift`
- `Reader/Database/Models/Highlight.swift`
- `Reader/Database/Models/TextNote.swift`
- `Reader/Database/Models/PageNote.swift`
  Подтверждают локальное SQLite-хранение книг, позиции чтения и аннотаций.
- `Reader/Database/Migrations/Migration_001.swift` ... `Migration_006.swift`
  Подтверждают эволюцию shipped data model: page-in-chapter, cache счёта страниц, exchange IDs и т.д.

## 4. Список продуктовых областей и где они подтверждаются

| Продуктовая область | Что подтверждено | Основные подтверждения |
|---|---|---|
| Библиотека | Добавление, удаление, отображение прогресса, форматный badge, выделение карточки | `LibraryView.swift`, `BookCardView.swift`, `LibraryStore.swift`, `LibraryStoreTests.swift` |
| Поиск в библиотеке | Поиск по названию и автору, подсветка совпадений, пустое состояние | `LibraryView.swift`, `BookCardView.swift`, `LibraryStore.swift`, commit `6a8d7ef` |
| Импорт книг | File picker и drag-and-drop для EPUB/PDF | `LibraryView.swift`, `BookImporter.swift`, commit `3426064`, `BookImporterTests.swift` |
| EPUB reader | Открытие книги, пагинация, переходы, TOC, поиск, page jump | `ReaderView.swift`, `ReaderStore.swift`, `NativeEPUBBridge.swift`, `PageIndicator.swift` |
| PDF reader | Открытие PDF, восстановление позиции, TOC, поиск, page jump | `PDFReaderView.swift`, `PDFReaderStore.swift`, `PDFReaderStoreTests.swift`, recent PDF commits |
| Аннотации | Highlights, text notes, sticky notes, панель аннотаций | `HighlightsStore.swift`, `TextNotesStore.swift`, `StickyNotesStore.swift`, `AnnotationPanelView.swift`, профильные тесты |
| Импорт/экспорт аннотаций | Экспорт текущей книги, экспорт всей библиотеки, Markdown preview/import apply | `AnnotationExportService.swift`, `AnnotationImportPreviewService.swift`, `AnnotationImportService.swift`, commits `d2e8659`, `25f495c` |
| Локальное хранение | SQLite, мгновенное сохранение состояния чтения, локальные файлы книг | `DatabaseManager.swift`, `LibraryRepository.swift`, `Book.swift`, `FileAccess.swift` |

## 5. Слабые и вторичные источники

### `_bmad-output/project-docs`

Использование: `medium` / `weak`

Что полезно брать:

- формулировки продукта и пользовательских сценариев;
- старые решения, если они всё ещё подтверждаются кодом;
- список planned directions.

Что нельзя брать без перепроверки:

- любые утверждения о текущем движке EPUB, если они расходятся с кодом;
- старые roadmap-пункты, которые уже успели стать shipped;
- детали, относящиеся к устаревшему состоянию MVP.

Конкретные документы с полезным, но неканоничным содержанием:

- `_bmad-output/project-docs/prd-reader-app.md`
  Полезен для исходной продуктовой рамки, но в нём уже есть устаревшие технические предположения.
- `_bmad-output/project-docs/retrospective-reader-app-mvp.md`
  Полезен как исторический снимок, но часть разделов явно устарела: например, там ещё указано, что PDF и экспорт аннотаций не сделаны.
- `_bmad-output/project-docs/architecture-iphone-mvp.md`
  Подходит как источник future direction, не как описание shipped behavior.

### GitHub Project `bon2362/3`

Использование: `weak`

Что полезно брать:

- список недавних и будущих пользовательских задач;
- cross-check, не пропущены ли свежие shipped-фичи вроде drag-and-drop, library search, page jump.

Что нельзя брать напрямую:

- формулировки статусов как доказательство shipped behavior без проверки кода;
- backlog ideas как часть текущего продукта.

## 6. Риски и белые пятна для следующего этапа commit/diff audit

- В старых документах встречаются устаревшие утверждения про Readium, отсутствие PDF и отсутствие экспорта аннотаций. Их нужно явно вычистить из финального overview.
- Недавние shipped-фичи сосредоточены в последних коммитах `main`: library search, drag-and-drop, import flow, page jump. Они легко теряются, если опираться только на ранние PRD/retro.
- Нужна отдельная проверка свежих merged commits вокруг `library`, `annotations`, `import/export`, `EPUB`, `PDF`.
- Для planned section стоит брать только направления, которые видны либо в актуальных secondary docs, либо в GitHub Project, и явно маркировать как `future` / `planned`.
- В проекте есть исторические следы названия `slow reader`; в финальном продуктовой файле нужно держаться текущего названия `Reader`, если не найдены обратные указания в актуальном UI.
