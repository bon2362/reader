# Story 2.1: EPUB Rendering & Navigation

**Epic:** 2 — Core Reading
**Status:** review
**Created:** 2026-04-18

---

## Story

Как пользователь, я хочу открыть EPUB файл и читать его постранично с навигацией, чтобы книгу можно было читать комфортно как в настоящем e-reader.

## Acceptance Criteria

- AC-1: `ReaderView` отображает WKWebView с загруженным EPUB и постраничной разметкой
- AC-2: Навигация через клавиши ←/→, стрелки тулбара, клик по левому/правому краю экрана
- AC-3: `ReaderStore` (@Observable) хранит текущий CFI, номер страницы, всего страниц, название главы
- AC-4: `ReaderToolbar` показывает название книги и текущей главы, скрывается автоматически через 3 секунды бездействия мыши
- AC-5: `PageIndicator` отображает "стр. X из Y" в нижней части экрана
- AC-6: `pageChanged` события из JS обновляют `ReaderStore` реактивно
- AC-7: При открытии книги автоматически восстанавливается `last_cfi` если есть
- AC-8: EPUB URL передаётся в JS через bridge `loadBook(url:)`
- AC-9: Тесты для `ReaderStore` логики (без реального WKWebView)

## Tasks / Subtasks

- [x] Task 1: ReaderStore (@Observable, @MainActor, late bridge binding через bindBridge)
- [x] Task 2: ReaderView + обновлённый EPUBWebView (onBridgeReady callback, edge clicks, onKeyPress)
- [x] Task 3: ReaderToolbar с ultraThinMaterial, keyboard shortcuts
- [x] Task 4: PageIndicator "стр. X из Y"
- [x] Task 5: ReaderStore реализует EPUBBridgeDelegate, persist через Task.detached
- [x] Task 6: 11 тестов в ReaderStoreTests — все проходят

## Dev Notes

### Архитектура

- ReaderStore — @Observable (macOS 14+), minimal boilerplate
- EPUBBridgeDelegate реализует ReaderStore — `pageChanged` обновляет state
- Клавиатурная навигация через `.focusable()` + `.onKeyPress`
- EdgeClickView — `Rectangle().contentShape(...)` с прозрачным fill
- Toolbar показывается по `NSEvent.mouseMoved` через `.onContinuousHover` (macOS 13+)

### Прогресс сохранения

После каждого `pageChanged` из JS → store обновляется → `Task.detached` пишет в БД `updateReadingProgress`. Debounce не нужен — SQLite WAL справится, а потеря последнего `cfi` при крэше неприемлема.

### Тесты

`ReaderStore` тестируется с `MockEPUBBridge` — все команды и события моделируются.
Реальный WKWebView не тестируем в unit-тестах (UI-тесты — Story QA).

---

## Dev Agent Record

### Implementation Plan

- `EPUBBridge` создаётся внутри `EPUBWebView.makeNSView` (нужен WKWebView)
- `ReaderStore` принимает bridge через `bindBridge()` после создания — store существует до WebView
- `onBridgeReady` callback с задержкой 0.3s для уверенности, что JS загружен

### Debug Log

- Архитектурный вопрос: bridge ownership. Решение — bridge принадлежит Coordinator-у WebView, store хранит weak reference через протокол
- SwiftUI `@Bindable` вместо `@ObservedObject` для Observation macro

### Completion Notes

- ReaderStore (@Observable) реализует весь state чтения + EPUBBridgeDelegate
- ReaderView с edge-click зонами (80pt), клавиатурной навигацией, auto-hide toolbar
- Мгновенное сохранение прогресса в БД через Task.detached после каждого pageChanged
- ReaderToolbar с ultraThinMaterial фоном, кнопки с keyboardShortcut(.leftArrow/.rightArrow)
- PageIndicator в виде Capsule с "стр. X из Y"
- 11 новых тестов в ReaderStoreTests, всего 64/64 тестов

---

## File List

- Reader/Features/Reader/ReaderStore.swift
- Reader/Features/Reader/ReaderView.swift
- Reader/Features/Reader/ReaderToolbar.swift
- Reader/Features/Reader/PageIndicator.swift
- Reader/Features/Reader/EPUBWebView.swift (обновлён)
- ReaderTests/Features/ReaderStoreTests.swift

---

## Change Log

- 2026-04-18: Story 2.1 завершена. ReaderStore + ReaderView + UI компоненты. 64/64 тестов.
