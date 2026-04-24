# iPhone EPUB Reader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить полноценную поддержку EPUB в iPhone-таргет приложения Reader — импорт, открытие, постраничное чтение с сохранением позиции.

**Architecture:** iPhone-таргет уже содержит `BookImporter.swift` и `BookFormat.swift`. Рендеринг EPUB реализован в macOS через `NativeEPUBBridge` + `NativeEPUBWebView` (WKWebView + кастомный JS). Переносим этот механизм на iOS: создаём `UIViewRepresentable`-обёртку над WKWebView с тем же JS-рантаймом и `IPhoneEPUBReaderStore` для управления главами и страницами. Роутинг в `IPhoneLibraryView` переключается по `book.format`.

**Tech Stack:** Swift, SwiftUI, WebKit (WKWebView), EPUBBook (ZIPFoundation), GRDB

---

## File Structure

| Файл | Действие | Ответственность |
|------|----------|-----------------|
| `Reader/Features/Reader/EPUBBook.swift` | Modify | Переместить `makeOffsetAnchor`/`makePageAnchor` сюда |
| `Reader/Bridge/NativeEPUBBridge.swift` | Modify | Обновить вызовы на `EPUBBook.makeOffsetAnchor` |
| `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift` | Create | UIViewRepresentable + readerJS + MessageHandler |
| `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift` | Create | @Observable: загрузка, навигация, сохранение позиции |
| `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift` | Create | SwiftUI view: WebView + кнопки prev/next + заголовок |
| `ReaderiPhone/Features/Library/IPhoneLibraryView.swift` | Modify | Роутинг по `book.format` + кнопка «Import Book» |
| `ReaderiPhone/Features/Library/IPhoneLibraryStore.swift` | Modify | Переименовать `importPDF` → `importBook`, убрать PDF-only guard |
| `ReaderiPhone/Features/Library/IPhonePDFDocumentPicker.swift` | Modify | Добавить UTType для epub |
| `Reader.xcodeproj/project.pbxproj` | Modify | Добавить `EPUBBook.swift` в Sources iPhone-таргета |

---

### Task 1: Перенести вспомогательные методы CFI в EPUBBook

`EPUBBook.search()` вызывает `NativeEPUBBridge.makeOffsetAnchor` — это делает `EPUBBook.swift` зависимым от macOS-только класса. Перемещаем методы в `EPUBBook`.

**Files:**
- Modify: `Reader/Features/Reader/EPUBBook.swift`
- Modify: `Reader/Bridge/NativeEPUBBridge.swift`

- [ ] **Step 1: Добавить статические методы в EPUBBook**

В `Reader/Features/Reader/EPUBBook.swift` после строки `func chapterIndex(forHref href: String) -> Int?` (≈ строка 36) добавить:

```swift
    static func makePageAnchor(href: String, page: Int) -> String {
        "\(href)|p:\(page)"
    }

    static func makeOffsetAnchor(href: String, offset: Int) -> String {
        "\(href)|o:\(offset)"
    }
```

- [ ] **Step 2: Обновить вызовы в EPUBBook.search()**

В `Reader/Features/Reader/EPUBBook.swift` строка 54 — заменить:
```swift
// ДО
let cfi = NativeEPUBBridge.makeOffsetAnchor(
    href: EPUBBook.normalizeHref(chapter.href),
    offset: offset
)
// ПОСЛЕ
let cfi = EPUBBook.makeOffsetAnchor(
    href: EPUBBook.normalizeHref(chapter.href),
    offset: offset
)
```

- [ ] **Step 3: Обновить NativeEPUBBridge — убрать дублирующие методы**

В `Reader/Bridge/NativeEPUBBridge.swift` заменить тела `makePageAnchor`, `makeOffsetAnchor`, `makeAnchor` на делегирование к `EPUBBook`:

```swift
nonisolated static func makePageAnchor(href: String, page: Int) -> String {
    EPUBBook.makePageAnchor(href: href, page: page)
}

nonisolated static func makeOffsetAnchor(href: String, offset: Int) -> String {
    EPUBBook.makeOffsetAnchor(href: href, offset: offset)
}

nonisolated static func makeAnchor(href: String, offset: Int) -> String {
    EPUBBook.makeOffsetAnchor(href: href, offset: offset)
}
```

- [ ] **Step 4: Добавить EPUBBook.swift в Sources iPhone-таргета**

