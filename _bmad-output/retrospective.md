# slow reader — итоги разработки

**Дата:** 20.04.2026
**Платформа:** macOS 14+, Swift 6, SwiftUI, WKWebView, GRDB/SQLite

---

## 1. Реализованные фичи

### 1.1 Для читателя (простым языком)

**Библиотека**
- Добавление EPUB-книг через обычный диалог выбора файла.
- Список книг с обложкой, названием, автором и процентом прочитанного.
- Удаление книги из библиотеки.
- Когда открываешь книгу — сразу на той же странице, где закрыл в прошлый раз.

**Чтение**
- Постраничный режим (как в бумажной книге), без бесконечной прокрутки.
- Листать можно: стрелками ←/→, клавишей пробел (вперёд), кликом по левому/правому краю страницы.
- Сверху — тонкая полоса с названием текущей главы.
- Снизу — «стр. X из Y» по всей книге, а не внутри главы.
- Маленькие кнопки по углам: назад в библиотеку, оглавление, поиск, аннотации, добавить sticky-заметку. Все подсвечиваются при наведении мыши.
- Сноски и внутренние ссылки: клик — перенос к месту, появляется кнопка «вернуться назад».

**Оглавление**
- Боковая панель со всеми главами книги.
- Клик по главе — переход. Текущая глава подсвечена.

**Поиск**
- Cmd+F — открывается поиск по всей книге.
- Показывает сниппет с подсвеченным словом.
- Запоминает последние 10 запросов (список «Недавние»), можно очистить.

**Выделение и заметки**
- Выделил текст мышкой — рядом появляется плашка с 5 цветами (жёлтый, красный, зелёный, синий, фиолетовый) и кнопкой «заметка».
- Хайлайт накладывается на текст сразу, сохраняется навсегда.
- Клик по существующему хайлайту — можно поменять цвет или удалить.
- Заметка к тексту (type A): пишешь свой комментарий, подчёркнутое слово в тексте помечается пунктиром. Клик по нему — всплывает карточка с твоим комментарием.
- Sticky-заметка к странице (type B): Cmd+Shift+N или кнопка — появляется жёлтый стикер в правом поле, привязан к конкретной странице.

**Панель аннотаций**
- Отдельная панель справа: все хайлайты, заметки и стикеры из книги в одном списке.
- 4 вкладки: всё / хайлайты / заметки / стикеры.
- Клик по элементу — переход на соответствующую страницу.

**Хранение**
- Всё сохраняется мгновенно в локальную базу `~/Library/Application Support/Reader/reader.sqlite`.
- Нумерация страниц считается один раз при первом открытии книги и кэшируется — потом открывается сразу.

---

### 1.2 Техническая сводка

**Архитектура**
- `NativeEPUBWebView` (NSViewRepresentable) содержит два `WKWebView`: основной + offscreen preflight для измерения страниц глав.
- `NativeEPUBBridge` (EPUBBridgeProtocol) — владеет WKScriptMessageHandler для `window.webkit.messageHandlers.native`, делает `evaluateJavaScript` в обратную сторону.
- `EPUBBookLoader` — нативный Swift-парсер EPUB (ZIPFoundation → распаковка в tmp + чтение `container.xml` → `content.opf` → spine → TOC из NCX/NAV).
- SPA-слой без iframe: каждая глава грузится через `loadFileURL(chapterURL, allowingReadAccessTo: rootDir)` — это разрешает file://-based ресурсы и даёт нативное text selection.

**Пагинация**
- CSS columns: `#__reader_wrap { column-width: calc(100vw - 128px); column-gap: 128px; column-fill: auto; height: 100vh; width: 100vw; }` + padding `48px 64px`.
- Перелистывание: `__wrap.style.transform = translateX(-page * window.innerWidth)` — без `window.scrollTo`.
- Страница считается через `Math.ceil(wrap.scrollWidth / window.innerWidth)`.

**Навигация**
- Клавиатура: SwiftUI `.onKeyPress(.leftArrow/.rightArrow/.space)` + JS `keydown` на document (purpose: работает даже когда фокус на iframe-подобных элементах).
- Внутренние ссылки: JS `click` handler делает `preventDefault` на любом `<a href>`, постит `linkTapped` в bridge. Bridge различает `#anchor` (scrollIntoView + вычисление страницы из `getBoundingClientRect`), относительные пути (резолвинг через `resolveRelativeHref`) и пушит source-позицию в `navStack` для возврата.

