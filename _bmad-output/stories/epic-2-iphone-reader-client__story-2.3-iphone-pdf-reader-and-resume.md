# Story 2.3: iPhone PDF Reader & Resume

**Epic:** 2 — iPhone Reader Client  
**Status:** proposed  
**Created:** 2026-04-21

---

## Story

Как пользователь iPhone, я хочу открыть PDF-книгу, листать страницы и вернуться ровно туда, где остановился, чтобы мобильное чтение было полезным уже в первой версии.

## Acceptance Criteria

- AC-1: На iPhone открывается PDF-книга из локальной копии
- AC-2: Работает базовая навигация по страницам
- AC-3: Последняя сохранённая позиция корректно восстанавливается при reopen
- AC-4: Локальные изменения прогресса попадают в sync pipeline
- AC-5: Приложение корректно обрабатывает книгу, которая ещё не скачана локально

## Tasks / Subtasks

- [ ] Task 1: Выбрать iOS-совместимый PDF rendering path
- [ ] Task 2: Реализовать iPhone reader screen
- [ ] Task 3: Подключить restore progress
- [ ] Task 4: Подключить publish progress

## Dev Notes

- В macOS уже есть отдельный PDF reading path, но он сильно опирается на `AppKit`
- MVP не требует TOC, поиска и сложных панелей на iPhone
