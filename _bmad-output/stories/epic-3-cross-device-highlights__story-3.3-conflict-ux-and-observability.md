# Story 3.3: Conflict UX & Observability

**Epic:** 3 — Cross-Device Highlights  
**Status:** proposed  
**Created:** 2026-04-21

---

## Story

Как пользователь и как команда разработки, мы хотим, чтобы параллельная работа на Mac и iPhone вела себя предсказуемо и была наблюдаемой, чтобы синхронизация не воспринималась как хаотичная.

## Acceptance Criteria

- AC-1: Конфликт прогресса не вызывает внезапный прыжок по книге
- AC-2: Появляется понятное состояние “есть более свежая позиция”
- AC-3: Sync layer пишет диагностические события для upload, pull, merge и conflicts
- AC-4: Основные конфликтные сценарии покрыты тестами

## Tasks / Subtasks

- [ ] Task 1: Добавить диагностическое логирование sync pipeline
- [ ] Task 2: Ввести состояние `pendingRemoteProgress` или эквивалент
- [ ] Task 3: Покрыть тестами сценарии parallel read / remote progress / tombstone highlights
- [ ] Task 4: Подготовить минимальные UX hooks для будущих подсказок пользователю

## Dev Notes

- Для MVP не нужно делать сложный conflict center
- Но архитектура уже должна поддерживать мягкое, объяснимое поведение вместо silent overrides
