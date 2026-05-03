# Story OF2.4: Размещение color picker над/под выделением

Status: done (реализовано 2026-04-29)

> Решает проблему **#7** из плана `_bmad-output/reader-iphone-overlay-fixes-2.md` (раздел "Группа 4 — Color picker над выделением").

## Story

Как пользователь, выделяющий текст в EPUB-ридере,
я хочу, чтобы color picker аннотации появлялся под последней строкой выделения, а если места снизу не хватает — над **первой** строкой выделения, не перекрывая выделенный текст и не уезжая под Dynamic Island/home indicator,
чтобы я видел и текст, и панель цветов одновременно.

## Контекст и первопричина

Две связанные проблемы:

1. JS присылал координаты visual viewport, а SwiftUI overlay живёт в физических координатах — рассинхрон ~59pt. **Эта часть решается автоматически после Группы 1.1** (`contentInsetAdjustmentBehavior = .never`), но эта стори всё равно зависит от Группы 1.
2. Для placement above SwiftUI использовал `lastRect` (низ выделения) вместо `firstRect` (верх) — для многострочных выделений picker оказывался **внутри** выделения.

Решение: JS присылает оба rect (`firstRect` для верха, `lastRect` для низа), Store расширяет `EPUBTextSelection`, overlay использует `firstRect.minY` для расчёта позиции выше и `lastRect.maxY` для позиции ниже, плюс clamp по `safeAreaInsets`.

## Acceptance Criteria

1. Выделение одной строки — picker появляется под выделением с зазором (gap = 10pt).
2. Выделение многострочное (5+ строк) с местом снизу — picker под последней строкой выделения.
3. Выделение многострочное у нижнего края экрана — picker над **первой** строкой выделения, не внутри выделения и не перекрывая последние строки.
4. Выделение текста у самого верха экрана — picker не заходит под Dynamic Island (учитывает `safeAreaInsets.top + 8`).
5. Выделение текста у самого низа — picker не уходит под home indicator (учитывает `safeAreaInsets.bottom + 8`).
6. Гигантское выделение (почти весь экран) — picker встаёт по вертикальному центру, не вылезая за safe area.
7. Обратная совместимость: если JS по какой-то причине не пришлёт `firstRect` (старый код / сетевой race) — fallback `firstRect = rect`, picker не падает.

## Tasks / Subtasks

- [ ] **4.1 — JS шлёт `firstRect` + `lastRect`** (AC: 2, 3)
  - [ ] В `IPhoneEPUBWebView.swift` в `selectionchange` (~line 558) получать `var rects = rng.getClientRects();`.
  - [ ] Если `rects.length > 0`: `firstRect = { x, y, w, h }` из `rects[0]`, `lastRect = { x, y, w, h }` из `rects[rects.length - 1]`.
  - [ ] В `post(...)` отправлять обе координаты: `rect: lastRect` (обратная совместимость), `firstRect: firstRect` (новое поле).
- [ ] **4.2 — Расширить `EPUBTextSelection` в Store** (AC: 7)
  - [ ] В `IPhoneEPUBReaderStore.swift` добавить поле `let firstRect: CGRect` к struct `EPUBTextSelection` (рядом с `rect`).
  - [ ] В `handleMessage("textSelected")` парсить `firstRect` так же, как `rect`.
  - [ ] Если `firstRect` отсутствует в payload → `firstRect = rect` (fallback для одной строки и для старых сообщений).
- [ ] **4.3 — Overlay использует `firstRect` для placement above + safe area для clamp** (AC: 1–6)
  - [ ] В `IPhoneEPUBReaderView.swift`, `highlightPickerOverlay(for:)` (~line 305), внутри `GeometryReader { geo in ... }`:
    - `let pickerHeight: CGFloat = 52`, `let gap: CGFloat = 10`.
    - `let safeTop = geo.safeAreaInsets.top + 8`, `let safeBottom = geo.safeAreaInsets.bottom + 8`.
    - `let bottomY = sel.rect.maxY + gap`.
    - `let topY = sel.firstRect.minY - pickerHeight - gap`.
    - `let canFitBelow = bottomY + pickerHeight <= geo.size.height - safeBottom`.
    - `let canFitAbove = topY >= safeTop`.
    - `unclampedY` = `bottomY` если `canFitBelow`, иначе `topY` если `canFitAbove`, иначе `(geo.size.height - pickerHeight) / 2` (центр).
    - Финальный `clampedY = min(max(safeTop, unclampedY), geo.size.height - pickerHeight - safeBottom)`.
  - [ ] Остальная горизонтальная логика — без изменений.
- [ ] **4.4 — Smoke на iPhone 15** (AC: 1–7)
  - [ ] Покрыть все 6 AC ручным тестом.
  - [ ] Дополнительно проверить, что после применения цвета picker корректно скрывается.

## Dev Notes

- **Зависимость:** Story OF2.1 (Группа 1) **должна быть смерджена раньше** — без `contentInsetAdjustmentBehavior = .never` JS-координаты разъедутся с SwiftUI и `clampedY` будет считать неверно.
- Точные сниппеты — в плане, раздел "Группа 4" (4.1, 4.2, 4.3).
- Имена полей в JSON-сообщении (`firstRect`, `rect`) сохранены для обратной совместимости — старые билды macOS-companion / другие потребители не сломаются.
- Fallback `firstRect = rect` критичен: иначе single-line выделение упадёт на nil/decode-error.
- `pickerHeight = 52`, `gap = 10`, `safeTop offset = 8`, `safeBottom offset = 8` — параметры из плана. Не подбирать заново.

### References

- `_bmad-output/reader-iphone-overlay-fixes-2.md` — раздел "Группа 4 — Color picker над выделением (решает #7)"
- `_bmad-output/reader-iphone-overlay-fixes-2.md` — таблица "Сводная карта проблем", строка #7
- Story `OF2.1` (`story-overlay-fixes-2-group1-coordinates-safearea.md`) — обязательная зависимость.

### Затронутые файлы

- `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift` — JS `selectionchange` шлёт `firstRect` + `lastRect`.
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift` — расширить `EPUBTextSelection.firstRect`, парсить `firstRect` в `handleMessage("textSelected")` (с fallback на `rect`).
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift` — `highlightPickerOverlay(for:)` использует `firstRect`/`lastRect` + `safeAreaInsets` для clamp.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
