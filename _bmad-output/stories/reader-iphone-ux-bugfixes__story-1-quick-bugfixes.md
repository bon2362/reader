# Story 1: Quick bugfixes для reader overlay, selection handles и chapter fade

Status: ready-for-dev

## Story

Как читатель EPUB на iPhone, я хочу, чтобы мелкие reader-действия не дергались визуально, selection handles оставались управляемыми, а переход между главами не давал пустой вспышки, чтобы чтение ощущалось стабильным и нативным.

## Context

Эта story объединяет локальные исправления из замечаний #2, #4 и #9. Родительский план определил их как высокоуверенные quick bugfixes без архитектурных изменений.

Текущий код уже содержит конкретные места для правки:

- `IPhoneEPUBReaderView.swift`: `actionTray` показывается через `.transition(.opacity.combined(with: .scale(scale: 0.96)))` без anchor, из-за чего tray может визуально прыгать.
- `IPhoneEPUBReaderView.swift`: `pickerBackdrop` кладет full-screen `Color.clear.contentShape(Rectangle()).onTapGesture`, который конкурирует с UIKit/WebKit selection handles и мешает drag-жестам.
- `IPhoneEPUBReaderView.swift`: visible `IPhoneEPUBWebView` завязан на `.opacity(store.isChapterReady ? 1 : 0)`, а `loadChapter` сбрасывает `isChapterReady = false`; на смене главы это может показывать пустой themed background.
- `IPhoneEPUBWebView.swift`: document-start `earlyStyle` с прозрачным background нужен сохранить. Он защищает от black WebView/HTML background и не является причиной fade issue.

## Acceptance Criteria

1. При открытии/закрытии action tray scale transition визуально исходит из нижнего правого угла, рядом с кнопкой `ellipsis.circle`, без заметного прыжка к центру.
2. После выделения текста системные selection handles можно перетаскивать; overlay highlight picker не блокирует drag handles.
3. Tap вне picker по-прежнему закрывает pending selection или edit state, но не ценой full-screen hit-test слоя поверх WebView selection handles.
4. При переходе между главами visible WebView не уходит в opacity 0 и не показывает пустую themed заливку.
5. Document-start прозрачный фон в `IPhoneEPUBWebView` остается на месте.
6. Существующие действия highlight picker: выбор цвета, удаление, заметка, редактирование существующего highlight - не регрессируют.

## Tasks / Subtasks

- Исправить transition anchor для `actionTray`.
  - В `IPhoneEPUBReaderView.swift` задать scale transition с anchor `.bottomTrailing`.
  - Проверить, что `.animation(.easeInOut(duration: 0.16), value: isActionTrayVisible)` продолжает применяться.
- Переработать `pickerBackdrop`.
  - Убрать full-screen блокирующий hit-test `Color.clear.contentShape(Rectangle())` поверх всей страницы или заменить на решение, которое не перехватывает drag по selection handles.
  - Сохранить возможность закрывать picker явным tap outside, если это возможно без конфликта; если нет, предпочесть работоспособные handles.
  - Убедиться, что сам `IPhoneHighlightColorPicker` остается интерактивным и позиционируется по текущей логике.
- Убрать chapter-ready fade с видимого WebView.
  - В `IPhoneEPUBReaderView.body` убрать opacity/animation, которые скрывают `IPhoneEPUBWebView` по `store.isChapterReady`.
  - Не удалять `isChapterReady` из store, если он еще нужен для sequencing offset navigation или будущей логики.
  - Не менять `earlyStyle` в `IPhoneEPUBWebView`.
- Проверить ручные сценарии.
  - Быстро открыть/закрыть меню и action tray.
  - Выделить текст, потянуть левый и правый selection handles.
  - Перейти на следующую/предыдущую главу с edge tap или swipe.

## Dev Notes

- Не расширять scope до unified selection menu. Это отдельная Story 7.
- Для `pickerBackdrop` наиболее вероятная причина бага - SwiftUI overlay поверх WKWebView, а не JS selection code. Начинать с hit-testing в SwiftUI.
- `Color.clear` с `contentShape(Rectangle())` является активным жестовым слоем даже без видимой заливки.
- Если нужен tap outside, рассмотрите ограниченный overlay вокруг picker или explicit dismiss через действия picker/menu, но не слой, который покрывает selection handles.
- `isChapterReady` можно оставить как внутреннее состояние store. Эта story требует убрать именно fade видимого `IPhoneEPUBWebView`.

## References

- Plan: `/Users/ekoshkin/reader/_bmad-output/reader-iphone-ux-bugfix-plan-2026-04-29.md`
- Prior related plan: `/Users/ekoshkin/reader/_bmad-output/reader-iphone-overlay-fixes-2.md`

## Affected Files

- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`
- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift` только для проверки, не ожидается обязательная правка
- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift` только для проверки lifecycle `isChapterReady`, не ожидается обязательная правка

## Non-goals / Risks

- Не внедрять native selection menu и не убирать custom picker целиком.
- Не менять архитектуру chapter loading.
- Не удалять document-start transparent background protection.
- Риск: если tap outside полностью убрать, UX dismiss станет менее удобным. Это допустимо только если handles становятся надежными; лучше найти компромисс без full-screen gesture interception.

## Verification Notes

- На iPhone simulator/device: action tray появляется из нижнего правого угла.
- На EPUB: выделить слово/абзац, изменить границы выделения handles, затем выбрать highlight color.
- Перейти через chapter boundary вперед и назад: нет пустой вспышки themed background.
- Проверить dark mode: WebView фон остается прозрачным/корректным, текст не пропадает.
