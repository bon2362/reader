# Ретроспектива: iPhone Standalone MVP (эпики 1–3)

**Дата:** 2026-04-24
**Участник:** Koshkin (Project Lead)
**Команда (party mode):** Amelia (Developer, facilitator), Alice (PO), Charlie (Senior Dev), Dana (QA), Elena (Junior Dev)
**Формат:** сводная ретро по треку iPhone Standalone MVP
**Язык документа:** русский (`document_output_language` из `_bmad/bmm/config.yaml`)

---

## 1. Сводка трека

| Метрика | Значение |
|---|---|
| Эпиков завершено | 3 из 3 (Foundation → Local PDF Library/Reader → Local Highlights/Polish) |
| Историй завершено | 9 из 9 (100%) |
| Продолжительность | один день (все истории 2026-04-24) |
| Ветка | `codex/iphone-standalone-mvp` от current `main` |
| Блокеры | 2 мелких (отсутствующий `iPhone 16` destination → перешли на `iPhone 17`; stale file reference требует повторного `xcodegen generate`) |
| Sync-leak scan | ✅ чисто (`rg` не нашёл `SyncCoordinator`, `CloudKit`, `publishStableProgress`, `beginReading/endReading` в standalone path) |
| macOS regressions | ✅ все зелёные (`BookImporterTests`, `PDFBookLoaderTests`, `PDFReaderStoreTests`, `AnnotationExportServiceTests`, `AnnotationImportServiceTests`, `HighlightsStoreTests`, `AnnotationRepositoryTests`, `LibraryRepositoryTests`, `PDFReadingProgressTests`) |
| Новые unit-тесты | `PDFReadingProgressTests`, обновлённый `HighlightsStoreTests` (external renderer path), обновлённый `BookImporterTests` (PDF import + broken-record guardrail) |
| Simulator smoke | ✅ install → launch → terminate → relaunch `com.koshkin.readeriphone` успешно |
| Real device testing | ✅ пройдено 2026-04-24 (import → open → resume → highlight lifecycle отработали на физическом iPhone) |

### Состав трека

**Epic 1 — iPhone Standalone Foundation:** безопасный старт от `main`, без donor branch как merge base; отдельный `ReaderiPhone` target с iOS deployment 17.0; local-only composition root; shared local core extraction (`DatabaseManager`, `LibraryRepository`, `AnnotationRepository`, `PDFBookLoader`, `BookImporter`, `FileAccess`); local DB boot + local library read path.

**Epic 2 — Local PDF Library and Reader:** iPhone PDF import через `UIDocumentPicker` с security-scoped ingest; standalone local-first library UX с cover/metadata/progress; iPhone PDF reader на `PDFKit` с local progress persistence/resume через существующий `LibraryRepository`.

**Epic 3 — Local Highlights and MVP Polish:** создание highlight через text selection + `PDFHighlightRenderer`; reload/render/delete цикл для highlights; standalone stability check (sync-leak scan + macOS regressions + edge cases).

---

## 2. Что получилось хорошо

### Продуктовая сторона
- **Sprint change proposal от 24.04 был правильным решением.** Отказ от sync-first курса и старт standalone MVP от `main` позволил избежать зависимости от paid Apple Developer account, CloudKit-entitlement и donor branch state. Core flow `local import → library → open/read → resume → local highlights` закрыт полностью.
- **Phase 2 из macOS MVP retrospective (20.04) закрыт на две трети:** iPhone-версия ✅, PDF ✅, экспорт аннотаций ✅ (Epic 4 annotation-markdown-exchange). Остаётся только iCloud sync, который сознательно отложен.

### Архитектурная сторона
- **Shared local core extraction без регрессий.** `PDFBookLoader` переехал с жёсткой зависимости от `NSImage` на cross-platform pipeline через новый `ImageDataTransformer` и `ImageIO`. `BookImporter` стал iOS-safe. Ни один macOS-тест не сломался.
- **`HighlightsStore` адаптирован под cross-platform reuse:** EPUB bridge path ограничен macOS, external renderer path открыт iPhone target. Один стор обслуживает обе платформы без развилки на уровне бизнес-логики.
- **`PDFReadingProgress` вынесен в отдельный unit-тестируемый модуль.** Логика page clamping / anchor encoding изолирована от iPhone UI — тестируется без Simulator.
- **Fail-safe startup в `IPhoneAppContainer`:** создание через `do/catch` с startup error screen. Падение DB не даёт крашнуть приложение без explanation.
- **Separate `ReaderiPhone` target с отдельным entry point и composition root.** Boundary зафиксирован структурно, а не условными компиляциями. Случайно протащить `Reader/Sync` невозможно без осознанного подключения файла.

### Процессная сторона
- **Sync-leak scan через `rg` как formalized verification.** Story 3.3 явно зафиксировала scan как acceptance criterion. Паттерн для воспроизведения в будущих эпиках.
- **End-to-end simulator smoke (install/launch/terminate/launch)** выполнен как часть DoD Story 3.3.
- **XcodeGen (`project.yml` как source of truth)** упростил управление двумя targets: изменения в структуре проекта — через один YAML.

