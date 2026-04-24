# План: iPhone MVP — Slice 1 Sync Foundation

**Дата:** 2026-04-21  
**Автор:** Winston (architect)  
**Статус:** готово к оценке

---

## 1. Цель слайса

Подготовить sync foundation так, чтобы существующее macOS-приложение стало:

- издателем PDF-книг и метаданных в CloudKit;
- издателем прогресса чтения;
- получателем удалённых изменений обратно в локальный кэш.

В рамках этого слайса iPhone-клиент ещё не обязателен. Главный результат: архитектура и код macOS должны уже уметь жить не только с локальной `SQLite`, но и с внешним sync-слоем.

---

## 2. Scope Slice 1

### In scope

- Sync-neutral модели и маппинг в CloudKit.
- Локальные metadata-поля для sync.
- `CloudKitSyncService` для книг и прогресса.
- Публикация PDF и `CKAsset` из macOS.
- Pull remote changes обратно в локальную БД.
- Понятные правила записи прогресса.
- Unit tests для маппинга и merge-логики.

### Out of scope

- iOS target.
- UI библиотеки на iPhone.
- Highlights sync.
- Text notes / sticky notes sync.
- Полноценный background sync scheduler.

---

## 3. Архитектурная идея

Нельзя делать `CloudKit <-> GRDB` напрямую из `Store`-слоя. Нужен отдельный sync boundary.

Этот sync boundary должен жить в том же репозитории, что и оба приложения. Для MVP не нужен отдельный репозиторий под sync: выгоднее развивать `ReaderMac`, `ReaderiPhone`, `ReaderShared` и `ReaderSync` как один `monorepo`.

Предлагаемая схема:

`LibraryStore / ReaderStore`
-> `LibraryRepository / AnnotationRepository`
-> локальная `SQLite`

и отдельно:

`SyncCoordinator`
-> `CloudKitSyncService`
-> `CloudKitBookMapper`
-> `CKRecord / CKAsset`

`SyncCoordinator` отвечает за:

- постановку sync-задач;
- pull изменений из CloudKit;
- merge в локальную БД;
- защиту от циклической перезаписи “получили из облака -> снова отправили в облако”.

### 3.1 Границы модулей в одном репозитории

Рекомендуемая модульная структура для следующего этапа:

- `Reader` — macOS app target
- `ReaderiPhone` — iOS app target
- `ReaderShared` — общая доменная логика и platform-neutral code
- `ReaderSync` — CloudKit и merge logic

Если на первом шаге это неудобно оформить как отдельные пакеты, допустимо начать с отдельных директорий/групп в одном Xcode-проекте. Важнее выдержать границы, чем сразу выбрать идеальную упаковку.

---

## 4. Изменения модели данных

### 4.1 Локальная `Book` модель

В [Book.swift](/Users/ekoshkin/reader/Reader/Database/Models/Book.swift:4) добавить поля, нужные для sync:

- `contentHash: String`
- `syncState: String`
- `remoteRecordName: String?`
- `updatedAt: Date`
- `deletedAt: Date?`
- `progressUpdatedAt: Date?`
- `assetUpdatedAt: Date?`

Идея:

- `filePath` и `fileBookmark` остаются локальными.
- `contentHash` нужен, чтобы распознать один и тот же PDF на разных устройствах.
- `remoteRecordName` связывает локальную книгу с записью в CloudKit.
- `updatedAt` и `progressUpdatedAt` нужны для merge.

### 4.2 Новая sync-модель

Ввести отдельные DTO, не завязанные на GRDB:

- `SyncedBookRecord`
- `SyncedProgressRecord`

`SyncedBookRecord` содержит:

- `bookID`
- `contentHash`
- `title`
- `author`
- `format`
- `remoteRecordName`
- `updatedAt`
- `deletedAt`
- `assetChecksum`

`SyncedProgressRecord` содержит:

- `bookID`
- `lastReadAnchor`
- `currentPage`
- `totalPages`
- `progressUpdatedAt`

Причина разделения: прогресс меняется сильно чаще, чем карточка книги и файл PDF.

---

## 5. Решение по CloudKit schema

### Record type: `Book`

Поля:

- `bookID`
- `contentHash`
- `title`
- `author`
- `format`
- `fileAsset`
- `updatedAt`
- `deletedAt`

### Record type: `ReadingProgress`

Поля:

- `bookID`
- `lastReadAnchor`
- `currentPage`
- `totalPages`
- `progressUpdatedAt`

Один `Book` и один `ReadingProgress` на книгу.

Это проще для MVP, чем держать прогресс внутри `Book`, потому что прогресс будет обновляться значительно чаще и не должен каждый раз перезаливать asset.

---

## 6. Предлагаемые новые компоненты

### 6.1 `Reader/Sync/CloudKitSyncService.swift`

Низкоуровневый сервис CloudKit:

- fetch книг;
- upload/update книги;
- upload/update прогресса;
- delete/tombstone;
- fetch incremental changes.

### 6.2 `Reader/Sync/SyncCoordinator.swift`

