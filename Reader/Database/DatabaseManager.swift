import Foundation
import GRDB

final class DatabaseManager {
    let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try runMigrations()
    }

    // MARK: - Factory

    static func onDisk() throws -> DatabaseManager {
        let url = try databaseURL()
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        do {
            let pool = try DatabasePool(path: url.path, configuration: config)
            return try DatabaseManager(writer: pool)
        } catch {
            throw AppError.databaseSetup(underlying: error)
        }
    }

    static func inMemory() throws -> DatabaseManager {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        let queue = try DatabaseQueue(configuration: config)
        return try DatabaseManager(writer: queue)
    }

    // MARK: - Migrations

    private func runMigrations() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration(Migration_001.identifier, migrate: Migration_001.migrate)
        migrator.registerMigration(Migration_002.identifier, migrate: Migration_002.migrate)
        migrator.registerMigration(Migration_003.identifier, migrate: Migration_003.migrate)
        migrator.registerMigration(Migration_004.identifier, migrate: Migration_004.migrate)
        migrator.registerMigration(Migration_005.identifier, migrate: Migration_005.migrate)
        migrator.registerMigration(Migration_006.identifier, migrate: Migration_006.migrate)
        migrator.registerMigration(Migration_007.identifier, migrate: Migration_007.migrate)
        do {
            try migrator.migrate(writer)
        } catch {
            throw AppError.migrationFailed(underlying: error)
        }
    }

    // MARK: - Path

    private static func databaseURL() throws -> URL {
        let fm = FileManager.default
        let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = support.appendingPathComponent("Reader", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("reader.sqlite")
    }
}
