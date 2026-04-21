import Foundation
import os

protocol SyncDiagnosticsLogging: Sendable {
    func log(_ category: SyncDiagnosticCategory, _ message: String)
}

enum SyncDiagnosticCategory: String, Sendable {
    case upload
    case pull
    case merge
    case conflict
    case hydration
    case error
}

struct SyncDiagnosticsLogger: SyncDiagnosticsLogging {
    private let logger = Logger(subsystem: "com.koshkin.reader", category: "sync")

    func log(_ category: SyncDiagnosticCategory, _ message: String) {
        logger.log("[\(category.rawValue, privacy: .public)] \(message, privacy: .public)")
    }
}
