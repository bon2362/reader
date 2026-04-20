# Story 1.1: Project Initialization

**Epic:** 1 — Foundation  
**Status:** review  
**Created:** 2026-04-18

---

## Story

Как разработчик, я хочу создать базовую структуру Xcode проекта с подключёнными зависимостями и рабочим Swift↔JS bridge, чтобы все последующие фичи имели надёжный фундамент.

## Acceptance Criteria

- AC-1: Xcode проект создан (macOS App, SwiftUI, Bundle ID `com.koshkin.reader`, минимум macOS 14.0)
- AC-2: GRDB.swift v7.10.0 подключён через SPM, проект компилируется
- AC-3: epub.js и jszip.js встроены в `Resources/JS/`, доступны в bundle
- AC-4: Скелеты `reader.js` и `reader.css` созданы в `Resources/JS/`
- AC-5: `EPUBBridgeProtocol` определён и MockEPUBBridge реализован в тестах
- AC-6: `EPUBWebView` (WKWebView + NSViewRepresentable) реализован
- AC-7: `EPUBBridge` реализует протокол, ping/pong тест проходит
- AC-8: Структура папок соответствует архитектуре: App/, Features/, Bridge/, Database/, Shared/, Resources/JS/
- AC-9: Все тесты в `ReaderTests/` проходят

## Tasks / Subtasks

- [x] Task 1: Создать структуру Xcode проекта
  - [x] 1.1 Создать директории согласно структуре из архитектуры
  - [x] 1.2 Создать `ReaderApp.swift` (точка входа @main)
  - [x] 1.3 Создать `AppDelegate.swift` (NSApplicationDelegate)
  - [x] 1.4 Создать `ContentView.swift` (временный placeholder)

- [x] Task 2: Встроить JS-ресурсы
  - [x] 2.1 Скачать epub.js v0.3.93 и jszip.js v3.10.1, поместить в `Reader/Resources/JS/`
  - [x] 2.2 Создать скелет `reader.js` с базовой структурой bridge
  - [x] 2.3 Создать `reader.css` с базовыми стилями reading view

- [x] Task 3: Создать project.yml для xcodegen (SPM зависимости)
  - [x] 3.1 Добавить GRDB.swift v7.10.0

- [x] Task 4: Реализовать Bridge layer
  - [x] 4.1 Создать `EPUBBridgeProtocol.swift` с полным API (@MainActor)
  - [x] 4.2 Создать `BridgeMessage.swift` (входящие события — enum)
  - [x] 4.3 Создать `BridgeCommand.swift` (исходящие команды — enum)
  - [x] 4.4 Создать `EPUBBridge.swift` (реализация WKScriptMessageHandler, @MainActor)

- [x] Task 5: Реализовать EPUBWebView
  - [x] 5.1 Создать `EPUBWebView.swift` (WKWebView + NSViewRepresentable)
  - [x] 5.2 Загрузка HTML shell с epub.js при инициализации

- [x] Task 6: Написать тесты
  - [x] 6.1 Создать `MockEPUBBridge.swift` с `DelegateRecorder`
  - [x] 6.2 Создать `EPUBBridgeTests.swift` — 29 тестов: BridgeCommand JS, BridgeMessageParser, ping/pong
  - [x] 6.3 Все 29 тестов проходят

## Dev Notes

### Архитектурный контекст

- Движок: epub.js v0.3.x внутри WKWebView (не Readium — см. architecture.md)
- Bridge: WKWebView ↔ Swift через `WKScriptMessageHandler` + `EPUBBridgeProtocol`
- БД: GRDB.swift v7.10.0, но схема создаётся в Story 1.2
- OS: macOS 14.0+ обязательно (@Observable, NavigationSplitView)

### Bridge Protocol API

**Swift → JS (команды):**
```
loadBook(url), goToCFI(cfi), search(query)
highlightRange(cfiStart, cfiEnd, color, id)
removeHighlight(id), scrollToAnnotation(cfi), getAnnotationPositions()
```

**JS → Swift (события):**
```
pageChanged(cfi, spineIndex, currentPage, totalPages)
textSelected(cfiStart, cfiEnd, text)
pageTap(x, y)
searchResults([{cfi, excerpt}])
annotationPositions([{id, x, y, type}])
```

### Правила из architecture.md

- Никогда не обращаться к WKWebView напрямую из бизнес-логики — только через `EPUBBridgeProtocol`
- Показывать ошибки через Alert, не через print/console
- Тесты в `ReaderTests/`, именовать `FeatureNameTests.swift`

### Структура папок

```
Reader/
  App/
  Features/Library/, Reader/, Annotations/, TOC/, Search/
  Bridge/
  Database/Migrations/, Models/
  Shared/Extensions/
  Resources/JS/
ReaderTests/Bridge/, Database/, Features/
```

### Ping/Pong тест

reader.js должен принимать сообщение `{type: "ping"}` и отвечать `{type: "pong"}`.
Swift bridge должен отправить ping и получить pong через WKScriptMessage.

---

## Dev Agent Record

### Implementation Plan

Использован xcodegen для генерации .xcodeproj. Протоколы и EPUBBridge помечены @MainActor для совместимости с Swift 6 strict concurrency. WKScriptMessageHandler вынесен в отдельный non-isolated класс `MainActorMessageHandler` с переброской на MainActor через Task.

### Debug Log

- Swift 6 data race error в EPUBBridge: `DispatchQueue.main.async` заменён на `@MainActor` + отдельный `MainActorMessageHandler`
- xcode-select указывал на CLI tools вместо Xcode.app — обходится через `DEVELOPER_DIR=`
- GENERATE_INFOPLIST_FILE отсутствовал в project.yml — добавлен для обоих таргетов

### Completion Notes

Реализован полный foundation layer:
- Xcode проект сгенерирован через xcodegen 2.45.4 + project.yml
- GRDB.swift 7.10.0 подключён через SPM, зависимости разрешены
- epub.js v0.3.93 + jszip.js v3.10.1 встроены в Resources/JS/
- reader.js: ping/pong, loadBook, навигация, поиск, highlights, textSelected, pageChanged
- EPUBBridgeProtocol + EPUBBridge (@MainActor) с полным API (10 команд / 6 событий)
- BridgeCommand (JS генерация) + BridgeMessageParser (парсинг входящих событий)
- EPUBWebView (NSViewRepresentable) с HTML shell загрузкой
- 29 тестов: BridgeCommand (10), BridgeMessageParser (9), MockEPUBBridge PingPong (10)
- Все тесты проходят: 29/29

---

## File List

- Reader/App/ReaderApp.swift
- Reader/App/AppDelegate.swift
- Reader/App/ContentView.swift
- Reader/Bridge/EPUBBridgeProtocol.swift
- Reader/Bridge/EPUBBridge.swift
- Reader/Bridge/BridgeMessage.swift
- Reader/Bridge/BridgeCommand.swift
- Reader/Features/Reader/EPUBWebView.swift
- Reader/Resources/JS/epub.js
- Reader/Resources/JS/jszip.js
- Reader/Resources/JS/reader.js
- Reader/Resources/JS/reader.css
- ReaderTests/Bridge/MockEPUBBridge.swift
- ReaderTests/Bridge/EPUBBridgeTests.swift
- project.yml
- Reader.xcodeproj (сгенерирован xcodegen)

---

## Change Log

- 2026-04-18: Story 1.1 завершена. Создан Xcode проект, подключён GRDB.swift, встроен epub.js bundle, реализован EPUBBridge с @MainActor, написаны 29 тестов (все проходят).