**Аннотации**
- Хайлайты: сохранение offset-range внутри нормализованного текста главы (`TreeWalker` по `NodeFilter.SHOW_TEXT`) вместо EPUB CFI — стандартный CFI оказался избыточно сложен, свой формат `"href|offset"` решает задачу якоря.
- Text notes (type A): подчёркивание через `<mark class="reader-note">` с `border-bottom: 2px dashed`. Клик на mark — popover со всплывающим `TextNotePopoverOverlay`.
- Sticky notes (type B): привязаны к `(spineIndex, pageInChapter)` — не ко всей главе. Колонка `page_in_chapter` добавлена Migration_003.
- JS-методы bridge: `applyHighlights` (replace-all для загрузки), `addHighlight` (single, сохраняет существующие), `applyNotes/addNote`, `removeHighlight`, `goToAnchor(id)`.

**Page counting**
- Offscreen preflight WKWebView: позиционирован на +10 000 px от контейнера (`masksToBounds = true` на CALayer → клиппинг), чтобы иметь реальный layout, но не просвечивать. Последовательно грузит каждую главу, считывает `pageChanged`, сохраняет в `chapterPageCounts: [Int]`.
- Кэш: `Migration_004` добавил `chapter_page_counts` TEXT-колонку (JSON-строка) в `books`. Перед `loadBook` bridge получает `setCachedChapterPageCounts(_:)`; если размер кэша = число глав — preflight пропускается, `preflightComplete = true`.
- Persist: `bridgeDidFinishPageCountPreflight(counts:)` → `LibraryRepository.updateChapterPageCountsCache(id:counts:)`.

**Поиск**
- `SearchStore` с debounce 300ms, `recent: [String]` в `UserDefaults` (ключ `reader.recentSearches`, лимит 10). Commit в историю — на `selectResult`.

**База данных**
- GRDB 7.10 + DatabasePool + WAL. Миграции через `DatabaseMigrator`:
  - `Migration_001`: таблицы books/highlights/text_notes/page_notes.
  - `Migration_002`: поля для range CFI (`cfi_start`/`cfi_end`).
  - `Migration_003`: `page_notes.page_in_chapter`.
  - `Migration_004`: `books.chapter_page_counts`.

**UI**
- `ChapterHeaderBar` — постоянная строка-заголовок, часть layout (не overlay), webview сдвигается вниз → больше нет перекрытия текста.
- `FloatingIconButton` — кружки на `ultraThinMaterial` с `HoverLift` modifier (scale 1.12 + opacity 0.75→1.0).
- `HighlightColorPicker` позиционируется через `.position()` по координатам `rng.getClientRects().last` с клампингом к границам и flip вверх, если близко к низу.
- Dismiss пикера — через JS `selectionchange` event → `selectionCleared` → `HighlightsStore.onSelectionCleared()`.

**Состояние и Observation**
- `@Observable` @MainActor сторы: `ReaderStore`, `LibraryStore`, `TOCStore`, `SearchStore`, `HighlightsStore`, `TextNotesStore`, `StickyNotesStore`, `AnnotationPanelStore`.
- Все стораджи (`AnnotationRepository`, `LibraryRepository`) — `Sendable` протоколы с async-методами.

**Статистика кода**
- 49 Swift-файлов в `Reader/`.
- 4 миграции БД.
- 1 inline JS-слой (~400 строк) в `NativeEPUBWebView.readerJS`.

---

## 2. Проблемы и решения

### 2.1 Отказ от epub.js → нативный парсер

**Проблема.** По плану (PRD v1) движок рендеринга — сначала epub.js в iframe, потом Readium Swift Toolkit. В процессе реализации:
- epub.js в iframe ломает нативное text selection в macOS WKWebView (изоляция origin).
- Readium-toolkit требует непростую интеграцию, подтягивает большие deps, плохо работает с кастомной пагинацией.

**Решение.** Написал собственный минимальный EPUB-парсер (`EPUBBookLoader`): ZIPFoundation распаковывает архив в tmp-папку, читает `META-INF/container.xml`, `content.opf` (spine + manifest), TOC из NCX/NAV. Каждая глава — отдельный HTML-файл на диске. Рендеринг: один WKWebView без iframe, `loadFileURL` с доступом к корню книги. Плюсы: нативное выделение, полный контроль над CSS columns, никаких внешних JS-зависимостей.

### 2.2 Пагинация останавливалась через несколько страниц

**Проблема.** Использовал `overflow: hidden` на `html/body` вместе с `window.scrollTo(page * width, 0)` — через 3-5 страниц `scrollTo` переставал работать, страница залипала.

