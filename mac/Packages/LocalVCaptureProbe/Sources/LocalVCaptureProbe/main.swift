import AudioToolbox
import CoreMedia
import Foundation
import LocalVCore
import ScreenCaptureKit

@main
struct LocalVCaptureProbe {
    static func main() async {
        do {
            let options = ProbeOptions(arguments: CommandLine.arguments)
            let content = try await ShareableContentLoader.load()

            if options.shouldListApplications {
                printApplications(content.applications)
                return
            }

            guard let display = content.displays.first else {
                throw ProbeError.noDisplayAvailable
            }

            guard let application = selectApplication(from: content.applications, matching: options.bundleIdentifier) else {
                printApplications(content.applications)
                throw ProbeError.applicationNotFound(options.bundleIdentifier)
            }

            print("Selected source: \(application.applicationName) (\(application.bundleIdentifier), pid \(application.processID))")
            print("Starting audio probe for \(options.durationSeconds) seconds...")
            print("Pipeline: ScreenCaptureKit -> Float PCM -> AudioRingBuffer -> Energy VAD")

            let probe = AudioProbe(
                sampleRate: options.sampleRate,
                ringCapacitySeconds: options.ringCapacitySeconds,
                partialWindowSeconds: options.partialWindowSeconds,
                partialIntervalSeconds: options.partialIntervalSeconds,
                preRollSeconds: options.preRollSeconds,
                maxSegmentSeconds: options.maxSegmentSeconds
            )
            let filter = SCContentFilter(
                display: display,
                including: [application],
                exceptingWindows: []
            )

            let configuration = SCStreamConfiguration()
            configuration.capturesAudio = true
            configuration.excludesCurrentProcessAudio = true
            configuration.sampleRate = options.sampleRate
            configuration.channelCount = 1
            configuration.width = 2
            configuration.height = 2
            configuration.queueDepth = 3
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            configuration.showsCursor = false

            let stream = SCStream(filter: filter, configuration: configuration, delegate: probe)
            let queue = DispatchQueue(label: "localv.capture-probe.audio")
            try stream.addStreamOutput(probe, type: .audio, sampleHandlerQueue: queue)
            try await stream.startCaptureAsync()

            try await Task.sleep(nanoseconds: UInt64(options.durationSeconds) * 1_000_000_000)

            try await stream.stopCaptureAsync()
            print(
                "Stopped. buffers=\(probe.audioBufferCount), samples=\(probe.audioSampleCount), extracted=\(probe.extractedSampleCount), ring=\(String(format: "%.2f", probe.ringDuration))s, speechTransitions=\(probe.speechTransitionCount)"
            )
        } catch {
            fputs("LocalVCaptureProbe error: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func selectApplication(
        from applications: [SCRunningApplication],
        matching bundleIdentifier: String
    ) -> SCRunningApplication? {
        applications.first { $0.bundleIdentifier == bundleIdentifier }
            ?? applications.first { $0.applicationName.localizedCaseInsensitiveContains("Chrome") }
    }

    private static func printApplications(_ applications: [SCRunningApplication]) {
        print("Shareable applications:")
        for application in applications.sorted(by: { $0.applicationName < $1.applicationName }) {
            print("- \(application.applicationName) | \(application.bundleIdentifier) | pid \(application.processID)")
        }
    }
}

struct ProbeOptions {
    var bundleIdentifier = "com.google.Chrome"
    var durationSeconds: Int = 10
    var sampleRate: Int = 16_000
    var ringCapacitySeconds: TimeInterval = 60
    var partialWindowSeconds: TimeInterval = 2.4
    var partialIntervalSeconds: TimeInterval = 0.45
    var preRollSeconds: TimeInterval = 0.2
    var maxSegmentSeconds: TimeInterval = 12
    var shouldListApplications = false

    init(arguments: [String]) {
        var iterator = arguments.dropFirst().makeIterator()

        while let argument = iterator.next() {
            switch argument {
            case "--list":
                shouldListApplications = true
            case "--bundle-id":
                if let value = iterator.next() {
                    bundleIdentifier = value
                }
            case "--duration":
                if let value = iterator.next(), let seconds = Int(value) {
                    durationSeconds = max(1, seconds)
                }
            case "--sample-rate":
                if let value = iterator.next(), let rate = Int(value) {
                    sampleRate = max(8_000, rate)
                }
            case "--ring-seconds":
                if let value = iterator.next(), let seconds = Double(value) {
                    ringCapacitySeconds = max(1, seconds)
                }
            case "--partial-window":
                if let value = iterator.next(), let seconds = Double(value) {
                    partialWindowSeconds = max(0.2, seconds)
                }
            case "--partial-interval":
                if let value = iterator.next(), let seconds = Double(value) {
                    partialIntervalSeconds = max(0.1, seconds)
                }
            case "--pre-roll":
                if let value = iterator.next(), let seconds = Double(value) {
                    preRollSeconds = max(0, seconds)
                }
            case "--max-segment":
                if let value = iterator.next(), let seconds = Double(value) {
                    maxSegmentSeconds = max(1, seconds)
                }
            case "--vad-window":
                if let value = iterator.next(), let seconds = Double(value) {
                    partialWindowSeconds = max(0.2, seconds)
                }
            default:
                break
            }
        }
    }
}

enum ProbeError: Error, CustomStringConvertible {
    case noDisplayAvailable
    case applicationNotFound(String)
    case shareableContentLoadFailed(String)
    case captureStartFailed(String)
    case captureStopFailed(String)

    var description: String {
        switch self {
        case .noDisplayAvailable:
            return "No display is available for ScreenCaptureKit filtering."
        case .applicationNotFound(let bundleIdentifier):
            return "Could not find a shareable application for bundle id \(bundleIdentifier). Open Chrome and try again."
        case .shareableContentLoadFailed(let message):
            return "Could not load ScreenCaptureKit shareable content: \(message)"
        case .captureStartFailed(let message):
            return "Could not start capture: \(message)"
        case .captureStopFailed(let message):
            return "Could not stop capture: \(message)"
        }
    }
}

enum ShareableContentLoader {
    static func load() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )
        } catch {
            throw ProbeError.shareableContentLoadFailed(error.localizedDescription)
        }
    }
}

