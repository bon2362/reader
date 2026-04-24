# Sprint Change Proposal: iPhone MVP from Sync-First to Standalone Local-First

**Дата:** 2026-04-24  
**Статус:** Draft for approval  
**Режим:** Batch  
**Change scope:** Moderate  

---

## 1. Summary of the Issue

### Проблема

Текущее направление iPhone MVP зафиксировано как `sync-first`: iPhone-клиент считается lightweight companion app для macOS и зависит от `CloudKit`, remote hydration и сценария "импорт на Mac -> чтение на iPhone".

Это больше не соответствует целевому продукту.

### Новый курс

Новый iPhone MVP должен быть `standalone local-first reader`:

- iPhone-приложение запускается и приносит ценность само по себе;
- не зависит от macOS;
- не зависит от CloudKit;
- не зависит от paid Apple Developer account;
- покрывает локальный сценарий: import PDF -> local library -> read -> restore progress -> local highlights.

### Триггер и evidence

Триггером change navigation стало переопределение продуктового направления на основе checkpoint-анализа ветки `codex/iphone-mvp-cloudkit`:

- ветка полезна как донор iPhone/PDF foundation, но не как база для продолжения;
- direct merge конфликтует с текущим `main`;
- app/container/repository/boot flow слишком завязаны на sync;
- local import на iPhone отсутствует;
- standalone UX для библиотеки отсутствует;
- current branch state не является runnable baseline для standalone MVP.

Источники:

- `/Users/ekoshkin/_bmad-output/feature-docs/ios-standalone/iphone-cloudkit-branch-checkpoint.md`
- `/Users/ekoshkin/reader/_bmad-output/feature-docs/ios-standalone/epics-reader-app-iphone-mvp.md`
- `/Users/ekoshkin/reader/_bmad-output/project-docs/architecture-iphone-mvp.md`

---

## 2. Checklist Status

### Section 1: Understand the Trigger and Context

- [x] 1.1 Triggering story identified
  Trigger story group: current iPhone MVP track (`Epic 1-3` in `epics-reader-app-iphone-mvp.md`).
- [x] 1.2 Core problem defined
  Issue type: strategic pivot plus mismatch between implementation direction and new product goal.
- [x] 1.3 Evidence collected
  Evidence comes from branch checkpoint and current planning artifacts.

### Section 2: Epic Impact Assessment

- [x] 2.1 Current epic assessed
  Existing iPhone epic set cannot be completed "as planned" because its value proposition is cross-device sync, not standalone reading.
- [x] 2.2 Epic-level changes identified
  Existing iPhone sync-first epics must be replaced with standalone local-first epics.
- [x] 2.3 Remaining epics reviewed
  Current macOS MVP and annotation exchange work on `main` should remain intact.
- [x] 2.4 Future epics evaluated
  CloudKit sync should survive as a follow-up epic group after standalone foundation lands.
- [x] 2.5 Epic ordering reconsidered
  Implementation order must shift from sync substrate first to local import/library/reader first.

### Section 3: Artifact Conflict and Impact Analysis

- [x] 3.1 PRD conflict reviewed
  PRD must be extended from "future iPhone + iCloud sync" to explicitly define standalone iPhone PDF MVP before sync.
- [x] 3.2 Architecture conflict reviewed
  `architecture-iphone-mvp.md` is sync-first and must be rewritten or superseded.
- [x] 3.3 UI/UX impact reviewed
  iPhone library UX, empty states, boot flow, and import flow must become local-first.
- [x] 3.4 Secondary artifact impact reviewed
  `sprint-status.yaml`, future story files, and branch strategy must be updated after approval.

### Section 4: Path Forward Evaluation

- [x] 4.1 Option 1: Direct adjustment
  Viable. Rebuild iPhone roadmap around standalone local-first, reusing only safe foundation.
- [ ] 4.2 Option 2: Potential rollback
  Not viable as primary path. The checkpointed branch should be preserved as reference, not merged or rolled forward.
- [ ] 4.3 Option 3: PRD MVP review
  Partially viable as a supporting action. PRD wording needs adjustment, but not a reduction of macOS MVP itself.
- [x] 4.4 Recommended path selected
  Hybrid leaning to Option 1: direct roadmap reset for iPhone, plus explicit future-sync deferral.

### Section 5: Sprint Change Proposal Components

- [x] 5.1 Issue summary created
- [x] 5.2 Epic and artifact impacts documented
- [x] 5.3 Recommended path documented
- [x] 5.4 MVP impact and action plan defined
- [x] 5.5 Handoff plan established

