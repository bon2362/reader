import SwiftUI

struct IPhoneCompositionRoot {
    let libraryRepository: LibraryRepositoryProtocol
    let annotationRepository: AnnotationRepositoryProtocol

    @MainActor
    @ViewBuilder
    func makeRootView() -> some View {
        IPhoneRootView(
            libraryRepository: libraryRepository,
            annotationRepository: annotationRepository
        )
    }
}

private struct IPhoneRootView: View {
    @State private var libraryStore: IPhoneLibraryStore
    @State private var openedBook: IPhoneOpenedBook?

    private let libraryRepository: LibraryRepositoryProtocol

    init(
        libraryRepository: LibraryRepositoryProtocol,
        annotationRepository: AnnotationRepositoryProtocol
    ) {
        self.libraryRepository = libraryRepository
        _libraryStore = State(initialValue: IPhoneLibraryStore(
            libraryRepository: libraryRepository,
            annotationRepository: annotationRepository
        ))
    }

    var body: some View {
        ZStack {
            if let openedBook {
                if openedBook.book.format != .pdf {
                    IPhoneEPUBReaderView(
                        openedBook: openedBook,
                        libraryRepository: libraryRepository,
                        onClose: { self.openedBook = nil }
                    )
                } else {
                    IPhonePDFReaderView(
                        openedBook: openedBook,
                        libraryRepository: libraryRepository,
                        onClose: { self.openedBook = nil }
                    )
                }
            } else {
                IPhoneLibraryView(
                    store: libraryStore,
                    onOpenBook: { openedBook in
                        self.openedBook = openedBook
                    }
                )
            }
        }
    }
}