Открыть `Reader.xcodeproj/project.pbxproj` в текстовом редакторе. Найти блок Sources для iPhone-таргета (UUID `5F620F138DF06118B2FA9502`). Добавить новый PBXBuildFile:

1. В секцию `/* Begin PBXBuildFile section */` добавить:
```
		AAAA0001000000000000001 /* EPUBBook.swift in Sources */ = {isa = PBXBuildFile; fileRef = B6F036F85EB0F18A0CD0EF37 /* EPUBBook.swift */; };
```
(UUID `AAAA0001000000000000001` — замените на любой уникальный 24-символьный hex)

2. В файловом разделе Sources для таргета `5F620F138DF06118B2FA9502` добавить:
```
				AAAA0001000000000000001 /* EPUBBook.swift in Sources */,
```

- [ ] **Step 5: Проверить сборку**

```bash
xcodebuild -project /Users/ekoshkin/reader/Reader.xcodeproj \
  -scheme ReaderiPhone \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E "error:|Build succeeded"
```
Ожидаемый вывод: `Build succeeded`

- [ ] **Step 6: Commit**

```bash
git add Reader/Features/Reader/EPUBBook.swift \
        Reader/Bridge/NativeEPUBBridge.swift \
        Reader.xcodeproj/project.pbxproj
git commit -m "refactor: move CFI anchor helpers to EPUBBook, add to iPhone target"
```

---

### Task 2: Создать IPhoneEPUBWebView

**Files:**
- Create: `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`

- [ ] **Step 1: Создать файл IPhoneEPUBWebView.swift**

Создать `ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift`:

```swift
import SwiftUI
import WebKit

struct IPhoneEPUBWebView: UIViewRepresentable {
    let store: IPhoneEPUBReaderStore

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        let userScript = WKUserScript(
            source: IPhoneEPUBWebView.readerJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)

        let handler = MessageHandler()
        handler.store = store
        config.userContentController.add(handler, name: "native")
        context.coordinator.handler = handler

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.isScrollEnabled = false
        webView.allowsBackForwardNavigationGestures = false
        if #available(iOS 16.4, *) { webView.isInspectable = true }

        store.attachWebView(webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "native")
        coordinator.handler?.store = nil
    }

    @MainActor
    final class Coordinator {
        var handler: MessageHandler?
    }

    final class MessageHandler: NSObject, WKScriptMessageHandler {
        weak var store: IPhoneEPUBReaderStore?

        func userContentController(
            _ controller: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any],
                  let type = body["type"] as? String else { return }
            Task { @MainActor [weak self] in
                self?.store?.handleMessage(type: type, data: body)
            }
        }
    }

    // Скопировать verbatim из Reader/Features/Reader/NativeEPUBWebView.swift
    // строки 72–467 (static let readerJS: String = """...""")
    static let readerJS: String = // <-- COPY FROM NativeEPUBWebView.readerJS
    """
    """
}
```

- [ ] **Step 2: Скопировать readerJS**

Открыть `Reader/Features/Reader/NativeEPUBWebView.swift`, строки 72–467. Скопировать содержимое `static let readerJS: String` (включая тройные кавычки) в `IPhoneEPUBWebView.readerJS`.

- [ ] **Step 3: Добавить файл в iPhone-таргет через Xcode**

Открыть Xcode → ReaderiPhone target → Build Phases → Compile Sources → добавить `IPhoneEPUBWebView.swift`.
(Или добавить через pbxproj по аналогии с Task 1 Step 4.)

- [ ] **Step 4: Проверить сборку**

```bash
xcodebuild -project /Users/ekoshkin/reader/Reader.xcodeproj \
  -scheme ReaderiPhone \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E "error:|Build succeeded"
```
Ожидаемый вывод: `Build succeeded`

- [ ] **Step 5: Commit**

```bash
git add ReaderiPhone/Features/Reader/IPhoneEPUBWebView.swift \
        Reader.xcodeproj/project.pbxproj
git commit -m "feat: add IPhoneEPUBWebView (UIViewRepresentable + WKWebView + readerJS)"
```

---

### Task 3: Создать IPhoneEPUBReaderStore

**Files:**
- Create: `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`

- [ ] **Step 1: Создать файл**

Создать `ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift`:

