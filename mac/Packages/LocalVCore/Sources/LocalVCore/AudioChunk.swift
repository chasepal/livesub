import Foundation

public struct AudioChunk: Equatable, Sendable {
    public var samples: [Float]
    public var sampleRate: Int
    public var channelCount: Int
    public var startTime: TimeInterval

    public init(
        samples: [Float],
        sampleRate: Int = 16_000,
        channelCount: Int = 1,
        startTime: TimeInterval
    ) {
        precondition(sampleRate > 0, "sampleRate must be positive")
        precondition(channelCount > 0, "channelCount must be positive")
        self.samples = samples
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.startTime = startTime
    }

    public var frameCount: Int {
        samples.count / channelCount
    }

    public var duration: TimeInterval {
        TimeInterval(frameCount) / TimeInterval(sampleRate)
    }

    public var endTime: TimeInterval {
        startTime + duration
    }

    public var rootMeanSquare: Float {
        guard !samples.isEmpty else {
            return 0
        }

        let sum = samples.reduce(Float(0)) { partial, sample in
            partial + sample * sample
        }

        return sqrt(sum / Float(samples.count))
    }

    public func monoDownmixed() -> AudioChunk {
        guard channelCount > 1 else {
            return self
        }

        var mono: [Float] = []
        mono.reserveCapacity(frameCount)

        for frameIndex in 0..<frameCount {
            let offset = frameIndex * channelCount
            let frameSum = samples[offset..<(offset + channelCount)].reduce(Float(0), +)
            mono.append(frameSum / Float(channelCount))
        }

        return AudioChunk(
            samples: mono,
            sampleRate: sampleRate,
            channelCount: 1,
            startTime: startTime
        )
    }
}

