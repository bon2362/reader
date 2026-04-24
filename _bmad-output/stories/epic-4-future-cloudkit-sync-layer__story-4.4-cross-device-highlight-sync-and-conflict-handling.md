# Story 4.4: Cross-Device Highlight Sync and Conflict Handling

**Epic:** 4 — Future CloudKit Sync Layer  
**Status:** ready-for-dev  
**Created:** 2026-04-24  
**Dependencies:** Story 4.1, Story 4.2, Story 4.3

---

## Story

Как cross-device reader, я хочу, чтобы highlights надежно появлялись на разных устройствах, чтобы мои аннотации оставались согласованными после осознанного включения sync.

## Acceptance Criteria

- AC-1: Create/delete highlight flows синхронизируются через dedicated sync phase с явной metadata, deletion handling и conflict policy
- AC-2: Введение highlight sync не компрометирует standalone-first architecture boundaries, закрепленные в Epics 1-3

## Tasks / Subtasks

- [ ] Task 1: Определить sync model для highlights
  - [ ] 1.1 Create/update/delete semantics
  - [ ] 1.2 Conflict handling
  - [ ] 1.3 Deletion/tombstone policy

- [ ] Task 2: Подготовить cross-device highlight flow
  - [ ] 2.1 Publish path
  - [ ] 2.2 Apply path
  - [ ] 2.3 Reconciliation rules

- [ ] Task 3: Проверить architecture boundaries
  - [ ] 3.1 Local highlight MVP path остается valid
  - [ ] 3.2 Sync remains additive, not foundational

## Dev Notes

### Контекст

`3.1` и `3.2` intentionally local-only. Эта story не должна переписывать их историю задним числом; она должна строиться поверх готового local-first behavior.

### Guardrails

- Не тянуть sync metadata в MVP stories 3.1/3.2.
- Не нарушать local create/reload/delete semantics, уже подтвержденные standalone MVP.

## Definition of Done

- Highlight sync описан как отдельный post-MVP capability
- Local highlight path остается базовым и рабочим
- Sync layer additive и архитектурно изолирован

