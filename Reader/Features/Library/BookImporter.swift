import Foundation
import ZIPFoundation

struct EPUBMetadata {
    let title: String
    let author: String?
    let coverData: Data?
    let coverMimeType: String?
}

enum BookImporterError: LocalizedError {
    case cannotOpenArchive
    case missingContainer
    case missingOPF
    case missingTitle
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .cannotOpenArchive: return "Не удалось открыть EPUB архив"
        case .missingContainer:  return "EPUB повреждён: отсутствует META-INF/container.xml"
        case .missingOPF:        return "EPUB повреждён: отсутствует .opf файл"
        case .missingTitle:      return "EPUB повреждён: отсутствует заголовок"
        case .unsupportedFormat: return "Поддерживаются только EPUB, PDF и FB2"
        }
    }
}

enum BookImporter {

    /// Parse EPUB metadata without copying.
    static func parseMetadata(from url: URL) throws -> EPUBMetadata {
        let archive = try Archive(url: url, accessMode: .read)

        // 1. META-INF/container.xml → rootfile path
        guard let containerEntry = archive["META-INF/container.xml"] else {
            throw BookImporterError.missingContainer
        }
        let containerData = try readEntry(archive: archive, entry: containerEntry)
        guard let opfPath = parseContainerXML(containerData) else {
            throw BookImporterError.missingOPF
        }

        // 2. Read OPF
        guard let opfEntry = archive[opfPath] else {
            throw BookImporterError.missingOPF
        }
        let opfData = try readEntry(archive: archive, entry: opfEntry)
        let opf = parseOPF(opfData)

        guard let title = opf.title else {
            throw BookImporterError.missingTitle
        }

        // 3. Cover image
        var coverData: Data?
        var coverMime: String?
        if let coverHref = opf.coverHref {
            let opfDir = (opfPath as NSString).deletingLastPathComponent
            let coverPath = opfDir.isEmpty ? coverHref : "\(opfDir)/\(coverHref)"
            let normalized = normalizeZipPath(coverPath)
            if let coverEntry = archive[normalized] {
                coverData = try? readEntry(archive: archive, entry: coverEntry)
                coverMime = opf.coverMime
            }
        }

        return EPUBMetadata(
            title: title,
            author: opf.author,
            coverData: coverData,
            coverMimeType: coverMime
        )
    }

    /// Import EPUB: parse metadata → copy to sandbox → save cover → insert into DB.
    static func importBook(
        from sourceURL: URL,
        using repository: LibraryRepositoryProtocol
    ) async throws -> Book {
        let fileExtension = sourceURL.pathExtension.lowercased()
        guard fileExtension == BookFormat.epub.rawValue
            || fileExtension == BookFormat.pdf.rawValue
            || fileExtension == BookFormat.fb2.rawValue else {
            throw BookImporterError.unsupportedFormat
        }
        if fileExtension == BookFormat.pdf.rawValue {
            return try await PDFBookLoader.importPDF(from: sourceURL, using: repository)
        }
        if fileExtension == BookFormat.fb2.rawValue {
            return try await FB2Importer.importFB2(from: sourceURL, using: repository)
        }

        let metadata = try parseMetadata(from: sourceURL)

        let bookId = UUID().uuidString
        let destinationURL = try FileAccess.copyEPUBToSandbox(from: sourceURL, bookId: bookId)

        var coverPath: String?
        if let data = metadata.coverData {
            coverPath = try saveCover(data: data, bookId: bookId)
        }

        let book = Book(
            id: bookId,
            title: metadata.title,
            author: metadata.author,
            coverPath: coverPath,
            filePath: destinationURL.path,
            addedAt: Date()
        )

        try await repository.insert(book)
        return book
    }

    // MARK: - Cover

    private static func saveCover(data: Data, bookId: String) throws -> String {
        let destination = try FileAccess.coversDir.appendingPathComponent("\(bookId).png")
        let normalizedData = ImageDataTransformer.normalizedPNGData(from: data) ?? data
        try normalizedData.write(to: destination)

        return destination.path
    }

    // MARK: - XML parsing (minimal, regex-based)

    private static func parseContainerXML(_ data: Data) -> String? {
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        let pattern = #"<rootfile[^>]*full-path=\"([^\"]+)\""#
        return firstCapture(in: str, pattern: pattern)
    }

    struct OPFParsed {
        var title: String?
        var author: String?
        var coverHref: String?
        var coverMime: String?
    }

    private static func parseOPF(_ data: Data) -> OPFParsed {
        guard let str = String(data: data, encoding: .utf8) else { return OPFParsed() }
        var result = OPFParsed()

        result.title  = firstCapture(in: str, pattern: #"<dc:title[^>]*>([^<]+)</dc:title>"#)
        result.author = firstCapture(in: str, pattern: #"<dc:creator[^>]*>([^<]+)</dc:creator>"#)

        // EPUB 3: <item ... properties="cover-image" href="..." media-type="..."/>
        if let coverItem = firstMatch(in: str, pattern: #"<item[^>]*properties=\"[^\"]*cover-image[^\"]*\"[^>]*/>"#) {
            result.coverHref = firstCapture(in: coverItem, pattern: #"href=\"([^\"]+)\""#)
            result.coverMime = firstCapture(in: coverItem, pattern: #"media-type=\"([^\"]+)\""#)
        }

        // EPUB 2: <meta name="cover" content="cover-id"/> + <item id="cover-id" href="..." />
        if result.coverHref == nil,
           let coverId = firstCapture(in: str, pattern: #"<meta\s+name=\"cover\"\s+content=\"([^\"]+)\""#) {
            let itemPattern = "<item[^>]*id=\"\(NSRegularExpression.escapedPattern(for: coverId))\"[^>]*/>"
            if let coverItem = firstMatch(in: str, pattern: itemPattern) {
                result.coverHref = firstCapture(in: coverItem, pattern: #"href=\"([^\"]+)\""#)
                result.coverMime = firstCapture(in: coverItem, pattern: #"media-type=\"([^\"]+)\""#)
            }
        }

        return result
    }

    // MARK: - Regex helpers

    private static func firstCapture(in string: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range), match.numberOfRanges >= 2 else { return nil }
        guard let captureRange = Range(match.range(at: 1), in: string) else { return nil }
        return String(string[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstMatch(in string: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range) else { return nil }
        guard let matchRange = Range(match.range, in: string) else { return nil }
        return String(string[matchRange])
    }

    // MARK: - ZIP helpers

    private static func readEntry(archive: Archive, entry: Entry) throws -> Data {
        var data = Data()
        _ = try archive.extract(entry) { chunk in
            data.append(chunk)
        }
        return data
    }

    private static func normalizeZipPath(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        var normalized: [String] = []
        for c in components {
            if c == ".." { if !normalized.isEmpty { normalized.removeLast() } }
            else if c == "." || c.isEmpty { continue }
            else { normalized.append(c) }
        }
        return normalized.joined(separator: "/")
    }
}
