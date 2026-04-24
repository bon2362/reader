import SwiftUI

@main
struct ReaderiPhoneApp: App {
    private let container: IPhoneAppContainer?
    private let startupError: String?

    init() {
        do {
            self.container = try IPhoneAppContainer()
            self.startupError = nil
        } catch {
            self.container = nil
            self.startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                container.makeRootView()
            } else {
                ContentUnavailableView(
                    "Startup Error",
                    systemImage: "externaldrive.badge.xmark",
                    description: Text(startupError ?? "The local database could not be opened.")
                )
            }
        }
    }
}
