import Foundation

public struct VoiceActivityDecision: Equatable, Sendable {
    public var isSpeech: Bool
    public var rms: Float
    public var threshold: Float

    public init(isSpeech: Bool, rms: Float, threshold: Float) {
        self.isSpeech = isSpeech
        self.rms = rms
        self.threshold = threshold
    }
}

public struct EnergyVoiceActivityDetector: Sendable {
    public var speechThreshold: Float
    public var silenceThreshold: Float
    public var minimumSpeechDuration: TimeInterval
    public var minimumSilenceDuration: TimeInterval

    public init(
        speechThreshold: Float = 0.012,
        silenceThreshold: Float = 0.006,
        minimumSpeechDuration: TimeInterval = 0.08,
        minimumSilenceDuration: TimeInterval = 0.25
    ) {
        precondition(speechThreshold >= silenceThreshold, "speechThreshold should be >= silenceThreshold")
        self.speechThreshold = speechThreshold
        self.silenceThreshold = silenceThreshold
        self.minimumSpeechDuration = minimumSpeechDuration
        self.minimumSilenceDuration = minimumSilenceDuration
    }

    public func classify(_ chunk: AudioChunk, wasSpeech: Bool = false) -> VoiceActivityDecision {
        let rms = chunk.rootMeanSquare
        let threshold = wasSpeech ? silenceThreshold : speechThreshold
        let durationIsEnough = wasSpeech
            ? chunk.duration >= minimumSilenceDuration
            : chunk.duration >= minimumSpeechDuration

        if wasSpeech {
            return VoiceActivityDecision(
                isSpeech: !(durationIsEnough && rms < threshold),
                rms: rms,
                threshold: threshold
            )
        }

        return VoiceActivityDecision(
            isSpeech: durationIsEnough && rms >= threshold,
            rms: rms,
            threshold: threshold
        )
    }
}
