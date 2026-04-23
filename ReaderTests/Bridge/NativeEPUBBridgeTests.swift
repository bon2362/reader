import Testing
@testable import Reader

@Suite("NativeEPUBBridge")
struct NativeEPUBBridgeTests {

    @Test func parsePageTurnResultReadsValidDictionary() {
        let result = NativeEPUBBridge.parsePageTurnResult([
            "before": 4,
            "after": 5,
            "totalPages": 12
        ])

        #expect(result == .init(before: 4, after: 5, totalPages: 12))
        #expect(result?.didMove == true)
    }

    @Test func parsePageTurnResultRejectsIncompleteDictionary() {
        let result = NativeEPUBBridge.parsePageTurnResult([
            "before": 4,
            "after": 4
        ])

        #expect(result == nil)
    }
}
