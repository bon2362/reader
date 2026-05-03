# Story OF2.3: Убрать мигание при переходе между главами

Status: done (реализовано 2026-04-29)

> Решает проблему **#6** из плана `_bmad-output/reader-iphone-overlay-fixes-2.md` (раздел "Группа 3 — Убрать мигание при переходе глав").

## Story

Как пользователь, листающий главы EPUB,
я хочу, чтобы переход между главами проходил без белой вспышки и без проблеска "сырой" первой страницы,
чтобы чтение было спокойным и темa выглядела целостно.

## Контекст и первопричина

При переключении главы прозрачный WebView сначала парсит HTML, и только после события `'ready'` JS-инжект применяет тему. Между этими моментами:

- видна белая "стандартная" подложка WebView/EPUB-файла,
- мелькает первая страница без применённых стилей.

Решение трёхслойное:

1. SwiftUI-фон темой кладём **под** WebView — даже если WebView "белый", виден правильный цвет.
2. Скрываем сам WebView до прихода `'ready'` через `opacity` + лёгкий fade-in.
3. Document-start user script делает `html, body { background: transparent !important }` ещё до парсинга — страховка для случая, если основной `setupLayout` запоздает на пару кадров.

## Acceptance Criteria

1. Переход между главами — без белой вспышки.
2. Переход между главами — без проблеска предыдущей или "сырой" следующей страницы (старый контент не виден до полной готовности нового).
3. Появление новой главы выглядит мягким fade-in (~120 ms), без рывка.
4. Все темы (light, sepia, dark, auto) дают корректный фон-подложку — белого/чёрного "не той" темы не видно.
5. Регрессии: первая загрузка книги (cold start) тоже выглядит корректно — не "белый кадр + контент".

## Tasks / Subtasks

- [ ] **3.1 — `themeBackgroundColor` в Store** (AC: 1, 4)
  - [ ] В `IPhoneEPUBReaderStore.swift` добавить computed property `themeBackgroundColor: Color` с маппингом для `.light` (`#faf8f4`), `.sepia` (`#f5efe0`), `.dark` (`#1a1a1a`), `.auto` (`Color(UIColor.systemBackground)`). Точные значения — в плане.
- [ ] **3.2 — Слой фона в корневом ZStack** (AC: 1, 4)
  - [ ] В `IPhoneEPUBReaderView.swift` первым слоем корневого `ZStack` поместить `store.themeBackgroundColor.ignoresSafeArea()` — **до** `IPhoneEPUBWebView`.
- [ ] **3.3 — Флаг `isChapterReady` и его сброс/выставление** (AC: 2, 3, 5)
  - [ ] В Store: `@Published var isChapterReady = false`.
  - [ ] Сбрасывать в `false` перед `webView.loadFileURL(...)` (внутри `loadChapter` или эквивалентного места).
  - [ ] В `handleMessage` для `case "ready"` — выставлять в `true`.
- [ ] **3.4 — `.opacity` + fade-in на WebView** (AC: 2, 3)
  - [ ] В `IPhoneEPUBReaderView.swift` к `IPhoneEPUBWebView(store: store)` добавить:
    - `.opacity(store.isChapterReady ? 1 : 0)`
    - `.animation(.easeIn(duration: 0.12), value: store.isChapterReady)`
    - `.ignoresSafeArea()` (сохранить).
- [ ] **3.5 — Document-start user script (страховка)** (AC: 1)
  - [ ] В `makeUIView` после `viewportScript` добавить `WKUserScript` с `injectionTime: .atDocumentStart`, `forMainFrameOnly: true`, исходник: создать `<style>` `html,body{background:transparent!important;margin:0;padding:0}` и вставить в `document.head || document.documentElement`.
  - [ ] `config.userContentController.addUserScript(earlyStyle)`.
- [ ] **3.6 — Проверка** (AC: 1–5)
  - [ ] Cold start книги, листание next/prev главы по 5–10 раз для каждой темы — никаких белых кадров и проблесков.

## Dev Notes

- Точные сниппеты — в плане, раздел "Группа 3" (3.1–3.3).
- Длительность fade-in (`0.12`) намеренно короткая — чтобы переход не ощущался лагающим.
- `themeBackgroundColor` для `.auto` — `Color(UIColor.systemBackground)`, а **не** жёсткий white/black, чтобы корректно отрабатывать iOS-тему.
- Document-start script кладётся вместе с `viewportScript`, до прочих user-scripts; следить, чтобы порядок добавления `addUserScript` сохранил приоритет (early style сначала).
- Сброс `isChapterReady = false` обязан произойти **до** `loadFileURL`, иначе на кадр-два будет показываться предыдущая глава.

### References

- `_bmad-output/reader-iphone-overlay-fixes-2.md` — раздел "Группа 3 — Убрать мигание при переходе глав (решает #6)"
- `_bmad-output/reader-iphone-overlay-fixes-2.md` — таблица "Сводная карта проблем", строка #6

### Затронутые файлы

- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift` — `themeBackgroundColor`, `@Published var isChapterReady`, сброс/выставление флага в местах загрузки главы и в `handleMessage("ready")`.
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift` — слой `themeBackgroundColor` в корневом `ZStack`, `.opacity` + `.animation` на `IPhoneEPUBWebView`.
- `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift` — document-start `WKUserScript` (`earlyStyle`).

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
