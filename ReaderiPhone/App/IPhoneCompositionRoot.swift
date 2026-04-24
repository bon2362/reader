import SwiftUI

struct IPhoneCompositionRoot {
    let libraryRepository: LibraryRepositoryProtocol
    let annotationRepository: AnnotationRepositoryProtocol

    @MainActor
    @ViewBuilder
    func makeRootView() -> some View {
        NavigationStack(path: .constant([IPhoneRoute]())) {
            IPhoneLibraryView(
                store: IPhoneLibraryStore(
                    libraryRepository: libraryRepository,
                    annotationRepository: annotationRepository
                )
            )
        }
    }
}
