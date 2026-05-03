# Story 6: Минимальная page turn animation для EPUB reader

Status: ready-for-dev

## Story

Как читатель EPUB на iPhone, я хочу, чтобы перелистывание страницы имело короткое горизонтальное движение, чтобы чтение ощущалось нативнее без тяжелой смены архитектуры reader.

## Context

Эта story покрывает замечание #6. План требует минимальную CSS transform transition:

- заменить `#__reader_wrap` transition с `none` на `transform 220ms cubic-bezier(0.4, 0.0, 0.2, 1)`;
- проверить inputs/navigation;
- не внедрять `UIPageViewController.pageCurl`.

Сейчас в `IPhoneEPUBWebView.readerJS`:

- `#__reader_wrap` имеет `will-change: transform; transition: none;`;
- `applyTransform()` выставляет `translateX(-page * pageSize())`;
- `goToPage`, `nextPage`, `prevPage`, `goToLastPage`, `goToAnchor`, `goToOffset`, `currentPageStartOffset` временно сбрасывают transform в `translateX(0px)` для измерений.

## Acceptance Criteria

1. Tap zones и swipe page turns получают короткую горизонтальную transform animation около 220ms.
2. Animation не ломает `goToPage`, `nextPage`, `prevPage`, `goToLastPage`.
3. Programmatic navigation (`goToOffset`, search result, footnote return, global page entry) остается корректной; допустима та же slide-анимация, если нет визуального глитча.
4. Boundary transitions between chapters не дают stale transform или анимацию из старой главы в новую.
5. Быстрые повторные taps/swipes не приводят к desync `pageInChapter`, `totalInChapter`, `globalPage`.
6. `currentPageStartOffset`, `goToAnchor`, `goToOffset` продолжают корректно измерять layout при временном reset transform.
7. Не используется `UIPageViewController.pageCurl` и не меняется основная reader shell architecture.

## Tasks / Subtasks

- Включить CSS transition.
  - В `IPhoneEPUBWebView.readerJS` заменить `transition: none;` у `#__reader_wrap` на `transition: transform 220ms cubic-bezier(0.4, 0.0, 0.2, 1);`.
- Защитить measurement/reset paths.
  - Проверить `goToAnchor`, `goToOffset`, `currentPageStartOffset`: они выставляют transform 0 для измерений.
  - Если reset начинает видимо анимироваться, временно отключать transition на время measurement и восстанавливать после `applyTransform()`.
  - Свести helper к JS functions, чтобы не дублировать manual style manipulation.
- Проверить page turn result timing.
  - `evaluatePageTurn` ожидает immediate `currentPage()` after JS call. Так как `__page` меняется синхронно, animation не должна ломать Swift result.
  - Убедиться, что `reportPage` не опаздывает критично для UI.
- Проверить chapter load/boundaries.
  - On new chapter page starts at 0 with correct transform.
  - Previous chapter `goToLastPage()` не анимирует странно от page 0 через всю главу, если это выглядит плохо; при необходимости disable transition during initial restore.

## Dev Notes

- Главное техническое искушение - просто включить transition. Но из-за measurement code, который сбрасывает transform, может появиться визуальный bounce. Проверить эти пути обязательно.
- Можно добавить JS helpers вроде `withoutTransition(fn)` или `setTransform(animated:)`, если это уменьшит риск.
- Не менять gesture recognizers в Swift без необходимости.
- Не блокировать быстрые taps на Swift side, если JS state уже синхронно обновляется. Но если появится race, минимальный debounce должен быть аккуратным и не ухудшать responsiveness.

## References

- Plan: `/Users/ekoshkin/reader/_bmad-output/reader-iphone-ux-bugfix-plan-2026-04-29.md`
- Reader JS: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
- Store page turn helper: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
- Reader tap zones/swipes: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`

## Affected Files

- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift` only if input race handling is needed

## Non-goals / Risks

- Не внедрять page curl.
- Не переводить EPUB reader на native page controller.
- Не менять pagination model.
- Риск: programmatic offset navigation может показать нежелательную slide from page 0. Если так, отключать transition только для measurement/restore paths.

## Verification Notes

- Tap right/left zones: visible smooth horizontal slide.
- Swipe left/right: same behavior, no double movement.
- Быстро tap несколько раз: page counter and content remain in sync.
- Search result navigation and `goToOffset`: lands on correct page.
- Chapter boundary forward/backward: no long slide from old content or blank flash.
