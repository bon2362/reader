# Epics — Reader App iPhone Standalone MVP

**Источники:**
- [prd-reader-app.md](/Users/ekoshkin/reader/_bmad-output/project-docs/prd-reader-app.md)
- [sprint-change-proposal-2026-04-24.md](/Users/ekoshkin/reader/_bmad-output/feature-docs/ios-standalone/sprint-change-proposal-2026-04-24.md)
- [architecture-iphone-standalone-mvp.md](/Users/ekoshkin/reader/_bmad-output/feature-docs/ios-standalone/architecture-iphone-standalone-mvp.md)

**Дата:** 2026-04-24  
**Статус:** proposed  
**Scope note:** документ описывает standalone local-first iPhone MVP и отдельный follow-up для будущего sync layer.

---

## Краткий вывод

iPhone MVP для `Reader` больше не планируется как sync-first companion app. Новая цель MVP: запустить самостоятельное iPhone-приложение для локального чтения PDF без `CloudKit`, без зависимости от macOS и без зависимости от paid Apple Developer account.

Core flow MVP:

`local PDF import on iPhone -> local library -> open/read PDF -> restore progress -> local highlights`

---

## Требования и ограничения

### Функциональные требования

- FR1: Пользователь может импортировать локальный PDF прямо на iPhone через системный file picker.
- FR2: Импортированный PDF копируется в sandbox приложения и регистрируется в локальной библиотеке.
- FR3: Пользователь видит локальную библиотеку PDF на iPhone с базовыми метаданными и прогрессом чтения.
- FR4: Пользователь может открыть PDF из локальной библиотеки и читать его на iPhone.
- FR5: Приложение сохраняет и восстанавливает последнюю позицию чтения для PDF.
- FR6: Пользователь может создавать локальные highlights в PDF.
- FR7: Пользователь может видеть ранее сохранённые локальные highlights после повторного открытия книги.
- FR8: Пользователь может удалять локальные highlights.
- FR9: iPhone-приложение должно запускаться и работать независимо от macOS app.

### Нефункциональные требования

- NFR1: Boot path iPhone MVP не должен зависеть от `CloudKit`, entitlement checks и sync services.
- NFR2: Изменения для iPhone не должны ломать текущий macOS app на `main`.
- NFR3: Изменения для iPhone не должны ломать текущий annotation/export-import flow на `main`.
- NFR4: Разработка должна вестись от current `main` в новой ветке, а не как продолжение `codex/iphone-mvp-cloudkit`.
- NFR5: Donor branch может использоваться только как reference/donor isolated pieces, но не как merge base.
- NFR6: Sync metadata, sync-specific migrations и CloudKit DTO не должны попадать в MVP без отдельного этапа.
- NFR7: Архитектура MVP должна сохранить чёткую точку расширения для будущего sync layer.

### Архитектурные требования

- AR1: У iPhone должен быть отдельный composition root с local-only зависимостями.
- AR2: Shared local data layer должен публиковать только local-first API.
- AR3: `Reader/Sync` не должен участвовать в startup/import/open/read path standalone MVP.
- AR4: Shared между macOS и iPhone остаются local DB/repositories/models/PDF foundation после небольшого extraction.
- AR5: iPhone-specific UI и app flow должны жить в отдельном `ReaderiPhone` target.
- AR6: `PDFBookLoader` и/или `BookImporter` нужно разделить так, чтобы PDF import path стал iOS-safe.
- AR7: Reusable donor pieces из `codex/iphone-mvp-cloudkit` должны переноситься file-by-file с адаптацией под current `main`.

---

## Epic 1: iPhone Standalone Foundation

Поднять runnable iPhone target в текущем монорепо и выделить standalone local-first composition root без sync-зависимостей.

### Story 1.1: iPhone Target from Main and Local-Only App Shell

As a developer,  
I want to create a new iPhone app target from current `main` with a standalone app shell,  
So that iPhone work starts from a safe baseline and does not depend on donor branch state.

**Acceptance Criteria:**

- **Given** current `main` branch as the source baseline  
  **When** a new iPhone target is added to the project  
  **Then** the target is created from `main` in a new branch and not by continuing `codex/iphone-mvp-cloudkit`

- **Given** the new iPhone target exists  
  **When** the app starts  
  **Then** it launches through a dedicated iPhone app entry point and local-only composition root

- **Given** the iPhone app composition root is initialized  
  **When** dependencies are wired  
  **Then** no `Reader/Sync`, `CloudKit`, entitlement checks, or sync service selection are part of startup

- **Given** the project builds for iPhone Simulator  
  **When** the standalone target is compiled  
  **Then** platform-unsafe macOS-only app bootstrap code is not pulled into the iPhone target

### Story 1.2: Shared Local Core Extraction for iPhone Reuse

As a developer,  
I want to extract and adapt the local shared core needed by iPhone from current `main`,  
So that macOS and iPhone can reuse local models, repositories, and PDF primitives without sharing platform-specific UI code.

**Acceptance Criteria:**

