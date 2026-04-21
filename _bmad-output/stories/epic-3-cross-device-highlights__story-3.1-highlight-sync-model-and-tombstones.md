# Story 3.1: Highlight Sync Model & Tombstones

**Epic:** 3 — Cross-Device Highlights  
**Status:** proposed  
**Created:** 2026-04-21

---

## Story

Как разработчик, я хочу подготовить модель синхронизации highlights с `updatedAt` и `deletedAt`, чтобы создание, удаление и изменение подсветок было устойчивым и предсказуемым между устройствами.

## Acceptance Criteria

- AC-1: Для highlights существует отдельная sync-модель
- AC-2: Удаление highlights идёт через tombstone, а не через мгновенное исчезновение следов записи
- AC-3: Более новые изменения побеждают более старые
- AC-4: Remote-deleted highlight не “воскрешается” из локального кэша
- AC-5: Unit tests покрывают upsert/delete merge rules

## Tasks / Subtasks

- [ ] Task 1: Ввести sync DTO для highlights
- [ ] Task 2: Добавить `updatedAt` / `deletedAt` merge policy
- [ ] Task 3: Реализовать apply remote upsert/delete в локальную БД
- [ ] Task 4: Написать тесты на tombstones

## Dev Notes

- Локальная модель highlights уже существует в [Highlight.swift](/Users/ekoshkin/reader/Reader/Database/Models/Highlight.swift:1)
- Для MVP достаточно `last-write-wins` + tombstones
