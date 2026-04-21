# Architecture Scope: iPhone MVP

**Дата:** 21.04.2026  
**Статус:** Proposed  
**Issue:** [#9](https://github.com/bon2362/reader/issues/9)

## 1. Цель

Проверить продуктовую гипотезу, что `Reader` полезен не как локальная читалка на одном устройстве, а как личная Apple-first читалка, где можно:

- добавить книгу на Mac;
- продолжить чтение на iPhone;
- видеть один и тот же прогресс и одни и те же аннотации на обоих устройствах.

Это не цель добиться feature parity между macOS и iPhone. MVP должен доказать ценность cross-device reading с минимальным объёмом реализации.

## 2. Главное решение

### MVP для iPhone делаем только для PDF

`EPUB` переносится на следующую фазу.

### Новое приложение и sync делаем в том же репозитории

Рекомендуемый путь: не отдельный репозиторий, а `monorepo` с двумя приложениями и общими слоями.

Почему это решение выбрано:

- текущая macOS-кодовая база уже содержит рабочие модели, repository-слой, PDF/EPUB reader paths и BMad-артефакты;
- основная задача iPhone MVP — не “запустить второй независимый продукт”, а переиспользовать существующую доменную логику и аккуратно добавить sync;
- ранний вынос iPhone и sync в отдельный репозиторий почти гарантированно приведёт к дублированию моделей, расхождению merge-логики и дорогой синхронизации архитектурных изменений между двумя кодовыми базами.

Итоговое правило:

- новый iPhone app target — в этом же репозитории;
- sync layer — в этом же репозитории;
- разделение делать по targets и модулям, а не по репозиториям.

### Почему PDF проще и честнее для первого MVP

- У PDF есть стабильная страница, поэтому позицию чтения и аннотации проще синхронизировать между Mac и iPhone.
- В текущем коде PDF уже выделен в отдельный поток чтения, ближе к нативному Apple stack: [Reader/Features/PDFReader](/Users/ekoshkin/reader/Reader/Features/PDFReader).
- Текущий EPUB-ридер заметно более кастомный и завязан на bridge, preflight и paginated layout в `WKWebView`: [NativeEPUBBridge.swift](/Users/ekoshkin/reader/Reader/Bridge/NativeEPUBBridge.swift), [NativeEPUBWebView.swift](/Users/ekoshkin/reader/Reader/Features/Reader/NativeEPUBWebView.swift).
- Для EPUB “страница” зависит от экрана, шрифта и layout. Для MVP это добавляет продуктовую двусмысленность: пользователь ожидает “открыть там же”, а система оперирует CFI и пересчитанной пагинацией.

Итог: `PDF-first` даёт более короткий путь к проверке ключевой ценности продукта.

## 3. Предлагаемый MVP Scope

### In scope

- Новый iPhone target.
- Синхронизируемая библиотека PDF-книг между macOS и iPhone.
- Чтение PDF на обоих устройствах.
- Синхронизация последней позиции чтения.
- Синхронизация highlights.
- Локальный offline cache на каждом устройстве.
- Автоматический фоновый sync с eventual consistency.

### Важное упрощение MVP

Импорт PDF выполняется только на `macOS`.

На iPhone пользователь:

- видит синхронизированную библиотеку;
- открывает книги;
- читает;
- создаёт и удаляет highlights.

Это самое важное сокращение объёма. Оно сохраняет демонстрационную ценность MVP, но убирает отдельный mobile import flow из первой итерации.

### Out of scope

- EPUB на iPhone.
- Поиск по тексту.
- Text notes.
- Sticky notes.
- Панель аннотаций с фильтрами.
- Экспорт аннотаций.
- Настройки темы, шрифта и layout.
- Синхронизация всей `SQLite` базы как файла.
- Собственный backend, auth и multi-user сценарии.

## 4. Пользовательские сценарии, которые MVP обязан закрыть

### Scenario A: Add on Mac, continue on iPhone

1. Пользователь импортирует PDF на Mac.
2. Книга появляется на iPhone.
3. Пользователь открывает книгу на iPhone на последней сохранённой странице.

### Scenario B: Read on iPhone, continue on Mac

1. Пользователь читает PDF на iPhone.
2. Прогресс синхронизируется.
3. На Mac книга открывается на актуальной странице.

### Scenario C: Highlight sync

1. Пользователь делает highlight на одном устройстве.
2. Highlight появляется на другом устройстве.
3. Удаление highlight также синхронизируется.

Если эти три сценария работают стабильно, MVP уже валидирует основную продуктовую ценность.

## 5. Что можно переиспользовать из текущей архитектуры

### Можно переиспользовать почти напрямую

- Формат книги и базовую форму модели `Book`: [Book.swift](/Users/ekoshkin/reader/Reader/Database/Models/Book.swift:4)
- Паттерн repository + async `Sendable` протоколы: [LibraryRepository.swift](/Users/ekoshkin/reader/Reader/Features/Library/LibraryRepository.swift:4), [AnnotationRepository.swift](/Users/ekoshkin/reader/Reader/Features/Annotations/AnnotationRepository.swift:4)
- Общую оркестрацию reader state: [ReaderStore.swift](/Users/ekoshkin/reader/Reader/Features/Reader/ReaderStore.swift:6)
- PDF page-anchor подход: [PDFReaderStore.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFReaderStore.swift:7)

### Потребует extraction в shared layer

- Sync-neutral доменные модели.
- Правила merge и conflict resolution.
- CloudKit mapping.
- Общие сервисы синхронизации, независимые от конкретного UI target.

### Практически не переиспользуется как есть

- `AppKit`-специфичный import и cover handling: [BookImporter.swift](/Users/ekoshkin/reader/Reader/Features/Library/BookImporter.swift:1)
- `NSViewRepresentable` и mouse/hover-поведение в PDF UI: [NativePDFView.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/NativePDFView.swift:4)
- `AppKit`-зависимые PDF renderers для hover/text note поведения: [PDFHighlightRenderer.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFHighlightRenderer.swift:1), [PDFTextNoteRenderer.swift](/Users/ekoshkin/reader/Reader/Features/PDFReader/PDFTextNoteRenderer.swift:1)
- Весь текущий EPUB path.

## 6. Целевая архитектура MVP

### 6.1 Высокоуровневая схема

- `ReaderMac` продолжает существовать как основной ingestion client.
- `ReaderiPhone` становится lightweight reading client.
- `ReaderShared` содержит общую доменную логику и платформенно-нейтральные модели.
- `ReaderSync` содержит CloudKit sync boundary, DTO, mapper-ы и merge rules.
- На обоих устройствах остаётся локальная `SQLite` база как cache и local source for UI.
- Между устройствами синхронизируются не локальные файлы БД, а отдельные sync entities через `CloudKit`.

### 6.1.1 Рекомендуемая структура monorepo

Предлагаемая структура в этом репозитории:

```text
Reader/
  App/                    -- macOS app composition
  Features/               -- macOS-specific UI/features
  Bridge/                 -- текущий EPUB bridge
  Database/               -- локальная SQLite/GRDB
  Shared/                 -- уже существующий shared слой
  Sync/                   -- новый CloudKit sync слой

ReaderiPhone/
  App/                    -- iOS app composition
  Features/               -- iPhone-specific UI/features

ReaderShared/
  Models/
  Repositories/
  ReaderCore/
  Utilities/

ReaderSync/
  CloudKit/
  Mapping/
  Merge/
```

На старте это не обязательно должны быть отдельные Swift Packages. Для MVP достаточно начать с групп/директорий внутри одного Xcode-проекта, но с жёсткими архитектурными границами.

### 6.1.2 Что должно жить в каждом слое

В `ReaderShared`:

- модели книг, прогресса и highlights;
- repository-протоколы;
- часть reader/business logic, не завязанная на `AppKit`/`UIKit`;
- общие утилиты для anchor/format/sync metadata.

В `ReaderSync`:

- `SyncCoordinator`;
- `CloudKitSyncService`;
- DTO и mapper-ы;
- dedup logic;
- merge rules;
- conflict policy.

В `Reader`:

- macOS import flow;
- macOS-specific PDF and EPUB UI;
- `AppKit`-зависимые renderer-ы.

В `ReaderiPhone`:

- iPhone library UI;
- iPhone PDF reader UI;
- mobile-specific interaction layer.

### 6.2 Решение по sync substrate

Для MVP использовать `CloudKit private database`.

Почему не sync всей SQLite:

- высокий риск конфликтов;
- плохая наблюдаемость ошибок;
- сложнее контролировать merge политику;
- труднее эволюционировать модель данных.

Почему не отдельный backend:

- слишком дорого по объёму для первой проверки продукта;
- ценность продукта пока локальная и personal-use;
- экосистема Apple already available.

### 6.3 Решение по хранению файлов книг

Для MVP PDF-файл хранится в `CloudKit` как `CKAsset`, а локально копируется в sandbox каждого устройства.

Это решение выбрано вместо sync через `iCloud Drive`, потому что для первой версии оно проще в реализации:

- один sync substrate вместо двух;
- единый change feed;
- проще связать книгу, её метаданные и бинарный файл в одном жизненном цикле.

Ограничение MVP: этот подход подходит для личного приложения и умеренной библиотеки, но не оптимизируется под большие объёмы и shared-library сценарии.

## 7. Sync Model

### 7.1 Sync entity: BookRecord

`BookRecord` в CloudKit:

- `bookID`
- `contentHash`
- `title`
- `author`
- `format` (`pdf`)
- `fileAsset`
- `updatedAt`
- `deletedAt`
- `lastReadAnchor`
- `currentPage`
- `totalPages`
- `progressUpdatedAt`

### 7.2 Sync entity: HighlightRecord

`HighlightRecord` в CloudKit:

- `highlightID`
- `bookID`
- `anchor`
- `color`
- `selectedText`
- `updatedAt`
- `deletedAt`

### 7.3 Локальная модель остаётся другой

Текущая локальная `Book` модель содержит поля, привязанные к конкретному устройству:

- `filePath`
- `fileBookmark`

Эти поля не должны считаться sync truth. Они остаются локальным кэшем. Для sync нужен отдельный слой DTO/mapper, а не прямой upload локальной GRDB-модели.

## 8. Merge Rules

### Progress

- `last-write-wins` по `progressUpdatedAt`.
- Более старый прогресс не должен затирать более новый.

### Highlights

- Создание и изменение: `last-write-wins` по `updatedAt`.
- Удаление: через `deletedAt` tombstone.
- Удалённый highlight не должен “воскресать” из локального кэша.

### Books

- Дедупликация по `contentHash`.
- Удаление книги через tombstone + удаление локального sandbox-кэша после подтверждённого sync.

## 9. UI Scope по платформам

### macOS

В MVP macOS остаётся более функциональным клиентом:

- импорт PDF;
- чтение PDF;
- highlights;
- публикация sync changes.

### iPhone

На iPhone нужен минимальный, но полноценный reading flow:

- список книг;
- экран чтения PDF;
- создание и удаление highlights;
- индикация загрузки/sync ошибок;
- автоматическое восстановление последней позиции.

`TOC`, поиск, заметки и сложные панели не обязательны для первой версии.

## 10. Рекомендуемая декомпозиция реализации

### Slice 1: Sync foundation на macOS

- Ввести sync-neutral модели и CloudKit mapping.
- Добавить `contentHash`, `updatedAt`, `deletedAt` туда, где это нужно для sync.
- Научить macOS публиковать и принимать изменения книг и прогресса.

### Slice 2: iPhone reading client

- Добавить iOS target.
- Подключить локальный cache + CloudKit pull.
- Реализовать библиотеку и PDF reading flow.

### Slice 3: Highlight sync

- Поднять двусторонний sync для highlights.
- Добавить tombstone-удаления.
- Прогнать конфликтные сценарии “Mac -> iPhone -> Mac”.

## 11. Что считаем достаточным для оценки реализации

Issue `#9` можно считать архитектурно проработанной, если команда согласна со следующими утверждениями:

- iPhone MVP идёт как `PDF-only`.
- Импорт книг в MVP остаётся только на macOS.
- Sync substrate для MVP — `CloudKit private database`.
- Книги синхронизируются как `CKAsset`, а не как общий файл `SQLite`.
- В sync scope MVP входят только:
  - библиотека PDF;
  - прогресс чтения;
  - highlights.

Если эти решения приняты, следующая работа уже не архитектурная, а планировочная: разложить MVP на stories и отдельно оценить extraction shared слоя между macOS и iOS.