```swift
import Foundation
import WebKit
import Observation

@MainActor
@Observable
final class IPhoneEPUBReaderStore {
    var chapterTitle: String = ""
    var pageInChapter: Int = 0
    var totalInChapter: Int = 1
    var isLoading: Bool = true
    var errorMessage: String?

    private let book: Book
    private let bookURL: URL
    private let libraryRepository: LibraryRepositoryProtocol
    private var epubBook: EPUBBook?
    private var currentChapterIndex: Int = 0
    private var pendingRestorePage: Int?
    private weak var webView: WKWebView?

    init(
        book: Book,
        resolvedURL: URL,
        libraryRepository: LibraryRepositoryProtocol
    ) {
        self.book = book
        self.bookURL = resolvedURL
        self.libraryRepository = libraryRepository
    }

    func attachWebView(_ webView: WKWebView) {
        self.webView = webView
    }

    func load() async {
        defer { isLoading = false }
        do {
            let epub = try EPUBBookLoader.load(from: bookURL)
            self.epubBook = epub
            let (chapter, page) = parsePosition(book.lastCFI, in: epub)
            loadChapter(at: chapter, restorePage: page)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var canGoToPreviousPage: Bool {
        pageInChapter > 0 || currentChapterIndex > 0
    }

    var canGoToNextPage: Bool {
        guard let epub = epubBook else { return false }
        return pageInChapter < totalInChapter - 1 || currentChapterIndex < epub.chapters.count - 1
    }

    func goToNextPage() {
        Task {
            guard let webView else { return }
            guard let result = await evaluatePageTurn(webView: webView, call: "nextPage()") else { return }
            if result.didMove {
                syncPage(result.after, total: result.totalPages)
            } else if result.after >= result.totalPages - 1 {
                advanceChapter(by: 1)
            }
        }
    }

    func goToPreviousPage() {
        Task {
            guard let webView else { return }
            guard let result = await evaluatePageTurn(webView: webView, call: "prevPage()") else { return }
            if result.didMove {
                syncPage(result.after, total: result.totalPages)
            } else if result.after == 0 {
                advanceChapter(by: -1)
            }
        }
    }

    func handleMessage(type: String, data: [String: Any]) {
        switch type {
        case "ready":
            let total = (data["totalPages"] as? Int) ?? 1
            totalInChapter = max(1, total)
            if let page = pendingRestorePage {
                pendingRestorePage = nil
                if page > 0 {
                    webView?.evaluateJavaScript("window.__reader && window.__reader.goToPage(\(page));")
                }
                pageInChapter = page
            }
        case "pageChanged":
            if let page = data["page"] as? Int, let total = data["totalPages"] as? Int {
                pageInChapter = page
                totalInChapter = max(1, total)
                saveProgress()
            }
        case "jsError":
            let msg = (data["msg"] as? String) ?? ""
            NSLog("[IPhoneEPUBReader] JS error: %@", msg)
        default:
            break
        }
    }

    // MARK: - Private

    private func loadChapter(at index: Int, restorePage: Int? = nil) {
        guard let epub = epubBook, epub.chapters.indices.contains(index) else { return }
        currentChapterIndex = index
        pageInChapter = 0
        totalInChapter = 1
        pendingRestorePage = restorePage
        chapterTitle = chapterLabel(at: index, in: epub)
        webView?.loadFileURL(epub.chapters[index].fileURL, allowingReadAccessTo: epub.rootDir)
    }

    private func advanceChapter(by delta: Int) {
        guard let epub = epubBook else { return }
        let next = currentChapterIndex + delta
        guard epub.chapters.indices.contains(next) else { return }
        let restorePage: Int? = (delta < 0) ? Int.max : 0
        loadChapter(at: next, restorePage: restorePage)
    }

    private func syncPage(_ page: Int, total: Int) {
        pageInChapter = page
        totalInChapter = max(1, total)
        saveProgress()
    }

    private func chapterLabel(at index: Int, in epub: EPUBBook) -> String {
        let href = EPUBBook.normalizeHref(epub.chapters[index].href)
        if let node = epub.toc.first(where: {
            EPUBBook.normalizeHref($0.href.components(separatedBy: "#")[0]) == href
        }) {
            return node.label
        }
        return "Chapter \(index + 1)"
    }

    private func saveProgress() {
        guard let epub = epubBook, epub.chapters.indices.contains(currentChapterIndex) else { return }
        let href = EPUBBook.normalizeHref(epub.chapters[currentChapterIndex].href)
        let cfi = EPUBBook.makePageAnchor(href: href, page: pageInChapter)
        Task {
            try? await libraryRepository.updateReadingProgress(
                id: book.id,
                lastCFI: cfi,
                currentPage: currentChapterIndex + 1,
                totalPages: epub.chapters.count
            )
        }
    }

    private func parsePosition(_ cfi: String?, in epub: EPUBBook) -> (chapter: Int, page: Int) {
        guard let cfi, !cfi.isEmpty else { return (0, 0) }
        let parts = cfi.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return (0, 0) }
        let href = String(parts[0])
        let loc = String(parts[1])
        let page: Int = loc.hasPrefix("p:") ? (Int(loc.dropFirst(2)) ?? 0) : 0
        let chapter = epub.chapterIndex(forHref: href) ?? 0
        return (chapter, page)
    }

    // MARK: - JS helpers

    private struct PageTurnResult {
        let before, after, totalPages: Int
        var didMove: Bool { before != after }
    }

    private func evaluatePageTurn(webView: WKWebView, call: String) async -> PageTurnResult? {
        let js = """
        (() => {
            if (!window.__reader) return null;
            const before = window.__reader.currentPage();
            window.__reader.\(call);
            return {
                before,
                after: window.__reader.currentPage(),
                totalPages: window.__reader.totalPages()
            };
        })();
        """
        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(js) { result, _ in
                guard let dict = result as? [String: Any],
                      let before = dict["before"] as? Int,
                      let after = dict["after"] as? Int,
                      let total = dict["totalPages"] as? Int else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: PageTurnResult(before: before, after: after, totalPages: total))
            }
        }
    }
}
```

