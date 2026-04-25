# iPhone EPUB Reader — Code Review

**Date:** 2026-04-25  
**Reviewer:** Claude Code (automated iterative review)  
**Plan:** `docs/superpowers/plans/2026-04-24-iphone-epub-reader.md`  
**Files reviewed:**
- `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`
- `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`
- `ReaderiPhone/Features/Library/IPhoneLibraryView.swift`
- `ReaderiPhone/Features/Library/IPhoneLibraryStore.swift`
- `ReaderiPhone/Features/Library/IPhonePDFDocumentPicker.swift`
- `Reader/Features/Reader/EPUBBook.swift`
- `Reader/Bridge/NativeEPUBBridge.swift`
- `Reader.xcodeproj/project.pbxproj`

---

## Round 1

### Issues Found

| # | Severity | File | Issue |
|---|----------|------|-------|
| 1 | **Critical** | `project.pbxproj` | `BridgeTypes.swift` (defines `SearchResult`) not in iPhone Sources phase `5F620F138DF06118B2FA9502`. `EPUBBook.swift` references `SearchResult` in its `search()` method — compilation failure. |
| 2 | Best practice | `IPhoneEPUBReaderStore.swift` | `goToNextPage()` and `goToPreviousPage()` create `Task {}` with implicit strong capture of `self`, preventing deallocation during an in-flight async JS evaluation if the view is dismissed. |
| 3 | Best practice | `IPhoneEPUBReaderStore.swift` | `saveProgress()` inner `Task {}` implicitly captures `self` for the duration of a DB write. Better to capture only the values needed. |
| 4 | Cosmetic | `IPhoneLibraryStore.swift` | `prepareOpenBook` error messages said "Локальный **PDF** не найден" / "Локальный **PDF** недоступен для чтения" — wrong for EPUB files. |

### Fixes Applied

1. Added new `PBXBuildFile` entry `AA000008000000000000AA08` for `BridgeTypes.swift` (fileRef `EAFBAF0642BDFF843D5A322D`) and inserted it into Sources phase `5F620F138DF06118B2FA9502`.
2. Changed `Task {` → `Task { [weak self] in` with `guard let self else { return }` in both `goToNextPage()` and `goToPreviousPage()`.
3. In `saveProgress()`, extracted `bookID`, `repo`, `chapterNumber`, `chapterCount` into local `let` constants before the `Task {}`, eliminating the implicit `self` capture.
4. Replaced PDF-specific error strings with generic "Файл книги не найден / недоступен для чтения".

**Commit:** `8e338b2` — `fix: add BridgeTypes to iPhone target, weak self in Tasks, generic error messages`

---

## Round 2

### Issues Found

| # | Severity | File | Issue |
|---|----------|------|-------|
| 5 | **Logic bug** | `IPhoneEPUBReaderStore.swift` | `handleMessage("ready")` set `totalInChapter = max(1, total)` where `total` was always 1 (the `ready` JS message carries no `totalPages` field). Because the JS always posts `pageChanged` (with the correct `totalPages`) immediately before posting `ready`, processing order is `pageChanged → ready`, so `ready` silently overwrote the correct page count with 1. Result: the page counter displayed "1 / 1" for every chapter on initial load. |

### Fix Applied

Removed the two lines:
```swift
let total = (data["totalPages"] as? Int) ?? 1
totalInChapter = max(1, total)
```
from the `ready` case. `totalInChapter` is exclusively owned by the `pageChanged` handler, which already sets it correctly before `ready` arrives.

**Commit:** `1def15f` — `fix: ready handler must not reset totalInChapter to 1`

---

## Round 3 (Final Pass)

No new issues found. Confirmed:

- **Swift errors:** All symbols resolve. `SearchResult` available via `BridgeTypes.swift` in iPhone target. All protocol requirements satisfied (`LibraryRepositoryProtocol`, `AnnotationRepositoryProtocol`, `EPUBBookLoader`, `EPUBBook.*`). ZIPFoundation linked in iPhone Frameworks phase.
- **Retain cycles:** `MessageHandler.store` is `weak`; Tasks in `goToNextPage`/`goToPreviousPage` use `[weak self]`; `saveProgress` Task uses value captures only.
- **WKWebView lifecycle:** `dismantleUIView` removes the `"native"` script message handler and nulls `MessageHandler.store` — no ghost handler leak.
- **pbxproj Sources phase `5F620F138DF06118B2FA9502`:** Contains all 5 required files: `EPUBBook.swift`, `BridgeTypes.swift`, `IPhoneEPUBWebView.swift`, `IPhoneEPUBReaderStore.swift`, `IPhoneEPUBReaderView.swift`.
- **Logic:**
  - `pendingRestorePage == Int.max` → calls `goToLastPage()` → JS fires `pageChanged` → `pageInChapter` updated. ✓
  - `pendingRestorePage > 0` → calls `goToPage(page)`, sets `pageInChapter = page` optimistically, confirmed by subsequent `pageChanged`. ✓
  - `pendingRestorePage == 0` → no JS call, stays at page 0. `pageChanged` from initial `reportPage()` already set correct `totalInChapter`. ✓
  - `saveProgress` guard: `epub.chapters.indices.contains(currentChapterIndex)` before accessing the array. ✓
  - Cross-chapter boundary: `advanceChapter(by: 1)` only called when `!result.didMove && result.after >= result.totalPages - 1` (on last page, can't go further). `advanceChapter(by: -1)` only called when `!result.didMove && result.after == 0` (on first page, can't go back). ✓
- **Plan coverage (all 6 tasks):**
  - Task 1: CFI helpers (`makePageAnchor`, `makeOffsetAnchor`) in `EPUBBook`; `NativeEPUBBridge` delegates. ✓
  - Task 2: `IPhoneEPUBWebView` with full `readerJS`, `MessageHandler`, lifecycle. ✓
  - Task 3: `IPhoneEPUBReaderStore` with chapter/page navigation, position save/restore. ✓
  - Task 4: `IPhoneEPUBReaderView` with WebView + page controls + chapter title. ✓
  - Task 5: `IPhoneLibraryView` routes `book.format == .epub` to `IPhoneEPUBReaderView`. ✓
  - Task 6: `IPhonePDFDocumentPicker` accepts EPUB; `importBook` validates both formats; UI labels updated. ✓

### Known Limitation (out of scope)

`EPUBBookLoader.load(from:)` is a synchronous throwing function and runs on the `@MainActor` in both the macOS `NativeEPUBBridge` and the new `IPhoneEPUBReaderStore`. For large EPUB files, unzipping blocks the main thread for several hundred milliseconds. This is an existing pre-condition of the architecture; fixing it would require wrapping the call in `Task.detached` and is outside the scope of this feature.

---

## Verdict

**APPROVED.** Two rounds of fixes addressed one build-breaking symbol error (`SearchResult` undefined) and one logic bug causing incorrect page-count display. The implementation is complete, all 6 plan tasks are done, no retain cycles, WKWebView lifecycle is clean, and the pbxproj correctly includes all required files.
