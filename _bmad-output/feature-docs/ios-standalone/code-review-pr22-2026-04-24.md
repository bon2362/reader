# Код-ревью PR #22 — iPhone Standalone MVP

**Date:** 2026-04-24
**PR:** https://github.com/bon2362/reader/pull/22
**Branch:** `codex/iphone-standalone-mvp` → `main`
**Commit:** 2a41c76
**Scope:** 42 файла, +3294/-111

**Verdict:** approve-with-nits — MVP закрыт согласно плану, shared-core рефакторинг корректен, macOS путь защищён. Приложение валидировано на iPhone 15 (iOS 26.4.1). Есть замечания по lifecycle и project.yml, но они не блокируют merge.

---

## Критические находки
Нет блокеров merge.

---

## Важные находки

### 1. `project.yml` — отсутствуют Info.plist ключи для файлов
`project.yml:87` — `GENERATE_INFOPLIST_FILE: YES`, но не заданы `INFOPLIST_KEY_UIFileSharingEnabled`, `INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace`, `NSDocumentUsageDescription`. UIDocumentPicker с `asCopy: false` + `startAccessingSecurityScopedResource()` (`ReaderiPhone/Features/Library/IPhoneLibraryStore.swift:61`) без usage-описания — риск rejection при App Store submission.

### 2. Утечка PDFView через external renderer
`ReaderiPhone/Features/Reader/IPhonePDFReaderStore.swift:52-59`:
```
render: { highlight in
    PDFHighlightRenderer.apply(highlight: highlight, in: pdfView)
}
```
Escaping-замыкание захватывает локальный `pdfView` strong-ref. Если SwiftUI пересоздаст PDFView, старый удержится в `HighlightsStore.externalRender`. macOS-версия (`Reader/Features/PDFReader/PDFReaderStore.swift:69-78`) использует `[weak self]` + `self.pdfView` — унифицировать.

### 3. Мёртвый цикл рендера при первом attach
`IPhonePDFReaderStore.swift:60-63` — `highlights` гарантированно пуст при первом `attachPDFView`, цикл бесполезен. Убрать или перенести после `loadAndRender`.

### 4. Misleading name: `nsColor(for:)`
`Reader/Features/PDFReader/PDFHighlightRenderer.swift:64` — возвращает `PlatformColor` (на iOS это `UIColor`). Переименовать в `platformColor(for:)`, дублирующий wrapper на строке 54 убрать.

### 5. Дедупликация tap-а на существующий хайлайт утеряна
`IPhonePDFReaderStore.swift:119-126` — создаёт `pendingSelection` безусловно. macOS-версия (`PDFReaderStore.swift:156-160`) проверяет `highlights.first(where: { $0.cfiStart == anchor.stringValue })` и показывает `activeHighlight` UI вместо picker-а. На iOS перевыделение существующего хайлайта приведёт к дублю в БД.

### 6. `overlayRect` на iOS не используется
`IPhonePDFReaderStore.swift:125` — rect вычисляется через `pdfView.convert(..., from: page)`, но SwiftUI picker прибит к `.bottom` в `IPhonePDFReaderView`. Либо использовать rect для позиционирования, либо убрать `updateSelectionRect` call.

### 7. Race в `applyPageState` при быстром скролле
`IPhonePDFReaderStore.swift:197-210` — обычный `Task { try await libraryRepository.updateReadingProgress(...) }` вместо `Task.detached` с capture-list (как на macOS `PDFReaderStore.swift:296`). При быстрой смене страниц параллельные запись в БД с недетерминированным порядком. Добавить debounce или сериализацию.

### 8. Мёртвый `IPhoneRoute` + `path: .constant(...)`
`ReaderiPhone/App/IPhoneCompositionRoot.swift:10` — `NavigationStack(path: .constant([IPhoneRoute]()))` делает программную навигацию невозможной, `IPhoneRoute` enum вообще не используется. Удалить или дать реальный `@State` binding.

---

## Nits

