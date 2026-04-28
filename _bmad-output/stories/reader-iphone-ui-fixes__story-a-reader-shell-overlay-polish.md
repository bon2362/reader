---
story_id: reader-iphone-ui-fixes-a
story_title: "Story A: Reader shell + overlay polish"
status: ready-for-review
source_plan: /Users/ekoshkin/reader/_bmad-output/bmad-help-unified-clarke.md
scope_items: "#1, #2, #3, #4, #7, #8, #9, #6.2"
---

# Story A: Reader shell + overlay polish

## Story

As an iPhone Reader user, I want the EPUB reader shell to use the full screen with unobtrusive floating controls, so reading feels native and the page itself remains the primary surface.

## Acceptance Criteria

1. Given an EPUB is opened on iPhone, when the reader appears, then the view hides the pushed navigation bar and the root reader surface ignores safe areas so there is no top white artifact or reduced content area.
2. Given reader text is displayed, when a chapter is loaded, then body text uses start alignment, not justified alignment.
3. Given the menu overlay is visible, when top and bottom controls render, then chapter title, counter, and action icons float without material/background panels.
4. Given a long chapter title, when the top overlay is visible, then the title is not forcibly truncated to one line and may wrap to two lines.
5. Given the user swipes down inside the EPUB web view, when the gesture is recognized, then the reader requests dismissal back to the library.
6. Given the highlight color picker is shown, when the picker renders, then there is no explicit xmark/cancel button.
7. Given the toolbar and overlay render after fullscreen fixes, when viewed on iPhone, then controls remain proportionate and do not appear oversized.

## Tasks / Subtasks

- [x] Update `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`
  - [x] Apply `.toolbar(.hidden, for: .navigationBar)` and root `.ignoresSafeArea()` to the root reader `ZStack`.
  - [x] Remove material/background panels from `menuOverlay` top and bottom bars while preserving readable floating controls.
  - [x] Change chapter title line limit from one line to wrapping up to two lines.
  - [x] Observe `store.requestDismiss` and call `dismiss()` when a downward swipe requests exit.
- [x] Update `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
  - [x] Change injected reader CSS from `text-align: justify` to `text-align: start`.
  - [x] Add a downward `UISwipeGestureRecognizer` alongside left/right gestures.
  - [x] Route downward swipe through the coordinator to the store.
- [x] Update `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
  - [x] Add reader dismissal state/method for the web view gesture.
- [x] Update `ReaderiPhone/Features/Reader/IPhoneHighlightColorPicker.swift`
  - [x] Remove the explicit dismiss/xmark button surface from the picker.
- [x] Check `ReaderiPhone/Features/Library/IPhoneLibraryView.swift`
  - [x] Replace system navigation/sheet reader presentation with root-state reader presentation after simulator validation exposed iPhone letterboxing/navigation container effects.
  - [x] Replace the iPhone library system navigation title/toolbar with a custom header so system large-title layout does not create excess top space.
- [x] Update `ReaderiPhone/App/IPhoneCompositionRoot.swift`
  - [x] Move iPhone EPUB/PDF reader ownership to root app state, outside `NavigationStack`.
- [x] Update `Reader.xcodeproj/project.pbxproj`
  - [x] Enable generated `UILaunchScreen` for the iPhone target to remove UIKit letterboxing on modern iPhone simulators/devices.
- [x] Run available build/typecheck/test verification.

## Dev Notes

- Do not introduce broad layout refactors outside `ReaderiPhone/Features/Reader/` unless needed for the listed AC.
- Preserve the existing 56px JS content padding; it keeps overlays from covering book text.
- Do not remove tap-to-menu behavior or edge tap page zones.
- iPhone fullscreen correctness depends on the app-level launch screen metadata as well as SwiftUI safe-area handling.
- Existing relevant files:
  - `Reader.xcodeproj/project.pbxproj`
  - `ReaderiPhone/App/IPhoneCompositionRoot.swift`
  - `ReaderiPhone/Features/Library/IPhoneLibraryView.swift`
  - `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`
  - `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
  - `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
  - `ReaderiPhone/Features/Reader/IPhoneHighlightColorPicker.swift`

