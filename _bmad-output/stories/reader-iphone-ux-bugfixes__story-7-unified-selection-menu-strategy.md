# Story 7: Unified selection menu strategy для highlights, notes и system actions

Status: ready-for-dev

## Story

Как читатель EPUB на iPhone, я хочу видеть одно понятное меню выделения текста, где доступны и системные действия, и действия приложения, чтобы не выбирать между Copy/Look Up/Translate и highlight/note controls.

## Context

Эта story покрывает замечание #3 и является самой архитектурно чувствительной в batch. План фиксирует:

- сначала чинится custom picker/handles в Story 1;
- затем отдельной story решается unified menu;
- предпочтительный путь: native `UIEditMenuInteraction` или equivalent WebKit menu integration;
- fallback: расширять custom picker только если native integration слишком рискованна;
- нельзя suppress system menu, если Copy/Look Up/Translate/Share не остаются доступны.

Текущий flow:

- JS `selectionchange` отправляет `textSelected` с offsets/rects.
- Store выставляет `pendingSelection`.
- SwiftUI `highlightPickerOverlay(for:)` показывает custom `IPhoneHighlightColorPicker`.
- WebKit/iOS system selection menu может появляться отдельно, что создает конкурирующие controls.
- Full-screen picker backdrop из Story 1 должен быть исправлен, чтобы handles работали.

## Acceptance Criteria

1. Пользователь видит один coherent selection menu UX, а не competing system menu плюс отдельный custom picker.
2. Системные действия Copy, Look Up, Translate, Share или platform-equivalent остаются доступными.
3. App actions для highlight colors и note доступны из того же coherent flow.
4. Selection handles продолжают перетаскиваться после открытия menu.
5. Highlight creation/update/delete и note creation сохраняют существующие repository/offset semantics.
6. Решение документировано в коде коротким комментарием только там, где platform integration неочевидна.
7. Если native path невозможен/слишком рискован, fallback сохраняет system actions явным способом и объяснен в implementation notes/PR.

## Tasks / Subtasks

- Исследовать native integration path.
  - Проверить применимость `UIEditMenuInteraction`, `UIMenuController`, WebKit edit menu delegates или iOS APIs, доступных для текущего deployment target.
  - Проверить, можно ли добавить app actions в menu над WKWebView selection без отключения standard actions.
  - Проверить ограничения SwiftUI `UIViewRepresentable`/`WKWebView`.
- Спроектировать unified behavior.
  - Выбрать native preferred path, если feasible.
  - Определить actions: highlight yellow/red/green/blue/purple, note, maybe delete/update when overlapping existing highlight.
  - Сохранить existing `EPUBTextSelection` offsets and overlap logic in store.
- Реализовать native path.
  - В `IPhoneEPUBWebView.Coordinator` или related UIKit bridge добавить menu integration.
  - Использовать store APIs для highlight/note actions; не дублировать repository logic в WebView layer.
  - Не ломать JS selection offset reporting.
- Если native path не проходит, реализовать fallback.
  - Custom menu должен не suppress system actions без замены.
  - Возможный fallback: custom compact picker появляется после system menu dismissal или рядом, но не конкурирует одновременно.
  - Fallback должен явно сохранять Copy/Look Up/Translate/Share availability.
- Регрессия annotations.
  - Highlight add/update/delete работает.
  - Note draft from selection works.
  - Existing highlight tap/edit still works.

## Dev Notes

- Эта story не про визуальный polish picker; это UX architecture.
- Не удалять system menu ради чистоты. Это главный guardrail.
- Store уже содержит большинство business logic: `addHighlight`, `updateHighlightColor`, `deleteHighlight`, `prepareHighlightNoteDraft`, overlap detection.
- JS offsets остаются source of truth для persistence; native menu action должен работать с текущим `pendingSelection`.
- Если используется private/fragile WebKit behavior, лучше выбрать более скромный fallback.
- Проверить iOS version availability перед использованием `UIEditMenuInteraction`.

## References

- Plan: `/Users/ekoshkin/reader/_bmad-output/reader-iphone-ux-bugfix-plan-2026-04-29.md`
- Reader view picker overlay: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`
- Store selection/highlight logic: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
- WebView JS selection events and coordinator: `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`

## Affected Files

- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`
- `/Users/ekoshkin/reader/ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`

## Non-goals / Risks

- Не исправлять handles backdrop здесь; это Story 1 prerequisite.
- Не удалять Copy/Look Up/Translate/Share.
- Не переписывать annotation persistence.
- Риск: `UIEditMenuInteraction` with WKWebView may be constrained by WebKit ownership of selection menu. Timebox native investigation and use fallback only with explicit rationale.

## Verification Notes

- Long press/select text: one coherent menu appears.
- Copy works.
- Look Up/Translate/Share remain available where iOS provides them.
- Highlight color action creates highlight at correct offsets.
- Note action opens note draft and saves note at selection.
- Drag handles before/after menu interaction still works.
