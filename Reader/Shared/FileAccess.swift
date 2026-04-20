import Foundation

enum FileAccess {

    // MARK: - Directories

    static var applicationSupportDir: URL {
        get throws {
            let fm = FileManager.default
            let url = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Reader", isDirectory: true)
            try ensureDirectory(url)
            return url
        }
    }

    static var booksDir: URL {
        get throws {
            let url = try applicationSupportDir.appendingPathComponent("Books", isDirectory: true)
            try ensureDirectory(url)
            return url
        }
    }

    static var coversDir: URL {
        get throws {
            let url = try applicationSupportDir.appendingPathComponent("Covers", isDirectory: true)
            try ensureDirectory(url)
            return url
        }
    }

    // MARK: - Copy EPUB to sandbox

    @discardableResult
    static func copyEPUBToSandbox(from source: URL, bookId: String) throws -> URL {
        let destination = try booksDir.appendingPathComponent("\(bookId).epub")
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
        return destination
    }

    static func deleteBookFiles(bookId: String) throws {
        let fm = FileManager.default

        let epub = try booksDir.appendingPathComponent("\(bookId).epub")
        if fm.fileExists(atPath: epub.path) {
            try fm.removeItem(at: epub)
        }

        let cover = try coversDir.appendingPathComponent("\(bookId).png")
        if fm.fileExists(atPath: cover.path) {
            try fm.removeItem(at: cover)
        }
    }

    // MARK: - Private

    private static func ensureDirectory(_ url: URL) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