**Решение.** Убрал scroll полностью. Добавил внутренний `<div id="__reader_wrap">`, на нём `transform: translateX(-page * pageSize)`. Transform-based пагинация не зависит от scroll-контейнера, работает детерминированно.

### 2.3 Неровное выравнивание текста в колонках

**Проблема.** Текст в колонках выглядел «прыгающим» — правый край каждой страницы не совпадал.

**Причина.** `padding: 64px` на wrap + `column-gap: 64px` даёт шаг колонки = `100vw - 64` (из-за padding), но `translateX` сдвигает на `100vw`. Рассинхрон → текст съезжал на пару пикселей.

**Решение.** `column-gap: 128px` (= 2 × padding). Теперь шаг колонки строго равен ширине viewport, transform совпадает.

### 2.4 Счётчик показывал неправильные «главы»

**Проблема.** PageIndicator показывал «гл. 7 из 486» — но по факту это была глава 2, а 486 — количество spine items (технических секций из content.opf), не визуальных глав.

**Решение.** Полностью убрал chapter-число из индикатора. Оставил только «стр. X из Y» по всей книге.

### 2.5 Хайлайты пропадали при повторном выделении

**Проблема.** Сделал первое выделение → хайлайт жёлтым. Сделал второе → первый хайлайт исчезает, остаётся только второй.

**Причина.** `applyOneJS` под капотом вызывал `applyHighlights([h])`, который перед применением чистил ВСЕ существующие `mark.reader-hl`.

**Решение.** Добавил отдельный JS-метод `addHighlight(h)` — он удаляет только `mark` с тем же `data-hl-id` (если перезапись) и применяет новый, не трогая остальные. `applyHighlights` остался для bulk-загрузки при открытии книги.

### 2.6 Sticky note показывала неверный номер страницы

**Проблема.** На любой странице при добавлении sticky note подпись писала «страница 7» (или другое фиксированное число).

**Причина.** Label использовал `spineIndex + 1` — это номер главы (spine item), а не страницы.

**Решение.** Изменил формат на «Гл. X · стр. Y», где Y — `pageInChapter + 1`. Одновременно добавил Migration_003 с колонкой `page_in_chapter`, чтобы sticky привязывалась к конкретной странице внутри главы.

### 2.7 Нумерация страниц только внутри главы → сквозная

**Проблема.** «стр. X из Y» показывало номера внутри текущей главы — непонятно, насколько близко конец книги.

**Решение.** Offscreen preflight WKWebView измеряет количество страниц каждой главы при первой загрузке. `chapterPageCounts: [Int]` → `current = prefix.sum() + pageInChapter + 1`, `total = counts.sum()`. Счётчик теперь реальный по всей книге.

### 2.8 Preflight просвечивал контент и оставлял залипший текст

**Проблема.** Offscreen-WKWebView изначально лежал «под» основным (`positioned: .below`) с alphaValue=1. Во время подсчёта страниц пользователь видел мелькание всех глав с наложенной обложкой. После завершения preflight его содержимое (например «454 Стругацкий А.Н., Указ. соч. С. 120…») залипало поверх каждой страницы. Попытка alphaValue=0 или isHidden=true ломала layout — WKWebView не рендерит невидимые view, preflight перестаёт работать.

**Решение двухходовое:**
1. Позиционирую preflight на `+10 000 px` от контейнера по leading через AutoLayout (с explicit widthAnchor/heightAnchor = container) → layout работает, контент реально рендерится.
2. `container.layer?.masksToBounds = true` → всё, что выходит за границы контейнера, клиппится CoreAnimation-ом.
3. Плюс после завершения preflight `preflightView.loadHTMLString("<html><body></body></html>", baseURL: nil)` — дополнительная страховка от остаточной отрисовки.

### 2.9 Верхняя панель перекрывала текст

**Проблема.** `ReaderToolbar` был overlay поверх webview, высотой ~40pt. CSS padding текста всего 48px сверху → тулбар накрывал первую строку. Показ/скрытие по movement не помогало.

**Решение.** Кардинально пересобрал UI:
- Большая тулбар-панель удалена.
- `ChapterHeaderBar` — тонкая (24pt) постоянная строка с названием главы, внутри `VStack` (не overlay) → webview честно сдвигается вниз, перекрытия нет.
- Кнопки действий — маленькие `FloatingIconButton` в углах (кружки на `ultraThinMaterial`), всегда видимые, с hover-лифтом. Большая панель не нужна.
- Книги название убрано (видно в заголовке окна).

### 2.10 Пикер цвета внизу экрана

