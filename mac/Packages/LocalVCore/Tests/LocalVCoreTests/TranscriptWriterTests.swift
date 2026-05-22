import Foundation
import XCTest
@testable import LocalVCore

final class TranscriptWriterTests: XCTestCase {
    func testTranscriptWriterCreatesJsonLine() throws {
        let segment = SubtitleSegment(
            sessionID: UUID(),
            index: 1,
            state: .translated,
            startTime: 1,
            endTime: 2,
            englishText: "airdrop is live",
            chineseText: "空投开始了",
            sourceName: "Google Chrome",
            mode: .live,
            models: .liveDefault
        )

        let line = try TranscriptWriter().jsonLine(for: segment)

        XCTAssertTrue(line.hasSuffix("\n"))
        XCTAssertTrue(line.contains("\"englishText\":\"airdrop is live\""))
        XCTAssertTrue(line.contains("\"chineseText\":\"空投开始了\""))
    }

    func testTranscriptWriterFormatsTimestamps() {
        XCTAssertEqual(TranscriptWriter.timestamp(0), "00:00")
        XCTAssertEqual(TranscriptWriter.timestamp(61), "01:01")
        XCTAssertEqual(TranscriptWriter.timestamp(3661), "01:01:01")
    }

    func testTranscriptWriterCreatesMarkdown() {
        let manifest = SessionManifest(
            sourceKind: .chromeApp,
            sourceName: "Google Chrome",
            title: "Morning Space",
            mode: .live,
            models: .liveDefault,
            glossaryVersion: "crypto-seed-v1"
        )
        let segment = SubtitleSegment(
            sessionID: manifest.id,
            index: 1,
            state: .translated,
            startTime: 1,
            endTime: 3,
            englishText: "SOL looks strong",
            chineseText: "SOL 看起来很强",
            sourceName: "Google Chrome",
            mode: .live,
            models: .liveDefault
        )
        let writer = TranscriptWriter()

        XCTAssertTrue(writer.markdownHeader(for: manifest).contains("# Morning Space"))
        XCTAssertTrue(writer.markdownBlock(for: segment).contains("SOL 看起来很强"))
    }
}

