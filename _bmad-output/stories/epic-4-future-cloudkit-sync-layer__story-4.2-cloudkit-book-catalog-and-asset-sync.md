# Story 4.2: CloudKit Book Catalog and Asset Sync

**Epic:** 4 — Future CloudKit Sync Layer  
**Status:** ready-for-dev  
**Created:** 2026-04-24  
**Dependencies:** Story 4.1

---

## Story

Как пользователь future cross-device режима, я хочу синхронизировать PDF catalog и file assets через CloudKit, чтобы одна и та же библиотека была доступна на macOS и iPhone.

## Acceptance Criteria

- AC-1: Book catalog и asset sync реализуются как dedicated sync layer, а не как скрытое изменение standalone MVP boot path
- AC-2: При появлении remote assets local-first reading остается валиден для уже локально доступных файлов

## Tasks / Subtasks

- [ ] Task 1: Определить sync model для books/assets
  - [ ] 1.1 Catalog records
  - [ ] 1.2 Asset transport rules
  - [ ] 1.3 Local cache interaction

- [ ] Task 2: Подготовить CloudKit sync implementation plan
  - [ ] 2.1 Upload/download flows
  - [ ] 2.2 Error/retry expectations
  - [ ] 2.3 Asset hydration boundaries

- [ ] Task 3: Проверить compatibility с standalone local-first mode
  - [ ] 3.1 Existing local books remain readable
  - [ ] 3.2 Startup path does not require CloudKit

## Dev Notes

### Контекст

Это future-only story. Она не должна использоваться как основание для изменения текущего MVP import/open/read path.

### Guardrails

- Не внедрять remote hydration в current MVP stories.
- Не менять local import requirement для standalone MVP.

## Definition of Done

- Dedicated CloudKit catalog/asset sync path спроектирован отдельно от MVP boot path
- Local-first behavior сохраняется для already local files

