import Foundation

enum MarkdownAnnotationDecodingError: Error, Equatable {
    case missingFrontMatter
    case invalidFrontMatter
    case missingRequiredField(String)
    case unsupportedFormat(String)
    case malformedItem
    case malformedMetadata
    case invalidDate(String)
}

struct MarkdownAnnotationDecoder: Sendable {
    func decode(_ markdown: String) throws -> AnnotationExchangeDocument {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let (frontMatter, body) = try splitFrontMatter(from: normalized)
        let frontMatterFields = try parseFrontMatter(frontMatter)

        guard let format = frontMatterFields.format else {
            throw MarkdownAnnotationDecodingError.missingRequiredField("format")
        }
        guard format == AnnotationExchangeDocumentFormat.readerAnnotationsV1.rawValue else {
            throw MarkdownAnnotationDecodingError.unsupportedFormat(format)
        }
        guard let exportedAtRaw = frontMatterFields.exportedAt else {
            throw MarkdownAnnotationDecodingError.missingRequiredField("exportedAt")
        }

        return AnnotationExchangeDocument(
            format: .readerAnnotationsV1,
            exportedAt: try decodeDate(exportedAtRaw),
            book: try AnnotationExchangeBook(
                id: frontMatterFields.bookId,
                title: require(frontMatterFields.bookTitle, field: "book.title"),
                author: frontMatterFields.bookAuthor,
                format: try decodeBookFormat(require(frontMatterFields.bookFormat, field: "book.format")),
                contentHash: require(frontMatterFields.bookContentHash, field: "book.contentHash")
            ),
            items: try parseItems(from: body)
        )
    }

    private func splitFrontMatter(from markdown: String) throws -> (String, String) {
        guard markdown.hasPrefix("---\n") else {
            throw MarkdownAnnotationDecodingError.missingFrontMatter
        }

        let contentStart = markdown.index(markdown.startIndex, offsetBy: 4)
        guard let closingRange = markdown.range(of: "\n---\n", range: contentStart..<markdown.endIndex) else {
            throw MarkdownAnnotationDecodingError.invalidFrontMatter
        }

        return (
            String(markdown[contentStart..<closingRange.lowerBound]),
            String(markdown[closingRange.upperBound...])
        )
    }

    private func parseFrontMatter(_ frontMatter: String) throws -> FrontMatterFields {
        var fields = FrontMatterFields()

        for line in frontMatter.split(separator: "\n", omittingEmptySubsequences: false) {
            let rawLine = String(line)
            if rawLine.hasPrefix("format: ") {
                fields.format = try decodeScalar(String(rawLine.dropFirst("format: ".count)))
            } else if rawLine.hasPrefix("exportedAt: ") {
                fields.exportedAt = try decodeScalar(String(rawLine.dropFirst("exportedAt: ".count)))
            } else if rawLine.hasPrefix("  id: ") {
                fields.bookId = try decodeScalar(String(rawLine.dropFirst("  id: ".count)))
            } else if rawLine.hasPrefix("  title: ") {
                fields.bookTitle = try decodeScalar(String(rawLine.dropFirst("  title: ".count)))
            } else if rawLine.hasPrefix("  author: ") {
                fields.bookAuthor = try decodeScalar(String(rawLine.dropFirst("  author: ".count)))
            } else if rawLine.hasPrefix("  format: ") {
                fields.bookFormat = try decodeScalar(String(rawLine.dropFirst("  format: ".count)))
            } else if rawLine.hasPrefix("  contentHash: ") {
                fields.bookContentHash = try decodeScalar(String(rawLine.dropFirst("  contentHash: ".count)))
            }
        }

        return fields
    }

