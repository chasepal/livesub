import Foundation
import XCTest
@testable import LocalVCore

final class SubtitleSegmentTests: XCTestCase {
    func testSegmentMovesFromPartialToFinalToTranslated() {
        let sessionID = UUID()
        let partial = SubtitleSegment(
            sessionID: sessionID,
            index: 1,
            state: .partial,
            startTime: 0,
            englishText: "this is hyperliquid",
            sourceName: "Google Chrome",
            mode: .live,
            models: .liveDefault
        )

        let final = partial.finalized(endTime: 2.4, englishText: "This is Hyperliquid.")
        let translated = final.translated("这是 Hyperliquid。")

        XCTAssertEqual(final.state, .final)
        XCTAssertEqual(final.endTime, 2.4)
        XCTAssertEqual(translated.state, .translated)
        XCTAssertEqual(translated.chineseText, "这是 Hyperliquid。")
        XCTAssertEqual(translated.id, partial.id)
    }
}

