# Plan: Reader iPhone — Overlay & WebView Fixes (round 2, 7 issues)

**Status:** Реализовано 2026-04-29

## Context

Вторая порция фиксов после `bmad-help-unified-clarke.md`. Все 7 проблем выявлены при ручном тесте на iPhone 15 (Dynamic Island) и сводятся к двум корневым причинам:

1. **Рассинхрон координат WebView ↔ SwiftUI** — `contentInsetAdjustmentBehavior` по умолчанию `.automatic`, plus `.ignoresSafeArea()` на корневом ZStack обнуляет safe area для дочерних `.safeAreaPadding(...)`
2. **WebView не закрыт от системных жестов и переходов** — pinch, bounces, content inset, тема через JS post-factum

Минимальный набор правок (#1, #2, #5, #6) визуально решает большинство кейсов; #4 и #7 — полировка многострочных и edge-сценариев.

---

## Сводная карта проблем

| # | Симптом | Корневая причина |
|---|---------|------------------|
| 1 | Белая полоса сверху, бежевый не доходит до краёв | `contentInsetAdjustmentBehavior = .automatic` инсетит контент scrollView, прозрачный WebView показывает SwiftUI-фон в "хвостах" |
| 2 | Иконки меню (☰, ✕, название главы) внутри Dynamic Island, нечитаемо | `.ignoresSafeArea()` на корневом ZStack → `.safeAreaPadding(.top)` читает 0 |
| 3 | Каунтер страниц "1 / 55" у самого края, под home indicator | То же, что #2, но снизу |
| 4 | Кнопка "…" в правом нижнем углу пересекает текст книги | Жёсткий `padding: 56px` в `__reader_wrap` не учитывает safe area + место под плавающие кнопки меню |
| 5 | Жест "два пальца вверх/вниз" сдвигает контент, видны соседние страницы | Pinch не отключён, `bounces`/`bouncesZoom` активны, viewport не заперт |
| 6 | При переходе между главами — белая вспышка с проблеском первой страницы | Прозрачный WebView + тема применяется через JS после `'ready'`, между парсингом HTML и применением стилей виден "сырой" белый |
| 7 | Color picker аннотации перекрывает выделенный текст | (а) JS шлёт CSS-координаты visual viewport, SwiftUI overlay живёт в физических координатах — рассинхрон ~59pt; (б) для placement above используется last rect (низ выделения) вместо first rect (верх) |

---

## Группа 1 — Координаты и safe area (решает #1, #2, #3, #4)

### 1.1 — `contentInsetAdjustmentBehavior = .never`

**Файл:** `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`

После строки `webView.scrollView.isScrollEnabled = false`:
```swift
webView.scrollView.contentInsetAdjustmentBehavior = .never
```

→ HTML-вьюпорт = весь экран, белые "хвосты" исчезают, JS-координаты теперь совпадают с физическими.

### 1.2 — `viewport-fit=cover` + `env(safe-area-inset-*)` для контента

**Файл:** `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`

В viewport-скрипте (~line 22) обновить обе ветки:
```javascript
existing.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover');
// и в else:
meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
```

В `setupLayout()` CSS заменить:
```javascript
'#__reader_wrap { padding: 56px 24px;'
```
на:
```javascript
'#__reader_wrap { padding: calc(env(safe-area-inset-top) + 56px) 24px calc(env(safe-area-inset-bottom) + 56px) 24px;'
```

→ Контент автоматически отступает от Dynamic Island и home indicator + резервирует место под плавающие кнопки меню.

### 1.3 — Снять `.ignoresSafeArea()` с корневого ZStack

**Файл:** `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift:77`

Удалить строку `.ignoresSafeArea()` после `}` корневого `ZStack`. Внутренние слои уже имеют свой:
- `IPhoneEPUBWebView` (line 35)
- `edgeTapZones` (line 152)
- `actionTray` (line 260)
- `tocDrawer` (line 436)

→ `.safeAreaPadding(.top/.bottom)` в `menuOverlay` начнут отдавать реальные значения; меню само встанет под Dynamic Island и над home indicator.

---

## Группа 2 — Запереть WebView от пользовательских жестов (решает #5)

**Файл:** `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`

После `isScrollEnabled = false` добавить блок:
```swift
webView.scrollView.bounces = false
webView.scrollView.bouncesZoom = false
webView.scrollView.minimumZoomScale = 1.0
webView.scrollView.maximumZoomScale = 1.0
webView.scrollView.pinchGestureRecognizer?.isEnabled = false
```

Дополнительно в `Coordinator` добавить `UIScrollViewDelegate`-методы (страховка от accessibility-зум):
```swift
@MainActor
final class Coordinator: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    // …существующие методы…

    nonisolated func viewForZooming(in scrollView: UIScrollView) -> UIView? { nil }
    nonisolated func scrollViewDidZoom(_ scrollView: UIScrollView) {
        if scrollView.zoomScale != 1.0 {
            DispatchQueue.main.async { scrollView.setZoomScale(1.0, animated: false) }
        }
    }
}
```

И в `makeUIView` после создания WebView:
```swift
webView.scrollView.delegate = context.coordinator
```

`maximum-scale=1.0, user-scalable=no` уже добавлены в viewport-скрипт в Группе 1.

---

## Группа 3 — Убрать мигание при переходе глав (решает #6)

### 3.1 — SwiftUI-фон по теме (убирает белую вспышку)

**Файл:** `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`

Добавить computed property (рядом с прочими themed-полями):
```swift
var themeBackgroundColor: Color {
    switch theme {
    case .light: return Color(red: 0xfa/255.0, green: 0xf8/255.0, blue: 0xf4/255.0)
    case .sepia: return Color(red: 0xf5/255.0, green: 0xef/255.0, blue: 0xe0/255.0)
    case .dark:  return Color(red: 0x1a/255.0, green: 0x1a/255.0, blue: 0x1a/255.0)
    case .auto:  return Color(UIColor.systemBackground)
    }
}
```

**Файл:** `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`

Первым слоем корневого ZStack:
```swift
ZStack {
    store.themeBackgroundColor
        .ignoresSafeArea()
    IPhoneEPUBWebView(store: store)
        .ignoresSafeArea()
    // …
}
```

### 3.2 — Скрывать WebView до `'ready'` (убирает проблеск старой главы)

**Файл:** `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`

Добавить:
```swift
@Published var isChapterReady = false
```

Перед `webView.loadFileURL(...)` (в `loadChapter` / аналогичном месте): сбрасывать в `false`. В `handleMessage` для `case "ready"`: ставить в `true`.

**Файл:** `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`

```swift
IPhoneEPUBWebView(store: store)
    .opacity(store.isChapterReady ? 1 : 0)
    .animation(.easeIn(duration: 0.12), value: store.isChapterReady)
    .ignoresSafeArea()
```

### 3.3 — Document-start стиль (страховка)

**Файл:** `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`

В `makeUIView`, после viewportScript добавить ранний инжект:
```swift
let earlyStyle = WKUserScript(
    source: """
    (function() {
        var s = document.createElement('style');
        s.textContent = 'html,body{background:transparent!important;margin:0;padding:0}';
        var head = document.head || document.documentElement;
        if (head) head.appendChild(s);
    })();
    """,
    injectionTime: .atDocumentStart,
    forMainFrameOnly: true
)
config.userContentController.addUserScript(earlyStyle)
```

→ Body прозрачный с самого начала парсинга; даже если основной `setupLayout` запоздает на кадр-два, белого фона EPUB-файла не будет.

---

## Группа 4 — Color picker над выделением (решает #7)

**Бóльшая часть проблемы #7 уходит автоматически после фикса #1 (Группа 1.1)** — JS-координаты и SwiftUI-overlay-координаты выравниваются. Ниже — полировка для многострочных выделений.

### 4.1 — JS шлёт firstRect + lastRect

**Файл:** `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`

В `selectionchange` (~line 558):
```javascript
var rects = rng.getClientRects();
var firstRect = null, lastRect = null;
if (rects && rects.length > 0) {
    var f = rects[0], l = rects[rects.length - 1];
    firstRect = { x: f.left, y: f.top, w: f.width, h: f.height };
    lastRect  = { x: l.left, y: l.top, w: l.width, h: l.height };
}
post({
    type: 'textSelected',
    startOffset: offs.start, endOffset: offs.end, text: text,
    rect: lastRect,           // обратная совместимость
    firstRect: firstRect      // новое поле
});
```

### 4.2 — Store читает оба rect

**Файл:** `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`

```swift
struct EPUBTextSelection {
    let startOffset: Int
    let endOffset: Int
    let text: String
    let rect: CGRect       // last rect (placement below)
    let firstRect: CGRect  // first rect (placement above)
}
```

В `handleMessage("textSelected")` парсить `firstRect` аналогично `rect`, при отсутствии — `firstRect = rect` (fallback для одной строки).

### 4.3 — Overlay использует firstRect для placement above + safe area для clamp

**Файл:** `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`

В `highlightPickerOverlay(for:)` (~line 305):
```swift
GeometryReader { geo in
    let pickerHeight: CGFloat = 52
    let gap: CGFloat = 10
    let safeTop = geo.safeAreaInsets.top + 8
    let safeBottom = geo.safeAreaInsets.bottom + 8

    let bottomY = sel.rect.maxY + gap
    let topY = sel.firstRect.minY - pickerHeight - gap
    let canFitBelow = bottomY + pickerHeight <= geo.size.height - safeBottom
    let canFitAbove = topY >= safeTop

    let unclampedY: CGFloat = canFitBelow ? bottomY
                            : canFitAbove ? topY
                            : (geo.size.height - pickerHeight) / 2  // центр для гигантских выделений

    let clampedY = min(max(safeTop, unclampedY), geo.size.height - pickerHeight - safeBottom)
    // …остальная логика без изменений…
}
```

→ Picker корректно встаёт ниже последней строки, выше первой строки, либо в центре для редких случаев "выделено почти всё".

---

## Stories

План разбит на 4 BMAD-стори (по группам). Каждая стори self-contained, со своими acceptance criteria, привязкой к этому плану и списком файлов.

| Story ID | Заголовок | Решает | Файл |
|----------|-----------|--------|------|
| **OF2.1** | Координаты и safe area (WebView ↔ SwiftUI) | #1, #2, #3, #4 | [stories/story-overlay-fixes-2-group1-coordinates-safearea.md](stories/story-overlay-fixes-2-group1-coordinates-safearea.md) |
| **OF2.2** | Запереть WebView от пользовательских жестов | #5 | [stories/story-overlay-fixes-2-group2-lock-webview-gestures.md](stories/story-overlay-fixes-2-group2-lock-webview-gestures.md) |
| **OF2.3** | Убрать мигание при переходе между главами | #6 | [stories/story-overlay-fixes-2-group3-chapter-transition-flicker.md](stories/story-overlay-fixes-2-group3-chapter-transition-flicker.md) |
| **OF2.4** | Color picker над выделенным текстом | #7 | [stories/story-overlay-fixes-2-group4-highlight-picker-placement.md](stories/story-overlay-fixes-2-group4-highlight-picker-placement.md) |

**Зависимости:** OF2.4 зависит от OF2.1 (без `contentInsetAdjustmentBehavior = .never` clamp в picker сработает неверно). Остальные стори независимы.

---

## Порядок реализации

| # | Story | Шаг | Сложность | Риск | Решает |
|---|-------|-----|-----------|------|--------|
| 1 | OF2.1 | `contentInsetAdjustmentBehavior = .never` | Низкая | Низкий | #1, частично #7 |
| 2 | OF2.1 | Снять `.ignoresSafeArea()` с корня | Низкая | Низкий | #2, #3 |
| 3 | OF2.2 | Lock zoom/pinch/bounces + viewport meta | Низкая | Низкий | #5 |
| 4 | OF2.1 | `viewport-fit=cover` + `env()` padding | Низкая | Низкий | #4 |
| 5 | OF2.3 | `themeBackgroundColor` + `isChapterReady` | Средняя | Низкий | #6 |
| 6 | OF2.3 | Document-start style script | Низкая | Нет | #6 (страховка) |
| 7 | OF2.4 | First/last rect + safe area clamp | Средняя | Низкий | #7 (полировка) |

Между шагами проверять визуально на iPhone 15 — каждая группа даёт самостоятельный эффект.

---

## Проверка (верификация)

- [ ] Бежевый фон темы доходит до самого верха и низа экрана, белой полосы нет
- [ ] При выключенной теме (auto, light) — фон тоже без "дырок"
- [ ] Иконки ☰ и ✕ полностью под Dynamic Island, кликабельны
- [ ] Название главы не пересекается со временем/батареей в статус-баре
- [ ] Каунтер "X / Y" над home indicator с заметным отступом
- [ ] Кнопка "…" не перекрывает текст книги — текст заканчивается выше неё
- [ ] Двумя пальцами вверх/вниз/вбок — контент **не** двигается, не зумится
- [ ] Pinch — масштаб не меняется
- [ ] Переход между главами — без белой вспышки и без проблеска предыдущей страницы
- [ ] Выделение одной строки — picker появляется под выделением с зазором
- [ ] Выделение многострочное (5+ строк сверху экрана) — picker под выделением
- [ ] Выделение многострочное у нижнего края — picker над **первой** строкой выделения, не внутри
- [ ] Выделение текста у самого верха — picker не заходит под Dynamic Island
- [ ] Выделение текста у самого низа — picker не уходит под home indicator

---

## Ключевые файлы

- [`ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`](ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift) — снять `.ignoresSafeArea()` с корня (line 77), добавить `themeBackgroundColor` слой, `.opacity` на WebView, обновить `highlightPickerOverlay`
- [`ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`](ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift) — `contentInsetAdjustmentBehavior`, scroll/zoom-локи, `viewForZooming` делегат, viewport-meta (`viewport-fit=cover` + `user-scalable=no` + `maximum-scale=1.0`), `setupLayout` CSS (`env()` padding), document-start user script, JS `selectionchange` (firstRect)
- [`ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`](ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift) — `themeBackgroundColor`, `isChapterReady`, расширить `EPUBTextSelection.firstRect`, парсинг `firstRect` в `handleMessage("textSelected")`
