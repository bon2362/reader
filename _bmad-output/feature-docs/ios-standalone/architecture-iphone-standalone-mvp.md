# Architecture Scope: iPhone Standalone Local-First MVP

**Дата:** 24.04.2026  
**Статус:** Proposed  
**Supersedes in direction:** `architecture-iphone-mvp.md` as the architecture basis for the first iPhone MVP  
**Inputs:**
- `/Users/ekoshkin/reader/_bmad-output/feature-docs/ios-standalone/sprint-change-proposal-2026-04-24.md`
- `/Users/ekoshkin/_bmad-output/feature-docs/ios-standalone/iphone-cloudkit-branch-checkpoint.md`
- current `main` codebase

## 1. Краткий архитектурный вывод

Первый iPhone MVP нужно строить как **standalone local-first app target внутри текущего монорепо**, начиная от `main` в новой ветке. В MVP не должно быть `CloudKit`, sync boot path, entitlement checks и sync-specific schema pressure.

Практическое следствие:

- iPhone app получает собственный composition root и собственный UI flow;
- локальная база, local file storage, PDF foundation и highlight/progress persistence остаются в общем reusable слое;
- sync проектируется только как **будущий extension layer**, который подключается позже и не участвует в boot path, import path или open/read path MVP;
- donor branch `codex/iphone-mvp-cloudkit` используется как **reference/donor of isolated pieces**, но не как merge base и не как источник branch-wide migrations.

## 2. MVP Outcome и Architectural Drivers

### 2.1 Целевой MVP outcome

iPhone app должен:

- работать независимо от macOS;
- запускаться без paid Apple Developer account;
- не зависеть от `CloudKit`;
- закрывать сценарий:
  `local PDF import on iPhone -> local library -> open/read PDF -> restore progress -> local highlights`.

### 2.2 Нефункциональные драйверы

- не ломать существующий macOS app на `main`;
- не ломать текущий annotation/export-import flow;
- не тащить sync metadata и branch migrations до отдельного этапа;
- сохранить возможность будущего CloudKit sync без переписывания iPhone UI заново;
- минимизировать divergence между macOS и iPhone в local domain/data logic.

## 3. Целевая модульная и слойная структура

### 3.1 Repository-level shape

Новая реализация должна остаться в текущем Xcode project/monorepo, но с явной архитектурной декомпозицией.

```text
Reader/                             macOS app + shared local core from main
  App/                              macOS composition root
  Features/Library                  existing macOS library UX + import/export flows
  Features/Reader                   existing EPUB/macOS reading flow
  Features/PDFReader                shared PDF reader core + macOS PDF UI pieces
  Features/Annotations              shared annotation stores + macOS annotation UI pieces
  Database/                         GRDB schema + migrations
  Shared/                           file access, hashing, format helpers
  Bridge/                           EPUB bridge

ReaderiPhone/                       new iPhone app target
  App/
    ReaderiPhoneApp.swift
    IPhoneAppContainer.swift
    IPhoneCompositionRoot.swift
  Features/Library/
    IPhoneLibraryView.swift
    IPhoneLibraryStore.swift
    IPhoneImportCoordinator.swift
  Features/Reader/
    IPhonePDFReaderScreen.swift
    IPhonePDFViewAdapter.swift
  Features/Navigation/
    IPhoneRoute.swift

Reader/Features/LocalLibraryCore/   optional extraction target/group from main code
Reader/Features/LocalReaderCore/    optional extraction target/group from main code
Reader/Sync/                        future only, not linked into iPhone MVP boot path
```

### 3.2 Layer boundaries

#### Shared local data layer

Отвечает за:

- `DatabaseManager`;
- `Book`, `Highlight`, local note models;
- `LibraryRepositoryProtocol` и `AnnotationRepositoryProtocol`;
- file storage helpers в `Reader/Shared`;
- PDF anchor/geometry/helper logic;
- local progress persistence;
- local highlight CRUD и render-agnostic state.

Не отвечает за:

- screen navigation;
- iPhone document picker/import UX;
- sync orchestration;
- CloudKit DTO/mappers/metadata.

#### iPhone-specific UI/app flow

Отвечает за:

- iPhone app lifecycle и composition root;
- document picker / share-sheet / file-import UX;
- local library list, empty states, open flow;
- `PDFView` integration через `UIViewRepresentable`;
- mobile navigation, toolbar/actions, scene restoration.

Не отвечает за:

- schema evolution под sync;
- remote hydration;
- sync conflict resolution;
- macOS-specific import/export UI.

#### Future sync extension layer

Отвечает за:

- `SyncCoordinator`, sync service abstraction, CloudKit adapters;
- remote DTO/mappers;
- tombstones, remote merge, remote hydration, retry/diagnostics;
- optional sync-specific repository extensions.

Не отвечает за:

- создание local app container по умолчанию;
- import/open/read boot path;
- обязательную доступность книги для чтения на iPhone.

## 4. Что остаётся shared между macOS и iPhone

### 4.1 Должно остаться общим

- `Reader/Database/DatabaseManager.swift`
- `Reader/Database/Models/Book.swift`
- `Reader/Database/Models/Highlight.swift`
- `Reader/Features/Library/LibraryRepository.swift`
- `Reader/Features/Annotations/AnnotationRepository.swift`
- `Reader/Features/Annotations/HighlightsStore.swift`
- `Reader/Features/PDFReader/PDFAnchor.swift`
- `Reader/Features/PDFReader/PDFMarkupGeometry.swift`
- local PDF metadata/import primitives after AppKit split from `PDFBookLoader` / `BookImporter`
- `Reader/Shared/FileAccess.swift`
- `Reader/Shared/BookFormat.swift`

### 4.2 Должно остаться platform-specific

macOS-specific:

- `Reader/App/ContentView.swift`
- `Reader/Features/Library/LibraryView.swift`
- `Reader/Features/Library/BookImporter.swift` in current form because it imports `AppKit`
- `Reader/Features/PDFReader/NativePDFView.swift`
- `Reader/Features/PDFReader/PDFReaderView.swift`
- `Reader/Features/PDFReader/PDFTextNoteRenderer.swift`
- export/import UI flows for annotations

iPhone-specific:

- `ReaderiPhone/App/*`
- `ReaderiPhone/Features/Library/*`
- `ReaderiPhone/Features/Reader/*`
- `UIViewRepresentable` wrapper around `PDFView`
- document picker and security-scoped file import coordination

### 4.3 Условно shared, но только после небольшой extraction

- `Reader/Features/PDFReader/PDFBookLoader.swift`
  Сейчас использует `AppKit` для cover generation и потому должен быть split into:
  - cross-platform PDF metadata/import core;
  - platform-specific cover rendering helper.

- `Reader/Features/Library/BookImporter.swift`
  Сейчас объединяет EPUB/PDF import и macOS-only cover conversion; для iPhone MVP безопасно переносить только PDF import path после extraction.

## 5. Reusable pieces from `codex/iphone-mvp-cloudkit`

### 5.1 Можно безопасно переиспользовать с минимальной адаптацией

- `ReaderiPhone/Features/IPhonePDFKitView.swift`
  Хорошая `UIViewRepresentable`-обёртка вокруг `PDFView`.

- `ReaderiPhone/Features/IPhonePDFReaderView.swift`
  Полезна как donor для screen structure, toolbar/actions и PDF event wiring, но только после удаления `SyncCoordinator` из init и page/highlight flow.

- `ReaderiPhone/Features/IPhoneLibraryView.swift`
  Полезна как donor для первого iPhone library screen/layout.

- `Reader/Features/PDFReader/PDFAnchor.swift`
- `Reader/Features/PDFReader/PDFHighlightRenderer.swift`
- `Reader/Features/PDFReader/PDFMarkupGeometry.swift`
  Эти части уже подтверждены checkpoint как practical PDF foundation для iPhone.

- идея отдельного iPhone target в `project.yml`
  Сам target strategy правильный и совместим с новым курсом.

### 5.2 Можно переиспользовать как reference, но не copy-paste as-is

- `ReaderiPhone/Features/IPhoneLibraryViewModel.swift`
  Нужна полная local-first rewrite.

- `Reader/App/AppContainer.swift` из donor branch
  Полезен как reference по составу зависимостей, но сам контейнер нельзя переносить.

- `Reader/Sync/DisabledSyncService.swift`
  Может пригодиться только на future sync stage, не в standalone MVP.

## 6. Что нельзя переносить как есть

### 6.1 Sync-coupled composition

Нельзя переносить:

- donor `Reader/App/AppContainer.swift`
- любой boot code с `SecTaskCreateFromSelf`, entitlement detection и `CloudKitSyncService` auto-wiring

Почему:

- ломает platform safety для iPhone;
- делает sync частью startup path;
- нарушает требование "no paid Apple Developer account dependency".

### 6.2 Sync-expanded repository contracts

Нельзя переносить как есть donor-версию:

- `Reader/Features/Library/LibraryRepository.swift`
- sync-expanded `AnnotationRepository` APIs

Почему:

- local CRUD и remote lifecycle смешаны в одном контракте;
- это подтягивает sync semantics в shared local layer слишком рано.