**Проблема.** `HighlightColorPicker` был прибит к низу страницы. Курсор-то у выделенного слова, а пикер — где-то внизу. Неудобно.

**Решение.** JS шлёт `rng.getClientRects()` в `textSelected`. Bridge → `HighlightsStore.pendingSelection.rect`. Вьюха позиционируется через `.position(x: rect.midX, y: rect.maxY + 24)` с клампингом к границам viewport и flip-ом вверх, если близко к низу. Ещё убрал превью выделенного текста (избыточно — сам текст выделен) и крестик закрытия (закрывается автоматически при снятии выделения через `selectionchange` → `selectionCleared`).

### 2.11 Возврат по сноскам

**Проблема.** Клик по сноске уводил к пункту назначения, вернуться обратно было невозможно.

**Решение.** JS click handler перехватывает `<a href>` с `preventDefault`, посылает `linkTapped`. Bridge:
- Хэш-ссылка (`#fn1`) — `getElementById → getBoundingClientRect → goToPage`.
- Относительный путь — резолв относительно текущей главы, смена главы, применение anchor после onReady.
- Текущая позиция (глава + страница) пушится в `navStack` → появляется кнопка `arrow.uturn.backward`, клик возвращает.

### 2.12 Подсчёт страниц при каждом открытии

**Проблема.** Preflight работает 30-60 секунд на большой книге — повторять его каждый раз при открытии избыточно.

**Решение.** `Migration_004` добавил JSON-колонку `chapter_page_counts` в `books`. После первого preflight счётчики сохраняются. При повторном открытии — если размер кэша совпадает с количеством глав, preflight пропускается полностью, `isPageCountReady = true` сразу.

### 2.13 Потерянные пакеты SPM после `rm -rf DerivedData`

**Проблема.** Ручная чистка DerivedData для сброса имени приложения стёрла распакованные GRDB и ZIPFoundation — Xcode показал «Missing package product».

**Решение.** `xcodebuild -resolvePackageDependencies` переустанавливает пакеты. (Нюанс: failed clone subsubmodule'а требует повторного запуска после первой неудачи.)

### 2.14 Имя приложения «Reader» → «slow reader»

**Проблема.** `PRODUCT_NAME = $(TARGET_NAME) = "Reader"`. Менять напрямую — риск сломать code-signing и пути в проекте.

**Решение.** Оставил `PRODUCT_NAME` и bundle id неизменными. Добавил `INFOPLIST_KEY_CFBundleDisplayName = "slow reader"` и `INFOPLIST_KEY_CFBundleName = "slow reader"` в Debug/Release-конфиги. Эти ключи управляют отображаемым именем в Finder/Dock/меню, не трогая подпись.

### 2.15 Прочие мелочи
- Text selection issue в iframe → решено отказом от iframe (см. 2.1).
- При `@MainActor` + WKScriptMessageHandler-у-`@unchecked Sendable` пришлось обернуть в `Task { @MainActor in ... }` для маршрутизации сообщений.
- Невозможность опросить `drawsBackground` WKWebView напрямую в Swift — пришлось через KVC (`setValue(false, forKey: "drawsBackground")`).
- Фокус на SwiftUI-вьюхе для onKeyPress — через `@FocusState` + `.focusable().focusEffectDisabled()` + `onAppear { isFocused = true }`.

---

## 3. Отличия от изначального плана

| Область | План (PRD) | Факт |
|---|---|---|
| EPUB-движок | epub.js → Readium | Свой нативный парсер на Swift + ZIPFoundation |
| Текст selection | Через iframe с epub.js | Single-webview, loadFileURL без iframe |
| CFI-якоря | Стандартный EPUB CFI | Упрощённый формат `href|offset` |
| Тулбар | Большая панель, auto-hide | Тонкий header + floating icon-кнопки |
| Пагинация | Через epub.js API | Нативные CSS columns + transform |
| Подсчёт страниц | Не планировался | Offscreen preflight + кэш в БД |
| Возврат по сноскам | Не в плане | Nav-stack + кнопка «назад» |
| Recent searches | Не в плане | `UserDefaults`, последние 10 |
| Имя приложения | Reader | slow reader |

---

## 4. Что не делали / отложено

- Readium Swift Toolkit — отложено ради нативной реализации.
- iPhone-версия — по плану Фаза 2.
- iCloud sync — по плану Фаза 2.
- PDF — пока только EPUB.
- Экспорт аннотаций (markdown/txt) — по плану Фаза 2.
- Горячие клавиши для смены цвета хайлайта — не в MVP.
- Тема/шрифты/размер текста — не в MVP.
