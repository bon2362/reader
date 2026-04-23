import SwiftUI

struct ContentView: View {
    @State private var libraryStore: LibraryStore
    @State private var readerStore: ReaderStore
    @State private var openedBook: (book: Book, url: URL)?
    @State private var testBookURL: URL?

    init() {
        do {
            let db = try DatabaseManager.onDisk()
            let libraryRepo = LibraryRepository(database: db)
            let annotationRepo = AnnotationRepository(database: db)
            _libraryStore = State(initialValue: LibraryStore(
                repository: libraryRepo,
                annotationRepository: annotationRepo
            ))
            _readerStore = State(initialValue: ReaderStore(
                libraryRepository: libraryRepo,
                annotationRepository: annotationRepo
            ))
        } catch {
            fatalError("Не удалось инициализировать базу данных: \(error.localizedDescription)")
        }
    }

    var body: some View {
        NavigationStack {
            if let testURL = testBookURL {
                EPUBTestView(epubURL: testURL, onClose: { testBookURL = nil })
            } else if let opened = openedBook {
                ReaderView(
                    store: readerStore,
                    book: opened.book,
                    resolvedURL: opened.url,
                    onClose: { openedBook = nil }
                )
            } else {
                LibraryView(
                    store: libraryStore,
                    onOpenBook: { book, url in openedBook = (book, url) },
                    onOpenTest: { _, url in testBookURL = url }
                )
            }
        }
        .frame(minWidth: 900, minHeight: 650)
    }
}
