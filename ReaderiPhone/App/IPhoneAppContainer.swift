import SwiftUI

struct IPhoneAppContainer {
    let database: DatabaseManager
    let libraryRepository: LibraryRepository
    let annotationRepository: AnnotationRepository

    init() throws {
        let database = try DatabaseManager.onDisk()
        self.database = database
        self.libraryRepository = LibraryRepository(database: database)
        self.annotationRepository = AnnotationRepository(database: database)
    }

    @MainActor
    @ViewBuilder
    func makeRootView() -> some View {
        IPhoneCompositionRoot(
            libraryRepository: libraryRepository,
            annotationRepository: annotationRepository
        )
        .makeRootView()
    }
}
