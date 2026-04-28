import Testing
@testable import Reader

@Suite("EPUB Page Mapper")
struct EPUBPageMapperTests {
    @Test func validatesCompletePositiveCountsOnly() {
        #expect(EPUBPageMapper.isValid(counts: [2, 3, 1], chapterCount: 3))
        #expect(!EPUBPageMapper.isValid(counts: [2, 3], chapterCount: 3))
        #expect(!EPUBPageMapper.isValid(counts: [2, 0, 1], chapterCount: 3))
        #expect(!EPUBPageMapper.isValid(counts: [2, -1, 1], chapterCount: 3))
    }

    @Test func mapsChapterLocalPageToGlobalPage() {
        let counts = [3, 2, 4]

        #expect(EPUBPageMapper.globalPage(chapterIndex: 0, pageInChapter: 0, counts: counts) == 1)
        #expect(EPUBPageMapper.globalPage(chapterIndex: 1, pageInChapter: 0, counts: counts) == 4)
        #expect(EPUBPageMapper.globalPage(chapterIndex: 2, pageInChapter: 3, counts: counts) == 9)
        #expect(EPUBPageMapper.globalPage(chapterIndex: 2, pageInChapter: 99, counts: counts) == 9)
        #expect(EPUBPageMapper.globalPage(chapterIndex: 4, pageInChapter: 0, counts: counts) == nil)
    }

    @Test func mapsGlobalPageToChapterLocalPage() {
        let counts = [3, 2, 4]

        #expect(EPUBPageMapper.target(forGlobalPage: 1, counts: counts)?.chapterIndex == 0)
        #expect(EPUBPageMapper.target(forGlobalPage: 1, counts: counts)?.pageInChapter == 0)
        #expect(EPUBPageMapper.target(forGlobalPage: 4, counts: counts)?.chapterIndex == 1)
        #expect(EPUBPageMapper.target(forGlobalPage: 4, counts: counts)?.pageInChapter == 0)
        #expect(EPUBPageMapper.target(forGlobalPage: 9, counts: counts)?.chapterIndex == 2)
        #expect(EPUBPageMapper.target(forGlobalPage: 9, counts: counts)?.pageInChapter == 3)
    }

    @Test func clampsInvalidGlobalPageInput() {
        let counts = [3, 2, 4]

        #expect(EPUBPageMapper.target(forGlobalPage: 0, counts: counts)?.chapterIndex == 0)
        #expect(EPUBPageMapper.target(forGlobalPage: 99, counts: counts)?.chapterIndex == 2)
        #expect(EPUBPageMapper.target(forGlobalPage: 99, counts: counts)?.pageInChapter == 3)
        #expect(EPUBPageMapper.target(forGlobalPage: 1, counts: [3, 0, 4]) == nil)
    }

    @Test func rejectsInvalidGlobalPageInputForReaderNavigation() {
        let counts = [3, 2, 4]

        #expect(EPUBPageMapper.target(forValidGlobalPage: 0, counts: counts) == nil)
        #expect(EPUBPageMapper.target(forValidGlobalPage: 10, counts: counts) == nil)
        #expect(EPUBPageMapper.target(forValidGlobalPage: 9, counts: counts)?.chapterIndex == 2)
        #expect(EPUBPageMapper.target(forValidGlobalPage: 9, counts: counts)?.pageInChapter == 3)
    }
}
