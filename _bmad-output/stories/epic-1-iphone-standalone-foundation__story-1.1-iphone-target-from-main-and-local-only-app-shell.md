# Story 1.1: iPhone Target from Main and Local-Only App Shell

**Epic:** 1 — iPhone Standalone Foundation  
**Status:** done  
**Created:** 2026-04-24  
**Dependencies:** none

---

## Story

Как разработчик, я хочу создать новый iPhone app target от current `main` с local-only app shell, чтобы iPhone-направление стартовало с безопасного baseline и не зависело от donor branch state.

## Acceptance Criteria

- AC-1: Новый iPhone target создается от current `main` в новой ветке и не продолжает `codex/iphone-mvp-cloudkit`
- AC-2: Приложение запускается через отдельный iPhone entry point и отдельный local-only composition root
- AC-3: В startup path отсутствуют `Reader/Sync`, `CloudKit`, entitlement checks и auto-selection sync services
- AC-4: iPhone Simulator build не подтягивает macOS-only app bootstrap code

## Tasks / Subtasks

- [x] Task 1: Подготовить безопасный branch strategy для standalone iPhone work
  - [x] 1.1 Зафиксировать, что реализация идет от current `main`
  - [x] 1.2 Не использовать donor branch как merge base
  - [x] 1.3 Отразить branch rule в story implementation notes

- [x] Task 2: Создать iPhone target и app shell
  - [x] 2.1 Добавить `ReaderiPhone` target в текущий Xcode project
  - [x] 2.2 Создать iPhone app entry point
  - [x] 2.3 Создать начальный route/library placeholder screen

- [x] Task 3: Вынести local-only composition root
  - [x] 3.1 Создать `IPhoneAppContainer` / `IPhoneCompositionRoot`
  - [x] 3.2 Исключить sync service wiring из startup path
  - [x] 3.3 Исключить macOS-only bootstrap dependencies

- [x] Task 4: Проверить platform boundaries
  - [x] 4.1 Убедиться, что iPhone target собирается для Simulator
  - [x] 4.2 Убедиться, что macOS app продолжает собираться без изменений поведения

## Dev Notes

### Контекст

Эта story открывает весь standalone track. Ее задача не в том, чтобы уже дать import/read value, а в том, чтобы создать безопасную архитектурную рамку для последующих stories.

### Архитектурные guardrails

- Реализация обязана идти от `main`, а не от `codex/iphone-mvp-cloudkit`.
- Любые sync-related зависимости должны отсутствовать в iPhone startup path.
- Нельзя переносить donor `AppContainer` как есть.
- Нельзя протаскивать entitlement detection и `CloudKit` wiring в baseline.

### Полезные исходные точки

- [ReaderApp.swift](/Users/ekoshkin/reader/Reader/App/ReaderApp.swift)
- [AppDelegate.swift](/Users/ekoshkin/reader/Reader/App/AppDelegate.swift)
- [ContentView.swift](/Users/ekoshkin/reader/Reader/App/ContentView.swift)
- [architecture-iphone-standalone-mvp.md](/Users/ekoshkin/reader/_bmad-output/feature-docs/ios-standalone/architecture-iphone-standalone-mvp.md)
- [plan.md](/Users/ekoshkin/reader/_bmad-output/feature-docs/ios-standalone/plan.md)

### Donor branch policy

Из donor branch можно брать только ideas/reference по target strategy. Нельзя копировать branch-wide startup flow, sync boot logic или container assembly.

## Definition of Done

- Существует новый `ReaderiPhone` target
- Есть отдельный iPhone app entry и local-only composition root
- iPhone target собирается для Simulator
- В startup path отсутствуют `CloudKit`, `Reader/Sync` и entitlement checks
- Текущий macOS app продолжает собираться и не меняет существующее поведение

---

## Dev Agent Record

### Implementation Plan

- Реализация начата от current `main` в новой ветке `codex/iphone-standalone-mvp`
- Donor branch `codex/iphone-mvp-cloudkit` использовалась только как reference для target strategy, не как merge base
- Для чистого startup boundary `ReaderiPhone` пока собирается только из `ReaderiPhone/*` и shared assets, без подключения `Reader/Sync` или macOS bootstrap файлов

### Debug Log

- `project.yml` обновлен как source of truth, затем `Reader.xcodeproj` пересобран через `xcodegen generate`
- Первая проверка iPhone build зависла из-за отсутствующего simulator destination `iPhone 16`; build успешно перепроверен на доступном `iPhone 17`

### Completion Notes

- Добавлен новый `ReaderiPhone` target с iOS deployment target `17.0`
- Созданы отдельные `ReaderiPhoneApp`, `IPhoneAppContainer`, `IPhoneCompositionRoot` и placeholder library route
- Startup path iPhone target изолирован от `CloudKit`, `Reader/Sync`, entitlement checks и macOS-only bootstrap кода
- Проверены обе platform boundaries: `ReaderiPhone` собирается для iOS Simulator, текущий `Reader` продолжает собираться для macOS

## File List

- project.yml
- Reader.xcodeproj/project.pbxproj
- ReaderiPhone/App/ReaderiPhoneApp.swift
- ReaderiPhone/App/IPhoneAppContainer.swift
- ReaderiPhone/App/IPhoneCompositionRoot.swift
- ReaderiPhone/Features/Navigation/IPhoneRoute.swift
- ReaderiPhone/Features/Library/IPhoneLibraryPlaceholderView.swift

## Change Log

- 2026-04-24: Story 1.1 завершена. Добавлен standalone `ReaderiPhone` target и local-only app shell, проверки `ReaderiPhone` Simulator build и `Reader` macOS build выполнены успешно.