final class AudioProbe: NSObject, SCStreamOutput, SCStreamDelegate {
    private(set) var audioBufferCount = 0
    private(set) var audioSampleCount = 0
    private(set) var extractedSampleCount = 0
    private(set) var ringDuration: TimeInterval = 0
    private(set) var speechTransitionCount = 0

    private var segmenter: StreamingAudioSegmenter
    private var firstAudioDate: Date?

    init(
        sampleRate: Int,
        ringCapacitySeconds: TimeInterval,
        partialWindowSeconds: TimeInterval,
        partialIntervalSeconds: TimeInterval,
        preRollSeconds: TimeInterval,
        maxSegmentSeconds: TimeInterval
    ) {
        let configuration = AudioSegmenterConfiguration(
            sampleRate: sampleRate,
            ringCapacitySeconds: ringCapacitySeconds,
            partialWindowSeconds: partialWindowSeconds,
            partialIntervalSeconds: partialIntervalSeconds,
            preRollSeconds: preRollSeconds,
            maxSegmentSeconds: maxSegmentSeconds
        )
        self.segmenter = StreamingAudioSegmenter(configuration: configuration)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid else {
            return
        }

        let sampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
        let startTime = TimeInterval(audioSampleCount) / TimeInterval(segmenter.configuration.sampleRate)
        audioBufferCount += 1
        audioSampleCount += sampleCount

        guard let chunk = AudioSampleExtractor.chunk(from: sampleBuffer, startTime: startTime) else {
            if firstAudioDate == nil {
                firstAudioDate = Date()
                print("First audio buffer received, but sample extraction failed. samples=\(sampleCount)")
            }
            return
        }

        firstAudioDate = firstAudioDate ?? Date()
        extractedSampleCount += chunk.frameCount

        let previousSpeech = segmenter.isSpeech
        let windows = segmenter.append(chunk)
        let decision = segmenter.lastDecision
        ringDuration = segmenter.ringBuffer.duration

        if segmenter.isSpeech != previousSpeech {
            speechTransitionCount += 1
            print("VAD transition: speech=\(segmenter.isSpeech), rms=\(String(format: "%.5f", decision.rms)), at=\(String(format: "%.2f", segmenter.ringBuffer.endTime))s")
        }

        for window in windows {
            print(
                "Speech window: kind=\(window.kind.rawValue), segment=\(window.segmentIndex), revision=\(window.revision), start=\(String(format: "%.2f", window.startTime))s, end=\(String(format: "%.2f", window.endTime))s, duration=\(String(format: "%.2f", window.duration))s, rms=\(String(format: "%.5f", window.decision.rms))"
            )
        }

        if audioBufferCount == 1 {
            print("First audio buffer extracted: samples=\(chunk.samples.count), frames=\(chunk.frameCount), format=\(chunk.sampleRate)Hz/\(chunk.channelCount)ch")
        }

        if audioBufferCount % 50 == 0 {
            print(
                "buffers=\(audioBufferCount), samples=\(audioSampleCount), extracted=\(extractedSampleCount), rms=\(String(format: "%.5f", decision.rms)), speech=\(segmenter.isSpeech), ring=\(String(format: "%.2f", segmenter.ringBuffer.duration))s"
            )
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        fputs("ScreenCaptureKit stream stopped with error: \(error)\n", stderr)
    }
}

enum AudioSampleExtractor {
    static func chunk(from sampleBuffer: CMSampleBuffer, startTime: TimeInterval) -> AudioChunk? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer),
              let streamDescriptionPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
        else {
            return nil
        }

