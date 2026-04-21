import AppKit
import Foundation
import PDFKit
import Testing
@testable import Reader

@MainActor
@Suite("PDFBookLoader")
struct PDFBookLoaderTests {

    @Test func parsesMetadataFromTextPDF() throws {
        let url = try TestPDFFactory.makeTextPDF(
            text: "Hello PDF world",
            title: "Sample PDF",
            author: "Test Author"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let metadata = try PDFBookLoader.parseMetadata(from: url)

        #expect(metadata.title == "Sample PDF")
        #expect(metadata.author == "Test Author")
        #expect(metadata.pageCount == 1)
        #expect(metadata.isImageOnly == false)
        #expect(metadata.coverData != nil)
    }

    @Test func detectsImageOnlyPDF() throws {
        let url = try TestPDFFactory.makeImageOnlyPDF(title: "Scanned")
        defer { try? FileManager.default.removeItem(at: url) }

        let metadata = try PDFBookLoader.parseMetadata(from: url)

        #expect(metadata.title == "Scanned")
        #expect(metadata.isImageOnly == true)
        #expect(metadata.pageCount == 1)
    }

    @Test func fallsBackToFilenameWhenPDFMetadataIsRawHex() throws {
        let url = try TestPDFFactory.makeTextPDF(
            text: "Hello PDF world",
            title: "<E7E0EAE0F0E8FF2031393937>",
            author: "<C2E8F2>",
            filename: "Закария 1997"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let metadata = try PDFBookLoader.parseMetadata(from: url)

        #expect(metadata.title == "Закария 1997")
        #expect(metadata.author == nil)
    }

    @Test func duplicateImportReusesExistingBookByContentHash() async throws {
        let db = try DatabaseManager.inMemory()
        let repository = LibraryRepository(database: db)
        let url = try TestPDFFactory.makeTextPDF(
            text: "Repeated content",
            title: "Repeatable",
            author: "Author"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let first = try await PDFBookLoader.importPDF(from: url, using: repository)
        let second = try await PDFBookLoader.importPDF(from: url, using: repository)
        let all = try await repository.fetchAll()

        #expect(first.id == second.id)
        #expect(first.filePath == second.filePath)
        #expect(all.count == 1)
        #expect(first.contentHash == second.contentHash)
    }
}

@MainActor
enum TestPDFFactory {
    static func makeTextPDF(
        text: String,
        title: String,
        author: String? = nil,
        filename: String? = nil
    ) throws -> URL {
        try makeTextPDF(pages: [text], title: title, author: author, filename: filename)
    }

    static func makeTextPDF(
        pages: [String],
        title: String,
        author: String? = nil,
        filename: String? = nil
    ) throws -> URL {
        let url = temporaryURL(filename: filename, extension: "pdf")
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)

        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18),
            .foregroundColor: NSColor.black
        ]

        for text in pages {
            context.beginPDFPage(nil)
            let graphics = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = graphics
            NSColor.white.setFill()
            NSBezierPath(rect: mediaBox).fill()
            NSAttributedString(string: text, attributes: attrs)
                .draw(in: CGRect(x: 72, y: 640, width: 468, height: 100))
            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }
        context.closePDF()

        try data.write(to: url)

        guard let document = PDFDocument(url: url) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var attributes: [PDFDocumentAttribute: Any] = [PDFDocumentAttribute.titleAttribute: title]
        if let author {
            attributes[PDFDocumentAttribute.authorAttribute] = author
        }
        document.documentAttributes = attributes

        guard document.write(to: url) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return url
    }

    static func makeImageOnlyPDF(title: String) throws -> URL {
        let url = temporaryURL(extension: "pdf")
        let image = NSImage(size: CGSize(width: 600, height: 800))
        image.lockFocus()
        NSColor.white.setFill()
        NSBezierPath(rect: CGRect(x: 0, y: 0, width: 600, height: 800)).fill()
        NSColor.darkGray.setFill()
        NSBezierPath(rect: CGRect(x: 80, y: 120, width: 440, height: 560)).fill()
        image.unlockFocus()

        guard let page = PDFPage(image: image) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let document = PDFDocument()
        document.insert(page, at: 0)
        document.documentAttributes = [PDFDocumentAttribute.titleAttribute: title]

        guard document.write(to: url) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return url
    }

    private static func temporaryURL(filename: String? = nil, extension fileExtension: String) -> URL {
        let baseName = filename ?? UUID().uuidString
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(baseName)
            .appendingPathExtension(fileExtension)
    }
}
