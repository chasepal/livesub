import Foundation

public enum CaptureSourceKind: String, Codable, Equatable, Sendable {
    case chromeApp
    case systemAudio
}

public enum LocalVMode: String, Codable, Equatable, Sendable {
    case live
    case quality
    case asrOnly
    case cloud
}

public struct ModelSelection: Codable, Equatable, Sendable {
    public var asrModel: String
    public var translationModel: String?

    public init(asrModel: String, translationModel: String? = nil) {
        self.asrModel = asrModel
        self.translationModel = translationModel
    }

    public static let liveDefault = ModelSelection(
        asrModel: "large-v3-v20240930_626MB",
        translationModel: "qwen3.5:4b"
    )

    public static let qualityDefault = ModelSelection(
        asrModel: "large-v3-v20240930_626MB",
        translationModel: "qwen3.5:35b-a3b-coding-nvfp4"
    )

    public static let asrOnlyDefault = ModelSelection(
        asrModel: "large-v3-v20240930_626MB",
        translationModel: nil
    )
}