- **Given** current shared code on `main`  
  **When** reusable local pieces are prepared for iPhone  
  **Then** `DatabaseManager`, local models, local repositories, `FileAccess`, and PDF anchor/geometry helpers remain reusable and local-first

- **Given** `PDFBookLoader` and `BookImporter` currently include AppKit-specific logic  
  **When** the shared PDF import/read core is extracted  
  **Then** iPhone receives an iOS-safe PDF path without pulling AppKit-only cover generation or macOS-only import UI into the target

- **Given** shared code is adapted for iPhone  
  **When** the macOS app is rebuilt or reviewed  
  **Then** existing macOS behavior remains intact

### Story 1.3: Local Persistence Boot for iPhone

As a developer,  
I want the iPhone app to boot with local database and repository dependencies only,  
So that the standalone MVP has a predictable offline-capable foundation.

**Acceptance Criteria:**

- **Given** the iPhone app starts for the first time  
  **When** the container is created  
  **Then** it initializes the local database and local repositories successfully without network prerequisites

- **Given** the local persistence layer is initialized  
  **When** the app opens the library screen  
  **Then** it can read the current local book list from the on-device database

- **Given** the iPhone app has no imported books yet  
  **When** the library screen is shown  
  **Then** the app presents a local-first empty state rather than sync or macOS-dependent messaging

---

## Epic 2: Local PDF Library and Reader

Закрыть основной standalone сценарий: пользователь импортирует PDF на iPhone, видит его в локальной библиотеке, открывает книгу и продолжает чтение с последней сохранённой позиции.

### Story 2.1: Local PDF Import on iPhone

As an iPhone reader,  
I want to import a PDF from local files into the app,  
So that I can start reading without using the Mac app or any sync pipeline.

**Acceptance Criteria:**

- **Given** the library screen is open  
  **When** the user chooses to import a PDF  
  **Then** the app opens a system file picker suitable for iPhone import

- **Given** the user selects a valid PDF  
  **When** the import is confirmed  
  **Then** the file is copied into the app sandbox and a local `Book` record is created in the database

- **Given** the PDF import completes successfully  
  **When** the library reloads  
  **Then** the imported book appears in the local library with PDF format metadata

- **Given** the user selects an invalid or unsupported file  
  **When** import handling runs  
  **Then** the app reports a local import error and does not create a broken library entry

### Story 2.2: Local Library UX for Standalone iPhone Use

As an iPhone reader,  
I want a library screen designed for standalone local reading,  
So that I can clearly see my imported PDFs and open them without sync-related confusion.

**Acceptance Criteria:**

- **Given** the user has no books in the app  
  **When** the library is shown  
  **Then** the empty state explains how to import a local PDF on iPhone and does not reference Mac import or CloudKit sync

- **Given** the user has one or more imported PDFs  
  **When** the library is shown  
  **Then** the screen displays each book with title, optional author/cover, and reading progress if available

- **Given** the user selects a locally available book  
  **When** they tap to open it  
  **Then** the app resolves a local file URL and navigates directly into the reader

- **Given** the book file is missing or unreadable locally  
  **When** the user attempts to open it  
  **Then** the app shows a local recovery error rather than attempting remote hydration

### Story 2.3: iPhone PDF Reader and Resume

As an iPhone reader,  
I want to open a PDF and return to where I left off,  
So that reading feels continuous across app launches on the same device.

**Acceptance Criteria:**

- **Given** a local PDF exists in the library  
  **When** the user opens it  
  **Then** the app renders the document in an iPhone PDF reader using a UIKit-compatible PDF view integration

- **Given** the reader is active  
  **When** the user changes pages or reading position  
  **Then** the app stores progress locally using the existing local repository path

- **Given** the user closes and later reopens the same PDF  
  **When** the reader restores state  
  **Then** the book opens at the last saved anchor/page from local storage

- **Given** the reader flow is implemented  
  **When** it is reviewed architecturally  
  **Then** there is no progress publication to sync services in the MVP reader path

---

## Epic 3: Local Highlights and MVP Polish

Довести standalone iPhone MVP до состояния usable local reader: локальные highlights, повторная загрузка annotations, базовая устойчивость и guardrails против регрессий в shared code.

### Story 3.1: Local Highlight Creation and Persistence

As an iPhone reader,  
I want to highlight text in a PDF and keep that highlight locally,  
So that I can mark important passages during reading without any sync dependency.

**Acceptance Criteria:**

- **Given** the user selects text in the iPhone PDF reader  
  **When** they choose a highlight action  
  **Then** the app creates a local highlight anchored to the PDF selection and stores it through the local annotation repository

- **Given** a new highlight is created  
  **When** the action completes  
  **Then** the highlight is rendered in the currently open PDF view

- **Given** the MVP highlight flow is implemented  
  **When** the code path is reviewed  
  **Then** highlight creation does not publish changes to any sync coordinator or remote service

### Story 3.2: Highlight Reloading, Rendering, and Deletion

As an iPhone reader,  
I want my previously saved highlights to reappear and be removable,  
So that local annotations stay consistent over time on the device.

**Acceptance Criteria:**

- **Given** a PDF has saved local highlights  
  **When** the user reopens the book  
  **Then** the app loads those highlights from local storage and renders them in the reader