### Section 6: Final Review and Handoff

- [x] 6.1 Checklist reviewed
- [x] 6.2 Proposal verified
- [!] 6.3 User approval pending
- [!] 6.4 `sprint-status.yaml` update deferred until approval

---

## 3. Impact Analysis

### Что именно меняется в курсе проекта

Проект не отменяет iPhone-направление и не отменяет будущий `CloudKit sync`, но меняет порядок и главный критерий ценности:

- было: `sync-first iPhone companion app`;
- становится: `standalone local-first iPhone reader`;
- было: iPhone зависит от macOS ingestion и CloudKit;
- становится: iPhone сам импортирует PDF, хранит локальную библиотеку и работает без внешних зависимостей;
- было: sync foundation открывает путь к iPhone;
- становится: standalone iPhone foundation открывает путь к будущему sync layer.

### Epic impact

Current iPhone epics affected:

- `Epic 1: Sync Foundation` -> больше не является входной точкой iPhone MVP;
- `Epic 2: iPhone Reader Client` -> должен быть переписан из sync client в standalone app;
- `Epic 3: Cross-Device Highlights` -> выносится из MVP в future sync track.

Unaffected / protected:

- текущий macOS app на `main`;
- уже реализованные macOS features;
- текущие annotation exchange improvements на `main`.

### PRD impact

PRD сейчас описывает:

- macOS MVP как основную поставку;
- future phase с `iPhone-версией` и `iCloud sync`.

Нужно уточнить roadmap:

- standalone iPhone PDF MVP становится отдельной фазой перед CloudKit sync;
- CloudKit sync остается в roadmap, но после local-first iPhone foundation;
- iPhone EPUB можно зафиксировать как post-MVP/follow-up phase.

### Architecture impact

Архитектурно меняется следующее:

1. iPhone composition root должен быть local-first и platform-safe.
2. Sync не должен присутствовать в основном boot path iPhone MVP.
3. Repository API нужно делить на local contract и future sync extensions.
4. Data model не должен сейчас получать sync metadata поверх `main`.
5. Ветка `codex/iphone-mvp-cloudkit` должна использоваться как donor/reference, а не как branch для merge continuation.

### Technical/codebase impact

- новая разработка должна идти от `main` в новой ветке;
- reusable code переносится выборочно;
- branch-specific migrations, sync DTO, CloudKit container wiring и sync boot logic не переносятся;
- macOS composition и существующие stores на `main` не заменяются branch-версиями.

---

## 4. Path Forward Recommendation

### Recommended approach

Рекомендуется `Direct Adjustment + Explicit Future Sync Deferral`.

Это означает:

1. Остановить iPhone MVP как sync-first stream.
2. Зафиксировать новый standalone scope как основной.
3. Создать новую ветку от `main`.
4. Переносить из `codex/iphone-mvp-cloudkit` только reusable foundation.
5. Спланировать future CloudKit sync как отдельный epic после standalone MVP.

### Почему это лучший путь

- минимальный риск сломать `main`;
- сохраняет полезный код из branch без опасного merge;
- сокращает MVP до реально runnable и проверяемого сценария;
- отделяет продуктовую валидацию standalone reading от более дорогой sync-задачи;
- оставляет CloudKit как следующий шаг, а не выбрасывает его.

### Оценка

- Effort: Medium
- Risk: Medium
- Timeline impact: положительный для standalone MVP, потому что убирается sync-first dependency chain

---

## 5. Detailed Change Proposals

### 5.1 Epic Plan Replacement

#### Artifact: `epics-reader-app-iphone-mvp.md`

**OLD**

- Epic 1: Sync Foundation
- Epic 2: iPhone Reader Client
- Epic 3: Cross-Device Highlights

**NEW**

- Epic 1: iPhone Standalone Foundation
- Epic 2: Local PDF Library and Reader
- Epic 3: Local Highlights and Polish
- Epic 4: Future CloudKit Sync Layer

**Rationale**

Новый набор эпиков отражает standalone ценность в правильной последовательности. Sync остается, но больше не блокирует первую работающую поставку на iPhone.

#### Proposed updated epics

##### Epic 1: iPhone Standalone Foundation

Цель: поднять отдельный iPhone target и local-first composition, не затрагивая macOS app flow.

Stories:

- Story 1.1: iOS Target from Main and Standalone Composition
  Создать новую ветку от `main`, поднять runnable iPhone target, выделить local-first container без CloudKit, entitlement checks и sync bootstrap.