        let streamDescription = streamDescriptionPointer.pointee
        guard streamDescription.mFormatID == kAudioFormatLinearPCM else {
            return nil
        }

        var blockBuffer: CMBlockBuffer?
        var audioBufferList = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(mNumberChannels: 1, mDataByteSize: 0, mData: nil)
        )

        let status = withUnsafeMutablePointer(to: &audioBufferList) { listPointer in
            CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                sampleBuffer,
                bufferListSizeNeededOut: nil,
                bufferListOut: listPointer,
                bufferListSize: MemoryLayout<AudioBufferList>.size,
                blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault,
                flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                blockBufferOut: &blockBuffer
            )
        }

        guard status == noErr,
              let data = audioBufferList.mBuffers.mData
        else {
            return nil
        }

        let channelCount = max(1, Int(streamDescription.mChannelsPerFrame))
        let sampleRate = Int(streamDescription.mSampleRate.rounded())
        let bytesPerSample = max(1, Int(streamDescription.mBitsPerChannel / 8))
        let sampleCount = Int(audioBufferList.mBuffers.mDataByteSize) / bytesPerSample
        let flags = streamDescription.mFormatFlags

        let samples: [Float]
        if flags & kAudioFormatFlagIsFloat != 0 && streamDescription.mBitsPerChannel == 32 {
            let pointer = data.bindMemory(to: Float.self, capacity: sampleCount)
            samples = Array(UnsafeBufferPointer(start: pointer, count: sampleCount))
        } else if flags & kAudioFormatFlagIsSignedInteger != 0 && streamDescription.mBitsPerChannel == 16 {
            let pointer = data.bindMemory(to: Int16.self, capacity: sampleCount)
            samples = UnsafeBufferPointer(start: pointer, count: sampleCount).map { Float($0) / Float(Int16.max) }
        } else if flags & kAudioFormatFlagIsSignedInteger != 0 && streamDescription.mBitsPerChannel == 32 {
            let pointer = data.bindMemory(to: Int32.self, capacity: sampleCount)
            samples = UnsafeBufferPointer(start: pointer, count: sampleCount).map { Float($0) / Float(Int32.max) }
        } else {
            return nil
        }

        return AudioChunk(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: channelCount,
            startTime: startTime
        )
    }
}

extension SCStream {
    func startCaptureAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            startCapture { error in
                if let error {
                    continuation.resume(throwing: ProbeError.captureStartFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func stopCaptureAsync() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stopCapture { error in
                if let error {
                    continuation.resume(throwing: ProbeError.captureStopFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