> Примечание: `advanceChapter(by: -1)` передаёт `restorePage: Int.max` — в `handleMessage("ready")` это означает «перейти на последнюю страницу». В следующей задаче `goToLastPage` будет вызван вместо `goToPage(Int.max)`.

- [ ] **Step 2: Исправить логику restorePage для конца главы**

В `IPhoneEPUBReaderStore.handleMessage` в ветке `case "ready"` заменить:
```swift
// ДО
if page > 0 {
    webView?.evaluateJavaScript("window.__reader && window.__reader.goToPage(\(page));")
}
pageInChapter = page
// ПОСЛЕ
if page == .max {
    webView?.evaluateJavaScript("window.__reader && window.__reader.goToLastPage();")
    // pageInChapter будет обновлён через последующий pageChanged
} else if page > 0 {
    webView?.evaluateJavaScript("window.__reader && window.__reader.goToPage(\(page));")
    pageInChapter = page
}
```

- [ ] **Step 3: Добавить файл в iPhone-таргет через Xcode**

Открыть Xcode → ReaderiPhone target → Build Phases → Compile Sources → добавить `IPhoneEPUBReaderStore.swift`.

- [ ] **Step 4: Проверить сборку**

```bash
xcodebuild -project /Users/ekoshkin/reader/Reader.xcodeproj \
  -scheme ReaderiPhone \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E "error:|Build succeeded"
```
Ожидаемый вывод: `Build succeeded`

- [ ] **Step 5: Написать тест parsePosition**

В `ReaderTests/Features/` создать `IPhoneEPUBReaderStoreTests.swift`:

```swift
import Testing
@testable import ReaderiPhone

struct IPhoneEPUBReaderStoreParserTests {
    // Тестируем parsePosition через открытый путь — через результат load().
    // Так как load() требует WKWebView и EPUBBook, тестируем вспомогательную
    // логику через интеграционный тест EPUBBook + parsePosition.

    @Test func parsePageAnchorRoundTrip() throws {
        let href = "Text/ch02.xhtml"
        let cfi = EPUBBook.makePageAnchor(href: href, page: 5)
        #expect(cfi == "Text/ch02.xhtml|p:5")

        // Парсинг вручную (повторяет логику parsePosition)
        let parts = cfi.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        #expect(parts.count == 2)
        let loc = String(parts[1])
        #expect(loc.hasPrefix("p:"))
        #expect(Int(loc.dropFirst(2)) == 5)
    }

    @Test func parseEmptyOrNilCFI() {
        // parsePosition("") → (0, 0)
        // parsePosition(nil) → (0, 0)
        // Проверяем через makePageAnchor — пустой cfi не должен парситься
        let empty = ""
        let parts = empty.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        #expect(parts.count < 2)
    }
}
```

- [ ] **Step 6: Запустить тест**

```bash
xcodebuild test \
  -project /Users/ekoshkin/reader/Reader.xcodeproj \
  -scheme ReaderTests \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:ReaderTests/IPhoneEPUBReaderStoreParserTests \
  2>&1 | grep -E "Test.*passed|Test.*failed|error:"
```
Ожидаемый вывод: все тесты passed.

