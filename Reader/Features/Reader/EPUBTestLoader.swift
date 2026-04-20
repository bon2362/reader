import Foundation
import ZIPFoundation

enum EPUBTestLoaderError: LocalizedError {
    case missingContainer
    case missingOPF
    case missingSpine

    var errorDescription: String? {
        switch self {
        case .missingContainer: return "Нет META-INF/container.xml"
        case .missingOPF:       return "Нет .opf"
        case .missingSpine:     return "Нет spine"
        }
    }
}

struct EPUBTestUnpacked {
    let rootDir: URL
    let chapterURLs: [URL]
}

enum EPUBTestLoader {

    static func unpack(from epubURL: URL) throws -> EPUBTestUnpacked {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("epub-test-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        try fm.unzipItem(at: epubURL, to: tmp)

        let containerURL = tmp.appendingPathComponent("META-INF/container.xml")
        guard let containerData = try? Data(contentsOf: containerURL),
              let opfRel = parseContainer(containerData) else {
            throw EPUBTestLoaderError.missingContainer
        }

        let opfURL = tmp.appendingPathComponent(opfRel)
        guard let opfData = try? Data(contentsOf: opfURL) else {
            throw EPUBTestLoaderError.missingOPF
        }

        let hrefs = parseSpineHrefs(opfData)
        guard !hrefs.isEmpty else { throw EPUBTestLoaderError.missingSpine }

        let opfDir = opfURL.deletingLastPathComponent()
        let urls = hrefs.compactMap { href -> URL? in
            let u = opfDir.appendingPathComponent(href).standardizedFileURL
            return fm.fileExists(atPath: u.path) ? u : nil
        }
        guard !urls.isEmpty else { throw EPUBTestLoaderError.missingSpine }

        return EPUBTestUnpacked(rootDir: tmp, chapterURLs: urls)
    }

    private static func parseContainer(_ data: Data) -> String? {
        guard let s = String(data: data, encoding: .utf8) else { return nil }
        return firstCapture(in: s, pattern: #"<rootfile[^>]*full-path=\"([^\"]+)\""#)
    }

    private static func parseSpineHrefs(_ data: Data) -> [String] {
        guard let s = String(data: data, encoding: .utf8) else { return [] }

        var manifest: [String: String] = [:]
        let range = NSRange(s.startIndex..., in: s)

        if let itemRegex = try? NSRegularExpression(pattern: #"<item\b[^>]*?>"#, options: [.dotMatchesLineSeparators]) {
            itemRegex.enumerateMatches(in: s, range: range) { m, _, _ in
                guard let m, let r = Range(m.range, in: s) else { return }
                let tag = String(s[r])
                guard let id = firstCapture(in: tag, pattern: #"id=\"([^\"]+)\""#),
                      let href = firstCapture(in: tag, pattern: #"href=\"([^\"]+)\""#) else { return }
                manifest[id] = href
            }
        }

        var hrefs: [String] = []
        if let refRegex = try? NSRegularExpression(pattern: #"<itemref\b[^>]*?idref=\"([^\"]+)\""#, options: [.dotMatchesLineSeparators]) {
            refRegex.enumerateMatches(in: s, range: range) { m, _, _ in
                guard let m, m.numberOfRanges >= 2,
                      let r = Range(m.range(at: 1), in: s) else { return }
                let id = String(s[r])
                if let href = manifest[id] { hrefs.append(href) }
            }
        }
        return hrefs
    }

    private static func firstCapture(in string: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, options: [], range: range), match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: string) else { return nil }
        return String(string[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
