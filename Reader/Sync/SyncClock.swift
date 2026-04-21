import Foundation

protocol SyncClock: Sendable {
    func now() -> Date
}

struct SystemSyncClock: SyncClock {
    func now() -> Date { Date() }
}
