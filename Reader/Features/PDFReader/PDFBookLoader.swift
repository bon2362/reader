import AppKit
import Foundation
import PDFKit

struct PDFBookMetadata: Equatable, Sendable {
    let title: String
    let author: String?
    let coverData: Data?
    let pageCount: Int
    let isImageOnly: Bool
}

enum PDFBookLoaderError: LocalizedError {
    case cannotOpenPDF

    var errorDescription: String? {
        switch self {
        case .cannotOpenPDF:
            return "Не удалось открыть PDF"
        }
    }
}

enum PDFBookLoader {
    static func loadDocument(from url: URL) throws -> PDFDocument {
        guard let document = PDFDocument(url: url) else {
            throw PDFBookLoaderError.cannotOpenPDF
        }
        return document
    }

    static func parseMetadata(from url: URL) throws -> PDFBookMetadata {
        let document = try loadDocument(from: url)
        let attributes = document.documentAttributes ?? [:]
        let filenameTitle = url.deletingPathExtension().lastPathComponent

        let rawTitle = attributes[PDFDocumentAttribute.titleAttribute] as? String
        let rawAuthor = attributes[PDFDocumentAttribute.authorAttribute] as? String

        let title = normalizedTitle(rawTitle, fallbackFilename: filenameTitle)
        let author = normalizedAuthor(rawAuthor)
        let coverData = document.page(at: 0).flatMap { page in
            pngData(from: page.thumbnail(of: CGSize(width: 400, height: 600), for: .cropBox))
        }
        let text = document.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return PDFBookMetadata(
            title: title,
            author: author,
            coverData: coverData,
            pageCount: document.pageCount,
            isImageOnly: text.isEmpty
        )
    }

    static func importPDF(from sourceURL: URL, using repository: LibraryRepositoryProtocol) async throws -> Book {
        let metadata = try parseMetadata(from: sourceURL)
        let contentHash = try FileHash.sha256(for: sourceURL)

        if let existingBook = try await repository.fetchByContentHash(contentHash) {
            return existingBook
        }

        let bookId = UUID().uuidString
        let destinationURL = try FileAccess.copyPDFToSandbox(from: sourceURL, bookId: bookId)
        let importedAt = Date()

        var coverPath: String?
        if let coverData = metadata.coverData {
            coverPath = try saveCover(data: coverData, bookId: bookId)
        }

        let book = Book(
            id: bookId,
            title: metadata.title,
            author: metadata.author,
            coverPath: coverPath,
            filePath: destinationURL.path,
            addedAt: importedAt,
            lastCFI: "pdf:0",
            totalPages: metadata.pageCount,
            currentPage: metadata.pageCount > 0 ? 1 : 0,
            format: .pdf,
            contentHash: contentHash,
            syncState: Book.SyncState.pendingUpload.rawValue,
            updatedAt: importedAt,
            assetUpdatedAt: importedAt
        )

        try await repository.insert(book)
        return book
    }

    static func isImageOnly(_ document: PDFDocument) -> Bool {
        (document.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func needsMetadataRepair(title: String, author: String?) -> Bool {
        isRawHexMetadata(title) || isRawHexMetadata(author)
    }

    private static func saveCover(data: Data, bookId: String) throws -> String {
        let destination = try FileAccess.coversDir.appendingPathComponent("\(bookId).png")
        try data.write(to: destination)
        return destination.path
    }

    private static func normalizedTitle(_ value: String?, fallbackFilename: String) -> String {
        clean(value) ?? fallbackFilename
    }

    private static func normalizedAuthor(_ value: String?) -> String? {
        clean(value)
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty, !isRawHexMetadata(trimmed) else {
            return nil
        }
        return trimmed
    }

    private static func isRawHexMetadata(_ value: String?) -> Bool {
        guard let value else { return false }
        guard value.count >= 4, value.first == "<", value.last == ">" else { return false }
        let hex = value.dropFirst().dropLast()
        return !hex.isEmpty && hex.count.isMultiple(of: 2) && hex.allSatisfy(\.isHexDigit)
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return rep.representation(using: .png, properties: [:])
    }
}
