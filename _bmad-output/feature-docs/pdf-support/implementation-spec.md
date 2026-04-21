---
title: 'PDF support'
type: 'feature'
created: '2026-04-20 21:41:40 CEST'
status: 'in-progress'
context:
  - '_bmad-output/feature-docs/pdf-support/plan.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** slow reader currently imports and opens EPUB only; the MVP plan requires PDF books to live in the same library and use the same reader shell where feasible.

**Approach:** Add a `BookFormat` foundation, persist PDF books in the existing `books` table, and introduce a native PDFKit reader path that handles PDF opening, paging, TOC, search, page progress, and sticky notes while preserving the EPUB path.

## Boundaries & Constraints

**Always:** Preserve existing EPUB behavior; store anchors as opaque text; use repositories for persistence; use PDFKit with no new package dependency; keep new stores `@Observable @MainActor`.

**Ask First:** Any schema change beyond `books.format`; replacing EPUB bridge internals; OCR or PDF file mutation.

**Never:** WKWebView/JS for PDF rendering; direct GRDB access from views/stores; exporting annotations; OCR scanned PDFs.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| EPUB import/open | Existing EPUB file or existing DB row without `format` | Imports and opens as EPUB; legacy rows decode as `.epub` | Existing EPUB importer errors |
| PDF import/open | `.pdf` file with text layer | Copies PDF, extracts metadata/cover/page count, opens in native PDF view | User-facing localized import/open error |
| Unsupported import | Non-EPUB/PDF file | Import fails before repository insert | “Поддерживаются только EPUB и PDF” |
| Image-only PDF | PDF without document text | Opens and pages; search returns empty message; sticky notes still work | No crash |

</frozen-after-approval>

## Code Map

- `Reader/Shared/BookFormat.swift` -- book format enum and DB raw values.
- `Reader/Database/Models/Book.swift` -- persists `format` with legacy default `.epub`.
- `Reader/Database/Migrations/Migration_005.swift` -- adds `books.format`.
- `Reader/Database/DatabaseManager.swift` -- registers migration 005.
- `Reader/Shared/FileAccess.swift` -- copies/deletes PDF files alongside EPUBs.
- `Reader/Features/Library/BookImporter.swift` -- routes EPUB/PDF imports and extracts PDF metadata.
- `Reader/Features/Library/LibraryView.swift` -- allows selecting EPUB and PDF.
- `Reader/Features/Library/BookCardView.swift` -- shows PDF/image-only indicators.
- `Reader/Features/Reader/ReaderView.swift` -- dispatches EPUB vs PDF reader panes.
- `Reader/Features/PDFReader/*` -- PDFKit reader, loader, anchor, TOC/search/navigation helpers.
- `ReaderTests/Features/*PDF*Tests.swift` -- unit coverage for anchor, loader, and store behavior.

## Implemented Scope

The following PDF support is implemented in the codebase and exercised by automated tests plus manual QA passes:

- PDF import into the existing library flow with `BookFormat.pdf`, sandbox copy, bookmark handling, metadata extraction, cover thumbnail generation, and page count persistence.
- Shared reader shell dispatch between EPUB and PDF in `ReaderView`.
- Native PDF reader path based on `PDFKit` with vertical continuous scroll, page indicator, saved progress persistence, and reopen support plumbing.
- PDF outline parsing into shared TOC structures, PDF text search, and navigation from TOC/search/annotation panel into the PDF view.
- PDF highlights with persisted anchors, color changes, deletion, and re-render on reopen.
- PDF text notes with persisted anchors, inline underline marker, hover state, and note popover on click.
- PDF sticky notes stored by page and surfaced in the shared annotation panel.
- Image-only PDF detection with graceful degradation for text-only features.

## Compromises & Deviations

The implementation intentionally differs from the original plan in a few places:

- Rendering mode uses vertical continuous scroll instead of horizontal single-page paging because it tested better for the current UX.
- PDF anchors are page-based and text-range-based opaque strings, but rendering of highlights and note underlines currently uses per-line annotations rather than a single quad-point annotation object. This was chosen for better reliability on reopen.
- Back navigation for PDF links currently relies on native `PDFView` history rather than a custom cross-format navigation coordinator.
- The right-margin note icon overlay used in EPUB is not mirrored for PDF text notes; PDF uses inline underline markers and popovers directly on the page content.
- The shared annotation/search/TOC stores are reused, but parts of the PDF path still normalize coordinates and state separately from the EPUB bridge path.

## Tasks & Acceptance

**Execution:**
- [x] `Reader/Shared/BookFormat.swift`, `Reader/Database/*`, `Reader/Features/Library/*` -- add PDF persistence/import foundation.
- [x] `Reader/Features/PDFReader/*`, `Reader/Features/Reader/ReaderView.swift` -- render PDF, page, save progress, TOC/search, and sticky-note navigation.
- [x] `ReaderTests/Features/PDFAnchorTests.swift`, `ReaderTests/Features/PDFBookLoaderTests.swift`, `ReaderTests/Features/PDFReaderStoreTests.swift` -- cover parsing/import/store edge cases.
- [x] Run available verification and document any environment blocker.

**Acceptance Criteria:**
- Given an existing EPUB row, when the app loads it after migration, then `format` is `.epub` and existing opening flow remains unchanged.
- Given a PDF file, when the user imports it, then the library stores `format='pdf'`, cover/page count metadata, and opens a native PDF reader.
- Given a PDF reader session, when the user pages or reopens the book, then page indicator and saved position reflect the current PDF page.
- Given a PDF with outline/searchable text, when TOC/search are used, then selection navigates to the expected PDF page/result.
- Given an image-only PDF, when search/highlight text features are unavailable, then the app does not crash and sticky notes still work.

## Known Gaps / Follow-ups

- **PDF reopen position is not fully reliable yet.** Reading progress is persisted, but manual QA still reports reopening at the beginning for at least one real document. There is active defensive work in progress around `PDFView` reattachment and transient page-change events, but the acceptance criterion for reopen position should be treated as not fully closed.
- **PDF TOC behavior needs one more manual validation pass.** The inspected sample PDF contains a real outline entry, but manual UI verification previously showed only the book title. State-reset fixes landed, yet this still needs confirmation on the target document.
- **Continuous-scroll performance should be re-checked on larger documents.** The earlier full-document note-annotation rebuild issue was addressed, but a dedicated large-PDF sanity pass has not been completed after the subsequent reopen/navigation fixes.
- **Picker positioning polish remains imperfect across formats.** The current placement is acceptable but not final-quality, especially when comparing EPUB and PDF coordinate systems.
- **Image-only PDF support remains intentionally limited.** Search, text highlights, and text notes are unavailable without OCR, which is outside current scope.

## Spec Change Log

- 2026-04-21: Updated implemented scope to match the shipped PDF path, recorded current compromises, and captured unresolved reopen/TOC/performance follow-ups from QA and review.

## Verification

**Commands:**
- `xcodebuild test -project Reader.xcodeproj -scheme Reader -destination 'platform=macOS' -derivedDataPath /tmp/reader-derived-data` -- automated suite currently passes under full Xcode.

**Latest Result:**
- 2026-04-21: `126 tests passed` under full Xcode (`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`).
