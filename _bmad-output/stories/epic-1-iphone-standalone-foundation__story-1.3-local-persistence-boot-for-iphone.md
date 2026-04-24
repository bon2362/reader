# Story 1.3: Local Persistence Boot for iPhone

**Epic:** 1 — iPhone Standalone Foundation  
**Status:** done  
**Created:** 2026-04-24  
**Dependencies:** Story 1.1, Story 1.2

---

## Story

Как разработчик, я хочу, чтобы iPhone app поднимался только с local database и local repositories, чтобы standalone MVP имел предсказуемую offline-capable foundation.

## Acceptance Criteria

- AC-1: iPhone app инициализирует local database и local repositories без network prerequisites
- AC-2: Library screen может читать локальный список книг из on-device базы
- AC-3: При пустой библиотеке показывается local-first empty state без ссылок на sync или macOS ingestion

## Tasks / Subtasks

- [x] Task 1: Подключить local DB boot для iPhone
  - [x] 1.1 Инициализировать `DatabaseManager` в iPhone container
  - [x] 1.2 Подключить local repositories
  - [x] 1.3 Проверить file/database paths для iOS-safe runtime

- [x] Task 2: Подключить library read path
  - [x] 2.1 Создать базовый store/state для iPhone library
  - [x] 2.2 Прочитать локальный список книг
  - [x] 2.3 Обработать пустое состояние

- [x] Task 3: Убедиться в отсутствии sync pressure
  - [x] 3.1 Удалить ожидания remote hydration
  - [x] 3.2 Не подключать sync coordinators
  - [x] 3.3 Не требовать paid Apple developer entitlements

- [x] Task 4: Проверить baseline
  - [x] 4.1 Cold launch без книг
  - [x] 4.2 Повторный launch
  - [x] 4.3 Проверка, что macOS app unaffected

## Dev Notes

### Контекст

Эта story завершает foundation phase и готовит почву для import/library stories. После нее iPhone app уже должен уметь жить как local-only оболочка с базой и repositories.

### Релевантные файлы

- [DatabaseManager.swift](/Users/ekoshkin/reader/Reader/Database/DatabaseManager.swift)
- [LibraryRepository.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryRepository.swift)
- [LibraryStore.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryStore.swift)
- [Book.swift](/Users/ekoshkin/reader/Reader/Database/Models/Book.swift)
- [FileAccess.swift](/Users/ekoshkin/reader/Reader/Shared/FileAccess.swift)

### Guardrails

- Не добавлять sync services даже как disabled dependency в startup path.
- Не показывать empty states, отсылающие пользователя на Mac.
- Не использовать remote asset availability как условие открытия книги.

### Previous Story Intelligence

- [story 1.1](/Users/ekoshkin/reader/_bmad-output/stories/epic-1-iphone-standalone-foundation__story-1.1-iphone-target-from-main-and-local-only-app-shell.md) зафиксировала iPhone shell и branch rules.
- [story 1.2](/Users/ekoshkin/reader/_bmad-output/stories/epic-1-iphone-standalone-foundation__story-1.2-shared-local-core-extraction-for-iphone-reuse.md) подготовила shared local core и iOS-safe extraction.

## Definition of Done

- iPhone app стабильно поднимает local DB и repositories
- Library screen читает локальные книги
- Empty state local-first и не зависит от sync/macOS
- Startup path остается local-only

---

## Dev Agent Record

### Implementation Plan

- Поднять `DatabaseManager.onDisk()` прямо в `IPhoneAppContainer` и собрать local-only dependency graph: `LibraryRepository` + `AnnotationRepository`
- Заменить placeholder screen на реальный iPhone library store/view, читающий `fetchAll()` из on-device БД
- Проверить baseline не только сборкой, но и simulator cold launch / relaunch без каких-либо network prerequisites

### Debug Log

- `ReaderiPhoneApp` переведен на fail-safe startup: container создается через `do/catch`, а ошибка открытия local DB показывает startup error screen
- После замены placeholder view потребовалась повторная генерация `Reader.xcodeproj` через `xcodegen generate`, чтобы удалить stale file reference
- Cold launch / relaunch проверены через `xcrun simctl install`, `launch`, `terminate`, `launch` на simulator `iPhone 17`

### Completion Notes

- iPhone startup path теперь поднимает local database и local repositories без sync coordinators, remote hydration или entitlement checks
- Добавлены `IPhoneLibraryStore` и `IPhoneLibraryView`, которые читают локальный список книг из on-device БД
- Empty state переведен на local-first формулировку без ссылок на Mac или sync
- `ReaderiPhone` успешно собирается для iOS Simulator, а `LibraryRepositoryTests` подтверждают, что macOS/local repository behavior не сломан

## File List

- Reader.xcodeproj/project.pbxproj
- ReaderiPhone/App/ReaderiPhoneApp.swift
- ReaderiPhone/App/IPhoneAppContainer.swift
- ReaderiPhone/App/IPhoneCompositionRoot.swift
- ReaderiPhone/Features/Library/IPhoneLibraryStore.swift
- ReaderiPhone/Features/Library/IPhoneLibraryView.swift

## Change Log

- 2026-04-24: Story 1.3 завершена. iPhone app поднимает local DB/repositories, local library screen читает on-device books, cold launch и relaunch на simulator подтверждены.