- **Given** the user taps an existing highlight  
  **When** they choose to delete it  
  **Then** the highlight is removed from local storage and from the visible PDF rendering

- **Given** the user reopens the same book after deleting a highlight  
  **When** highlights are reloaded  
  **Then** deleted local highlights do not reappear

### Story 3.3: Standalone Stability, Edge Cases, and Guardrails

As a developer,  
I want the standalone MVP to be protected by clear runtime and architecture guardrails,  
So that the iPhone work stays local-first and does not regress the macOS app.

**Acceptance Criteria:**

- **Given** the standalone iPhone flow is implemented  
  **When** core paths are exercised  
  **Then** import, open, resume, and local highlight flows behave correctly after app relaunch

- **Given** the iPhone target shares code with macOS  
  **When** the change set is reviewed  
  **Then** existing macOS import, reading, and annotation exchange flows on `main` remain unaffected

- **Given** donor branch code is reused  
  **When** files are migrated  
  **Then** branch-specific sync migrations, CloudKit metadata, and sync-expanded repository contracts are not pulled into the standalone MVP

- **Given** the MVP branch is prepared for future work  
  **When** architecture boundaries are checked  
  **Then** sync remains an optional future extension and not part of the local boot path

---

## Epic 4: Future CloudKit Sync Layer

Этот эпик не входит в standalone MVP и существует как follow-up track после подтверждения local-first foundation.

### Story 4.1: Sync Extension Contracts on Top of Local Core

As a developer,  
I want to define sync-specific extension contracts on top of the local core,  
So that future sync can be added without rewriting the standalone iPhone UI and boot flow.

**Acceptance Criteria:**

- **Given** the standalone MVP is already local-first  
  **When** sync extension points are designed  
  **Then** they layer on top of local repositories instead of replacing local contracts

- **Given** future sync needs progress and highlight publication hooks  
  **When** those hooks are introduced  
  **Then** they are optional adapters or decorators and not mandatory dependencies of standalone app startup

### Story 4.2: CloudKit Book Catalog and Asset Sync

As a user with future cross-device sync enabled,  
I want my PDF catalog and file assets to sync through CloudKit,  
So that the same library can be available on both macOS and iPhone.

**Acceptance Criteria:**

- **Given** sync is implemented in a later phase  
  **When** book catalog and asset sync are added  
  **Then** they use a dedicated sync layer and dedicated metadata/schema work rather than silently modifying the standalone MVP boot path

- **Given** remote assets are introduced later  
  **When** hydration behavior is added  
  **Then** local-first reading remains valid for already local files

### Story 4.3: Predictable Progress Sync Policy

As a cross-device reader,  
I want progress sync to be predictable,  
So that switching devices does not cause surprising jumps or overwrite active local reading sessions.

**Acceptance Criteria:**

- **Given** a future sync-enabled app  
  **When** reading progress is published or applied  
  **Then** the system uses explicit progress rules and conflict policy rather than publishing on every local UI change by default

- **Given** a book is actively open on one device  
  **When** remote progress arrives from another device  
  **Then** the sync layer can defer or reconcile the remote change without destabilizing the active reader

### Story 4.4: Cross-Device Highlight Sync and Conflict Handling

As a cross-device reader,  
I want highlights to appear reliably across devices,  
So that my annotations stay consistent once sync is intentionally introduced.

**Acceptance Criteria:**

- **Given** future cross-device highlight sync is implemented  
  **When** create/delete flows are synchronized  
  **Then** the system uses explicit sync metadata, deletion handling, and conflict policy introduced in a dedicated sync phase

- **Given** highlight sync is introduced later  
  **When** the implementation is reviewed  
  **Then** it does not retroactively compromise the standalone-first architecture boundaries established in Epics 1-3

---

## Порядок реализации

1. Epic 1 полностью.
2. Epic 2 полностью.
3. Epic 3 полностью.
4. Epic 4 только после завершения и оценки standalone MVP.

Этот порядок отражает целевой продуктовый риск-reduction path:

- сначала runnable iPhone baseline from `main`;
- затем standalone import/library/reader value;
- затем local highlights и устойчивость;
- только после этого future sync.

---

## Что сознательно не входит в standalone MVP

- CloudKit и любой sync boot path
- remote hydration
- branch-specific sync migrations
- sync metadata в текущих `Book` / `Highlight` моделях `main`
- iPhone EPUB
- text notes на iPhone
- sticky notes на iPhone
- annotation panel на iPhone
- перенос donor branch как merge base

---

## Definition of Done для standalone MVP

Standalone iPhone MVP считается достигнутым, когда:

- существует отдельный runnable iPhone target в текущем монорепо;
- app boot local-only и не зависит от sync;
- пользователь может импортировать локальный PDF на iPhone;
- импортированный PDF появляется в локальной библиотеке;
- PDF открывается и читаетcя на iPhone;
- progress сохраняется и восстанавливается локально;
- highlights создаются, повторно загружаются и удаляются локально;
- изменения не ломают текущий macOS app и annotation/export-import flow на `main`.
