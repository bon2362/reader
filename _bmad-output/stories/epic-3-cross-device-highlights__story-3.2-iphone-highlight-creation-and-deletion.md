# Story 3.2: iPhone Highlight Creation & Deletion

**Epic:** 3 — Cross-Device Highlights  
**Status:** proposed  
**Created:** 2026-04-21

---

## Story

Как пользователь iPhone, я хочу создавать и удалять highlights в PDF, чтобы мобильное чтение было не только для просмотра, но и для выделения важных мест.

## Acceptance Criteria

- AC-1: На iPhone можно выделить текст в PDF и создать highlight
- AC-2: Highlight локально сохраняется и сразу отображается
- AC-3: Удаление highlight доступно на iPhone
- AC-4: Создание и удаление уходят в sync pipeline
- AC-5: После синхронизации эти highlights корректно видны на macOS

## Tasks / Subtasks

- [ ] Task 1: Реализовать text selection -> create highlight flow на iPhone
- [ ] Task 2: Реализовать delete highlight flow
- [ ] Task 3: Подключить local persistence
- [ ] Task 4: Подключить sync enqueue

## Dev Notes

- Для MVP на iPhone достаточно create/delete; смену цвета можно отложить
- Это уменьшает объём UX и делает поведение проще для тестирования
