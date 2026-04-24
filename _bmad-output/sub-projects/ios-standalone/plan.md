# План: iPhone Standalone MVP — implementation track

**Дата:** 2026-04-24
**Автор:** Codex (`bmad-sprint-planning`)
**Статус:** recommended for create-story

---

## 1. Цель planning pass

Зафиксировать реалистичный порядок реализации для standalone local-first iPhone Reader MVP, исходя из уже утвержденного change direction:

- старт только от current `main` в новой ветке;
- текущий macOS app не должен ломаться;
- `codex/iphone-mvp-cloudkit` используется только как donor/reference branch;
- `CloudKit`, remote hydration и sync boot path не попадают в основной implementation track;
- целевой MVP остается узким и проверяемым:
  `local PDF import on iPhone -> local library -> open/read PDF -> restore progress -> local highlights`.

---

## 2. Planning stance

### 2.1 Основной принцип порядка

Порядок stories должен снижать продуктовый риск как можно раньше:

1. Сначала поднимаем отдельный runnable iPhone shell из `main`.
2. Потом делаем минимально достаточный local-first foundation для PDF и persistence.
3. Затем как можно быстрее закрываем core reading loop:
   `import -> library -> open -> read -> resume`.
4. Только после этого добавляем highlights.
5. Отдельные stability/guardrail stories идут после подтверждения, что core loop реально работает.

### 2.2 Что считается первым meaningful validation

Первая настоящая проверка направления происходит не в момент, когда iPhone target просто компилируется, а когда standalone app на iPhone:

- импортирует локальный PDF;
- показывает его в библиотеке;
- открывает в reader;
- возвращается на последнюю позицию после relaunch.

Именно этот slice подтверждает, что новый курс лучше старого sync-first направления.

---

## 3. Recommended Story Order

### 3.1 Recommended execution order

1. **Story 1.1: iPhone Target from Main and Local-Only App Shell**
2. **Story 1.2: Shared Local Core Extraction for iPhone Reuse**
3. **Story 1.3: Local Persistence Boot for iPhone**
4. **Story 2.1: Local PDF Import on iPhone**
5. **Story 2.2: Local Library UX for Standalone iPhone Use**
6. **Story 2.3: iPhone PDF Reader and Resume**
7. **Story 3.1: Local Highlight Creation and Persistence**
8. **Story 3.2: Highlight Reloading, Rendering, and Deletion**
9. **Story 3.3: Standalone Stability, Edge Cases, and Guardrails**

### 3.2 Какая story должна быть первой

**Первая story должна быть `Story 1.1`.**

Причина:

- она создает безопасную стартовую точку от `main`;
- она отделяет iPhone track от legacy sync-first assumptions;
- без нее все остальные stories рискуют случайно продолжить donor branch architecture;
- она минимизирует риск повредить macOS app, потому что сначала задает boundary через отдельный target и local-only composition root.

### 3.3 Почему не начинать с import или reader

Начинать сразу с `2.1` или `2.3` слишком рано, потому что:

- у команды еще нет гарантированного iPhone app shell;
- shared PDF/import pieces пока не отделены от AppKit/macOS paths;
- слишком высок шанс тащить donor code кусками без стабильной архитектурной рамки.

---

## 4. Dependencies Between Stories

### 4.1 Dependency map

`1.1 -> 1.2 -> 1.3 -> 2.1 -> 2.2 -> 2.3 -> 3.1 -> 3.2 -> 3.3`

### 4.2 Story-by-story dependencies

**Story 1.1**
- Нет обязательных story-зависимостей.
- Должна создать новую ветку от `main`, iPhone target и local-only app entry.

**Story 1.2**
- Зависит от `1.1`.
- Нужна, чтобы безопасно отделить reusable local core от macOS/AppKit-only кода.

**Story 1.3**
- Зависит от `1.1` и частично от `1.2`.
- Нужна для локального boot path и library read path без sync dependencies.

**Story 2.1**
- Зависит от `1.2` и `1.3`.
- Нужна iOS-safe PDF import pipeline и local persistence.

**Story 2.2**
- Зависит от `1.3` и `2.1`.
- UI библиотеки имеет смысл делать после реального local import flow.

**Story 2.3**
- Зависит от `1.2`, `1.3`, `2.1`, `2.2`.
- Reader/resume опирается на уже работающие local file records и open flow из библиотеки.

**Story 3.1**
- Зависит от `2.3`.
- Highlight creation не должен появляться до рабочего open/read loop.

**Story 3.2**
- Зависит от `3.1`.
- Reload/render/delete логично строить поверх уже существующего create/persist flow.

**Story 3.3**
- Зависит от `2.1-3.2`.
- Это финальная hardening story, а не входная точка.

---

## 5. First Runnable Slice

### 5.1 Recommended first runnable slice

**Первый runnable slice:** `1.1 + 1.2 + 1.3 + 2.1 + 2.2 + 2.3`

### 5.2 Почему именно этот slice

Это самый ранний slice, который:

- проверяет standalone local-first direction;
- не требует `CloudKit`;
- не зависит от macOS ingestion flow;
- дает реальный пользовательский сценарий, а не только технический scaffold.

### 5.3 Observable outcome slice

После завершения этого slice должно быть возможно:

1. Собрать и запустить iPhone target из новой ветки, основанной на `main`.
2. Импортировать локальный PDF через iPhone file picker.
3. Увидеть PDF в локальной библиотеке.
4. Открыть PDF и читать его на iPhone.
5. Закрыть приложение и вернуться на ту же позицию чтения.

Это и есть первая ранняя валидация нового продукта.

---

## 6. MVP-Critical vs Later Polish

