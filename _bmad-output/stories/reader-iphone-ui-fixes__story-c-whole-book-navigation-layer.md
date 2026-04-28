---
story_id: reader-iphone-ui-fixes-c
story_title: "Story C: Whole-book navigation layer"
status: ready-for-review
source_plan: /Users/ekoshkin/reader/_bmad-output/bmad-help-unified-clarke.md
scope_items: "#10, #13, #12"
depends_on: reader-iphone-ui-fixes-b
---

# Story C: Whole-book navigation layer

## Story

As an iPhone Reader user, I want search and page navigation to work across the whole EPUB, so I can find text anywhere in the book and jump by global page number.

## Acceptance Criteria

1. Given a search query is submitted, when the book contains matches in multiple chapters, then results include matches across all chapters and show the chapter context.
2. Given a search result in another chapter is tapped, when navigation completes, then the reader loads that chapter and navigates to the matched offset using the existing offset navigation path.
3. Given a book is opened, when background page calculation completes, then the page counter switches from chapter-local format to global `current / total` format.
4. Given page calculation is still running or unavailable, when the counter renders, then the existing chapter-local fallback remains available.
5. Given font size or layout-affecting settings change, when page totals are no longer valid, then cached page counts are invalidated or recalculated.
6. Given the user taps the page counter, when they enter a valid global page number, then the store computes the target chapter/page or offset and navigates there.
7. Given page-count cache is persisted, when the app restarts, then the cache is local-first and not stored in `UserDefaults`.

## Tasks / Subtasks

- [x] Incorporate the real Winston architectural note before implementation.
- [x] Incorporate the real Murat test-design note before implementation.
- [x] Update search model and UI
  - [x] Extend `EPUBSearchResult` with chapter index/title and offset information.
  - [x] Implement whole-book Swift-side search using `EPUBBook.htmlTextContent(_:)`.
  - [x] Update `IPhoneReaderSearchView.swift` copy and result rows to remove current-chapter language and show chapter context.
  - [x] Navigate search results across chapter boundaries, using existing `goToOffset`/offset path after chapter load.
- [x] Implement whole-book page calculation
  - [x] Add `ReaderiPhone/Features/Reader/BookPageCalculator.swift`.
  - [x] Use hidden `WKWebView` rendering or an equivalent project-compatible path with the same reader JS/layout assumptions.
  - [x] Cache page counts locally with key including `bookId`, `fontSize`, screen width, and other layout-affecting inputs; do not use `UserDefaults`.
  - [x] Invalidate/recalculate on font size changes.
- [x] Update `IPhoneEPUBReaderStore.swift`
  - [x] Track global page, total book pages, chapter page counts, and calculation state.
  - [x] Start background page calculation after book load.
  - [x] Add `goToGlobalPage(_:)`.
  - [x] Keep chapter-local fallback while calculation is pending.
- [x] Update `IPhoneEPUBReaderView.swift`
  - [x] Show global counter when available.
  - [x] Add counter tap-to-page-entry UI with numeric keyboard.
- [x] Add the new Swift file to the Xcode project target if project membership is required.
- [x] Run available build/typecheck/test verification.

## Dev Notes

- Before using `scrollToOffset`, verify the JS bridge. Current reader JS exposes `window.__reader.goToOffset(offset)`; prefer that existing offset navigation path unless implementation proves otherwise.
- Use `EPUBBook.htmlTextContent(_:)` for whole-book search. Do not add a duplicate HTML stripping method.
- Page cache ownership should be in a local SQLite/file-backed service, not `UserDefaults`.
- Keep local-first behavior; do not introduce network or sync dependencies.
- Existing relevant files:
  - `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
  - `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`
  - `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
  - `ReaderiPhone/Features/Reader/IPhoneReaderSearchView.swift`
  - `Reader/Features/Reader/EPUBBook.swift`
  - `Reader.xcodeproj/project.pbxproj`

## Architecture Note

- Winston subagent note, 2026-04-28:
  - iPhone EPUB anchors are app anchors (`href|o:offset`, `href|p:page`), not real EPUB CFI.
  - `scrollToOffset` does not exist in iPhone JS. Current bridge exposes `window.__reader.goToOffset(offset)`; use it with feature checks.
  - Whole-book search should extend `EPUBSearchResult` with `chapterIndex`, chapter label/href, offset, length, and snippet. Use `EPUBBook.htmlTextContent(_:)`; preserve UTF-16 offset convention where possible.
  - Cross-chapter offset navigation needs `pendingOffset`: load chapter first, then call `goToOffset` after `ready`, layout, and annotation application.
  - Shared code already has a conceptual pattern in `NativeEPUBBridge.goToCFI`: parse `href|o:offset`, load chapter if needed, apply pending offset on ready.
  - Existing page-cache persistence exists in `books.chapter_page_counts`, `Book.chapterPageCounts`, and `LibraryRepository.updateChapterPageCountsCache`. Prefer this local-first owner over `UserDefaults`.
  - If layout keying by `fontSize + screenWidth` cannot fit the existing column, either safely invalidate/reset cache on layout changes or introduce a dedicated local cache table. Do not store page cache in `UserDefaults`.
  - `BookPageCalculator` must reuse `IPhoneEPUBWebView.readerJS` or equivalent reader JS/layout assumptions, or page totals will diverge from the visible web view.
  - New JS calls must check `window.__reader && typeof window.__reader.goToOffset === 'function'`.

## Test Design Note

