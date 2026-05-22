import Foundation
import XCTest
@testable import LocalVCore

final class SessionManifestTests: XCTestCase {
    func testManifestBuildsSafeFilename() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 60 * 62)
        let manifest = SessionManifest(
            startedAt: date,
            sourceKind: .chromeApp,
            sourceName: "Google Chrome",
            title: "X Space: SOL / HYPE?",
            mode: .live,
            models: .liveDefault
        )

        XCTAssertEqual(manifest.safeBaseFilename(calendar: calendar), "01-02_Google-Chrome_X-Space-SOL-HYPE")
    }

    func testManifestUsesUntitledFallback() {
        let manifest = SessionManifest(
            sourceKind: .chromeApp,
            sourceName: "",
            title: "",
            mode: .live,
            models: .liveDefault
        )

        let filename = manifest.safeBaseFilename()

        XCTAssertTrue(filename.contains("chromeApp"))
        XCTAssertTrue(filename.contains("Untitled-Chrome-Session"))
    }
}