### 6.1 Обязательные stories для первого runnable MVP

`MVP runnable core`

- `1.1`
- `1.2`
- `1.3`
- `2.1`
- `2.2`
- `2.3`

### 6.2 Обязательные stories для целевого MVP scope

`Full target MVP`

- `1.1`
- `1.2`
- `1.3`
- `2.1`
- `2.2`
- `2.3`
- `3.1`
- `3.2`

### 6.3 Что можно отложить на later polish

`Later polish / hardening`

- `3.3: Standalone Stability, Edge Cases, and Guardrails`

Важно:

- `3.3` все еще ценна до merge back, но не должна блокировать первую проверку product direction.
- Если потребуется еще более узкий cut, часть non-critical UX polish из `2.2` тоже можно держать минимальной в первой реализации:
  пустой state, список книг, open action, базовый error state.

---

## 7. Execution Notes Per Story

### 7.1 Story 1.1

**Цель:** создать безопасный implementation lane.

**Основной результат:**

- новая рабочая ветка от `main`;
- `ReaderiPhone` target;
- отдельный iPhone app shell;
- local-only composition root;
- явное отсутствие `CloudKit`, entitlement checks и `Reader/Sync` в startup.

**Почему это first story:** без нее нет гарантии, что все дальнейшие изменения идут по правильной архитектурной траектории.

### 7.2 Story 1.2

**Цель:** извлечь только те shared pieces, которые реально нужны iPhone MVP.

**Основной результат:**

- reusable local data/persistence core остается shared;
- PDF/import foundation split from AppKit/macOS-only paths;
- donor branch код переносится file-by-file, а не пакетно.

**Ключевой guardrail:** не переносить sync-expanded repository contracts и sync-specific schema.

### 7.3 Story 1.3

**Цель:** local persistence boot без скрытой зависимости на sync.

**Основной результат:**

- local DB init на iPhone;
- local repositories;
- библиотека может читать локальные книги;
- empty state local-first.

### 7.4 Story 2.1

**Цель:** добавить первый real-value entry point.

**Основной результат:**

- `UIDocumentPicker`;
- copy-to-sandbox;
- создание локального `Book`;
- базовый local import error handling.

**Почему это раньше `2.2`:** UI библиотеки без реального import flow хуже валидирует продукт.

### 7.5 Story 2.2

**Цель:** сделать понятный standalone local library UX.

**Основной результат:**

- empty state без ссылок на Mac/sync;
- список импортированных PDF;
- open action через local file URL;
- понятный fallback при missing file.

### 7.6 Story 2.3

**Цель:** закрыть основной сценарий чтения.

**Основной результат:**

- iPhone PDF reader screen;
- навигация;
- local progress persistence;
- restore reading position after relaunch;
- никаких progress publish hooks в sync path.

### 7.7 Story 3.1

**Цель:** добавить локальную полезность поверх reading loop.

**Основной результат:**

- создание highlight;
- local persistence;
- immediate rendering in open reader.

### 7.8 Story 3.2

**Цель:** сделать highlights устойчивыми во времени.

**Основной результат:**

- highlight reload on reopen;
- local deletion;
- отсутствие "воскресающих" highlights.

### 7.9 Story 3.3

**Цель:** закрепить архитектурные и runtime guardrails.

**Основной результат:**

- smoke checks на import/open/resume/highlight path;
- защита macOS flows от regressions;
- явная проверка, что donor sync code не протек в MVP lane.

---

## 8. Branch and Reuse Rules

### 8.1 Branch policy

- Начинать с новой ветки от current `main`.
- Не продолжать `codex/iphone-mvp-cloudkit`.
- Не использовать donor branch как merge base.

### 8.2 Reuse policy

Разрешено переносить только isolated reusable pieces:

- iPhone `PDFView` wrapper ideas;
- screen structure for iPhone reader/library;
- PDF anchor/highlight geometry helpers;
- target strategy.

Нельзя переносить в MVP lane:

- `CloudKit` wiring;
- entitlement checks;
- sync-expanded repository contracts;
- sync-specific migrations и metadata;
- remote hydration behavior;
- progress/highlight publication to sync from active reader path.

---

## 9. Create-Story Ready Queue

### 9.1 Recommended queue for next steps

1. `Story 1.1: iPhone Target from Main and Local-Only App Shell`
2. `Story 1.2: Shared Local Core Extraction for iPhone Reuse`
3. `Story 1.3: Local Persistence Boot for iPhone`
4. `Story 2.1: Local PDF Import on iPhone`
5. `Story 2.2: Local Library UX for Standalone iPhone Use`
6. `Story 2.3: iPhone PDF Reader and Resume`
7. `Story 3.1: Local Highlight Creation and Persistence`
8. `Story 3.2: Highlight Reloading, Rendering, and Deletion`
9. `Story 3.3: Standalone Stability, Edge Cases, and Guardrails`

### 9.2 Recommended next create-story target

**Следующей командой стоит запускать `create-story` для `Story 1.1`.**

Причина:

- это минимальная безопасная точка входа;
- она определяет branch strategy и composition boundary для всего остального трека;
- все последующие stories будут проще и чище, если `1.1` уже зафиксирована как story artifact.

---

## 10. Sprint Planning Summary

### Recommendation

- Первый implementation track должен покрывать `1.1 -> 1.2 -> 1.3 -> 2.1 -> 2.2 -> 2.3`.
- Первая story: `1.1`.
- Первый runnable slice: standalone import/library/read/resume.
- Highlights добавлять только после подтверждения, что local reading loop уже рабочий.
- `CloudKit sync` остается отдельным later track и не входит в первый MVP execution lane.
