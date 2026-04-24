# Feature Audit From Commits And Diffs

## Цель

Этот аудит фиксирует, какие пользовательские возможности `Reader` подтверждаются recent merged commits и текущим кодом, а какие остаются только planned или ambiguous. Статусы:

- `shipped` — подтверждено кодом в `main`, тестами или merged commit с явным user-facing diff.
- `ambiguous` — есть косвенные следы, но не хватает надёжного подтверждения для user-facing обещания.
- `planned` — видно в docs или GitHub Project, но нет достаточного подтверждения в текущем shipped code.

## 1. Недавние merged commits и их продуктовый смысл

| Commit | Что добавлено | Статус | Основание |
|---|---|---|---|
| `124a3cf` | Переход к конкретной странице из page indicator в EPUB и PDF | `shipped` | Изменения в `PageIndicator`, `ReaderStore`, `PDFReaderStore`, профильные тесты |
| `6a8d7ef` | Поиск в библиотеке по названию и автору с визуальной подсветкой совпадений | `shipped` | `LibraryView`, `BookCardView`, `LibraryStoreTests` |
| `3426064` | Drag-and-drop импорт книг в библиотеку | `shipped` | `LibraryView`, `LibraryStore`, `LibraryStoreTests` |
| `25f495c` | Поток импорта аннотаций из библиотеки с preview перед применением | `shipped` | `LibraryView`, `LibraryStore`, preview sheet, `LibraryStoreTests` |
| `d2e8659` | Разделение экспорта аннотаций на экспорт текущей книги и экспорт всей библиотеки | `shipped` | `AnnotationPanelView`, `LibraryView`, `AnnotationExportServiceTests` |
| `e3fd810` | Полировка экспорта и отображения локаций sticky notes | `shipped` | `AnnotationPanelStore`, `ReaderStore`, тесты форматирования локации |
| `17029a3` | Стабилизация восстановления позиции в PDF после повторного открытия | `shipped` | current `PDFReaderStore` и subsequent commits на `main` сохраняют этот поток |
| `b43f28a` | Исправления прогресса и TOC state в PDF | `shipped` | current `PDFReaderStore` строит TOC, сохраняет page state |
| `2bcde8a` | Поддержка PDF reader | `shipped` | Наличие отдельного PDF flow в `main` |
| `ec17a72` | Исправления sticky annotations в панели | `shipped` | current `AnnotationPanelStore` / `AnnotationPanelView` |

## 2. Аудит по продуктовым областям

### Библиотека

#### Подтверждённые shipped возможности

- Импорт книг через file picker для `EPUB` и `PDF`.
- Drag-and-drop импорт книг в библиотеку.
- Карточки книг с обложкой или placeholder, названием, автором, progress bar и badge формата.
- Одинарный клик для выбора книги и двойной клик для открытия.
- Удаление книги из библиотеки с подтверждением.
- Поиск по названию и автору.
- Подсветка совпадений в тексте карточки.

Подтверждения:

- `Reader/Features/Library/LibraryView.swift`
- `Reader/Features/Library/BookCardView.swift`
- `Reader/Features/Library/LibraryStore.swift`
- commits `6a8d7ef`, `3426064`, `cb146b6`, `fa7b083`, `cc1e441`

Статус: `shipped`

#### Что выглядит planned или не подтверждено

- Разделение библиотеки по статусу чтения: начатые / не начатые / прочитанные.
- Поддержка дополнительных форматов вроде FB2.

Источники:

- GitHub Project issues `#16`, `#13`, `#21`

Статус: `planned`

### EPUB reader

#### Подтверждённые shipped возможности

- Открытие EPUB из библиотеки.
- Постраничное чтение.
- Навигация вперёд/назад клавишами и кликами по краям страницы.
- Боковое оглавление.
- Поиск по книге с результатами и recent queries.
- Переход по внутренним ссылкам с возможностью вернуться назад.
- Переход к конкретной странице через page indicator.
- Восстановление позиции при повторном открытии книги.

Подтверждения:

- `Reader/Features/Reader/ReaderView.swift`
- `Reader/Features/Reader/ReaderStore.swift`
- `Reader/Bridge/NativeEPUBBridge.swift`
- `Reader/Features/Reader/SearchStore.swift`
- `Reader/Features/Reader/PageIndicator.swift`
- commit `124a3cf`

Статус: `shipped`

#### Ambiguous или неподтверждённое

- Любые user-facing обещания о настройках темы, шрифта, размера текста или режима колонок.

Основание:

- В коде текущего `main` нет пользовательского UI для этих настроек.
- В GitHub Project такие задачи есть как будущие.

Статус: `planned`

### PDF reader

#### Подтверждённые shipped возможности

- Открытие PDF-книг из библиотеки.
- Сохранение и восстановление позиции чтения.
- Оглавление на основе PDF outline, если оно есть.
- Поиск по PDF при наличии текстового слоя.
- Показ сообщения о недоступности поиска для image-only PDF.
- Переход к конкретной странице через page indicator.
- Навигация к найденным местам и аннотациям.

Подтверждения:

