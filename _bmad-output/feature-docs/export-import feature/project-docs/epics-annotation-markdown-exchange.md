# Epics — Annotation Markdown Exchange

## Epic 4: Annotation Markdown Exchange

Переносимый экспорт и обратный импорт аннотаций через `.md`, без резервного копирования всей `SQLite` базы и без поддержки `TXT`.

### Цель эпика

Сделать понятный и устойчивый контур обмена аннотациями:

- экспорт по одной книге в один Markdown-файл;
- массовый экспорт по библиотеке;
- preview перед импортом;
- повторный импорт без дублей;
- предсказуемое обновление существующих записей.

### Продуктовые правила

- Канонический exchange-формат: только `.md`
- Один файл экспорта = одна книга
- Книга при импорте сопоставляется по `contentHash`
- Аннотации сопоставляются по `exchangeId`
- Импорт идёт только для `reader-annotations/v1`
- Ошибка одной книги не должна ломать импорт остальных

### Story 4.1: Schema Support for Exchange ID

Добавить в `highlights`, `text_notes` и `page_notes` поле `exchange_id`, расширить локальные модели аннотаций и обеспечить автоматическую генерацию `exchangeId` для новых записей без обязательного backfill legacy-данных.

### Story 4.2: Repository Support for Exchange Lookup

Расширить `AnnotationRepository` методами поиска аннотаций по `bookId + exchangeId`, чтобы import-слой мог надёжно определять, какую запись нужно обновить, а какую создать заново.

### Story 4.3: Markdown Exchange Domain Model

Создать отдельную exchange-модель документа, книги, anchor и элементов аннотаций, не завязанную напрямую на GRDB, SwiftUI и текущие UI-сторы.

### Story 4.4: Markdown Export Encoder

Реализовать `MarkdownAnnotationEncoder`, который формирует человекочитаемый, но строго структурированный `.md` в формате `reader-annotations/v1` с YAML front matter и metadata-блоками для каждой аннотации.

### Story 4.5: Library-Wide Export Flow

Добавить orchestration-слой массового экспорта по библиотеке: обход книг, сбор аннотаций, генерация по одному `.md` на книгу, запись файлов в выбранную папку и итоговый summary/report.

### Story 4.6: Markdown Import Preview

Сделать безопасный preview импорта: разбор `.md`, проверка версии формата, match книги по `contentHash`, lookup аннотаций по `exchangeId` и расчёт ожидаемых `create / update / skip / invalid` без записи в базу.

### Story 4.7: Import Apply with Per-Book Transaction

Реализовать фактическое применение импорта: создание новых аннотаций, update существующих только при более новом `updatedAt`, идемпотентный re-import и отдельная транзакция на уровне одной книги.
