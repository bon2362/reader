---
title: 'PDF support'
type: 'feature'
created: '2026-04-20 21:41:40 CEST'
status: 'in-progress'
context:
  - '_bmad-output/planning-artifacts/pdf-support-plan.md'
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

## Tasks & Acceptance

**Execution:**
- [ ] `Reader/Shared/BookFormat.swift`, `Reader/Database/*`, `Reader/Features/Library/*` -- add PDF persistence/import foundation.
- [ ] `Reader/Features/PDFReader/*`, `Reader/Features/Reader/ReaderView.swift` -- render PDF, page, save progress, TOC/search, and sticky-note navigation.
- [ ] `ReaderTests/Features/PDFAnchorTests.swift`, `ReaderTests/Features/PDFBookLoaderTests.swift`, `ReaderTests/Features/PDFReaderStoreTests.swift` -- cover parsing/import/store edge cases.
- [ ] Run available verification and document any environment blocker.

**Acceptance Criteria:**
- Given an existing EPUB row, when the app loads it after migration, then `format` is `.epub` and existing opening flow remains unchanged.
- Given a PDF file, when the user imports it, then the library stores `format='pdf'`, cover/page count metadata, and opens a native PDF reader.
- Given a PDF reader session, when the user pages or reopens the book, then page indicator and saved position reflect the current PDF page.
- Given a PDF with outline/searchable text, when TOC/search are used, then selection navigates to the expected PDF page/result.
- Given an image-only PDF, when search/highlight text features are unavailable, then the app does not crash and sticky notes still work.

## Spec Change Log

## Verification

**Commands:**
- `xcodebuild test -project Reader.xcodeproj -scheme Reader -destination 'platform=macOS' -derivedDataPath /tmp/reader-derived` -- expected: test suite passes when full Xcode is selected.
