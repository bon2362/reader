# Plan: Reader iPhone — UX polish and bugfix batch

Status: planned
Created: 2026-04-29

## Context

План основан на списке из 10 замечаний по iPhone EPUB reader и проверке текущего кода в:

- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
- `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
- `ReaderiPhone/Features/Reader/IPhoneReaderSettingsView.swift`
- `ReaderiPhone/Features/Reader/BookPageCalculator.swift`

Блокирующих противоречий нет. Есть три архитектурные развязки, которые надо удержать при реализации:

1. Native selection menu (#3) конфликтует с текущим custom highlight picker только на уровне UX-архитектуры, поэтому сначала чиним picker/handles (#4), а unified native menu выносим в отдельную story.
2. Justify setting (#5) меняет количество страниц, поэтому `textAlign` должен стать частью page-count layout key и invalidation cache.
3. Page counter (#8) нельзя чинить гипотезой "не выставляется `totalBookPages`": финальный update уже есть. Нужна диагностика запуска/ключа/layout hidden calculator.

## Stories

- [Story 1: quick bugfixes (#2, #4, #9)](stories/reader-iphone-ux-bugfixes__story-1-quick-bugfixes.md)
- [Story 2: menu visual polish and close transition (#1, #7)](stories/reader-iphone-ux-bugfixes__story-2-menu-visual-polish-close-transition.md)
- [Story 3: text alignment setting and pagination cache integration (#5)](stories/reader-iphone-ux-bugfixes__story-3-text-alignment-pagination-cache.md)
- [Story 4: global page count diagnostics and fix (#8)](stories/reader-iphone-ux-bugfixes__story-4-global-page-count-diagnostics-fix.md)
- [Story 5: footnote return navigation (#10)](stories/reader-iphone-ux-bugfixes__story-5-footnote-return-navigation.md)
- [Story 6: page turn animation (#6)](stories/reader-iphone-ux-bugfixes__story-6-page-turn-animation.md)
- [Story 7: unified selection menu strategy (#3)](stories/reader-iphone-ux-bugfixes__story-7-unified-selection-menu-strategy.md)

## Implementation Order

### 1. Quick bugfixes without architecture changes

Fix the issues that are already localized and high-confidence:

- #2: anchor `actionTray` scale transition to `.bottomTrailing`.
- #4: remove or change the full-screen hit-test backdrop in highlight picker so UIKit selection handles can receive drag gestures.
- #9: remove the `isChapterReady` fade from the visible `IPhoneEPUBWebView`; keep the document-start transparent background protection.

Expected result: no action tray jump, selection handles are draggable, chapter transitions no longer flash through an empty themed background.

### 2. Menu visual polish and reader close transition

Polish the menu without returning to heavy panel UI:

- #1: replace technical SF Symbols with more reader-like symbols, reduce size to about 17pt, use `.secondary`, and add compact circular thin-material icon containers.
- #7: start with a simple custom removal transition for closing the reader. Keep `matchedGeometryEffect` as a separate larger enhancement because it touches library cell/opening flow.

Expected result: menu feels less technical while staying lightweight and readable.

### 3. Text alignment setting with page-count integration

Add user-facing alignment control:

- #5: introduce `ReaderTextAlign` (`.start`, `.justify`) in store.
- Persist it in `UserDefaults`.
- Add settings UI section "Выравнивание".
- Add JS API `setTextAlign(value)` and apply it to `#__reader_wrap p/li/blockquote`.
- Include `textAlign` in `BookPageLayoutKey`.
- Invalidate page counts when alignment changes.
- Apply the same alignment in `BookPageCalculator`.

Expected result: text alignment is selectable and global page count stays consistent with rendered layout.

### 4. Global page count diagnostics and fix

Investigate why fallback chapter numbering still appears:

- #8: inspect whether `startPageCalculationIfPossible` runs after first real viewport update.
- Surface/log `pageCalculationState`, layout key, chapter count validity, and calculator completion.
- Verify hidden calculator layout matches real reader layout: viewport, safe area vars, font size, line height, and text alignment.
- Fix the actual failure point: startup timing, layout-key mismatch, cache invalidation, hidden WebView layout, or counts validation.

Expected result: counter reliably shows `globalPage из totalBookPages` after calculation for EPUB books.

### 5. Footnote return navigation

Add return stack for internal links:

- #10: add navigation stack in store for `(chapterIndex, offset)`.
- Before `handleLinkTapped` navigates, save current chapter and current page start offset.
- Show a floating `arrow.uturn.backward` button when the stack is non-empty.
- On tap, pop and call existing `goToOffset(chapterIndex:offset:)`.

Expected result: following a footnote or internal link gives the reader a visible one-tap return path.

### 6. Page turn animation

Add minimal page turn motion without changing the reader shell:

- #6: change `#__reader_wrap` transition from `none` to `transform 220ms cubic-bezier(0.4, 0.0, 0.2, 1)`.
- Verify quick taps/swipes, `goToOffset`, search navigation, and chapter boundaries.

Do not implement `UIPageViewController.pageCurl` in this batch; that is a separate architecture change.

Expected result: page turns have a native-feeling horizontal slide and no obvious lag or input race.

### 7. Unified selection menu

Treat this as the most architecture-sensitive UX story:

- #3: decide and implement the iOS-native path if feasible.
- Avoid suppressing the system menu unless Copy/Look Up/Translate/Share remain available.
- Target solution: integrate system actions with app actions (Highlight colors, Note) through `UIEditMenuInteraction` or equivalent WebKit menu integration.
- Fallback path: extend the custom picker only if native integration proves too risky.

Expected result: user sees one coherent selection menu, not the system menu plus a competing custom picker.

## Verification

- Action tray opens without visible jump.
- Selection handles can be dragged after text selection.
- Chapter changes do not flash to an empty background.
- Menu icons are smaller, softer, and still accessible.
- Text alignment setting persists and changes rendered text.
- Page count recalculates when font size, line height, viewport, safe area, or text alignment changes.
- Global page counter appears after calculation.
- Footnote/internal-link navigation shows a return control and returns to the previous position.
- Page turn animation works for tap zones, swipe gestures, search/go-to-offset, and chapter boundaries.
- Selection menu has no duplicate competing controls.
