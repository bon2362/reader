# Plan: Reader iPhone — UI & Feature Fixes (14 issues)

## Context

Анализ пользовательских запросов к существующим фичам EPUB-ридера на iPhone.  
Все изменения касаются `ReaderiPhone/` и `Reader/` (shared). Коммитить не нужно до явной просьбы.

---

## Группа 1 — Полноэкранный режим и лишние области (пункты 1, 2, 9)

### Проблема
Ридер открывается через `navigationDestination` (push) — навигационная панель добавляет отступ сверху и даёт белый артефакт. `ignoresSafeArea()` применён только к `IPhoneEPUBWebView`, но не ко всему `IPhoneEPUBReaderView`.

### Правки

**`ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`**
- Добавить `.toolbar(.hidden, for: .navigationBar)` на корневой `ZStack`
- Добавить `.ignoresSafeArea()` на корневой `ZStack` (а не только на WebView внутри)

**Следствие:** пункт 9 (кнопки кажутся огромными) скорее всего устранится сам — контент занимал уменьшенную область, отчего UI казался непропорционально крупным. Если после фикса всё ещё большие — отдельно уменьшить `.font` и padding в toolbar-элементах.

**Библиотека (#14):** аналогично проверить `IPhoneLibraryView.swift` на наличие лишних отступов или нестандартных размеров — предположительно та же причина.

---

## Группа 2 — Оверлей (пункты 3, 4)

### Проблема
Название главы и счётчик показываются в "панелях" с Material-фоном. Нужно: те же элементы по тапу, но без фона.

### Правки

**`ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`**
- Удалить фоновое покрытие (`.background(.ultraThinMaterial)` / `.background(Color...)`) из `menuOverlay` / top bar / bottom bar
- Оставить текст и иконки как floating-элементы прямо на странице
- Отступы сверху и снизу книжного контента (56px padding в JS) обеспечивают зону, которую оверлей не перекрывает — менять padding не нужно
- **Пункт 4:** убрать `.lineLimit(1)` со строки Text(store.chapterTitle) (`IPhoneEPUBReaderView.swift:124`) — разрешить перенос или хотя бы `.lineLimit(2)`

---

## Группа 3 — Выделение текста и хайлайты (пункты 5, 6.1–6.5)

### Архитектура (из кода)
- Выделение: WKWebView JS (`selectionchange` → сообщение `textSelected`)
- Позиционирование панели: `sel.rect.maxY + 8`, clamp к экрану
- Хранилище: GRDB `highlights` таблица, CFI-диапазоны (`cfiStart`/`cfiEnd`)
- Дубликаты: **не проверяются**, можно добавить один и тот же цвет несколько раз
- Редактирование: тап по существующему хайлайту → `highlightTapped` → edit mode
- Заметки к хайлайту: модель `TextNote.highlightId` **есть**, UI **не подключён**

### Правки

**6.1 — Панель перекрывает текст**
- Проверить, в каких координатах `sel.rect` приходит из JS (абсолютные или относительные WebView)
- Убедиться, что конвертация в SwiftUI-координаты (через `GeometryReader`) корректна
- При необходимости скорректировать offset: если `rect.maxY` уже с учётом safe area — добавить `safeAreaInsets.top` при конвертации

**6.2 — Убрать кнопку отмены (крестик)**
- `ReaderiPhone/Features/Reader/IPhoneHighlightColorPicker.swift` — удалить dismiss-кнопку из компонента

**6.3 — Предотвращение дубликатов**
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift` — в `addHighlight()` (~line 267) перед `insertHighlight()` проверить, нет ли уже хайлайта с перекрывающим CFI-диапазоном (та же глава + пересечение offsets)
- Если есть — вместо добавления переключиться в режим обновления цвета

**6.4 — Повторное выделение: показать текущий цвет, поменять или удалить**
- В `handleMessage(.textSelected)` (~line 222 Store) добавить поиск по существующим хайлайтам: есть ли хайлайт, CFI которого покрывает `pendingSelection`?
- Если да — установить `editingHighlightId` и показать picker в edit-режиме с текущим цветом как активным
- Логика кнопок: тап на активный цвет = `deleteHighlight()`, тап на другой = `updateHighlightColor()`

**6.5 — Иконка заметки в панели хайлайта**
- `IPhoneHighlightColorPicker.swift` — добавить кнопку с иконкой `note.text` (или `square.and.pencil`)
- При тапе: сохранить хайлайт (если новый) → открыть форму заметки с `highlightId`
- Форма заметки: использовать существующий механизм `TextNotesStore.addNote(body:highlightId:)`

---

## Группа 4 — Жесты и навигация (пункты 7, 12)

**7 — Смахивание вниз → библиотека**
- `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift` — добавить `UISwipeGestureRecognizer` с `.direction = .down` рядом со swipe left/right (~line 59–74)
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift` — добавить `@Published var requestDismiss = false`; Coordinator в WebView вызывает `store.requestDismiss = true`
- `IPhoneEPUBReaderView.swift` — наблюдать `.onChange(of: store.requestDismiss)` → `dismiss()`

**12 — Тап по счётчику → ввод страницы**
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift` — обернуть Text счётчика в Button
- По тапу: показать `TextField` с числовой клавиатурой поверх страницы
- Логика навигации (после внедрения #13): принять глобальный номер страницы → вычислить главу и offset → `store.goToGlobalPage(n)`

---

## Группа 5 — Текст книги (пункты 8, 13)

**8 — Убрать выравнивание по ширине**
- `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift:148` — заменить `text-align: justify` на `text-align: start`

**13 — Сквозная нумерация (подход: фоновый рендеринг)**

Пользователь подтвердил: хочет точный подсчёт, как в Apple Books (нумерация меняется при изменении шрифта — ок).

**Алгоритм:**
1. При открытии книги запустить фоновую задачу `calcBookPages()`
2. Для каждой главы: загрузить её HTML в скрытый `WKWebView` (тот же JS), дождаться `pagesReady`-сообщения с `totalInChapter`, сохранить результат в массив `[Int]` (страниц на главу)
3. Кэшировать в SQLite (или файловый кэш) с ключом `bookId + fontSize + screenWidth` — **не UserDefaults**: данные могут быть большими (200+ глав)
4. Пока идёт подсчёт — показывать "Гл. 2 · 6 / 117" (прежний формат), после готовности заменить на сквозную "42 / 1230"
5. При смене размера шрифта — инвалидировать кэш и пересчитать

**Файлы:**
- Новый `BookPageCalculator.swift` в `ReaderiPhone/Features/Reader/`
- `IPhoneEPUBReaderStore.swift` — добавить `globalPage`, `totalBookPages`, запускать калькулятор при `loadBook()`
- `IPhoneEPUBReaderView.swift` — обновить Text счётчика

---

## Группа 6 — Поиск по всей книге (пункт 10)

### Проблема
`store.search()` вызывает `webView.evaluateJavaScript()` — ищет только в DOM текущей главы.

### Подход: Swift-side поиск по сырому тексту глав
1. EPUB-главы — HTML-файлы. Использовать существующий `EPUBBook.htmlTextContent(_ html: String)` (`Reader/Features/Reader/EPUBBook.swift:55`) — стриппит теги, возвращает строку. **Новый метод не нужен.**
2. Поиск: итерация по всем главам, накапливание результатов с `(chapterIndex, charOffset, snippet)`
3. Переход по результату: если другая глава — `store.loadChapter(at:)`, затем JS `scrollToOffset()` — **перед реализацией проверить наличие этой функции в JS ридера**; если нет — использовать существующий механизм перехода по offset-якорю
4. UI: `IPhoneReaderSearchView.swift` — убрать плейсхолдер "в текущей главе", показывать главу в результате

---

## Группа 7 — Заметка к странице (пункт 11)

- Добавить кнопку в bottom menu (рядом с поиском/настройками) с иконкой `note.text.badge.plus`
- По тапу: sheet с `TextEditor` для ввода заметки
- Сохранение: `TextNotesStore.addNote(body:highlightId: nil)` с `cfiAnchor` в **offset-формате** (`EPUBBook.makeOffsetAnchor(href:offset:)`) — **не page-формат**, иначе якорь сдвигается при смене шрифта

---

## Порядок реализации

| # | Группа | Сложность | Риск |
|---|--------|-----------|------|
| 1 | Полный экран + белый артефакт (#1,#2) | Низкая | Низкий |
| 2 | Убрать justification (#8) | Низкая | Нет |
| 3 | Название главы без обрезки (#4) | Низкая | Нет |
| 4 | Оверлей без фона (#3) | Средняя | Низкий |
| 5 | Жест вниз (#7) | Низкая | Низкий |
| 6 | Убрать кнопку крестика (#6.2) | Низкая | Нет |
| 7 | Позиция панели хайлайта (#6.1) | Средняя | Низкий |
| 8 | Дубликаты и повторное выделение (#6.3, #6.4) | Средняя | Средний |
| 9 | Иконка заметки в панели (#6.5) | Средняя | Низкий |
| 10 | Заметка к странице (#11) | Средняя | Низкий |
| 11 | Выделение текста (#5) | Средняя | Средний |
| 12 | Поиск по всей книге (#10) | Высокая | Средний |
| 13 | Сквозная нумерация (#13) | Высокая | Средний |
| 14 | Тап по счётчику (#12) ⚠️ зависит от #13 | Средняя | Низкий |

---

## Проверка (верификация)

- [ ] Ридер открывается на весь экран, нет чёрных полос и белого артефакта
- [ ] Название главы отображается полностью
- [ ] Текст не выровнен по ширине
- [ ] Тап по экрану показывает иконки/текст без фоновых панелей
- [ ] Смахивание вниз → возврат в библиотеку
- [ ] Выделение текста → появляется стандартный iOS handle, затем панель хайлайта под выделением
- [ ] Панель хайлайта: нет крестика, не перекрывает выделение
- [ ] Повторное выделение хайлайта → показан активный цвет; тап = удалить; другой цвет = перекрасить
- [ ] Нет дублей одного цвета на одном фрагменте
- [ ] Поиск — результаты из всех глав
- [ ] Счётчик показывает сквозные страницы; тап → ввод номера → переход
- [ ] Заметка к странице добавляется через меню

---

## Ключевые файлы

- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift` — overlay, counter, layout
- `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift` — JS CSS, gestures
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift` — state, highlight logic
- `ReaderiPhone/Features/Reader/IPhoneHighlightColorPicker.swift` — picker UI
- `ReaderiPhone/Features/Reader/IPhoneReaderSearchView.swift` — search UI
- `ReaderiPhone/Features/Library/IPhoneLibraryView.swift` — library layout
- `Reader/Features/Annotations/AnnotationRepository.swift` — DB ops
- `Reader/Database/Models/TextNote.swift` — note model
- *(новый)* `ReaderiPhone/Features/Reader/BookPageCalculator.swift`
