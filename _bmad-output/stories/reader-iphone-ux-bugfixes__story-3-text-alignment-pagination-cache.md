# Story 3: Настройка выравнивания текста и интеграция с pagination cache

Status: ready-for-dev

## Story

Как читатель EPUB на iPhone, я хочу переключать выравнивание текста между обычным началом строки и полной выключкой, чтобы читать в комфортном стиле, а счетчик страниц оставался точным после изменения настройки.

## Context

Эта story покрывает замечание #5. Важно: выравнивание текста меняет layout и количество страниц, поэтому настройка должна участвовать не только в UI/JS, но и в ключе кэша page count.

Сейчас:

- `IPhoneEPUBReaderStore` хранит persisted `readerTheme`, `fontSize`, `lineHeight`.
- `fontSize` и `lineHeight` вызывают JS setters и `invalidatePageCountsAndRecalculate()`.
- `IPhoneReaderSettingsView` содержит sections "Тема", "Размер шрифта", "Межстрочный интервал".
- `IPhoneEPUBWebView.readerJS` задает default `text-align: start` для `html, body` и `#__reader_wrap p/li/blockquote`.
- `BookPageLayoutKey` содержит book signature, fontSize, lineHeight, viewport, safe areas, но не содержит text alignment.
- `BookPageCalculator.applyLayoutAndReadTotal` применяет font size, line height, safe areas, но не text align.

## Acceptance Criteria

1. Добавлен `ReaderTextAlign` с вариантами `.start` и `.justify`, человекочитаемыми русскими labels и raw values, пригодными для JS/CSS.
2. Выбор выравнивания хранится в `UserDefaults` и восстанавливается при следующем открытии reader.
3. В settings UI есть section "Выравнивание" с выбором "По левому краю"/"По ширине" или эквивалентными понятными labels.
4. При изменении alignment видимый WebView применяет стиль без перезагрузки книги.
5. JS API `window.__reader.setTextAlign(value)` применяет alignment к `#__reader_wrap p, li, blockquote` и, при необходимости, body/wrap так, чтобы EPUB-параграфы реально менялись.
6. При изменении alignment пересчитываются chapter page counts и обновляется global page counter.
7. `BookPageLayoutKey` включает alignment, поэтому cache для `.start` и `.justify` не смешивается.
8. `BookPageCalculator` применяет тот же alignment перед измерением total pages.
9. Текущие настройки font size, line height и theme не регрессируют.

## Tasks / Subtasks

- Добавить модель настройки.
  - В `IPhoneEPUBReaderStore.swift` рядом с `ReaderTheme` определить `ReaderTextAlign: String, CaseIterable`.
  - Добавить `displayName` на русском.
  - Raw values выбрать совместимые с CSS: например `start` и `justify`.
- Добавить persisted state в store.
  - `var textAlign: ReaderTextAlign` с `didSet`: сохранить в `UserDefaults`, вызвать `applyTextAlign()`, затем `invalidatePageCountsAndRecalculate()`.
  - Загрузить из `UserDefaults` в init, default `.start`.
  - Добавить `static` key/default рядом с existing settings или сохранить стиль текущего кода.
- Добавить JS integration.
  - В `IPhoneEPUBWebView.readerJS` добавить `setTextAlign`.
  - Обновить default CSS так, чтобы default остается `start`.
  - После изменения alignment clamp current page, `applyTransform()` и `reportPage()` после layout settle, аналогично font size/line height.
  - В `applyAppearanceSettings()` применять textAlign, если default отличается или всегда применять для явности.
- Добавить settings UI.
  - В `IPhoneReaderSettingsView` добавить section "Выравнивание".
  - Использовать компактный segmented/button style, согласованный с line height buttons.
  - Связать с `store.textAlign`.
- Интегрировать pagination cache.
  - Добавить `textAlign` в `BookPageLayoutKey`.
  - Обновить `BookPageCountCache.cacheURL(for:)`, чтобы alignment попадал в raw cache key.
  - Обновить создание layout key в `startPageCalculationIfPossible`.
  - Обновить `BookPageCalculator.applyLayoutAndReadTotal`, чтобы hidden WebView применял `setTextAlign`.
- Проверить invalidation.
  - Переключение start -> justify очищает current counts и переводит state через recalculation.
  - Возврат justify -> start берет корректный cache только для start.

## Dev Notes

- Не использовать `text-align: justify` глобально на все элементы без разбора, чтобы не испортить headings/code/images. План явно говорит применять к `#__reader_wrap p/li/blockquote`.
- Для CSS value `start` полезен logical alignment и уже используется в текущем codebase.
- Если `applyAppearanceSettings()` применяет только non-default settings, убедиться, что после загрузки chapter default CSS совпадает с default store.
- `BookPageLayoutKey` Codable/Equatable: добавление поля повлияет на decode старых cache entries. Текущий cache decode может fail для старых entries, это приемлемо: они будут пересчитаны.
- Не забыть, что hidden calculator использует тот же `IPhoneEPUBWebView.readerJS`, поэтому JS setter должен быть доступен и там.

## References

- Plan: `/Users/ekoshkin/reader/_bmad-output/reader-iphone-ux-bugfix-plan-2026-04-29.md`
- Store settings: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
- Settings UI: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneReaderSettingsView.swift`
- Reader JS: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
- Pagination calculator/cache: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/BookPageCalculator.swift`

## Affected Files

- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneReaderSettingsView.swift`
- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/BookPageCalculator.swift`

## Non-goals / Risks

- Не добавлять дополнительные typography settings.
- Не менять EPUB parsing.
- Риск: старые cache files станут unreadable из-за нового Codable поля. Это нормально, но не должно приводить к crash.
- Риск: justify в узких колонках может выглядеть хуже на некоторых EPUB. Поэтому default должен остаться `.start`.

## Verification Notes

- Открыть EPUB, переключить "По ширине": абзацы визуально меняют alignment.
- Закрыть/открыть reader: setting сохраняется.
- После переключения page counter временно может вернуться к chapter count, затем снова показывает global count.
- Сравнить total pages для start/justify: cache не смешивается.
- Проверить font size и line height после добавления alignment: пересчет работает для всех трех настроек.