- `BookImporter.saveCover` (строки 114-120) и `PDFBookLoader.saveCover` (строки 90-94) — две копии одной функции. Вынести в `ImageDataTransformer` или `FileAccess`.
- `ReaderTests/Features/PDFSelectionAnchorResolverTests.swift:10` — только 1 тест. По AC-2 story 1.2 добавить: пустая выборка, multi-page selection, whitespace-normalized fallback.
- `project.yml` перечисляет shared PDFReader файлы поимённо (строки 64-69) — хрупко. Лучше `Reader/Features/PDFReader/**/*.swift` с `excludes: [NativePDFView.swift, PDFTextNoteRenderer.swift, PDFReaderStore.swift, PDFReaderView.swift]`.
- `Reader/Features/Annotations/HighlightsStore.swift:72-78` — `#if os(macOS) / #else` с идентичными ветками; `bridge` не обнуляется в `reset()`.
- `ReaderiPhone/Features/Library/IPhoneLibraryStore.swift:76-96` — `fileExists` + `isReadableFile` дублирует проверку.
- `ReaderiPhone/Features/Library/IPhonePDFDocumentPicker.swift:24` — нет `documentPickerWasCancelled(_:)`, проверить сброс `isImportPickerPresented` при cancel.
- `IPhoneOpenedBook: Hashable` с reference-членом `annotationRepository` — смущает. Передавать отдельно во view.
- `project.yml` `TARGETED_DEVICE_FAMILY: "1"` + `CODE_SIGN_STYLE: Automatic` без `DEVELOPMENT_TEAM` — CI без локального team не соберёт.

---

## Positive

- Чистое выделение pure-модулей: `Reader/Features/PDFReader/PDFReadingProgress.swift:3` и `Reader/Features/PDFReader/PDFSelectionAnchorResolver.swift:5` — ровно то, что требовала story 1.2. Переиспользованы и на macOS (`PDFReaderStore.swift:380`), и на iPhone (`IPhonePDFReaderStore.swift:214`) без дублирования.
- `Reader/Shared/ImageDataTransformer.swift` — грамотный ImageIO-путь через `CGImageSourceCreateWithData` + UTType-проверка. Работает для JPEG/WebP/HEIC EPUB covers, `normalizedPNGData` корректно фоллбэкает на оригинальные данные.
- `HighlightsStore.swift:40-49` — external renderer binding: macOS `EPUBBridge` изолирован за `#if os(macOS)`, iOS получает renderer через замыкания, те же тесты покрывают оба пути.
- `InteractivePDFView` + `handleHighlightTap` (`ReaderiPhone/Features/Reader/IPhonePDFKitView.swift:55-82`) — корректное `page.annotation(at:)` + `markerPrefix` + `cancelsTouchesInView = false` сохраняет стандартный UX PDFKit.
- `Coordinator.notifyDisplayReadyIfPossible` (`IPhonePDFKitView.swift:158-169`) — корректная защита от race через проверки `document != nil`, `window != nil`, `!bounds.isEmpty` и флаг `hasReportedDisplayReady`. Гейтинг через `.PDFViewVisiblePagesChanged` + `.PDFViewScaleChanged` — разумный layout signal.
- macOS путь полностью сохранён: все существующие тесты на `EPUBBridge` зеленеют — AC-2 story 3.3 выполнена.
- `IPhoneAppContainer` → `IPhoneCompositionRoot` — минималистичная local-only композиция, без CloudKit/entitlement ссылок. Story 1.1 AC соблюдены.

---

## Follow-up (в отдельные stories)

1. **iPad support + size classes** — `TARGETED_DEVICE_FAMILY: "1"` блокирует; SwiftUI-слой выглядит готовым.
2. **Progress persistence debouncing** — см. п. 7. Debounce `updateReadingProgress` ~250ms.
3. **iOS-specific тесты** — unit-тесты на `IPhoneLibraryStore.importPDF` (валидные/невалидные URL, missing file, cancellation) + restore path `IPhonePDFReaderStore` с fake PDFKit.
4. **Refactor `saveCover` duplication** — общий хелпер.
5. **Design spike перед epic-4 CloudKit** — `HighlightsStore` на multi-source events (local + remote). Текущий single-reader через `externalRender` может потребовать event-stream.
6. **Общий iPhone/macOS presentation layer** — `IPhonePDFReaderStore` дублирует ~60% `PDFReaderStore`. Извлечь `PDFReaderCore` (без pdfView reference) + platform-specific facades до добавления TOC/search на iPhone.
7. **Удалить мёртвый `IPhoneRoute` enum** или дать реальный `NavigationStack(path:)` binding.
