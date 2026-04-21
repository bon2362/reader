import Foundation
import Security

@MainActor
final class AppContainer {
    let database: DatabaseManager
    let libraryRepository: LibraryRepository
    let annotationRepository: AnnotationRepository
    let syncCoordinator: SyncCoordinator

    init(syncService: SyncServiceProtocol? = nil) throws {
        let database = try DatabaseManager.onDisk()
        let libraryRepository = LibraryRepository(database: database)
        let annotationRepository = AnnotationRepository(database: database)
        let resolvedSyncService: SyncServiceProtocol
        if let syncService {
            resolvedSyncService = syncService
        } else if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            resolvedSyncService = DisabledSyncService()
        } else if !Self.hasCloudKitEntitlement() {
            resolvedSyncService = DisabledSyncService()
        } else {
            resolvedSyncService = CloudKitSyncService()
        }
        let syncCoordinator = SyncCoordinator(
            libraryRepository: libraryRepository,
            annotationRepository: annotationRepository,
            syncService: resolvedSyncService
        )

        self.database = database
        self.libraryRepository = libraryRepository
        self.annotationRepository = annotationRepository
        self.syncCoordinator = syncCoordinator
    }

    private static func hasCloudKitEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }

        let services = SecTaskCopyValueForEntitlement(
            task,
            "com.apple.developer.icloud-services" as CFString,
            nil
        ) as? [String]
        let containers = SecTaskCopyValueForEntitlement(
            task,
            "com.apple.developer.icloud-container-identifiers" as CFString,
            nil
        ) as? [String]

        return !(services?.isEmpty ?? true) && !(containers?.isEmpty ?? true)
    }
}