- Story 1.2: Shared PDF Foundation Extraction
  Перенести безопасные reusable PDF/iPhone primitives из reference branch и адаптировать их к актуальному `main`.
- Story 1.3: Local Persistence Boot for iPhone
  Подключить локальную базу, local repositories и standalone app boot без зависимости от macOS.

##### Epic 2: Local PDF Library and Reader

Цель: закрыть core standalone сценарий "импортировал PDF на iPhone -> вижу его в библиотеке -> открыл -> читаю -> вернулся на ту же позицию".

Stories:

- Story 2.1: Local PDF Import on iPhone
  Добавить `UIDocumentPicker`, копирование PDF в sandbox, вычисление локального metadata footprint и создание `Book`.
- Story 2.2: Local Library UX for iPhone
  Сделать empty state, list/grid state и library actions под standalone use case без упоминаний macOS/sync.
- Story 2.3: iPhone PDF Reader and Resume
  Открытие PDF, навигация, восстановление позиции чтения, локальное сохранение progress.

##### Epic 3: Local Highlights and MVP Polish

Цель: завершить standalone MVP локальными highlights без cross-device semantics.

Stories:

- Story 3.1: Local Highlight Creation and Persistence
  Использовать reusable highlight foundation, но сохранить только local behavior.
- Story 3.2: Highlight Loading, Rendering, and Deletion
  Показ существующих highlights и локальное удаление без sync pipeline.
- Story 3.3: Standalone Stability and Guardrails
  Проверить app lifecycle, import edge cases, restore behavior, and non-regression for macOS shared code.

##### Epic 4: Future CloudKit Sync Layer

Цель: отложенный follow-up epic, не входящий в standalone MVP.

Stories:

- Story 4.1: Sync-Neutral Contracts and Metadata Design on Top of Main
- Story 4.2: CloudKit Book and Asset Sync
- Story 4.3: Progress Sync Policy
- Story 4.4: Cross-Device Highlights and Conflict Handling

### 5.2 Architecture Redirection

#### Artifact: `architecture-iphone-mvp.md`

**OLD**

- iPhone рассматривается как lightweight reading client;
- import выполняется только на macOS;
- локальная база на устройствах играет роль cache;
- `CloudKit` входит в основной MVP path.

**NEW**

- iPhone рассматривается как самостоятельный local-first reader;
- import PDF выполняется прямо на iPhone;
- локальная база является основным source of truth для iPhone MVP;
- `CloudKit` и sync вынесены из основного MVP path в follow-up architecture;
- shared layer остается, но без смешивания local CRUD и sync lifecycle в одной обязательной линии запуска.

**Rationale**

Архитектура должна поддерживать самостоятельный запуск iPhone app, а не forced dependency на macOS ingestion и Apple cloud capabilities.

#### Архитектурные последствия

1. Нужен отдельный `iPhoneStandaloneContainer` или эквивалентный composition root.
2. `AppContainer` из reference branch не должен становиться shared default container на `main`.
3. Library repository contract должен иметь local-first базу; sync-specific методы выносятся в future extension layer.
4. Прогресс чтения и highlights должны сначала работать как локальные features с optional sync hooks later.
5. Миграции и модели из cloudkit-branch не переносятся поверх `main` механически.

### 5.3 Branch Strategy

#### Artifact: implementation approach / branch policy

**OLD**

- implicit continuation from `codex/iphone-mvp-cloudkit`

**NEW**

- создать новую рабочую ветку от `main`;
- использовать `codex/iphone-mvp-cloudkit` как reference branch/donor only;
- переносить код через selective cherry-pick or manual extraction by file/feature, а не через merge.

**Rationale**

Checkpoint уже подтвердил конфликты по migrations, models, stores and app composition. Новый branch-from-main путь безопаснее и дешевле.

### 5.4 Reusable vs Deferred Work

#### Reusable from `iphone-cloudkit` branch

Можно переносить как foundation после адаптации к `main`:

- отдельный iPhone target как направление структуры проекта;
- `ReaderiPhone/App/ReaderiPhoneApp.swift` как reference entrypoint pattern;
- `ReaderiPhone/Features/IPhonePDFReaderView.swift` как starting point для iPhone PDF reader UI;
- `ReaderiPhone/Features/IPhonePDFKitView.swift` как `UIViewRepresentable` wrapper around `PDFView`;
- PDF primitives:
  - `Reader/Features/PDFReader/PDFAnchor.swift`
  - `Reader/Features/PDFReader/PDFHighlightRenderer.swift`
  - `Reader/Features/PDFReader/PDFMarkupGeometry.swift`
