# Story OF2.2: Запереть WebView от пользовательских жестов

Status: done (реализовано 2026-04-29)

> Решает проблему **#5** из плана `_bmad-output/reader-iphone-overlay-fixes-2.md` (раздел "Группа 2 — Запереть WebView от пользовательских жестов").

## Story

Как пользователь iPhone-ридера,
я хочу, чтобы WebView не реагировал на pinch-зум, двупальцевый скролл и bounces,
чтобы я не мог случайно сдвинуть/зазумить страницу и увидеть соседние "сырые" страницы или сломать вёрстку.

## Контекст и первопричина

WebView сейчас не закрыт от системных жестов:

- `bounces` и `bouncesZoom` активны → двумя пальцами вверх/вниз/вбок контент сдвигается, видны соседние страницы.
- pinch-recognizer включён → пользователь может зазумить страницу.
- viewport не запрещает user scaling — `maximum-scale=1.0, user-scalable=no` появятся в Группе 1 (1.2), но без UIKit-локов этого недостаточно (accessibility-зум всё ещё может сработать).

## Acceptance Criteria

1. Двумя пальцами вверх/вниз/вбок — контент **не** двигается, не зумится, нет bounce-эффекта.
2. Pinch (два пальца) — масштаб не меняется.
3. Если accessibility/жест каким-то путём ставит `zoomScale != 1.0` — он немедленно возвращается в `1.0` без анимации (страховка).
4. Существующие жесты (тап для меню, edge-tap для пагинации, выделение текста) продолжают работать корректно.

## Tasks / Subtasks

- [ ] **2.1 — Жёстко выключить scroll/zoom в UIKit-слое** (AC: 1, 2)
  - [ ] В `IPhoneEPUBWebView.swift` после `webView.scrollView.isScrollEnabled = false` добавить:
    - `webView.scrollView.bounces = false`
    - `webView.scrollView.bouncesZoom = false`
    - `webView.scrollView.minimumZoomScale = 1.0`
    - `webView.scrollView.maximumZoomScale = 1.0`
    - `webView.scrollView.pinchGestureRecognizer?.isEnabled = false`
- [ ] **2.2 — `UIScrollViewDelegate`-страховка от accessibility-зум** (AC: 3)
  - [ ] В `Coordinator` добавить соответствие протоколу `UIScrollViewDelegate` (рядом с существующим `UIGestureRecognizerDelegate`).
  - [ ] Реализовать `viewForZooming(in:)` → `nil`.
  - [ ] Реализовать `scrollViewDidZoom(_:)` так, чтобы при `zoomScale != 1.0` вернуть `setZoomScale(1.0, animated: false)` через `DispatchQueue.main.async` (методы `nonisolated`, см. сниппет в плане).
- [ ] **2.3 — Привязать делегат scrollView** (AC: 3)
  - [ ] В `makeUIView` после создания WebView: `webView.scrollView.delegate = context.coordinator`.
- [ ] **2.4 — Проверить, что viewport-meta из Группы 1 содержит локи** (AC: 1, 2)
  - [ ] Убедиться, что после Группы 1 (1.2) viewport-meta содержит `maximum-scale=1.0, user-scalable=no` — это источник логики на стороне HTML.
- [ ] **2.5 — Smoke-тест на устройстве** (AC: 1–4)
  - [ ] Прогнать AC 1–3 руками на iPhone 15.
  - [ ] Проверить, что выделение текста (long-press), tap-to-toggle меню и edge-tap пагинация всё ещё работают.

## Dev Notes

- Точные сниппеты — в плане, раздел "Группа 2".
- В порядке реализации (плановая таблица) Группа 2 идёт после Группы 1.2 — viewport уже содержит `user-scalable=no, maximum-scale=1.0`, не дублировать.
- `nonisolated` на методах делегата — намеренно, согласовано с тем, что `Coordinator` помечен `@MainActor`.
- Не отключать целиком `scrollView.delegate` ради других целей — он нам теперь нужен под делегат.

### References

- `_bmad-output/reader-iphone-overlay-fixes-2.md` — раздел "Группа 2 — Запереть WebView от пользовательских жестов (решает #5)"
- `_bmad-output/reader-iphone-overlay-fixes-2.md` — таблица "Сводная карта проблем", строка #5

### Затронутые файлы

- `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift` — UIKit-локи zoom/pinch/bounces, расширение `Coordinator` через `UIScrollViewDelegate`, привязка делегата в `makeUIView`.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List
