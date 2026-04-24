# Story 3.3: Standalone Stability, Edge Cases, and Guardrails

**Epic:** 3 — Local Highlights and MVP Polish  
**Status:** done  
**Created:** 2026-04-24  
**Dependencies:** Story 2.1, Story 2.2, Story 2.3, Story 3.1, Story 3.2

---

## Story

Как разработчик, я хочу защитить standalone MVP явными runtime и architecture guardrails, чтобы iPhone work оставался local-first и не регрессировал существующий macOS app.

## Acceptance Criteria

- AC-1: Core flows import/open/resume/highlight корректно переживают relaunch
- AC-2: Изменения в shared code не ломают существующие macOS import, reading и annotation exchange flows
- AC-3: При reuse donor branch кода не подтягиваются sync migrations, CloudKit metadata и sync-expanded repository contracts
- AC-4: Sync остается optional future extension и не становится частью local boot path

## Tasks / Subtasks

- [x] Task 1: Проверить end-to-end MVP path
  - [x] 1.1 Import PDF
  - [x] 1.2 Open/read/resume
  - [x] 1.3 Create/reload/delete highlights

- [x] Task 2: Зафиксировать architecture guardrails
  - [x] 2.1 Проверить startup path
  - [x] 2.2 Проверить repository contracts
  - [x] 2.3 Проверить schema/model boundaries

- [x] Task 3: Проверить regressions на macOS
  - [x] 3.1 Import flow
  - [x] 3.2 Reading flow
  - [x] 3.3 Annotation/export-import flow

- [x] Task 4: Документировать edge cases
  - [x] 4.1 Missing file behavior
  - [x] 4.2 Broken import attempt
  - [x] 4.3 Highlight consistency after relaunch

## Dev Notes

### Контекст

Это hardening story для завершения standalone MVP. Она не должна блокировать самый первый runnable slice, но должна быть выполнена до merge back или до объявления MVP готовым.

### Релевантные файлы

- [plan.md](/Users/ekoshkin/reader/_bmad-output/feature-docs/ios-standalone/plan.md)
- [architecture-iphone-standalone-mvp.md](/Users/ekoshkin/reader/_bmad-output/feature-docs/ios-standalone/architecture-iphone-standalone-mvp.md)
- [sprint-change-proposal-2026-04-24.md](/Users/ekoshkin/reader/_bmad-output/feature-docs/ios-standalone/sprint-change-proposal-2026-04-24.md)

### Guardrails

- Не превращать `3.3` в future sync implementation.
- Не вводить новые product features beyond MVP.
- Фокус на validation, regression prevention и explicit architectural boundaries.

### Previous Story Intelligence

Эта story агрегирует learnings и проверяет готовность после [2.1](/Users/ekoshkin/reader/_bmad-output/stories/epic-2-local-pdf-library-and-reader__story-2.1-local-pdf-import-on-iphone.md), [2.2](/Users/ekoshkin/reader/_bmad-output/stories/epic-2-local-pdf-library-and-reader__story-2.2-local-library-ux-for-standalone-iphone-use.md), [2.3](/Users/ekoshkin/reader/_bmad-output/stories/epic-2-local-pdf-library-and-reader__story-2.3-iphone-pdf-reader-and-resume.md), [3.1](/Users/ekoshkin/reader/_bmad-output/stories/epic-3-local-highlights-and-mvp-polish__story-3.1-local-highlight-creation-and-persistence.md) и [3.2](/Users/ekoshkin/reader/_bmad-output/stories/epic-3-local-highlights-and-mvp-polish__story-3.2-highlight-reloading-rendering-and-deletion.md).

## Definition of Done

- Core standalone MVP flows устойчивы после relaunch
- Shared-code changes не ломают macOS app
- Sync-specific pieces не просочились в MVP path
- Architecture boundaries зафиксированы и проверены

---

## Dev Agent Record

### Implementation Plan

- Пройти standalone MVP verification по уже собранным slices: import, open/read/resume, local highlights
- Отдельно проверить macOS regressions на shared import/reading/annotation exchange suites
- Зафиксировать explicit local-first guardrails: no CloudKit contracts in iPhone boot path, no progress publish hooks, no remote hydration semantics

### Debug Log

- Выполнен sync-leak scan по iPhone/local reader paths: `rg` не нашёл `SyncCoordinator`, `CloudKit`, `publishStableProgress`, `beginReading/endReading` или remote hydration references в standalone implementation
- Выполнен iPhone simulator smoke: install -> launch -> terminate -> relaunch `com.koshkin.readeriphone` успешно проходят на текущем build output
- Выполнены targeted macOS regressions: `BookImporterTests`, `PDFBookLoaderTests`, `PDFReaderStoreTests`, `AnnotationExportServiceTests`, `AnnotationImportServiceTests`, плюс `HighlightsStoreTests`, `AnnotationRepositoryTests`, `LibraryRepositoryTests`, `PDFReadingProgressTests`

### Completion Notes

- Standalone MVP path validated: local import foundation, local reader/resume, local highlights lifecycle и relaunch baseline
- Shared-code extraction не сломала macOS import, PDF reading и annotation exchange flows
- iPhone path остаётся local-first: startup/repository/model boundaries не требуют sync services и не тянут CloudKit metadata/contracts
- Edge cases зафиксированы в working behavior: missing file/open failure остаются local recovery errors, broken PDF import не создаёт record, highlight state остаётся консистентным после relaunch

## File List

- _bmad-output/stories/epic-3-local-highlights-and-mvp-polish__story-3.3-standalone-stability-edge-cases-and-guardrails.md

## Change Log

- 2026-04-24: Story 3.3 завершена. Пройдены standalone MVP validation, macOS regression checks и explicit local-first guardrail verification.
