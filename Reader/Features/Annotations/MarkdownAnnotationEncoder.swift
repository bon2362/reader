import Foundation

enum MarkdownAnnotationEncodingError: Error, Equatable {
    case missingBookTitle
    case missingContentHash
    case missingExchangeId
    case missingAnchorValue
    case missingSelectedTextForHighlight
}

struct MarkdownAnnotationEncoder: Sendable {
    func encode(_ document: AnnotationExchangeDocument) throws -> String {
        try validate(document)

        var lines: [String] = []
        lines += renderFrontMatter(for: document)
        lines.append("")
        lines.append("# Annotations")

        let sections = [
            renderSection(
                title: "Highlights",
                items: document.highlights,
                render: renderHighlight
            ),
            renderSection(
                title: "Text Notes",
                items: document.textNotes,
                render: renderTextNote
            ),
            renderSection(
                title: "Sticky Notes",
                items: document.stickyNotes,
                render: renderStickyNote
            ),
        ].compactMap { $0 }

        for section in sections {
            lines.append("")
            lines.append(contentsOf: section)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private func validate(_ document: AnnotationExchangeDocument) throws {
        guard !document.book.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MarkdownAnnotationEncodingError.missingBookTitle
        }

        guard !document.book.contentHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MarkdownAnnotationEncodingError.missingContentHash
        }

        for item in document.items {
            guard !item.exchangeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MarkdownAnnotationEncodingError.missingExchangeId
            }

            guard !item.anchor.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MarkdownAnnotationEncodingError.missingAnchorValue
            }

            if item.type == .highlight {
                guard let selectedText = item.selectedText?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !selectedText.isEmpty
                else {
                    throw MarkdownAnnotationEncodingError.missingSelectedTextForHighlight
                }
            }
        }
    }

    private func renderFrontMatter(for document: AnnotationExchangeDocument) -> [String] {
        var lines = [
            "---",
            "format: \(yamlScalar(document.format.rawValue))",
            "exportedAt: \(yamlScalar(iso8601(document.exportedAt)))",
            "book:",
        ]

        if let id = document.book.id, !id.isEmpty {
            lines.append("  id: \(yamlScalar(id))")
        }

        lines.append("  title: \(yamlScalar(document.book.title))")

        if let author = document.book.author, !author.isEmpty {
            lines.append("  author: \(yamlScalar(author))")
        }

        lines.append("  format: \(yamlScalar(document.book.format.rawValue))")
        lines.append("  contentHash: \(yamlScalar(document.book.contentHash))")
        lines.append("---")
        return lines
    }

    private func renderSection(
        title: String,
        items: [AnnotationExchangeItem],
        render: (AnnotationExchangeItem) -> [String]
    ) -> [String]? {
        let sortedItems = items.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.exchangeId < $1.exchangeId
        }

        guard !sortedItems.isEmpty else { return nil }

        var lines = ["## \(title)"]
        for item in sortedItems {
            lines.append("")
            lines.append(contentsOf: render(item))
        }
        return lines
    }

    private func renderHighlight(_ item: AnnotationExchangeItem) -> [String] {
        var lines = commonItemHeader(title: "Highlight", item: item)
        if let color = item.color {
            lines.append("color: \(yamlScalar(color.rawValue))")
        }
        if let selectedText = item.selectedText {
            lines.append("selectedText: \(yamlScalar(selectedText, sanitizeForComment: true))")
        }
        lines.append("-->")
        lines.append("")
        lines.append(contentsOf: blockquoteLines(for: item.selectedText ?? ""))
        return lines
    }

    private func renderTextNote(_ item: AnnotationExchangeItem) -> [String] {
        var lines = commonItemHeader(title: "Text Note", item: item)
        if let selectedText = item.selectedText, !selectedText.isEmpty {
            lines.append("selectedText: \(yamlScalar(selectedText, sanitizeForComment: true))")
        }
        lines.append("-->")
        lines.append("")

        if let selectedText = item.selectedText, !selectedText.isEmpty {
            lines.append("**Selected text**")
            lines.append("")
            lines.append(contentsOf: blockquoteLines(for: selectedText))
            lines.append("")
        }

        lines.append("**Note**")
        lines.append("")
        lines.append(contentsOf: normalizedLines(for: item.body ?? ""))
        return lines
    }

    private func renderStickyNote(_ item: AnnotationExchangeItem) -> [String] {
        var lines = commonItemHeader(title: "Sticky Note", item: item)
        if let pageLabel = item.pageLabel, !pageLabel.isEmpty {
            lines.append("pageLabel: \(yamlScalar(pageLabel, sanitizeForComment: true))")
        }
        lines.append("-->")
        lines.append("")

        if let pageLabel = item.pageLabel, !pageLabel.isEmpty {
            lines.append("**Location**")
            lines.append("")
            lines.append(contentsOf: blockquoteLines(for: pageLabel))
            lines.append("")
        }

        lines.append("**Note**")
        lines.append("")
        lines.append(contentsOf: normalizedLines(for: item.body ?? ""))
        return lines
    }

    private func commonItemHeader(title: String, item: AnnotationExchangeItem) -> [String] {
        [
            "### \(title)",
            "<!--",
            "id: \(yamlScalar(item.exchangeId))",
            "type: \(yamlScalar(item.type.rawValue))",
            "anchor:",
            "  scheme: \(yamlScalar(item.anchor.scheme.rawValue))",
            "  value: \(yamlScalar(item.anchor.value, sanitizeForComment: true))",
            "createdAt: \(yamlScalar(iso8601(item.createdAt)))",
            "updatedAt: \(yamlScalar(iso8601(item.updatedAt)))",
        ]
    }

    private func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private func yamlScalar(_ value: String, sanitizeForComment: Bool = false) -> String {
        let normalized = sanitizeForComment ? sanitizeCommentValue(value) : value
        let escaped = normalized
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private func sanitizeCommentValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "<!--", with: "<\\!--")
            .replacingOccurrences(of: "-->", with: "--\\>")
    }

    private func normalizedLines(for value: String) -> [String] {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    private func blockquoteLines(for value: String) -> [String] {
        normalizedLines(for: value).map { "> \($0)" }
    }
}
