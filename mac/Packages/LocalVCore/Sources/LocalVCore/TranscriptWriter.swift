import Foundation

public struct TranscriptWriter: Sendable {
    public enum TranscriptError: Error, Equatable {
        case invalidUTF8
    }

    private let encoder: JSONEncoder

    public init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func jsonLine(for segment: SubtitleSegment) throws -> String {
        let data = try encoder.encode(segment)
        guard let json = String(data: data, encoding: .utf8) else {
            throw TranscriptError.invalidUTF8
        }

        return json + "\n"
    }

    public func markdownHeader(for manifest: SessionManifest) -> String {
        var lines: [String] = [
            "# \(manifest.title.isEmpty ? "Untitled Chrome Session" : manifest.title)",
            "",
            "- Source: \(manifest.sourceName)",
            "- Mode: \(manifest.mode.rawValue)",
            "- ASR: \(manifest.models.asrModel)"
        ]

        if let translationModel = manifest.models.translationModel {
            lines.append("- Translation: \(translationModel)")
        }

        if let glossaryVersion = manifest.glossaryVersion {
            lines.append("- Glossary: \(glossaryVersion)")
        }

        lines.append("")
        lines.append("## Transcript")
        lines.append("")

        return lines.joined(separator: "\n")
    }

    public func markdownBlock(for segment: SubtitleSegment) -> String {
        let start = Self.timestamp(segment.startTime)
        let end = segment.endTime.map(Self.timestamp) ?? "..."
        let confidence = segment.isLowConfidence ? " low-confidence" : ""
        var lines = [
            "### [\(start) - \(end)] \(segment.state.rawValue)\(confidence)",
            "",
            segment.englishText
        ]

        if let chineseText = segment.chineseText, !chineseText.isEmpty {
            lines.append("")
            lines.append(chineseText)
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    public static func timestamp(_ seconds: TimeInterval) -> String {
        let clamped = max(0, Int(seconds.rounded(.down)))
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let remainingSeconds = clamped % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
        }

        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