---

## 3. Что было непросто

### Технические трения
- **Xcode Simulator destination.** Первая попытка build зависла из-за отсутствия `iPhone 16` destination; перешли на `iPhone 17`. Мелочь, но замедляет итерации.
- **`xcodegen generate` требует повторного запуска** после замены view, иначе остаётся stale file reference.
- **`@MainActor` isolation в тестах:** `TestPDFFactory.makeTextPDF` пришлось пометить `@MainActor`, потому что factory уже actor-isolated.

### Стратегические издержки
- **Отменённая работа по sync-first треку.** Три эпика (`epic-1-sync-foundation`, `epic-2-iphone-reader-client`, `epic-3-cross-device-highlights`) со своими историями больше не актуальны. Sprint change proposal сохранил их как reference, но direct переноса не будет — это реальная потеря усилий до pivot.
- **Ограниченный scope MVP.** iPhone получил только PDF + highlights. EPUB, text notes, sticky notes, annotation panel — сознательно исключены из MVP, но пользователи могут этого ожидать по аналогии с macOS.

### Операционные разрывы
- **Нет real device testing.** Только Simulator. Это MVP-риск: PDFKit поведение на реальном iPhone (память, жесты, touch latency) не верифицировано.
- **Нет CI для iPhone target.** Сборка ReaderiPhone не автоматизирована; сломать её можно незаметно коммитом в shared code.
- **Simulator smoke вручную.** Нет скрипта, закрепляющего последовательность install/launch/terminate/launch.
- **Sync-leak scan вручную.** Есть как acceptance criterion, но не как regression guard в pipeline.

---

## 4. Follow-through предыдущей ретро (macOS MVP, 20.04.2026)

Предыдущая ретро (`retrospective-reader-app-mvp.md`) была flat-документом-сводкой, без явных action items. Но содержала раздел «Что не делали / отложено» — по сути список Phase 2:

| Пункт Phase 2 | Статус после iPhone MVP трека |
|---|---|
| iPhone-версия | ✅ Закрыто (этот трек) |
| PDF | ✅ Закрыто (этот трек) |
| Экспорт аннотаций (markdown) | ✅ Закрыто Epic 4 annotation-markdown-exchange |
| iCloud sync | ⏳ Остался в backlog (Epic 4 CloudKit Sync, 4 истории `ready-for-dev`, эпик сам `backlog`) |
| Readium Swift Toolkit | ❌ Не в приоритете; собственный парсер остаётся |
| Темы / шрифты / размер текста | ❌ Не в приоритете |
| Горячие клавиши для смены цвета highlight | ❌ Не в приоритете |

**Итог:** явных process-commitments из предыдущей ретро не было, но Phase 2 roadmap исполнен более чем наполовину.

---

## 5. Ключевые инсайты

1. **Local-first extraction работает для кроссплатформенности.** Выделение shared core (`Reader/Database`, repositories, `FileAccess`, PDF primitives) из macOS-кода в iOS-safe форму не требует переписывания macOS — только аккуратной замены AppKit-специфичных участков (`NSImage` → `ImageIO`).
2. **Отдельный target — недорогая инвестиция с высокой отдачей.** `ReaderiPhone` target с собственным composition root даёт структурную гарантию изоляции от sync. Это сильнее условной компиляции или runtime-проверок.
3. **Guardrails должны быть formalized.** Sync-leak scan как `rg`-проверка — хорошая идея, но без автоматизации в CI она деградирует до memory-based discipline.
4. **Pivot дешевле, чем упорство.** Переключение с sync-first на standalone MVP после проделанной работы было болезненно, но позволило закрыть реальную ценность без блокирующих dependencies (paid Apple Dev account).
5. **Simulator smoke ≠ production ready.** MVP собран и пройден как Simulator smoke, но для заявления real-world готовности нужен реальный iPhone + автоматизация.

---

## 6. Action items (по результатам ретро)

### Process / Architecture
| # | Действие | Owner | Критерий готовности |
|---|---|---|---|
| A1 | Автоматизировать sync-leak scan: оформить `rg`-проверку как скрипт `scripts/verify-iphone-local-first.sh` (или аналог) и подключить к CI/pre-commit | Developer | Скрипт падает, если в `ReaderiPhone/` или shared iPhone path встречается `SyncCoordinator`, `CloudKit`, `publishStableProgress`; проходит сейчас |
| A2 | Автоматизировать simulator smoke: скрипт `scripts/iphone-smoke.sh`, выполняющий `xcrun simctl install → launch → terminate → launch` за одну команду | Developer | Скрипт выполняет полный цикл smoke и возвращает exit code; документирован в README |
| A3 | Настроить CI-шаг для iPhone target: `xcodebuild -scheme ReaderiPhone -destination 'platform=iOS Simulator,name=iPhone 17'` в GitHub Actions | Developer | CI падает на PR, если iPhone target не собирается |

