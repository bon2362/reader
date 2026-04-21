# Reader

`Reader` is a native macOS reading app for EPUB and PDF books with local persistence, annotations, and a lightweight library workflow.

The app is built with SwiftUI for the interface, PDFKit for PDF rendering, and GRDB/SQLite for on-disk storage.

## Features

- Import EPUB and PDF files into a local library
- Read EPUB books with table of contents, page navigation, and search
- Read PDF books with saved reading position and table of contents state
- Create highlights, text notes, and sticky notes
- Browse and manage saved annotations in a side panel
- Persist books, reading progress, and annotations locally

## Tech Stack

- Swift 6
- SwiftUI
- macOS 14+
- PDFKit
- [GRDB.swift](https://github.com/groue/GRDB.swift)
- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation)

## Getting Started

### Requirements

- macOS 14 or newer
- Xcode 16 or newer

### Open the project

Open [Reader.xcodeproj](/Users/ekoshkin/reader/Reader.xcodeproj) in Xcode and run the `Reader` scheme.

### Build from Terminal

```bash
xcodebuild -project Reader.xcodeproj -scheme Reader -destination 'platform=macOS'
```

### Run tests

```bash
xcodebuild test -project Reader.xcodeproj -scheme Reader -destination 'platform=macOS'
```

## Project Structure

- [Reader/App](/Users/ekoshkin/reader/Reader/App) - app entry point and top-level composition
- [Reader/Features/Library](/Users/ekoshkin/reader/Reader/Features/Library) - import flow and library UI
- [Reader/Features/Reader](/Users/ekoshkin/reader/Reader/Features/Reader) - EPUB reader, navigation, search, TOC
- [Reader/Features/PDFReader](/Users/ekoshkin/reader/Reader/Features/PDFReader) - PDF loading, rendering, and markup overlays
- [Reader/Features/Annotations](/Users/ekoshkin/reader/Reader/Features/Annotations) - highlights, notes, annotation panel
- [Reader/Database](/Users/ekoshkin/reader/Reader/Database) - SQLite setup, models, and migrations
- [ReaderTests](/Users/ekoshkin/reader/ReaderTests) - unit tests

## Notes for Development

The repository includes a checked-in Xcode project and a source-of-truth [project.yml](/Users/ekoshkin/reader/project.yml) for XcodeGen-style project configuration.

Planning and product documents live under [_bmad-output/project-docs](/Users/ekoshkin/reader/_bmad-output/project-docs), including:

- [PRD](/Users/ekoshkin/reader/_bmad-output/project-docs/prd-reader-app.md)
- [Architecture](/Users/ekoshkin/reader/_bmad-output/project-docs/architecture-reader-app.md)
- [Epics](/Users/ekoshkin/reader/_bmad-output/project-docs/epics-reader-app-mvp.md)

## Status

This project is currently focused on the core macOS reading experience: library management, EPUB/PDF reading, navigation, search, and annotations.
