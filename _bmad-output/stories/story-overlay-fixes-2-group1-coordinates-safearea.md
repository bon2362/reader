# Story OF2.1: Координаты и safe area (WebView ↔ SwiftUI)

Status: done (реализовано 2026-04-29)

> Решает проблемы **#1, #2, #3, #4** из плана `_bmad-output/reader-iphone-overlay-fixes-2.md` (раздел "Группа 1 — Координаты и safe area").

## Story

Как пользователь iPhone-ридера на устройстве с Dynamic Island,
я хочу, чтобы фон темы доходил до самых краёв экрана, а UI-элементы (меню, название главы, счётчик страниц, кнопка "…") не залезали под Dynamic Island, статус-бар и home indicator,
чтобы интерфейс выглядел корректно и был кликабелен на iPhone 15.

## Контекст и первопричина

Две связанные проблемы:

1. `webView.scrollView.contentInsetAdjustmentBehavior` по умолчанию `.automatic` — UIKit добавляет инсеты к scrollView, прозрачный WebView "выпускает" SwiftUI-фон в виде белых полос, а JS-координаты (visual viewport) расходятся с физическими координатами SwiftUI на ~59pt.
2. На корневом `ZStack` стоит `.ignoresSafeArea()`, поэтому `.safeAreaPadding(.top/.bottom)` внутри `menuOverlay` читает 0 — иконки ☰, ✕, название главы и счётчик "X / Y" уезжают в Dynamic Island и под home indicator.

Дополнительно — жёсткий `padding: 56px` в `#__reader_wrap` не учитывает safe area, из-за чего кнопка "…" в правом нижнем углу пересекает текст книги.

## Acceptance Criteria

1. Бежевый фон темы (sepia/light/dark) доходит до самого верха и низа экрана, белой полосы сверху нет.
2. При выключенной кастомной теме (auto, light) фон тоже без "дырок" и белых полос.
3. Иконки ☰ и ✕ полностью под Dynamic Island, кликабельны.
4. Название главы не пересекается со временем/батареей в статус-баре.
5. Счётчик страниц "X / Y" располагается над home indicator с заметным отступом.
6. Кнопка "…" не перекрывает текст книги — текст заканчивается выше неё.
7. JS-координаты выделения (events `textSelected`) теперь совпадают с физическими координатами SwiftUI (overlay для color picker встаёт на нужное место — точные кейсы покрывает Группа 4, но рассинхрон ~59pt должен исчезнуть уже здесь).

## Tasks / Subtasks

- [ ] **1.1 — `contentInsetAdjustmentBehavior = .never`** (AC: 1, 2, 7)
  - [ ] В `IPhoneEPUBWebView.swift` после строки `webView.scrollView.isScrollEnabled = false` добавить `webView.scrollView.contentInsetAdjustmentBehavior = .never`.
- [ ] **1.2 — `viewport-fit=cover` + `env(safe-area-inset-*)` для контента** (AC: 3, 4, 5, 6)
  - [ ] В `IPhoneEPUBWebView.swift` в viewport-скрипте (~line 22) обновить обе ветки (`existing.setAttribute(...)` и `meta.content = ...`): добавить `viewport-fit=cover` к meta-viewport (полная строка: `width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover`).
  - [ ] В `setupLayout()` CSS заменить `'#__reader_wrap { padding: 56px 24px;'` на `'#__reader_wrap { padding: calc(env(safe-area-inset-top) + 56px) 24px calc(env(safe-area-inset-bottom) + 56px) 24px;'`.
- [ ] **1.3 — Снять `.ignoresSafeArea()` с корневого ZStack** (AC: 3, 4, 5)
  - [ ] В `IPhoneEPUBReaderView.swift:77` удалить строку `.ignoresSafeArea()` после закрытия корневого `ZStack`.
  - [ ] Убедиться, что внутренние слои уже имеют свой `.ignoresSafeArea()`: `IPhoneEPUBWebView` (line 35), `edgeTapZones` (line 152), `actionTray` (line 260), `tocDrawer` (line 436). Не трогать.
- [ ] **1.4 — Визуальная проверка на iPhone 15** (AC: 1–7)
  - [ ] Прогнать чек-лист из раздела "Acceptance Criteria" на iPhone 15 (Dynamic Island).
  - [ ] Дополнительно проверить, что выделение текста уже становится "ближе" к курсору (полная коррекция — Группа 4).

## Dev Notes

- Точные сниппеты кода — в плане `_bmad-output/reader-iphone-overlay-fixes-2.md`, разделы 1.1, 1.2, 1.3.
- `viewport-fit=cover` обязателен, иначе `env(safe-area-inset-*)` в CSS вернёт 0.
- После 1.1 JS-координаты выделения и SwiftUI-координаты совпадают — это снимает большую часть проблемы #7 даже без Группы 4.
- Если до этого где-то полагались на старое поведение `.automatic` (нет — но проверить glob), это может всплыть. Smoke: прокрутка не должна "проседать".

### References

- `_bmad-output/reader-iphone-overlay-fixes-2.md` — раздел "Группа 1 — Координаты и safe area (решает #1, #2, #3, #4)"
- `_bmad-output/reader-iphone-overlay-fixes-2.md` — таблица "Сводная карта проблем", строки #1–#4
- `_bmad-output/reader-iphone-overlay-fixes-2.md` — раздел "Ключевые файлы"

### Затронутые файлы

- `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift` — `contentInsetAdjustmentBehavior`, viewport meta (`viewport-fit=cover`), `setupLayout` CSS (`env()` padding).
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift:77` — удалить `.ignoresSafeArea()` с корневого `ZStack`.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
