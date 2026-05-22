import Foundation

public enum SegmentState: String, Codable, Equatable, Sendable {
    case partial
    case final
    case translated
}

public struct SubtitleSegment: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var sessionID: UUID
    public var index: Int
    public var state: SegmentState
    public var startTime: TimeInterval
    public var endTime: TimeInterval?
    public var englishText: String
    public var chineseText: String?
    public var isLowConfidence: Bool
    public var sourceName: String
    public var mode: LocalVMode
    public var models: ModelSelection
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        index: Int,
        state: SegmentState,
        startTime: TimeInterval,
        endTime: TimeInterval? = nil,
        englishText: String,
        chineseText: String? = nil,
        isLowConfidence: Bool = false,
        sourceName: String,
        mode: LocalVMode,
        models: ModelSelection,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.index = index
        self.state = state
        self.startTime = startTime
        self.endTime = endTime
        self.englishText = englishText
        self.chineseText = chineseText
        self.isLowConfidence = isLowConfidence
        self.sourceName = sourceName
        self.mode = mode
        self.models = models
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func finalized(endTime: TimeInterval, englishText: String? = nil, at date: Date = Date()) -> SubtitleSegment {
        var copy = self
        copy.state = .final
        copy.endTime = endTime
        copy.englishText = englishText ?? self.englishText
        copy.updatedAt = date
        return copy
    }

    public func translated(_ text: String, at date: Date = Date()) -> SubtitleSegment {
        var copy = self
        copy.state = .translated
        copy.chineseText = text
        copy.updatedAt = date
        return copy
    }
}