- Murat subagent note, 2026-04-28:
  - Acceptance tests:
    - Whole-book search returns matches from multiple chapters with `chapterIndex`, href/label, offset, length, and snippet, using `EPUBBook.htmlTextContent()` instead of current DOM JS search.
    - Search is case-insensitive; empty/whitespace query returns `[]` without scanning every chapter.
    - Tapping a result in another chapter loads that chapter, waits for `ready`, then calls `goToOffset`.
    - Tapping a current-chapter result calls offset navigation without chapter reload.
    - Global page mapping handles first page, chapter boundaries, last page, invalid low values, and values greater than total.
    - Counter falls back to chapter-local format while calculation is pending, then switches to global `current / total`.
    - Font size, line height, and viewport width invalidate/recalculate page-count cache.
    - Valid counter input calls `goToGlobalPage`; invalid input must not crash.
  - Edge cases:
    - Empty chapters count as at least 1 page and do not crash search.
    - Inline HTML boundary and Unicode offset cases need verification because Swift `htmlTextContent()` and JS `collectTextNodes()` can diverge.
    - Fast taps on multiple search results must not let an older pending `ready` apply the wrong offset.
    - Hidden page calculator messages must not mutate visible reader state.
  - Cache invalidation:
    - Reject cache if counts length differs from chapter count or any count is `<= 0`.
    - Do not reuse cache across different `fontSize`, `lineHeight`, viewport width, or changed book file metadata if available.
    - Do not persist partial failed calculations as valid.
  - Async risks:
    - Hidden calculator must wait for layout-ready/page totals, not arbitrary sleep.
    - Visible and hidden WKWebViews must share the same CSS, padding, font size, line height, and viewport assumptions.
    - Cancel calculation when closing reader or loading another book.
  - Verification plan:
    - Add or update unit tests for search offsets and page mapping where project test harness supports it.
    - Run available Xcode build/tests.
    - Manual simulator checks remain required for final visual/gesture validation.

## Dev Agent Record

### Debug Log

- 2026-04-28: Loaded Winston architecture note and Murat test-design note before implementation.
- 2026-04-28: `xcodebuild -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme ReaderiPhone -configuration Debug -destination 'generic/platform=iOS Simulator' build` succeeded.
- 2026-04-28: `xcodebuild test -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme Reader -destination 'platform=macOS'` succeeded; 207 Swift Testing tests passed.
- 2026-04-28: Story C fix cycle: resolved P1/P2 review findings for body-scoped search offsets, viewport-height layout keys, stale calculator callbacks, book-file cache signatures, and invalid global page input.
- 2026-04-28: Re-ran `xcodebuild -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme ReaderiPhone -configuration Debug -destination 'generic/platform=iOS Simulator' build` — succeeded.
- 2026-04-28: Re-ran `xcodebuild test -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme Reader -destination 'platform=macOS'` — succeeded; 210 Swift Testing tests passed.
- 2026-04-28: Final checkpoint after fullscreen/root-shell stabilization retained Story C scope unchanged; manual follow-up opportunities remain for navigation/search UX polish.

### Completion Notes

- Implemented whole-book Swift-side EPUB search using `EPUBBook.htmlTextContent(_:)`; result rows now show chapter context and navigate by chapter-aware offset.
- Added pending offset navigation guarded by ready URL and `window.__reader.goToOffset` feature checks, avoiding `scrollToOffset`.
- Added hidden `WKWebView` page preflight using `IPhoneEPUBWebView.readerJS`, plus local file-backed layout-keyed cache (`bookId`, font size, line height, viewport width).
- Added global page state, fallback counter text, invalidation on font size/line height/viewport width changes, and numeric page entry routed through `goToGlobalPage(_:)`.
- Added pure tests for global page mapping and cache validation helper behavior.
- Fixed whole-book search offsets to use body-scoped text (`EPUBBook.htmlBodyTextContent`) so offsets match the JS `document.body` text-node stream used by `goToOffset`/`rangeForOffsets`; added a head/title drift regression test.
- Extended page layout cache identity with viewport height and file size/mtime signature; hidden calculator frame now uses actual visible viewport dimensions reported by the WebView/JS.
- Added calculator generation/session guards, href checks, inactive completion handling, and removed post-completion blank HTML loading to avoid stale callbacks and ready-loop churn.
- Changed reader global page entry to reject invalid/out-of-range values rather than clamping them through navigation.
- Final product check found remaining improvement opportunities, but no blocking P0/P1/P2 Story C acceptance issue was identified before commit.

## File List

- Reader/Features/Reader/BookContentProvider.swift
- Reader/Features/Reader/EPUBBook.swift
- ReaderTests/Features/EPUBBookTests.swift
- ReaderTests/Features/EPUBPageMapperTests.swift
- ReaderTests/Features/EPUBTestFactory.swift
- ReaderiPhone/Features/Reader/BookPageCalculator.swift
- ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift
- ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift
- ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift
- ReaderiPhone/Features/Reader/IPhoneReaderSearchView.swift
- Reader.xcodeproj/project.pbxproj
- _bmad-output/stories/reader-iphone-ui-fixes__story-c-whole-book-navigation-layer.md

## Change Log

- 2026-04-28: Story created from unified Reader iPhone fixes plan.
- 2026-04-28: Implemented Story C whole-book search, global page calculation/navigation, local page-count cache, page-entry UI, and verification tests.
- 2026-04-28: Fixed Story C review findings for search offset drift, viewport-height cache invalidation, stale calculator callbacks, cache file revision, invalid global page input, and focused test coverage.
- 2026-04-28: Added final checkpoint note after app-level fullscreen fix; follow-up navigation/search refinements deferred to separate sessions.
