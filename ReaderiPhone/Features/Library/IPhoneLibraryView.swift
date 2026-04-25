import SwiftUI

struct IPhoneLibraryView: View {
    @State var store: IPhoneLibraryStore
    @State private var isImportPickerPresented = false
    @State private var openedBook: IPhoneOpenedBook?

    var body: some View {
        List {
            if let errorMessage = store.errorMessage {
                Section {
                    ContentUnavailableView(
                        "Library Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                }
            } else if store.books.isEmpty, store.isLoading == false {
                Section {
                    ContentUnavailableView(
                        "Your Library Is Local",
                        systemImage: "books.vertical",
                        description: Text("This iPhone app starts fully offline. Import local PDFs in the next story to begin building your library.")
                    )
                }
            } else {
                ForEach(store.books) { book in
                    Button {
                        Task {
                            openedBook = await store.prepareOpenBook(book)
                        }
                    } label: {
                        IPhoneLibraryBookRow(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .overlay {
            if store.isLoading || store.isImporting {
                ProgressView(store.isImporting ? "Importing..." : "Loading Library")
            }
        }
        .navigationTitle("Library")
        .navigationDestination(item: $openedBook) { openedBook in
            if openedBook.book.format != .pdf {
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Import Book") {
                    isImportPickerPresented = true
                }
            }
        }
        .sheet(isPresented: $isImportPickerPresented) {
            IPhonePDFDocumentPicker { urls in
                isImportPickerPresented = false
                guard let url = urls.first else { return }
                Task {
                    await store.importBook(from: url)
                }
            }
        }
        .task {
            await store.load()
        }
        .refreshable {
            await store.load()
        }
    }
}