### Technical debt / Cleanup
| # | Действие | Owner | Приоритет |
|---|---|---|---|
| D1 | Очистить donor branch и отменённые sync-истории: архивировать или удалить ветку `codex/iphone-mvp-cloudkit`, файлы `epic-1-sync-foundation__*`, `epic-2-iphone-reader-client__*`, `epic-3-cross-device-highlights__*` из `_bmad-output/stories/` | Developer | средний — снижает confusion, но не блокирует |

### Readiness gating
| # | Действие | Owner | Критерий |
|---|---|---|---|
| ~~R1~~ | ✅ **Выполнено 2026-04-24.** Real device test iPhone MVP пройден на физическом устройстве: core flow (import PDF → open → resume после relaunch → create/reload/delete highlight) отработал без крашей и визуальных регрессий | Koshkin | **Done** |
| R2 | Актуализировать Epic 4 (CloudKit Sync) definition после real device testing: пересмотреть допущения (paid Apple Dev account необходим, schema migrations для sync metadata, conflict UX, tombstones в `Highlight`) до того, как эпик будет выведен из backlog | Koshkin + Architect | Epic 4 stories обновлены или явно помечены как требующие re-planning |

---

## 7. Preparation tasks для следующего эпика

**Решение по следующему эпику:** Epic 4 (Future CloudKit Sync Layer) **остаётся в backlog**. Стартовать не скоро. Вместо немедленного старта — закрыть prep-задачи и вернуться к вопросу timing позже.

Prep-задачи (все выбраны Koshkin в ретро-диалоге):

- [x] Согласовано: Автоматизировать sync-leak scan (см. A1)
- [x] Согласовано: Автоматизировать simulator smoke (см. A2)
- [x] Согласовано: Настроить CI для iPhone target (см. A3)
- [x] Согласовано: Очистить donor branch и отменённые sync-истории (см. D1)

**Порядок:** A1–A3 параллелятся, D1 можно делать в любой момент, R1 зависит от наличия physical device.

---

## 8. Significant discoveries — требуется актуализация Epic 4

**Решение Koshkin:** актуализация Epic 4 нужна до старта.

Обнаруженные расхождения плана Epic 4 с реальностью iPhone MVP:

1. **Paid Apple Developer account — не подтверждённая предпосылка.** Epic 4 Story 4.2 (CloudKit Book Catalog and Asset Sync) предполагает доступ к CloudKit. Это требует оплаченного Apple Developer Program. Если account недоступен, Epic 4 нереализуем в текущей форме.
2. **Schema migrations для sync metadata.** Epic 4 Story 4.3/4.4 требуют tombstones, remote IDs, conflict rules в моделях `Book` и `Highlight`. iPhone MVP сознательно не добавил эту метадату (NFR6). Значит Epic 4 открывается миграцией — это `Migration_005+` и пересборка shared schema.
3. **Real device testing infra отсутствует.** Epic 4 нельзя валидировать без реальных iPhone (минимум двух для cross-device сценария). Это предпосылка, которой нет.
4. **Conflict UX не спроектирован.** Epic 4 Story 4.3/4.4 упоминают «explicit conflict policy», но концепция UX для конфликтов (что видит пользователь, когда два устройства расходятся) не определена ни в PRD, ни в эпик-файле.

**Рекомендация:** до перевода Epic 4 из `backlog` в `in-progress` — провести отдельную planning-сессию: уточнить feasibility Apple Dev account, спроектировать schema migration, определить conflict UX, подтвердить real device availability.

---

## 9. Readiness assessment iPhone Standalone MVP

| Измерение | Статус |
|---|---|
| Testing & Quality | ✅ unit-тесты зелёные, simulator smoke пройден, real device test пройден |
| Architectural guardrails | ✅ sync-leak scan чисто, boundary формализован отдельным target; ⚠️ не автоматизирован (см. A1–A3) |
| macOS regressions | ✅ нет |
| Stakeholder acceptance | — (single-developer проект) |
| Deployment | Не задеплоено в App Store (single-user use case) |
| Stability | ✅ relaunch baseline стабилен на Simulator и на физическом iPhone |
| Unresolved blockers | ✅ нет блокеров для продолжения |

**Итог:** iPhone Standalone MVP **готов**. Simulator smoke и real device test пройдены (2026-04-24). До Epic 4 остаётся актуализация (R2, раздел 8) и prep-задачи (A1–A3, D1).

---

## 10. Critical path до следующего этапа

1. ~~**R1 — Real device test iPhone MVP**~~ ✅ Пройдено 2026-04-24.
2. **A1 — Автоматизировать sync-leak scan.**
3. **A2 — Автоматизировать simulator smoke.**
4. **A3 — CI для iPhone target.**
5. **D1 — Очистить donor branch / sync-истории.**
6. **R2 — Актуализировать Epic 4** (до вывода из backlog).

---

## 11. Благодарности

Трек iPhone Standalone MVP закрыт в один день с полным test coverage shared core, нулевыми macOS-регрессиями и чистым sync-leak scan. 9 из 9 историй завершены. Это результат дисциплины в соблюдении architectural guardrails и корректного pivot от sync-first к standalone.

---

*Ретроспектива проведена 2026-04-24. Следующий шаг — закрыть prep-задачи (A1–A3, D1) и R1 до возвращения к Epic 4 planning.*