- local utilities:
  - `Reader/Shared/FileAccess.swift`
  - `Reader/Shared/FileHash.swift`
- ideas from `HighlightsStore` where sync remains optional and can be removed cleanly.

#### Not for now / Future sync work

Не входит в standalone MVP и должно быть отложено:

- `Reader/Sync/*` и весь `CloudKit` stack;
- `SyncCoordinator`, `CloudKitSyncService`, mappers, DTOs, tombstones;
- sync metadata in `Book` and `Highlight`;
- branch migrations `006_books_sync_metadata` and `007_highlights_sync_metadata`;
- sync-dependent `AppContainer`;
- `syncOnLaunch()`, remote hydration, asset downloading states;
- repository API methods for remote upsert/tombstones/progress sync;
- cross-device conflict handling and observability for sync;
- any UX text that assumes "import on Mac and wait for sync".

### 5.5 PRD Roadmap Adjustment

#### Artifact: `prd-reader-app.md`

**OLD**

- Фаза 4 — Sync и резервирование
  - ручной экспорт/импорт SQLite
  - iCloud sync через CloudKit
  - iPhone-версия на том же Readium toolkit

**NEW**

- Фаза 4 — Standalone iPhone PDF Reader
  - отдельный iPhone target в том же репозитории
  - local PDF import on iPhone
  - local library
  - PDF reading with resume
  - local highlights
- Фаза 5 — CloudKit Sync Follow-up
  - cross-device sync через CloudKit
  - remote asset hydration
  - sync metadata
  - conflict handling
- EPUB на iPhone остается post-MVP/follow-up после standalone PDF baseline.

**Rationale**

Это точнее отражает реальный порядок снижения риска и доставки ценности.

---

## 6. Recommended Implementation Order

1. Создать новую ветку от `main` для standalone iPhone MVP.
2. Поднять standalone iPhone target и local-first composition.
3. Перенести reusable PDF foundation из reference branch.
4. Реализовать local PDF import on iPhone.
5. Реализовать local library UX.
6. Реализовать read/open/resume flow.
7. Подключить local highlights.
8. После стабилизации спланировать отдельный CloudKit sync epic.

---

## 7. Scope Classification and Handoff

### Scope classification

`Moderate`

Почему не Minor:

- меняется направление целого iPhone stream;
- требуется перестройка epics/stories and architecture artifact;
- нужна координация backlog, а не только implementation change.

Почему не Major:

- основной macOS MVP не пересматривается;
- продуктовая цель не ломается, а упрощается;
- CloudKit не отменяется, а переносится.

### Handoff recipients

- Product Owner / planning workflow:
  обновить epics, story sequence и sprint tracking после approval.
- Developer workflow:
  создать новую ветку от `main` и начать standalone foundation.
- Future Architect/PM follow-up:
  вернуться к sync layer после стабилизации standalone MVP.

### Success criteria

- iPhone MVP описан как standalone local-first;
- branch strategy фиксирует branch-from-main;
- reusable and deferred scope clearly separated;
- macOS `main` path protected from regression;
- future CloudKit sync preserved as separate follow-up epic.

---

## 8. Recommended Next BMad Step

Следующий шаг после approval этого correct course:

`bmad-create-epics-and-stories`

Почему именно он:

- этот workflow уже определил новый курс, но backlog еще не материализован;
- нужно официально переписать iPhone epic file и подготовить story list под standalone MVP;
- после этого можно сразу запускать `bmad-create-story` для Story 1.1 и передавать ее в `bmad-dev-story` или обычную dev-реализацию.

Practical sequence:

1. Approve this Sprint Change Proposal.
2. Run `bmad-create-epics-and-stories` for standalone iPhone MVP.
3. Create first implementation story: `iOS Target from Main and Standalone Composition`.
4. Start development from a new branch off `main`.

---

## 9. Approval Request

Предлагаемый Sprint Change Proposal:

- переводит iPhone MVP из sync-first в standalone local-first;
- фиксирует branch-from-main strategy;
- сохраняет reusable foundation из `codex/iphone-mvp-cloudkit`;
- выносит CloudKit sync в отдельный future epic;
- защищает текущий macOS app and `main`.

Ожидаемое решение пользователя:

- `Approve` — можно обновлять epic/story artifacts и `sprint-status.yaml`;
- `Revise` — требуется скорректировать структуру или scope;
- `Reject` — change proposal не принимается.
