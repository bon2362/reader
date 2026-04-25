import Foundation

final class FB2Book: BookContentProvider {
    let rootDir: URL
    let chapters: [EPUBChapter]
    let toc: [EPUBTOCNode]

    init(rootDir: URL, chapters: [EPUBChapter], toc: [EPUBTOCNode]) {
        self.rootDir = rootDir
        self.chapters = chapters
        self.toc = toc
    }

    deinit {
        try? FileManager.default.removeItem(at: rootDir)
    }

    func chapterIndex(forHref href: String) -> Int? {
        let normalized = EPUBBook.normalizeHref(href)
        return chapters.firstIndex { EPUBBook.normalizeHref($0.href) == normalized }
    }
}
