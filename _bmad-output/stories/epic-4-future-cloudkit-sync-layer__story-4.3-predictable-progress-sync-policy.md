# Story 4.3: Predictable Progress Sync Policy

**Epic:** 4 — Future CloudKit Sync Layer  
**Status:** ready-for-dev  
**Created:** 2026-04-24  
**Dependencies:** Story 4.1, Story 4.2

---

## Story

Как cross-device reader, я хочу предсказуемую политику sync прогресса, чтобы переключение между устройствами не вызывало неожиданные прыжки и не перезаписывало активную локальную сессию чтения.

## Acceptance Criteria

- AC-1: Progress publish/apply использует явные правила и conflict policy, а не публикацию на каждое локальное UI изменение по умолчанию
- AC-2: При приходе remote progress во время активного локального чтения sync layer умеет defer/reconcile change без destabilizing active reader

## Tasks / Subtasks

- [ ] Task 1: Определить progress sync policy
  - [ ] 1.1 Publish rules
  - [ ] 1.2 Apply rules
  - [ ] 1.3 Conflict handling

- [ ] Task 2: Подготовить integration points
  - [ ] 2.1 Optional progress hooks
  - [ ] 2.2 Reconciliation path

- [ ] Task 3: Проверить, что local read path остается usable без sync
  - [ ] 3.1 Active reader unaffected
  - [ ] 3.2 Standalone mode still local-first

## Dev Notes

### Контекст

Эта story сознательно отложена после standalone MVP. Нельзя retroactively менять `2.3` так, будто sync был обязательной частью reader path с самого начала.

### Guardrails

- Не публиковать progress на every UI change by default.
- Не делать remote progress приоритетнее active local session без явной policy.

## Definition of Done

- У progress sync есть явная policy
- Active local reading не destabilized remote updates
- Standalone local-first path остается intact