Оркестратор:

- принимает события от локального слоя;
- решает, что и когда отправлять в CloudKit;
- применяет remote changes локально;
- следит за anti-loop правилами.

### 6.3 `Reader/Sync/CloudKitBookMapper.swift`

Преобразует:

- `Book` -> `CKRecord`
- `CKRecord` -> sync DTO
- sync DTO -> локальные апдейты БД

### 6.4 `Reader/Sync/SyncClock.swift`

Небольшая абстракция над временем для тестируемой merge-логики.

---

## 7. Изменения существующих компонентов

### `BookImporter`

После успешного импорта PDF:

- считать `contentHash`;
- записать новые sync metadata;
- поставить книгу в очередь на upload.

### `LibraryRepository`

Нужны новые методы:

- `fetchBooksPendingSync()`
- `markBookSynced(...)`
- `applyRemoteBookUpsert(...)`
- `applyRemoteBookTombstone(...)`
- `updateProgressFromSync(...)`

### `ReaderStore` / `PDFReaderStore`

Текущий код сохраняет прогресс сразу в локальную БД. Это остаётся, но дополнительно нужен hook в `SyncCoordinator`.

Важно: sync progress не должен триггериться на каждом микросдвиге страницы. Для Slice 1 вводим правило записи только при:

- закрытии книги;
- уходе приложения в background / inactive;
- явной смене страницы после короткой задержки стабилизации;
- reopen того же документа на macOS.

---

## 8. Merge Rules для Slice 1

### Books

- Дедупликация по `contentHash`.
- При локальном импорте уже существующей remote-книги не создаём вторую карточку.
- Если одна и та же книга уже известна, локальная запись связывается с существующей remote-записью.

### Progress

- Побеждает запись с более новым `progressUpdatedAt`.
- Remote progress не должен во время активного чтения автоматически телепортировать пользователя.
- Если книга уже открыта, более свежий remote progress только помечается как доступный.

### Удаления

- Удаление книги — через `deletedAt`, а не через мгновенное физическое стирание remote record.
- Локальный файл можно удалять после успешного применения удаления локально.

---

## 9. UX-правила прогресса

Чтобы поведение было предсказуемым:

- не пушить прогресс в облако на каждое движение;
- не применять remote progress мгновенно в уже открытой книге;
- если пришла более свежая позиция для открытой книги, хранить её как `pendingRemoteProgress`;
- позже UI сможет показать мягкое действие: “Есть более свежая позиция. Перейти?”

Для Slice 1 UI можно ещё не строить полностью, но данные и API под это поведение должны уже существовать.

---

## 10. Последовательность реализации

### Step 1: Migration и локальные модели

- Добавить новую migration с sync metadata в `books`.
- Расширить `Book` и repository API.

### Step 2: DTO и mapper слой

- Создать sync DTO.
- Создать CloudKit mapper.
- Написать unit tests на маппинг и дедупликацию.

### Step 3: Upload pipeline из macOS

- После импорта PDF публиковать `Book`.
- При изменении прогресса публиковать `ReadingProgress`.

### Step 4: Pull pipeline

- На старте приложения и при ручном refresh вытягивать remote changes.
- Применять merge локально.

### Step 5: Anti-loop и стабилизация

- Не переотправлять только что полученные remote changes назад.
- Логировать sync decisions для отладки.

---

## 11. Acceptance Criteria Slice 1

- AC-1: После импорта PDF на macOS создаётся локальная книга с `contentHash` и sync metadata.
- AC-2: Книга публикуется в CloudKit как `Book` record с `CKAsset`.
- AC-3: Прогресс чтения публикуется отдельно как `ReadingProgress` record.
- AC-4: При pull remote changes книга и прогресс корректно применяются в локальную БД.
- AC-5: Один и тот же PDF не создаёт дубль при повторном импорте/получении.
- AC-6: Более старый progress не затирает более новый.
- AC-7: Получение remote progress не телепортирует пользователя, если книга уже открыта.
- AC-8: Unit tests покрывают mapper, merge rules и dedup logic.

---

## 12. Основные риски

### Риск 1: CKAsset слишком тяжёл для частых операций

Смягчение:

- asset загружается только для `Book`, не для прогресса;
- прогресс вынесен в отдельный record type.

### Риск 2: Конфликты от двойной записи локально и remote

Смягчение:

- anti-loop метки;
- `updatedAt` / `progressUpdatedAt`;
- строгие merge rules.

### Риск 3: Локальная модель слишком тесно связана с GRDB

Смягчение:

- sync DTO отделены от GRDB модели;
- CloudKit маппер живёт вне store-слоя.

---

## 13. Что должен получить dev-агент на выходе

После завершения Slice 1 у команды должны быть:

- расширенная локальная схема `books`;
- отдельный sync layer;
- рабочая публикация PDF и прогресса в CloudKit;
- pull и merge remote changes на macOS;
- тестируемые правила дедупликации и прогресса.

Это уже достаточный фундамент, чтобы затем строить iPhone client без повторной переделки модели.
