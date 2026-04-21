import SwiftUI

@main
struct ReaderiPhoneApp: App {
    @State private var container: AppContainer?
    @State private var startupError: String?

    init() {
        do {
            _container = State(initialValue: try AppContainer())
        } catch {
            _startupError = State(initialValue: error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                IPhoneLibraryView(
                    viewModel: IPhoneLibraryViewModel(
                        libraryRepository: container.libraryRepository,
                        syncCoordinator: container.syncCoordinator
                    ),
                    libraryRepository: container.libraryRepository,
                    annotationRepository: container.annotationRepository,
                    syncCoordinator: container.syncCoordinator
                )
            } else {
                ContentUnavailableView(
                    "Startup Error",
                    systemImage: "exclamationmark.triangle.fill",
                    description: Text(startupError ?? "Unknown startup error")
                )
            }
        }
    }
}
