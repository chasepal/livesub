import Foundation

public struct GlossaryTerm: Codable, Equatable, Sendable {
    public var source: String
    public var target: String?
    public var shouldPreserve: Bool
    public var notes: String?

    public init(
        source: String,
        target: String? = nil,
        shouldPreserve: Bool = false,
        notes: String? = nil
    ) {
        self.source = source
        self.target = target
        self.shouldPreserve = shouldPreserve
        self.notes = notes
    }
}

public struct Glossary: Codable, Equatable, Sendable {
    public var version: String
    public var terms: [GlossaryTerm]

    public init(version: String = "1", terms: [GlossaryTerm] = []) {
        self.version = version
        self.terms = terms
    }

    public var preservedTerms: [String] {
        terms
            .filter(\.shouldPreserve)
            .map(\.source)
            .sorted()
    }

    public func promptHint(maxTerms: Int = 80) -> String {
        let selectedTerms = Array(terms.prefix(maxTerms))

        guard !selectedTerms.isEmpty else {
            return "No glossary terms configured."
        }

        return selectedTerms
            .map { term in
                if term.shouldPreserve {
                    return "- Preserve \(term.source)"
                }

                if let target = term.target, !target.isEmpty {
                    return "- \(term.source) => \(target)"
                }

                return "- \(term.source)"
            }
            .joined(separator: "\n")
    }

    public static let cryptoSeed = Glossary(
        version: "crypto-seed-v1",
        terms: [
            GlossaryTerm(source: "BTC", shouldPreserve: true),
            GlossaryTerm(source: "ETH", shouldPreserve: true),
            GlossaryTerm(source: "SOL", shouldPreserve: true),
            GlossaryTerm(source: "FDV", shouldPreserve: true),
            GlossaryTerm(source: "TVL", shouldPreserve: true),
            GlossaryTerm(source: "TGE", shouldPreserve: true),
            GlossaryTerm(source: "Solana", shouldPreserve: true),
            GlossaryTerm(source: "Ethereum", shouldPreserve: true),
            GlossaryTerm(source: "Base", shouldPreserve: true),
            GlossaryTerm(source: "Hyperliquid", shouldPreserve: true),
            GlossaryTerm(source: "airdrop", target: "空投"),
            GlossaryTerm(source: "staking", target: "质押/staking"),
            GlossaryTerm(source: "restaking", target: "再质押/restaking"),
            GlossaryTerm(source: "perps", target: "永续合约/perps"),
            GlossaryTerm(source: "spot", target: "现货/spot"),
            GlossaryTerm(source: "liquidity", target: "流动性/liquidity")
        ]
    )
}

