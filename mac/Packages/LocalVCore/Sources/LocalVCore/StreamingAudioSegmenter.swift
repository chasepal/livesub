import Foundation

public enum SpeechWindowKind: String, Sendable {
    case partial
    case final
}

public struct SpeechWindow: Equatable, Sendable {
    public var segmentIndex: Int
    public var revision: Int
    public var kind: SpeechWindowKind
    public var audio: AudioChunk
    public var decision: VoiceActivityDecision

    public init(
        segmentIndex: Int,
        revision: Int,
        kind: SpeechWindowKind,
        audio: AudioChunk,
        decision: VoiceActivityDecision
    ) {
        self.segmentIndex = segmentIndex
        self.revision = revision
        self.kind = kind
        self.audio = audio
        self.decision = decision
    }

    public var startTime: TimeInterval {
        audio.startTime
    }

    public var endTime: TimeInterval {
        audio.endTime
    }

    public var duration: TimeInterval {
        audio.duration
    }
}

public struct AudioSegmenterConfiguration: Sendable {
    public var sampleRate: Int
    public var ringCapacitySeconds: TimeInterval
    public var partialWindowSeconds: TimeInterval
    public var partialIntervalSeconds: TimeInterval
    public var preRollSeconds: TimeInterval
    public var maxSegmentSeconds: TimeInterval
    public var voiceActivityDetector: EnergyVoiceActivityDetector

    public init(
        sampleRate: Int = 16_000,
        ringCapacitySeconds: TimeInterval = 60,
        partialWindowSeconds: TimeInterval = 4.2,
        partialIntervalSeconds: TimeInterval = 0.75,
        preRollSeconds: TimeInterval = 0.2,
        maxSegmentSeconds: TimeInterval = 14,
        voiceActivityDetector: EnergyVoiceActivityDetector = EnergyVoiceActivityDetector()
    ) {
        precondition(sampleRate > 0, "sampleRate must be positive")
        precondition(ringCapacitySeconds > 0, "ringCapacitySeconds must be positive")
        precondition(partialWindowSeconds > 0, "partialWindowSeconds must be positive")
        precondition(partialIntervalSeconds > 0, "partialIntervalSeconds must be positive")
        precondition(preRollSeconds >= 0, "preRollSeconds must be non-negative")
        precondition(maxSegmentSeconds > 0, "maxSegmentSeconds must be positive")
        self.sampleRate = sampleRate
        self.ringCapacitySeconds = ringCapacitySeconds
        self.partialWindowSeconds = partialWindowSeconds
        self.partialIntervalSeconds = partialIntervalSeconds
        self.preRollSeconds = preRollSeconds
        self.maxSegmentSeconds = maxSegmentSeconds
        self.voiceActivityDetector = voiceActivityDetector
    }
}

public struct StreamingAudioSegmenter: Sendable {
    public let configuration: AudioSegmenterConfiguration
    public private(set) var ringBuffer: AudioRingBuffer
    public private(set) var isSpeech = false
    public private(set) var currentSegmentIndex = 0
    public private(set) var lastDecision = VoiceActivityDecision(isSpeech: false, rms: 0, threshold: 0)

    private var vad: StreamingVoiceActivityDetector
    private var activeSegmentStart: TimeInterval?
    private var lastPartialTime: TimeInterval?
    private var revision = 0

    public init(configuration: AudioSegmenterConfiguration = AudioSegmenterConfiguration()) {
        self.configuration = configuration
        self.ringBuffer = AudioRingBuffer(
            sampleRate: configuration.sampleRate,
            capacitySeconds: configuration.ringCapacitySeconds
        )
        self.vad = StreamingVoiceActivityDetector(configuration: configuration.voiceActivityDetector)
        self.lastDecision = VoiceActivityDecision(
            isSpeech: false,
            rms: 0,
            threshold: configuration.voiceActivityDetector.speechThreshold
        )
    }

    public mutating func append(_ chunk: AudioChunk) -> [SpeechWindow] {
        let mono = chunk.monoDownmixed()
        precondition(mono.sampleRate == configuration.sampleRate, "StreamingAudioSegmenter requires a consistent sample rate")

        ringBuffer.append(mono)
        let decision = vad.process(mono)
        lastDecision = decision
        let previousSpeech = isSpeech
        isSpeech = decision.isSpeech

        var windows: [SpeechWindow] = []

        if !previousSpeech && isSpeech {
            activeSegmentStart = max(0, mono.endTime - configuration.voiceActivityDetector.minimumSpeechDuration - configuration.preRollSeconds)
            lastPartialTime = nil
            revision = 0
        }

        if isSpeech {
            if shouldEmitPartial(at: ringBuffer.endTime) {
                windows.append(makeWindow(kind: .partial, decision: decision))
                lastPartialTime = ringBuffer.endTime
                revision += 1
            }

            if let activeSegmentStart, ringBuffer.endTime - activeSegmentStart >= configuration.maxSegmentSeconds {
                windows.append(makeWindow(kind: .final, decision: decision))
                rollToNextSegment(at: ringBuffer.endTime)
            }
        }

        if previousSpeech && !isSpeech {
            windows.append(makeWindow(kind: .final, decision: decision))
            finishSegment()
        }

        return windows
    }

    private func shouldEmitPartial(at time: TimeInterval) -> Bool {
        guard activeSegmentStart != nil else {
            return false
        }

        guard let lastPartialTime else {
            return true
        }

        return time - lastPartialTime >= configuration.partialIntervalSeconds
    }

    private func makeWindow(kind: SpeechWindowKind, decision: VoiceActivityDecision) -> SpeechWindow {
        let start = windowStart(for: kind)
        let audio = ringBuffer.slice(from: start, to: ringBuffer.endTime)
        return SpeechWindow(
            segmentIndex: currentSegmentIndex,
            revision: revision,
            kind: kind,
            audio: audio,
            decision: decision
        )
    }

    private func windowStart(for kind: SpeechWindowKind) -> TimeInterval {
        let activeStart = activeSegmentStart ?? ringBuffer.startTime

        switch kind {
        case .partial:
            return max(activeStart, ringBuffer.endTime - configuration.partialWindowSeconds)
        case .final:
            return activeStart
        }
    }

    private mutating func finishSegment() {
        currentSegmentIndex += 1
        activeSegmentStart = nil
        lastPartialTime = nil
        revision = 0
    }

    private mutating func rollToNextSegment(at time: TimeInterval) {
        currentSegmentIndex += 1
        activeSegmentStart = max(0, time - configuration.preRollSeconds)
        lastPartialTime = nil
        revision = 0
    }
}