- [ ] **Step 7: Commit**

```bash
git add ReaderiPhone/Features/Reader/IPhoneEPUBReaderStore.swift \
        ReaderTests/Features/IPhoneEPUBReaderStoreTests.swift \
        Reader.xcodeproj/project.pbxproj
git commit -m "feat: add IPhoneEPUBReaderStore with chapter/page navigation and progress saving"
```

---

### Task 4: Создать IPhoneEPUBReaderView

**Files:**
- Create: `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`

- [ ] **Step 1: Создать файл**

Создать `ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift`:

```swift
import SwiftUI

struct IPhoneEPUBReaderView: View {
    @State private var store: IPhoneEPUBReaderStore?
    @State private var loadError: String?

    private let openedBook: IPhoneOpenedBook
    private let libraryRepository: LibraryRepositoryProtocol

    init(openedBook: IPhoneOpenedBook, libraryRepository: LibraryRepositoryProtocol) {
        self.openedBook = openedBook
        self.libraryRepository = libraryRepository
    }

    var body: some View {
        Group {
            if let store {
                readerBody(store: store)
            } else if let error = loadError {
                ContentUnavailableView(
                    "Не удалось открыть книгу",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else {
                ProgressView("Загрузка...")
            }
        }
        .navigationTitle(openedBook.book.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let s = IPhoneEPUBReaderStore(
                book: openedBook.book,
                resolvedURL: openedBook.url,
                libraryRepository: libraryRepository
            )
            store = s
            await s.load()
            if let msg = s.errorMessage {
                loadError = msg
                store = nil
            }
        }
    }

    @ViewBuilder
    private func readerBody(store: IPhoneEPUBReaderStore) -> some View {
        VStack(spacing: 0) {
            IPhoneEPUBWebView(store: store)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            pageControls(store: store)
        }
    }

    @ViewBuilder
    private func pageControls(store: IPhoneEPUBReaderStore) -> some View {
        HStack {
            Button {
                store.goToPreviousPage()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .padding()
            }
            .disabled(!store.canGoToPreviousPage)

            Spacer()

            VStack(spacing: 2) {
                Text(store.chapterTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("\(store.pageInChapter + 1) / \(store.totalInChapter)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button {
                store.goToNextPage()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .padding()
            }
            .disabled(!store.canGoToNextPage)
        }
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial)
    }
}
```

- [ ] **Step 2: Добавить файл в iPhone-таргет через Xcode**

Открыть Xcode → ReaderiPhone target → Build Phases → Compile Sources → добавить `IPhoneEPUBReaderView.swift`.

- [ ] **Step 3: Проверить сборку**

```bash
xcodebuild -project /Users/ekoshkin/reader/Reader.xcodeproj \
  -scheme ReaderiPhone \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E "error:|Build succeeded"
```
Ожидаемый вывод: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add ReaderiPhone/Features/Reader/IPhoneEPUBReaderView.swift \
        Reader.xcodeproj/project.pbxproj
git commit -m "feat: add IPhoneEPUBReaderView with page controls and chapter title"
```

---

### Task 5: Подключить роутинг по формату в IPhoneLibraryView

**Files:**
- Modify: `ReaderiPhone/Features/Library/IPhoneLibraryView.swift`

- [ ] **Step 1: Заменить navigationDestination**

В `ReaderiPhone/Features/Library/IPhoneLibraryView.swift` строки 45–50, заменить:

```swift
// ДО
.navigationDestination(item: $openedBook) { openedBook in
    IPhonePDFReaderView(
        openedBook: openedBook,
        libraryRepository: store.libraryRepository
    )
}
// ПОСЛЕ
.navigationDestination(item: $openedBook) { openedBook in
    if openedBook.book.format == .epub {
        IPhoneEPUBReaderView(
            openedBook: openedBook,
            libraryRepository: store.libraryRepository
        )
    } else {
        IPhonePDFReaderView(
            openedBook: openedBook,
            libraryRepository: store.libraryRepository
        )
    }
}
```

- [ ] **Step 2: Проверить сборку**

```bash
xcodebuild -project /Users/ekoshkin/reader/Reader.xcodeproj \
  -scheme ReaderiPhone \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E "error:|Build succeeded"
```
Ожидаемый вывод: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add ReaderiPhone/Features/Library/IPhoneLibraryView.swift
git commit -m "feat: route EPUB books to IPhoneEPUBReaderView by book.format"
```

---

### Task 6: Разрешить импорт EPUB

