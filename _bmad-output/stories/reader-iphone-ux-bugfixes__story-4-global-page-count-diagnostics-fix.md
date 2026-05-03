# Story 4: Диагностика и исправление сквозного счетчика страниц EPUB

Status: ready-for-dev

## Story

Как читатель EPUB на iPhone, я хочу видеть надежный счетчик "страница из всей книги", а не fallback по текущей главе, чтобы понимать реальный прогресс по книге.

## Context

Эта story покрывает замечание #8. Важно не чинить наугад. План специально предупреждает: не предполагать, что `totalBookPages` просто не присваивается. В текущем коде финальный update уже есть:

- `updateGlobalPage()` выставляет `globalPage` и `totalBookPages = chapterPageCounts.reduce(0, +)`, если counts валидны.
- `startPageCalculationIfPossible` может не стартовать, если viewport еще 0.
- `updateVisibleViewport` вызывает invalidation/recalculate при первом реальном viewport.
- `BookPageCalculator` hidden WKWebView измеряет главы через `readerJS`.
- `BookPageLayoutKey` должен совпадать с реальным reader layout. После Story 3 туда добавляется `textAlign`.

Цель story - диагностировать фактический failure point: startup timing, layout-key mismatch, cache invalidation, hidden WebView layout или validation counts.

## Acceptance Criteria

1. Добавлены диагностические breadcrumbs/logs для page calculation lifecycle без шумного постоянного spam.
2. Диагностика показывает: старт/skip причины `startPageCalculationIfPossible`, layout key, viewport/safe area, chapter count, cache hit/miss, calculator completion counts, validation result.
3. Определена фактическая причина fallback chapter numbering для EPUB books.
4. Исправлен реальный failure point, а не добавлен blind assignment `totalBookPages`.
5. После успешного расчета UI стабильно показывает `globalPage из totalBookPages`.
6. Page count пересчитывается при изменении font size, line height, viewport, safe area и text alignment.
7. Hidden calculator layout соответствует видимому reader layout по viewport, safe areas, font size, line height, text alignment и relevant CSS defaults.
8. Ошибочные/неполные counts не сохраняются в cache и не переводят state в ready.

## Tasks / Subtasks

- Добавить диагностику в store.
  - В `startPageCalculationIfPossible`: логировать skip reasons `empty chapters`, `zero viewport`, `already calculating same key`, cache hit/miss.
  - Логировать `BookPageLayoutKey` или безопасное краткое представление.
  - В completion логировать counts length, chapter count, validity, sum.
  - В `updateGlobalPage` логировать invalid counts condition только при state transitions или debug builds.
- Добавить диагностику в calculator.
  - В `BookPageCalculator`: логировать chapter measurement start, ready href mismatch, total pages result, completion.
  - Не засорять release logs; использовать `#if DEBUG` helper или existing logging convention.
- Проверить startup sequencing.
  - `load()` вызывает `startPageCalculationIfPossible` до первого viewport, где guard может вернуть.
  - Убедиться, что первый `updateVisibleViewport` после `makeUIView/updateUIView` запускает recalculation, если EPUB уже загружен.
  - Если sequencing race найден, исправить минимально: например через retry после attach/update или явное start после first ready viewport.
- Проверить layout parity.
  - `BookPageCalculator.webView.frame` соответствует `layoutKey`.
  - Safe area CSS vars применяются до измерения.
  - Font size, line height и textAlign применяются и дают settled layout перед `totalPages`.
  - Viewport meta в hidden calculator не расходится критично с visible reader; при необходимости привести к тому же `viewport-fit=cover`/user-scalable behavior.
- Проверить cache/validation.
  - `BookPageCountCache.load` получает правильный `chapterCount`.
  - Cache key включает все layout-affecting settings.
  - `EPUBPageMapper.isValid` не отвергает корректные counts.
- Внести минимальное исправление фактической причины.

## Dev Notes

- Не делать фиксом строку `totalBookPages = ...` вне `updateGlobalPage`; это замаскирует проблему.
- Если проблема в `pageCalculationKey` и `.failed`: сейчас guard блокирует только same key + `.calculating`; failed same key может перезапускаться. Проверить, не происходит ли бесконечный loop.
- Если проблема в hidden WebView measurement timing, увеличить/синхронизировать settle только там, где требуется, и не замедлять visible reader.
- Если calculator completion возвращает counts, но UI все равно fallback, смотреть `EPUBPageMapper.isValid` и current chapter index.
- После Story 3 обязательно учитывать `textAlign`; если Story 4 выполняется раньше, оставить явную TODO/compat point или включить alignment field вместе с этой story только при согласовании.

## References

- Plan: `/Users/ekoshkin/reader/_bmad-output/reader-iphone-ux-bugfix-plan-2026-04-29.md`
- Store page calculation: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
- Calculator/cache: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/BookPageCalculator.swift`
- Reader JS layout: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`

## Affected Files

- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/BookPageCalculator.swift`
- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift` при необходимости layout parity

## Non-goals / Risks

- Не переписывать pagination architecture.
- Не заменять hidden WKWebView calculator другим engine.
- Не считать fixed page count по главам без фактической layout measurement.
- Риск: диагностика может стать шумной. Ограничить debug-only или state-change logs.

## Verification Notes

- Запустить EPUB reader с cold cache: сначала fallback допустим, после calculation появляется global count.
- Перезапустить reader с warm cache: global count появляется быстро через cache hit.
- Изменить font size, line height, text alignment: counts invalidated and recalculated.
- Проверить book with multiple chapters and TOC links: global page remains valid after chapter navigation.
- Проверить logs: видна причина старта/skip и финальный valid counts sum.
