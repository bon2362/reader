import SwiftUI

struct IPhoneLibraryView: View {
    @State var store: IPhoneLibraryStore
    @State private var isImportPickerPresented = false
    @State private var bookToDelete: Book?
    let onOpenBook: (IPhoneOpenedBook) -> Void

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Библиотека")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)

                    Spacer()

                    Button {
                        isImportPickerPresented = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Добавить книгу")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .safeAreaPadding(.top)
                .background(Color(uiColor: .systemBackground))

                List {
                    if let errorMessage = store.errorMessage {
                        Section {
                            ContentUnavailableView(
                                "Библиотека недоступна",
                                systemImage: "exclamationmark.triangle",
                                description: Text(errorMessage)
                            )
                        }
                    } else if store.books.isEmpty, store.isLoading == false {
                        Section {
                            ContentUnavailableView(
                                "Библиотека пуста",
                                systemImage: "books.vertical",
                                description: Text("Нажмите + чтобы добавить книгу.")
                            )
                        }
                    } else {
                        ForEach(store.books) { book in
                            Button {
                                Task {
                                    if let openedBook = await store.prepareOpenBook(book) {
                                        onOpenBook(openedBook)
                                    }
                                }
                            } label: {
                                IPhoneLibraryBookRow(book: book)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    bookToDelete = book
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }

            if store.isLoading || store.isImporting {
                ProgressView(store.isImporting ? "Импорт..." : "Загрузка")
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
        .confirmationDialog(
            bookToDelete.map { $0.title.isEmpty ? "Без названия" : $0.title } ?? "",
            isPresented: Binding(
                get: { bookToDelete != nil },
                set: { if !$0 { bookToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let book = bookToDelete {
                Button("Удалить из библиотеки", role: .destructive) {
                    Task { await store.deleteFromLibrary(book) }
                }
                Button("Удалить с устройства", role: .destructive) {
                    Task { await store.deleteFromDevice(book) }
                }
                Button("Отмена", role: .cancel) {}
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
