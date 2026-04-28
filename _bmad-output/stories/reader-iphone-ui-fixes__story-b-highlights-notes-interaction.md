---
story_id: reader-iphone-ui-fixes-b
story_title: "Story B: Highlights + notes interaction"
status: ready-for-review
source_plan: /Users/ekoshkin/reader/_bmad-output/bmad-help-unified-clarke.md
scope_items: "#5, #6.1, #6.3, #6.4, #6.5, #11"
depends_on: reader-iphone-ui-fixes-a
---

# Story B: Highlights + notes interaction

## Story

As an iPhone Reader user, I want highlighting and note interactions to behave predictably, so I can mark text, edit existing highlights, and add page or highlight notes without duplicate artifacts.

## Acceptance Criteria

1. Given text is selected in the EPUB web view, when the selection message reaches Swift, then the highlight picker appears near the selection without covering the selected text.
2. Given a selection overlaps an existing highlight in the same chapter, when the picker opens, then it enters edit mode for that highlight and shows the active color.
3. Given an existing highlight is in edit mode, when the active color is tapped, then the highlight is deleted; when another color is tapped, then the highlight color is updated.
4. Given the same text range is selected more than once, when the user chooses a color, then a duplicate highlight is not inserted; the existing overlapping highlight is reused or updated.
5. Given the highlight picker is visible for a new or existing highlight, when the note button is tapped, then a note entry flow opens and persists a `TextNote` linked to the highlight id.
6. Given the bottom menu is visible, when the user taps the page-note action, then a note sheet opens and saves a page note as a `TextNote` with `highlightId: nil` and an offset anchor created by `EPUBBook.makeOffsetAnchor(href:offset:)`.
7. Given annotations reload on a chapter, when highlights and notes exist, then the existing JS bridge continues rendering highlights and note marks correctly.

## Tasks / Subtasks