    private func parseItems(from body: String) throws -> [AnnotationExchangeItem] {
        let pattern = #"(?ms)^### (Highlight|Text Note|Sticky Note)\n<!--\n(.*?)\n-->\n\n(.*?)(?=^### |^## |\z)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let bodyRange = NSRange(body.startIndex..<body.endIndex, in: body)
        let matches = regex.matches(in: body, range: bodyRange)

        return try matches.map { match in
            guard let titleRange = Range(match.range(at: 1), in: body),
                  let metadataRange = Range(match.range(at: 2), in: body),
                  let contentRange = Range(match.range(at: 3), in: body) else {
                throw MarkdownAnnotationDecodingError.malformedItem
            }

            let title = String(body[titleRange])
            let metadata = try parseMetadataBlock(String(body[metadataRange]))
            let visibleContent = String(body[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return try buildItem(title: title, metadata: metadata, visibleContent: visibleContent)
        }
    }

    private func parseMetadataBlock(_ metadata: String) throws -> ItemMetadata {
        var parsed = ItemMetadata()
        let lines = metadata.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var index = 0

        while index < lines.count {
            let line = lines[index]
            if line == "anchor:" {
                guard index + 2 < lines.count else {
                    throw MarkdownAnnotationDecodingError.malformedMetadata
                }
                let schemeLine = lines[index + 1]
                let valueLine = lines[index + 2]
                guard schemeLine.hasPrefix("  scheme: "),
                      valueLine.hasPrefix("  value: ") else {
                    throw MarkdownAnnotationDecodingError.malformedMetadata
                }
                parsed.anchorScheme = try decodeScalar(String(schemeLine.dropFirst("  scheme: ".count)))
                parsed.anchorValue = try decodeScalar(String(valueLine.dropFirst("  value: ".count)))
                index += 3
                continue
            }

            if line.hasPrefix("id: ") {
                parsed.id = try decodeScalar(String(line.dropFirst("id: ".count)))
            } else if line.hasPrefix("type: ") {
                parsed.type = try decodeScalar(String(line.dropFirst("type: ".count)))
            } else if line.hasPrefix("createdAt: ") {
                parsed.createdAt = try decodeScalar(String(line.dropFirst("createdAt: ".count)))
            } else if line.hasPrefix("updatedAt: ") {
                parsed.updatedAt = try decodeScalar(String(line.dropFirst("updatedAt: ".count)))
            } else if line.hasPrefix("color: ") {
                parsed.color = try decodeScalar(String(line.dropFirst("color: ".count)))
            } else if line.hasPrefix("selectedText: ") {
                parsed.selectedText = try decodeScalar(String(line.dropFirst("selectedText: ".count)))
            } else if line.hasPrefix("pageLabel: ") {
                parsed.pageLabel = try decodeScalar(String(line.dropFirst("pageLabel: ".count)))
            }

            index += 1
        }

        return parsed
    }

    private func buildItem(
        title: String,
        metadata: ItemMetadata,
        visibleContent: String
    ) throws -> AnnotationExchangeItem {
        guard let exchangeId = metadata.id else {
            throw MarkdownAnnotationDecodingError.missingRequiredField("id")
        }
        guard let typeRaw = metadata.type else {
            throw MarkdownAnnotationDecodingError.missingRequiredField("type")
        }
        guard let anchorScheme = metadata.anchorScheme else {
            throw MarkdownAnnotationDecodingError.missingRequiredField("anchor.scheme")
        }
        guard let anchorValue = metadata.anchorValue else {
            throw MarkdownAnnotationDecodingError.missingRequiredField("anchor.value")
        }
        guard let createdAtRaw = metadata.createdAt else {
            throw MarkdownAnnotationDecodingError.missingRequiredField("createdAt")
        }
        guard let updatedAtRaw = metadata.updatedAt else {
            throw MarkdownAnnotationDecodingError.missingRequiredField("updatedAt")
        }

        let itemType = try decodeItemType(typeRaw)
        let anchor = AnnotationExchangeAnchor(
            scheme: try decodeAnchorScheme(anchorScheme),
            value: anchorValue
        )
        let body = parseVisibleBody(title: title, visibleContent: visibleContent)

        return AnnotationExchangeItem(
            exchangeId: exchangeId,
            type: itemType,
            anchor: anchor,
            createdAt: try decodeDate(createdAtRaw),
            updatedAt: try decodeDate(updatedAtRaw),
            selectedText: metadata.selectedText ?? body.selectedText,
            body: body.noteBody,
            color: try metadata.color.map(decodeColor),
            pageLabel: metadata.pageLabel ?? body.pageLabel
        )
    }

    private func parseVisibleBody(title: String, visibleContent: String) -> VisibleBody {
        switch title {
        case "Highlight":
            let lines = visibleContent
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .map { $0.hasPrefix("> ") ? String($0.dropFirst(2)) : $0 }
            return VisibleBody(
                selectedText: lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
                noteBody: nil,
                pageLabel: nil
            )
        case "Text Note":
            let sections = splitVisibleSections(visibleContent)
            return VisibleBody(
                selectedText: normalizeBlockquoteIfNeeded(sections["Selected text"]),
                noteBody: sections["Note"],
                pageLabel: nil
            )
        case "Sticky Note":
            let sections = splitVisibleSections(visibleContent)
            return VisibleBody(
                selectedText: nil,
                noteBody: sections["Note"],
                pageLabel: normalizeBlockquoteIfNeeded(sections["Location"])
            )
        default:
            return VisibleBody(selectedText: nil, noteBody: nil, pageLabel: nil)
        }
    }

    private func splitVisibleSections(_ visibleContent: String) -> [String: String] {
        let normalized = visibleContent
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let pattern = #"(?ms)\*\*(Selected text|Location|Note)\*\*\n\n(.*?)(?=\n\n\*\*|\z)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [:] }
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)
        var result: [String: String] = [:]
        for match in regex.matches(in: normalized, range: range) {
            guard let keyRange = Range(match.range(at: 1), in: normalized),
                  let valueRange = Range(match.range(at: 2), in: normalized) else {
                continue
            }
            result[String(normalized[keyRange])] = String(normalized[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return result
    }

    private func normalizeBlockquoteIfNeeded(_ value: String?) -> String? {
        guard let value else { return nil }

        let lines = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        let normalized = lines.map { line in
            if line.hasPrefix("> ") {
                return String(line.dropFirst(2))
            }
            if line == ">" {
                return ""
            }
            return line
        }.joined(separator: "\n")

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeBookFormat(_ rawValue: String) throws -> BookFormat {
        guard let format = BookFormat(rawValue: rawValue) else {
            throw MarkdownAnnotationDecodingError.missingRequiredField("book.format")
        }
        return format
    }

    private func decodeItemType(_ rawValue: String) throws -> AnnotationExchangeItemType {
        guard let itemType = AnnotationExchangeItemType(rawValue: rawValue) else {
            throw MarkdownAnnotationDecodingError.malformedMetadata
        }
        return itemType
    }

    private func decodeAnchorScheme(_ rawValue: String) throws -> AnnotationExchangeAnchorScheme {
        guard let scheme = AnnotationExchangeAnchorScheme(rawValue: rawValue) else {
            throw MarkdownAnnotationDecodingError.malformedMetadata
        }
        return scheme
    }

    private func decodeColor(_ rawValue: String) throws -> AnnotationExchangeHighlightColor {
        guard let color = AnnotationExchangeHighlightColor(rawValue: rawValue) else {
            throw MarkdownAnnotationDecodingError.malformedMetadata
        }
        return color
    }

    private func decodeDate(_ rawValue: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        guard let date = formatter.date(from: rawValue) else {
            throw MarkdownAnnotationDecodingError.invalidDate(rawValue)
        }
        return date
    }

    private func decodeScalar(_ rawValue: String) throws -> String {
        struct Box: Decodable { let value: String }
        let data = Data(#"{"value": \#(rawValue)}"#.utf8)
        return try JSONDecoder().decode(Box.self, from: data).value
    }

    private func require(_ value: String?, field: String) throws -> String {
        guard let value, !value.isEmpty else {
            throw MarkdownAnnotationDecodingError.missingRequiredField(field)
        }
        return value
    }
}

private struct FrontMatterFields {
    var format: String?
    var exportedAt: String?
    var bookId: String?
    var bookTitle: String?
    var bookAuthor: String?
    var bookFormat: String?
    var bookContentHash: String?
}

private struct ItemMetadata {
    var id: String?
    var type: String?
    var anchorScheme: String?
    var anchorValue: String?
    var createdAt: String?
    var updatedAt: String?
    var color: String?
    var selectedText: String?
    var pageLabel: String?
}

private struct VisibleBody {
    var selectedText: String?
    var noteBody: String?
    var pageLabel: String?
}