### 6.3 Sync-specific schema/model changes

Нельзя переносить как есть donor-версию:

- `Reader/Database/Models/Book.swift`
- `Reader/Database/Models/Highlight.swift`
- donor migrations adding `content_hash`, `sync_state`, `remote_record_name`, tombstones, remote progress timestamps

Почему:

- это отдельный schema track;
- он конфликтует с current `main`;
- он меняет invariants и write paths существующего macOS flow.

### 6.4 Sync-first iPhone UX

Нельзя переносить:

- `syncOnLaunch()`
- `hydrateAssetIfNeeded(for:)`
- empty states вида "импортируйте PDF на Mac"
- progress/highlight publication в `SyncCoordinator` из reader path

Почему:

- это противоречит standalone MVP;
- boot/read path теряет локальную автономность.

## 7. Composition root для iPhone standalone app

### 7.1 Принцип

У iPhone должен быть **отдельный composition root**, собирающий только local dependencies.

### 7.2 Proposed composition

`ReaderiPhoneApp -> IPhoneAppContainer -> local feature stores/screens`

`IPhoneAppContainer` создаёт:

- `DatabaseManager.onDisk()`
- `LibraryRepository(database:)`
- `AnnotationRepository(database:)`
- `IPhoneImportCoordinator`
- `IPhoneLibraryStore`
- `ReaderStoreFactory` or `IPhonePDFReaderFactory`

### 7.3 Explicit no-sync rule for MVP

`IPhoneAppContainer` не должен:

- импортировать `Reader/Sync/*`;
- знать о `CloudKitSyncService`;
- определять entitlement;
- выбирать между enabled/disabled sync service;
- публиковать progress/highlights вовне.

### 7.4 Boot sequence

```text
App launch
-> initialize local database
-> initialize local repositories
-> load local library
-> render iPhone library screen
-> user imports local PDF
-> file copied to sandbox
-> Book inserted into local DB
-> open local PDF reader
-> persist progress/highlights locally
```

## 8. Граница между shared local data, iPhone flow и future sync

### 8.1 Shared local data contract

Shared local layer должен публиковать только local-first API:

- fetch library
- import local book
- fetch local file URL
- update local progress
- fetch/insert/update/delete local highlights

Никаких:

- `fetchPendingSync`
- `applyRemoteUpsert`
- `markSynced`
- `hydrateAsset`
- `publishStableProgress`

в базовом MVP контракте быть не должно.

### 8.2 iPhone app flow contract

iPhone layer должен зависеть только от:

- local repositories;
- local file resolver;
- PDF rendering adapters;
- local stores/use-cases.

Если позже sync появится, iPhone flow может получить **дополнительные optional adapters**, но только через отдельный extension point, например:

- `ReadingProgressPublisher?`
- `HighlightChangePublisher?`
- `RemoteLibrarySyncing?`

По умолчанию эти зависимости в standalone MVP равны `nil` и не участвуют в логике.

### 8.3 Future sync extension layer

Будущий sync должен подключаться как:

- отдельный `SyncCompositionRoot`;
- отдельные repository adapters или decorator layer;
- отдельные migrations только в dedicated sync phase;
- отдельный epic/branch plan после standalone MVP.

Ключевое правило:

**sync decorates local system, but never becomes the local system.**

## 9. Minimal runnable architecture slice

### 9.1 Slice definition

Минимальный runnable slice для первого standalone MVP:

1. Новый `ReaderiPhone` target из `main`.
2. Local-only app container.
3. iPhone library screen с local empty state.
4. iPhone PDF import через system document picker / file importer.
5. Copy imported PDF into app sandbox via `FileAccess`.
6. Insert `Book(format: .pdf)` into existing local DB.
7. Open PDF in `PDFView`.
8. Restore progress from `Book.lastCFI/currentPage`.
9. Save progress locally via `LibraryRepository.updateReadingProgress`.
10. Create/delete local highlights via `HighlightsStore` + `AnnotationRepository`.

### 9.2 Что intentionally вне slice

- sync services;
- remote hydration;
- iPhone EPUB;
- text notes / sticky notes on iPhone;
- cross-device anything;
- schema changes for sync metadata.

## 10. File/module-level migration strategy from donor branch

### 10.1 Branch strategy

- создать новую ветку от current `main`;
- donor branch использовать только через selective cherry-pick by file/content or manual copy;
- не делать merge/rebase от `codex/iphone-mvp-cloudkit`.

### 10.2 Recommended migration order

#### Phase 1. Introduce iPhone target skeleton

