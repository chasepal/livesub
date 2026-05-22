import Foundation

public struct StreamingVoiceActivityDetector: Sendable {
    public private(set) var isSpeech = false
    public private(set) var lastDecision = VoiceActivityDecision(isSpeech: false, rms: 0, threshold: 0)

    public var configuration: EnergyVoiceActivityDetector

    private var speechCandidateDuration: TimeInterval = 0
    private var silenceCandidateDuration: TimeInterval = 0

    public init(configuration: EnergyVoiceActivityDetector = EnergyVoiceActivityDetector()) {
        self.configuration = configuration
        self.lastDecision = VoiceActivityDecision(
            isSpeech: false,
            rms: 0,
            threshold: configuration.speechThreshold
        )
    }

    public mutating func process(_ chunk: AudioChunk) -> VoiceActivityDecision {
        let mono = chunk.monoDownmixed()
        let rms = mono.rootMeanSquare

        if isSpeech {
            if rms < configuration.silenceThreshold {
                silenceCandidateDuration += mono.duration
            } else {
                silenceCandidateDuration = 0
            }

            if silenceCandidateDuration >= configuration.minimumSilenceDuration {
                isSpeech = false
                speechCandidateDuration = 0
            }
        } else {
            if rms >= configuration.speechThreshold {
                speechCandidateDuration += mono.duration
            } else {
                speechCandidateDuration = 0
            }

            if speechCandidateDuration >= configuration.minimumSpeechDuration {
                isSpeech = true
                silenceCandidateDuration = 0
            }
        }

        let threshold = isSpeech ? configuration.silenceThreshold : configuration.speechThreshold
        lastDecision = VoiceActivityDecision(isSpeech: isSpeech, rms: rms, threshold: threshold)
        return lastDecision
    }
}
