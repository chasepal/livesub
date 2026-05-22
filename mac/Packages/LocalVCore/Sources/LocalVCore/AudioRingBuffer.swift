import Foundation

public struct AudioRingBuffer: Sendable {
    public private(set) var sampleRate: Int
    public private(set) var capacitySeconds: TimeInterval
    public private(set) var samples: [Float] = []
    public private(set) var startTime: TimeInterval = 0

    public init(sampleRate: Int = 16_000, capacitySeconds: TimeInterval = 60) {
        precondition(sampleRate > 0, "sampleRate must be positive")
        precondition(capacitySeconds > 0, "capacitySeconds must be positive")
        self.sampleRate = sampleRate
        self.capacitySeconds = capacitySeconds
    }

    public var capacitySamples: Int {
        max(1, Int((capacitySeconds * TimeInterval(sampleRate)).rounded(.down)))
    }

    public var duration: TimeInterval {
        TimeInterval(samples.count) / TimeInterval(sampleRate)
    }

    public var endTime: TimeInterval {
        startTime + duration
    }

    public mutating func append(_ chunk: AudioChunk) {
        let mono = chunk.monoDownmixed()
        precondition(mono.sampleRate == sampleRate, "AudioRingBuffer requires a consistent sample rate")

        if samples.isEmpty {
            startTime = mono.startTime
        } else if mono.startTime > endTime {
            let gapSamples = sampleOffset(at: mono.startTime, from: endTime)
            if gapSamples > 0 {
                samples.append(contentsOf: repeatElement(Float(0), count: gapSamples))
            }
        }

        samples.append(contentsOf: mono.samples)
        trimToCapacity()
    }

    public func recent(seconds: TimeInterval) -> AudioChunk {
        let requestedSamples = max(0, Int((seconds * TimeInterval(sampleRate)).rounded(.down)))
        let count = min(requestedSamples, samples.count)
        let suffix = Array(samples.suffix(count))
        let chunkStart = endTime - TimeInterval(count) / TimeInterval(sampleRate)

        return AudioChunk(
            samples: suffix,
            sampleRate: sampleRate,
            channelCount: 1,
            startTime: chunkStart
        )
    }

    public func slice(from requestedStart: TimeInterval, to requestedEnd: TimeInterval) -> AudioChunk {
        let lower = max(requestedStart, startTime)
        let upper = min(requestedEnd, endTime)

        guard upper > lower else {
            return AudioChunk(samples: [], sampleRate: sampleRate, channelCount: 1, startTime: lower)
        }

        let startIndex = max(0, sampleOffset(at: lower, from: startTime))
        let endIndex = min(samples.count, sampleOffset(at: upper, from: startTime))

        guard endIndex > startIndex else {
            return AudioChunk(samples: [], sampleRate: sampleRate, channelCount: 1, startTime: lower)
        }

        return AudioChunk(
            samples: Array(samples[startIndex..<endIndex]),
            sampleRate: sampleRate,
            channelCount: 1,
            startTime: lower
        )
    }

    private func sampleOffset(at time: TimeInterval, from origin: TimeInterval) -> Int {
        let raw = (time - origin) * TimeInterval(sampleRate)
        return Int((raw + 0.000_001).rounded(.down))
    }

    private mutating func trimToCapacity() {
        let overflow = samples.count - capacitySamples
        guard overflow > 0 else {
            return
        }

        samples.removeFirst(overflow)
        startTime += TimeInterval(overflow) / TimeInterval(sampleRate)
    }
}