- `Reader/Features/PDFReader/PDFReaderView.swift`
- `Reader/Features/PDFReader/PDFReaderStore.swift`
- `ReaderTests/Features/PDFReaderStoreTests.swift`
- commits `2bcde8a`, `b43f28a`, `17029a3`, `124a3cf`

Статус: `shipped`

#### Ambiguous или неподтверждённое

- Любые обещания о полном feature parity между EPUB и PDF beyond current code.

Почему:

- Базовые аннотации и навигация есть, но не все UX-потоки явно совпадают один в один.
- В product overview лучше описывать только то, что реально видно в текущем UI и store logic.

Статус: `ambiguous`

### Аннотации и заметки

#### Подтверждённые shipped возможности

- Highlights с пятью цветами.
- Изменение цвета существующего highlight.
- Удаление highlight.
- Text note по выделенному тексту.
- Sticky note на текущую страницу.
- Боковая панель аннотаций с вкладками `всё / хайлайты / заметки / стикеры`.
- Переход из панели аннотаций к месту в книге.
- Работа аннотаций как в EPUB, так и в PDF.

Подтверждения:

- `Reader/Features/Annotations/HighlightsStore.swift`
- `Reader/Features/Annotations/TextNotesStore.swift`
- `Reader/Features/Annotations/StickyNotesStore.swift`
- `Reader/Features/Annotations/AnnotationPanelView.swift`
- `Reader/Features/PDFReader/PDFReaderStore.swift`
- профильные тесты по highlights/notes/panel

Статус: `shipped`

#### Что нельзя заявлять как shipped

- Теги, цветовые фильтры по всей библиотеке, поиски по содержимому аннотаций.

Основание:

- Это фигурирует в ранних docs как roadmap, но не подтверждается текущим UI.

Статус: `planned`

### Импорт и экспорт аннотаций

#### Подтверждённые shipped возможности

- Экспорт аннотаций текущей книги из reader view.
- Массовый экспорт аннотаций по всей библиотеке.
- Экспорт в Markdown exchange format.
- Импорт Markdown-аннотаций из библиотеки.
- Preview импорта с подсчётом create / update / skip / invalid.
- Сопоставление импортируемых файлов с книгами по `contentHash`.
- Обновление существующих аннотаций по `exchangeId`.

Подтверждения:

- `Reader/Features/Annotations/AnnotationExportService.swift`
- `Reader/Features/Annotations/MarkdownAnnotationEncoder.swift`
- `Reader/Features/Annotations/AnnotationImportPreviewService.swift`
- `Reader/Features/Annotations/AnnotationImportService.swift`
- `Reader/Features/Library/LibraryView.swift`
- commits `7e009d3`, `d2e8659`, `25f495c`

Статус: `shipped`

#### Ambiguous

- Экспорт в plain text или TXT как отдельный пользовательский формат.

Почему:

- В части project/backlog-материалов фигурирует Markdown и TXT.
- В текущем shipped коде подтверждён Markdown encoder и `.md` файлы, но отдельного TXT export flow не видно.

Статус: `ambiguous`

#### Planned

- Постоянный автоматический экспорт в выбранную папку.
- Облачный backup поверх экспортируемых файлов.

Источники:

- GitHub Project issue `#20`

Статус: `planned`

## 3. Что из старых документов уже устарело

### Устаревшие или опасные утверждения

- PRD, где PDF указан как future phase, уже не соответствует `main`.
- Ранние документы, где экспорт аннотаций вынесен в future phase, уже не соответствуют `main`.
- Указания на Readium как текущий движок EPUB не должны использоваться без перепроверки: текущий shipped code показывает собственный bridge-based EPUB path.

Статус этих утверждений: `planned` или `obsolete`, не использовать в финальном overview как факт.

## 4. Сверка с GitHub Project `bon2362/3`

### Что project помог подтвердить как свежие shipped-фичи

- drag-and-drop импорт книг;
- hover/select поведение карточек;
- badge формата книги;
- поиск по библиотеке;
- page jump из page indicator.

### Что project показывает как future / planned

- iCloud sync;
- iPhone-версия;
- настройки отображения EPUB;
- дополнительные форматы;
- группировка библиотеки по прогрессу;
- автоматический регулярный экспорт.

Project использовался только как secondary cross-check. Все shipped-выводы в этом аудите опираются на код и merged commits.

## 5. Итог для финального product overview

### Точно описывать как shipped

- локальная библиотека EPUB/PDF;
- импорт книг через picker и drag-and-drop;
- поиск по библиотеке;
- чтение EPUB;
- чтение PDF;
- highlights, text notes, sticky notes;
- панель аннотаций;
- Markdown export/import аннотаций;
- локальное хранение и восстановление позиции чтения;
- page jump в EPUB и PDF.

### Держать отдельно как future / planned

- iCloud sync;
- iPhone PDF-first MVP;
- настройки внешнего вида чтения;
- дополнительные форматы;
- автоматический фоновый экспорт.

### Не обещать без осторожной формулировки

- TXT export как отдельный shipped режим;
- полное равенство UX между EPUB и PDF по всем деталям;
- любые облачные сценарии;
- любые настройки темы, шрифта и layout.
