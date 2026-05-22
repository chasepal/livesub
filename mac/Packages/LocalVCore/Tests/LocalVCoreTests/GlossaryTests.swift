import XCTest
@testable import LocalVCore

final class GlossaryTests: XCTestCase {
    func testGlossaryBuildsPromptHints() {
        let glossary = Glossary(
            terms: [
                GlossaryTerm(source: "SOL", shouldPreserve: true),
                GlossaryTerm(source: "airdrop", target: "空投")
            ]
        )

        let hint = glossary.promptHint()

        XCTAssertTrue(hint.contains("Preserve SOL"))
        XCTAssertTrue(hint.contains("airdrop => 空投"))
    }

    func testSeedGlossaryPreservesTickers() {
        XCTAssertTrue(Glossary.cryptoSeed.preservedTerms.contains("BTC"))
        XCTAssertTrue(Glossary.cryptoSeed.preservedTerms.contains("ETH"))
        XCTAssertTrue(Glossary.cryptoSeed.preservedTerms.contains("SOL"))
    }
}