- адаптировать `project.yml` для нового `ReaderiPhone` target
- добавить `ReaderiPhone/App/ReaderiPhoneApp.swift`
- добавить минимальный local-only container

Правило:

- target initially includes only local-safe files from `Reader/Database`, `Reader/Shared`, selected `Reader/Features/PDFReader`, selected `Reader/Features/Annotations`, plus `ReaderiPhone/*`

#### Phase 2. Extract cross-platform PDF import/read core from main

- split `PDFBookLoader` на shared core и platform-specific cover helper
- выделить iOS-safe PDF import path
- при необходимости split `BookImporter` so iPhone imports PDF only

#### Phase 3. Port iPhone UI donor pieces after decoupling

- перенести `IPhonePDFKitView`
- перенести `IPhoneLibraryView`
- переписать `IPhoneLibraryViewModel` в `IPhoneLibraryStore` без sync
- переписать `IPhonePDFReaderView` без `SyncCoordinator`

#### Phase 4. Wire local highlight/progress persistence

- подключить `HighlightsStore`
- подключить local page/progress persistence
- подтвердить reopen/resume behavior

#### Phase 5. Harden boundaries

- убедиться, что `ReaderiPhone` target не линкует `Reader/Sync`
- добавить tests for local import/progress/highlights
- зафиксировать extension seams for future sync, but without implementation

### 10.3 Preferred migration mechanism per area

- `project.yml`: manual edit based on donor reference
- `ReaderiPhone/*`: file-by-file donor import with rewrite
- `Reader/Features/PDFReader/*`: selective extraction, not overwrite from donor
- `Reader/Database/*`: reuse from `main`, no donor overwrite
- `Reader/Sync/*`: no migration in MVP branch
- `Reader/App/*`: no donor overwrite into macOS app

## 11. Risks

### 11.1 Main risk: false sharing between macOS and iPhone

Если shared слой останется смешанным с `AppKit` или macOS UX assumptions, iPhone target будет ломаться при сборке или вынудит unsafe compile guards.

### 11.2 Main risk: sync leakage into local contracts

Если добавить sync hooks в repository/store contracts уже на MVP-этапе, local-first архитектура формально останется, но фактически снова станет sync-first.

### 11.3 Main risk: branch-specific overwrite of main features

Если переносить donor branch wholesale, будут потеряны актуальные улучшения `main`, включая текущий annotation/export-import flow.

### 11.4 Main risk: over-extraction too early

Если сразу пытаться сделать полноценные Swift packages и большой shared refactor, команда потеряет скорость и runnable slice.

## 12. Architectural guardrails

### 12.1 Guardrail: no sync in boot path

Ни один из путей ниже не должен импортировать или вызывать sync:

- app startup
- local import
- open reader
- progress save
- highlight create/delete

### 12.2 Guardrail: main models stay local-first until dedicated sync phase

Поля типа:

- `remoteRecordName`
- `syncState`
- `deletedAt` for sync tombstones
- `progressUpdatedAt`
- `assetUpdatedAt`

не добавляются в current `main` model/schema в рамках standalone MVP.

### 12.3 Guardrail: donor is reference, not integration base

Разрешено:

- смотреть donor implementation;
- переносить isolated files/fragments;
- переписывать поверх current `main`.

Запрещено:

- merge donor into MVP branch;
- overwrite current `main` shared files donor-версиями без локального reconcile;
- тащить donor migrations наравне с `main`.

### 12.4 Guardrail: protect existing macOS flows

Изменения для iPhone не должны ломать:

- macOS import flow;
- macOS reader flow;
- current annotation/export-import stories;
- существующие unit tests on main.

### 12.5 Guardrail: sync arrives as a later phase with its own architecture delta

Когда команда вернётся к `CloudKit`, это должен быть отдельный архитектурный этап:

- с отдельным decision document delta;
- с отдельными migrations;
- с explicit repository extension strategy;
- с отдельной compatibility review against current standalone MVP.

## 13. Recommended implementation framing

Архитурно первый iPhone MVP следует рассматривать не как "урезанный sync client", а как **второй локальный app shell над уже существующим local reader core**.

Это даёт три преимущества:

- можно быстро получить runnable slice;
- можно безопасно переиспользовать ценное из donor branch;
- будущий sync останется add-on слоем, а не условием работоспособности продукта.

## 14. Next document updates recommended

- supersede or rewrite `/Users/ekoshkin/reader/_bmad-output/feature-docs/ios-standalone/architecture-iphone-mvp.md`
- update `/Users/ekoshkin/reader/_bmad-output/feature-docs/ios-standalone/epics-reader-app-iphone-mvp.md` to standalone-first epic order
- create implementation stories from sections 9 and 10 of this document