## Dev Agent Record

### Debug Log

- Loaded BMad developer workflow and Story A context.
- Confirmed no `project-context.md` exists in repository.
- Verified `IPhoneLibraryView` only owns library `NavigationStack` destination and does not need a Story A fullscreen/padding change.
- Ran `xcodebuild -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme ReaderiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/reader-story-a-derived build`: **BUILD SUCCEEDED**.
- Review/fix cycle addressed P1 stuck picker risk with transparent backdrop dismissal around EPUB create/edit picker overlays.
- Review/fix cycle addressed P2 swipe-down dismissal during annotation state by guarding `requestReaderDismiss()` when selection/highlight/note editing is active.
- Review/fix cycle addressed P2 EPUB paragraph CSS override by adding scoped `#__reader_wrap p/li/blockquote { text-align: start !important; }`.
- Optional P3 evaluated: kept `IPhoneHighlightColorPicker.onDismiss` API for PDF call-site compatibility, but it still renders no explicit xmark/cancel surface.
- Ran `xcodebuild -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme ReaderiPhone -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/reader-story-a-review-derived build`: **BUILD SUCCEEDED**. Existing Swift 6 warnings about async `evaluateJavaScript` alternatives remain outside this story's scope.
- 2026-04-28: User simulator validation showed fullscreen UI still letterboxed despite reader overlay fixes. Root cause was missing generated `UILaunchScreen` metadata for the iPhone target plus system navigation/container presentation. Added generated launch screen, moved reader presentation to app root state, replaced iPhone library navigation shell with a custom header, and verified clean reinstall on iPhone 17 simulator removed black letterboxing.

### Completion Notes

- Reader root `ZStack` now ignores safe areas and keeps the pushed navigation bar hidden.
- Menu overlay top/bottom controls no longer render material panels; safe-area padding keeps floating controls readable.
- Chapter title can wrap to two centered lines.
- EPUB body CSS now uses `text-align: start`.
- Downward swipe in the EPUB web view routes through the coordinator to store dismissal state and the SwiftUI view dismisses.
- Highlight color picker no longer renders an explicit xmark/cancel button.
- Tapping outside EPUB highlight picker dismisses selection/editing without reintroducing a visible cancel control; picker taps remain handled by the picker.
- Swipe-down dismissal is ignored while `pendingSelection`, `editingHighlightId`, or `editingNoteId` is active.
- EPUB paragraph/list/blockquote text alignment now uses a scoped late `start !important` override inside `#__reader_wrap`.
- iPhone app now launches fullscreen because `ReaderiPhone` has generated `UILaunchScreen` metadata.
- EPUB/PDF readers are selected from root app state rather than pushed or sheet-presented from a `NavigationStack`, preventing system container offsets in the reader.
- iPhone library uses a custom header and no longer depends on system large-title navigation layout.

## File List

- `Reader.xcodeproj/project.pbxproj`
- `ReaderiPhone/App/IPhoneCompositionRoot.swift`
- `ReaderiPhone/Features/Library/IPhoneLibraryView.swift`
- `ReaderiPhone/Features/Reader/IPhonePDFReaderView.swift`
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`
- `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
- `ReaderiPhone/Features/Reader/IPhoneHighlightColorPicker.swift`
- `_bmad-output/stories/reader-iphone-ui-fixes__story-a-reader-shell-overlay-polish.md`

## Change Log

- 2026-04-28: Story created from unified Reader iPhone fixes plan.
- 2026-04-28: Implemented Story A fullscreen reader shell, panel-free overlay, chapter title wrapping, down-swipe dismissal, start-aligned EPUB text, and picker xmark removal; verified ReaderiPhone simulator build.
- 2026-04-28: Review/fix cycle resolved picker dismissal, annotation-state swipe guard, and scoped EPUB text-align override; verified ReaderiPhone simulator build again.
- 2026-04-28: Added app-level iPhone fullscreen stabilization: generated launch screen metadata, root-state reader presentation, custom iPhone library header, and clean simulator reinstall verification.