**Files:**
- Modify: `ReaderiPhone/Features/Library/IPhonePDFDocumentPicker.swift`
- Modify: `ReaderiPhone/Features/Library/IPhoneLibraryStore.swift`
- Modify: `ReaderiPhone/Features/Library/IPhoneLibraryView.swift`

- [ ] **Step 1: Обновить document picker**

В `ReaderiPhone/Features/Library/IPhonePDFDocumentPicker.swift` строка 14, заменить:

```swift
// ДО
let controller = UIDocumentPickerViewController(
    forOpeningContentTypes: [UTType.pdf],
    asCopy: false
)
// ПОСЛЕ
let controller = UIDocumentPickerViewController(
    forOpeningContentTypes: [
        UTType.pdf,
        UTType(filenameExtension: "epub") ?? .item
    ],
    asCopy: false
)
```

- [ ] **Step 2: Обновить importPDF в IPhoneLibraryStore**

В `ReaderiPhone/Features/Library/IPhoneLibraryStore.swift` заменить метод `importPDF(from:)` целиком:

```swift
func importBook(from url: URL) async {
    let ext = url.pathExtension.lowercased()
    guard ext == BookFormat.pdf.rawValue || ext == BookFormat.epub.rawValue else {
        errorMessage = "Поддерживаются только PDF и EPUB файлы."
        return
    }

    isImporting = true
    defer { isImporting = false }

    let hasScopedAccess = url.startAccessingSecurityScopedResource()
    defer {
        if hasScopedAccess { url.stopAccessingSecurityScopedResource() }
    }

    do {
        _ = try await BookImporter.importBook(from: url, using: libraryRepository)
        await load()
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

- [ ] **Step 3: Обновить вызовы в IPhoneLibraryView**

В `ReaderiPhone/Features/Library/IPhoneLibraryView.swift`:

1. Строка с `ToolbarItem` — заменить:
```swift
// ДО
Button("Import PDF") {
// ПОСЛЕ
Button("Import Book") {
```

2. Строка с `ProgressView` (≈ строка 40) — заменить:
```swift
// ДО
ProgressView(store.isImporting ? "Importing PDF" : "Loading Library")
// ПОСЛЕ
ProgressView(store.isImporting ? "Importing..." : "Loading Library")
```

3. Строка вызова `store.importPDF` (≈ строка 63) — заменить:
```swift
// ДО
await store.importPDF(from: url)
// ПОСЛЕ
await store.importBook(from: url)
```

- [ ] **Step 4: Проверить сборку**

```bash
xcodebuild -project /Users/ekoshkin/reader/Reader.xcodeproj \
  -scheme ReaderiPhone \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E "error:|Build succeeded"
```
Ожидаемый вывод: `Build succeeded`

- [ ] **Step 5: Commit**

```bash
git add ReaderiPhone/Features/Library/IPhonePDFDocumentPicker.swift \
        ReaderiPhone/Features/Library/IPhoneLibraryStore.swift \
        ReaderiPhone/Features/Library/IPhoneLibraryView.swift
git commit -m "feat: enable EPUB import — document picker, store validation, UI labels"
```

---

## Self-Review

### Spec coverage

| Требование | Задача |
|---|---|
| Открытие EPUB на iPhone | Task 5 (роутинг) |
| Рендеринг EPUB через WebKit | Task 2 (WebView) |
| Постраничная навигация | Task 3 (store: goToNextPage/goToPreviousPage) |
| Межглавная навигация | Task 3 (store: advanceChapter) |
| Сохранение позиции при закрытии | Task 3 (saveProgress → libraryRepository) |
| Восстановление позиции при открытии | Task 3 (parsePosition + load) |
| Импорт EPUB из Files | Task 6 |
| UI: заголовок главы + счётчик страниц | Task 4 |

### Placeholder scan

Нет TBD, TODO, «implement later».

### Type consistency

- `IPhoneEPUBReaderStore` — передаётся в `IPhoneEPUBWebView.store` ✓
- `IPhoneOpenedBook` — тот же тип, что и в `IPhonePDFReaderView` ✓
- `EPUBBook.makePageAnchor` — добавляется в Task 1, используется в Task 3 ✓
- `EPUBBook.normalizeHref` — существующий static метод ✓
- `EPUBBookLoader.load(from:)` — существующий enum в EPUBBook.swift ✓
- `LibraryRepositoryProtocol.updateReadingProgress(id:lastCFI:currentPage:totalPages:)` — существующий метод ✓
