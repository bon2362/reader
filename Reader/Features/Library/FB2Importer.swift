import Foundation

struct FB2Metadata {
    let title: String
    let author: String?
    let coverData: Data?
}

enum FB2ImporterError: LocalizedError {
    case cannotReadFile
    case missingTitle

    var errorDescription: String? {
        switch self {
        case .cannotReadFile: return "Не удалось прочитать FB2 файл"
        case .missingTitle:   return "FB2 файл не содержит заголовка книги"
        }
    }
}

enum FB2Importer {

    static func parseMetadata(from url: URL) throws -> FB2Metadata {
        let data: Data
        do { data = try Data(contentsOf: url) }
        catch { throw FB2ImporterError.cannotReadFile }
        let scanner = FB2MetadataScanner(data: data)
        scanner.scan()
        guard let title = scanner.title, !title.isEmpty else {
            throw FB2ImporterError.missingTitle
        }
        let author = scanner.authorParts.isEmpty ? nil : scanner.authorParts.joined(separator: " ")
        return FB2Metadata(title: title, author: author, coverData: scanner.coverData)
    }

    static func importFB2(
        from sourceURL: URL,
        using repository: LibraryRepositoryProtocol
    ) async throws -> Book {
        let metadata = try parseMetadata(from: sourceURL)
        let bookId = UUID().uuidString

        let destinationURL = try FileAccess.copyFB2ToSandbox(from: sourceURL, bookId: bookId)

        var coverPath: String?
        if let coverData = metadata.coverData {
            let destination = try FileAccess.coversDir.appendingPathComponent("\(bookId).png")
            let normalized = ImageDataTransformer.normalizedPNGData(from: coverData) ?? coverData
            try normalized.write(to: destination)
            coverPath = destination.path
        }

        var book = Book(
            id: bookId,
            title: metadata.title,
            author: metadata.author,
            coverPath: coverPath,
            filePath: destinationURL.path,
            addedAt: Date()
        )
        book.format = .fb2

        try await repository.insert(book)
        return book
    }
}

// MARK: - Lightweight metadata-only SAX scanner

private final class FB2MetadataScanner: NSObject, XMLParserDelegate {

    let data: Data
    private(set) var title: String?
    private(set) var authorParts: [String] = []
    private(set) var coverData: Data?

    private var inTitleInfo = false
    private var inAuthor = false
    private var currentTag = ""
    private var accumulated = ""
    private var firstName = ""
    private var lastName = ""
    private var middleName = ""
    private var coverBinaryId = ""
    private var inBinary = false
    private var binaryId = ""
    private var binaryText = ""
    private var pendingCoverId = ""
    private var binaries: [String: Data] = [:]
    private var doneWithMeta = false

    init(data: Data) { self.data = data }

    func scan() {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = true
        parser.parse()

        // Resolve cover after parsing
        if !pendingCoverId.isEmpty, let imgData = binaries[pendingCoverId] {
            coverData = imgData
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        let tag = local(qName ?? elementName)

        if tag == "binary" {
            let id = attributeDict["id"] ?? ""
            // Only collect the binary we actually need (the cover image)
            if !pendingCoverId.isEmpty && id == pendingCoverId {
                inBinary = true
                binaryId = id
                binaryText = ""
            }
            return
        }

        if doneWithMeta && !inBinary { return }

        if tag == "title-info" { inTitleInfo = true; return }
        if tag == "publish-info" && inTitleInfo { inTitleInfo = false; doneWithMeta = true; return }

        guard inTitleInfo else { return }

        if tag == "author" { inAuthor = true; firstName = ""; lastName = ""; middleName = "" }
        currentTag = tag
        accumulated = ""

        if tag == "image", inTitleInfo {
            // coverpage image reference
            let href = (attributeDict["l:href"] ?? attributeDict["xlink:href"] ?? attributeDict["href"])
                .map { $0.trimmingCharacters(in: .init(charactersIn: "#")) } ?? ""
            if !href.isEmpty { pendingCoverId = href }
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let tag = local(qName ?? elementName)

        if tag == "binary" {
            if !binaryId.isEmpty, let decoded = Data(base64Encoded: binaryText, options: .ignoreUnknownCharacters) {
                binaries[binaryId] = decoded
            }
            inBinary = false
            binaryId = ""
            binaryText = ""
            return
        }

        guard inTitleInfo else { return }

        let value = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)

        switch tag {
        case "book-title": title = value
        case "first-name" where inAuthor: firstName = value
        case "middle-name" where inAuthor: middleName = value
        case "last-name" where inAuthor: lastName = value
        case "author":
            if inAuthor {
                var parts = [firstName, middleName, lastName].filter { !$0.isEmpty }
                if parts.isEmpty, !value.isEmpty { parts = [value] }
                if !parts.isEmpty { authorParts.append(parts.joined(separator: " ")) }
                inAuthor = false
            }
        default: break
        }
        currentTag = ""
        accumulated = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inBinary { binaryText += string; return }
        accumulated += string
    }

    private func local(_ qName: String) -> String {
        if let colon = qName.lastIndex(of: ":") {
            return String(qName[qName.index(after: colon)...])
        }
        return qName
    }
}
