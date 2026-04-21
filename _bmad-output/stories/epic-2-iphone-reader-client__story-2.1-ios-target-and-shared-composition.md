# Story 2.1: iOS Target & Shared Composition

**Epic:** 2 — iPhone Reader Client  
**Status:** ready for review  
**Created:** 2026-04-21

---

## Story

Как разработчик, я хочу добавить iOS target и вынести общий слой между macOS и iPhone, чтобы не дублировать доменную логику библиотеки, sync и reader state.

## Acceptance Criteria

- AC-1: В проекте есть iOS target, который собирается отдельно от macOS
- AC-2: Общие модели, repository-протоколы и sync layer переиспользуются между платформами
- AC-3: macOS-специфичные части (`AppKit`, `NSViewRepresentable`, hover) не протекают в shared слой
- AC-4: У iOS target есть базовая композиция приложения: launch -> library screen
- AC-5: Решение реализовано в том же репозитории, без вынесения iPhone app или sync слоя в отдельный repo

## Tasks / Subtasks

- [x] Task 1: Добавить iOS target в проект
- [x] Task 2: Вынести shared code в платформенно-нейтральные модули/группы
- [x] Task 3: Изолировать macOS-only реализации
- [x] Task 4: Собрать базовый iPhone app shell
- [x] Task 5: Зафиксировать структуру monorepo в `project.yml`/документации

## Dev Notes

- Текущий проект содержит много `AppKit`-зависимостей в import flow и PDF UI
- Shared boundary нужно выстроить до полноценной iPhone-реализации, иначе потом будет дорогой рефакторинг
- Предпочтительная форма для MVP: один репозиторий, два app targets, shared/sync directories внутри того же Xcode проекта

---

## Dev Agent Record

### Implemented

- В `project.yml` добавлен отдельный iOS target `ReaderiPhone`; проект пересобирается через `xcodegen`.
- Общие модели, репозитории, migrations и sync layer переиспользуются между macOS и iPhone в пределах одного репозитория.
- `PDFHighlightRenderer` адаптирован под платформенные импорты, чтобы shared PDF-highlight слой компилировался и на iOS, и на macOS.
- Добавлен базовый iPhone app shell `ReaderiPhoneApp` + library screen composition.

### Verification

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -quiet -project /Users/ekoshkin/reader/Reader.xcodeproj -scheme ReaderiPhone -destination 'generic/platform=iOS' -derivedDataPath /tmp/reader-derived-data-ios CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' DEVELOPMENT_TEAM=''`

### File List

- /Users/ekoshkin/reader/project.yml
- /Users/ekoshkin/reader/Reader/Features/PDFReader/PDFHighlightRenderer.swift
- /Users/ekoshkin/reader/ReaderiPhone/App/ReaderiPhoneApp.swift
- /Users/ekoshkin/reader/ReaderiPhone/Features/IPhoneLibraryView.swift
- /Users/ekoshkin/reader/ReaderiPhone/Features/IPhoneLibraryViewModel.swift