- [x] Incorporate the real Winston architectural note before implementation.
- [x] Update `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
  - [x] Normalize selection offset ranges and match overlapping highlights only within the current chapter.
  - [x] On `textSelected`, detect whether the selection overlaps an existing highlight and set edit mode appropriately.
  - [x] Prevent duplicate highlight insertion in `addHighlight(color:)`; update/reuse overlapping highlights instead.
  - [x] Add a path to create or reuse a highlight before opening a highlight-linked note flow.
  - [x] Add a page-note save path that stores a `TextNote` with an offset anchor and no `highlightId`.
- [x] Update `ReaderiPhone/Features/Reader/IPhoneHighlightColorPicker.swift`
  - [x] Add a compact note action using an appropriate SF Symbol.
  - [x] Support active-color tap semantics without adding duplicate UI state.
- [x] Update `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`
  - [x] Position the picker with correct coordinate assumptions and clamp away from the selected range where possible.
  - [x] Add note-entry sheet(s) for highlight-linked and page notes using existing SwiftUI patterns.
  - [x] Add a page-note action to the bottom menu.
- [x] Preserve existing annotation repository/schema contracts unless a necessary migration already exists.
- [x] Run available build/typecheck/test verification.

## Dev Notes

- Use existing offset-anchor functions in `EPUBBook`; do not introduce page anchors for page notes.
- `TextNote.highlightId` already exists and must be used for highlight notes.
- `IPhoneEPUBWebView.readerJS` emits selection offsets from its text-node collection; keep matching logic compatible with that offset space.
- Do not use `UserDefaults` for annotation/cache state.
- Existing relevant files:
  - `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
  - `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`
  - `ReaderiPhone/Features/Reader/IPhoneHighlightColorPicker.swift`
  - `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
  - `Reader/Features/Reader/EPUBBook.swift`
  - `Reader/Database/Models/TextNote.swift`
  - `Reader/Features/Annotations/AnnotationRepository.swift`

## Architecture Note

- Winston subagent note, 2026-04-28:
  - iPhone EPUB "CFI" is the app anchor format `href|o:offset` / `href|p:page`; do not introduce a new CFI format.
  - Canonical helpers are `EPUBBook.makePageAnchor`, `makeOffsetAnchor`, `normalizeHref`, and `htmlTextContent`.
  - JS selection offsets come from `collectTextNodes()` and should be matched in the same offset space.
  - Duplicate highlight prevention belongs in `IPhoneEPUBReaderStore`, not JS/DB. Compare current-chapter anchors only, using range overlap: `existingStart < newEnd && newStart < existingEnd`.
  - Re-selecting an existing range should set `editingHighlightId` before create mode; tap active color routes to delete, other color routes to update.
  - Highlight notes should be created by `IPhoneEPUBReaderStore` using `TextNote.highlightId`, since the iPhone store owns `textNotes`, `annotationRepository`, current href, and JS note rendering.
  - Page notes for #11 must be `TextNote(highlightId: nil, cfiAnchor: EPUBBook.makeOffsetAnchor(...))`, not `PageNote` and not page anchors.
  - Page-note marks need a safe length. Current restore path uses `selectedText.count`; page notes without selected text should render as length 1 or a separate marker-style path.

## Dev Agent Record

### Debug Log

- 2026-04-28: Read Winston architecture note before implementation; kept anchors in existing `href|o:offset` format and duplicate detection in `IPhoneEPUBReaderStore`.
- 2026-04-28: `xcodebuild -project Reader.xcodeproj -scheme ReaderiPhone -destination 'generic/platform=iOS Simulator' build` passed.
- 2026-04-28: `xcodebuild test -project Reader.xcodeproj -scheme Reader -destination 'platform=macOS'` passed: 203 Swift Testing tests. No dedicated `ReaderiPhoneTests` target exists in the project.
- 2026-04-28: Review fix cycle: closed highlight creation race by clearing/locking selection before awaits, added DB failure handling before in-memory/render updates, and tracked selection-overlap edit source separately from tapped-highlight edit source.
- 2026-04-28: Review fix cycle: replaced page-note page-start detection with inside-text-node binary search and transform restoration in JS.
- 2026-04-28: Re-ran `xcodebuild -project Reader.xcodeproj -scheme ReaderiPhone -destination 'generic/platform=iOS Simulator' build` — passed.
- 2026-04-28: Re-ran `xcodebuild test -project Reader.xcodeproj -scheme Reader -destination 'platform=macOS'` — passed: 203 Swift Testing tests.
- 2026-04-28: Post-fullscreen checkpoint confirmed old system `Menu` strings are no longer present in current source/installed iPhone build; remaining highlight/note UX refinements intentionally deferred to follow-up stories.

### Completion Notes

- Implemented current-chapter offset overlap matching for selections, reselection edit mode, duplicate highlight reuse/update, and active-color tap delete behavior.
- Added highlight-note flow that creates or reuses a highlight, then saves `TextNote.highlightId`; added page-note flow that saves `TextNote(highlightId: nil)` with `EPUBBook.makeOffsetAnchor(href:offset:)`.
- Added iPhone note-entry sheet, note action in highlight picker, page-note menu action, and picker placement that prefers below selection but moves above when lower space would cover or clip.
- Preserved existing annotation repository and model contracts; no database/schema changes.
- Review fixes resolved P1/P2 findings: rapid taps no longer create duplicate highlights, page-note offset anchors can land inside a text node, failed inserts no longer append/render phantom highlights or notes, selection-cleared no longer leaves stale reselection edit overlays, empty selected text restores with length 1, linked notes stay in memory after highlight delete with `highlightId` nil, and active color tap from selection-position edit picker deletes the existing highlight.
- Manual product check found remaining polish opportunities in highlight/note interactions; no blocking P0/P1/P2 issue is being carried in this story, and follow-up UX stories should handle refinements.

## File List

- ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift
- ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift
- ReaderiPhone/Features/Reader/IPhoneHighlightColorPicker.swift
- ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift

## Change Log

- 2026-04-28: Story created from unified Reader iPhone fixes plan.
- 2026-04-28: Implemented highlight duplicate prevention, edit/delete color semantics, highlight/page note entry, and offset-anchor note persistence; status set to review.
- 2026-04-28: Addressed Story B review P1/P2 findings and reran build/test verification.
- 2026-04-28: Focused re-review found no remaining P0/P1/P2 findings; status set to ready-for-review.
- 2026-04-28: Added final checkpoint note after fullscreen/root-shell stabilization; follow-up refinements deferred by product decision.
