import Foundation

public struct SessionManifest: Codable, Equatable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var sourceKind: CaptureSourceKind
    public var sourceName: String
    public var title: String
    public var mode: LocalVMode
    public var models: ModelSelection
    public var glossaryVersion: String?

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        sourceKind: CaptureSourceKind,
        sourceName: String,
        title: String,
        mode: LocalVMode,
        models: ModelSelection,
        glossaryVersion: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sourceKind = sourceKind
        self.sourceName = sourceName
        self.title = title
        self.mode = mode
        self.models = models
        self.glossaryVersion = glossaryVersion
    }

    public func safeBaseFilename(calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: startedAt)
        let hour = String(format: "%02d", components.hour ?? 0)
        let minute = String(format: "%02d", components.minute ?? 0)
        let source = Self.sanitize(sourceName.isEmpty ? sourceKind.rawValue : sourceName)
        let sessionTitle = Self.sanitize(title.isEmpty ? "Untitled Chrome Session" : title)
        return "\(hour)-\(minute)_\(source)_\(sessionTitle)"
    }

    public static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { scalar -> Character in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }

        let collapsed = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")

        return collapsed.isEmpty ? "Untitled" : String(collapsed.prefix(90))
    }
}

