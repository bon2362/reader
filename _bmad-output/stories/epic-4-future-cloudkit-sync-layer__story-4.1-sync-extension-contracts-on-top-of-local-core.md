# Story 4.1: Sync Extension Contracts on Top of Local Core

**Epic:** 4 — Future CloudKit Sync Layer  
**Status:** ready-for-dev  
**Created:** 2026-04-24  
**Dependencies:** Completion of Epics 1-3

---

## Story

Как разработчик, я хочу определить sync-specific extension contracts поверх local core, чтобы future sync можно было добавить без переписывания standalone iPhone UI и boot flow.

## Acceptance Criteria

- AC-1: Sync extension points наслаиваются поверх local repositories, а не заменяют local contracts
- AC-2: Future hooks для progress/highlight publication остаются optional adapters/decorators и не становятся обязательной частью standalone startup

## Tasks / Subtasks

- [ ] Task 1: Определить boundary между local core и future sync layer
  - [ ] 1.1 Описать extension points
  - [ ] 1.2 Не менять local-first contracts по умолчанию

- [ ] Task 2: Подготовить optional sync hooks
  - [ ] 2.1 Progress publication extension point
  - [ ] 2.2 Highlight publication extension point
  - [ ] 2.3 Sync adapter boundaries

- [ ] Task 3: Проверить compatibility со standalone MVP
  - [ ] 3.1 Startup path остается local-only
  - [ ] 3.2 UI flow iPhone не переписывается под sync-first

## Dev Notes

### Контекст

Epic 4 не входит в текущий standalone MVP implementation scope. Этот story-файл создается для полноты BMad package, но не должна попадать в первый implementation lane.

### Guardrails

- Не реализовывать `CloudKit` здесь в обход отдельного follow-up track.
- Не менять semantics stories 1.1-3.3.
- Любая sync layer должна быть opt-in и additive.

## Definition of Done

- Определены sync extension contracts
- Local-first core остается primary path
- Standalone MVP не регрессирует в sync-first architecture

