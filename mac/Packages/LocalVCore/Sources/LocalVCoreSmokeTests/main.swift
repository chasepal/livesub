import Foundation
import LocalVCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Smoke test failed: \(message)\n", stderr)
        exit(1)
    }
}

func runSmokeTests() throws {
    let glossary = Glossary(
        terms: [
            GlossaryTerm(source: "SOL", shouldPreserve: true),
            GlossaryTerm(source: "airdrop", target: "空投")
        ]
    )
    let hint = glossary.promptHint()
    expect(hint.contains("Preserve SOL"), "glossary preserve hint")
    expect(hint.contains("airdrop => 空投"), "glossary translation hint")

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let manifest = SessionManifest(
        startedAt: Date(timeIntervalSince1970: 60 * 62),
        sourceKind: .chromeApp,
        sourceName: "Google Chrome",
        title: "X Space: SOL / HYPE?",
        mode: .live,
        models: .liveDefault,
        glossaryVersion: Glossary.cryptoSeed.version
    )
    expect(
        manifest.safeBaseFilename(calendar: calendar) == "01-02_Google-Chrome_X-Space-SOL-HYPE",
        "safe filename generation"
    )

    let partial = SubtitleSegment(
        sessionID: manifest.id,
        index: 1,
        state: .partial,
        startTime: 0,
        englishText: "this is hyperliquid",
        sourceName: "Google Chrome",
        mode: .live,
        models: .liveDefault
    )
    let final = partial.finalized(endTime: 2.4, englishText: "This is Hyperliquid.")
    let translated = final.translated("这是 Hyperliquid。")
    expect(final.state == .final, "segment final state")
    expect(translated.state == .translated, "segment translated state")
    expect(translated.id == partial.id, "segment id stability")

    let writer = TranscriptWriter()
    let line = try writer.jsonLine(for: translated)
    expect(line.hasSuffix("\n"), "jsonl newline")
    expect(line.contains("\"englishText\":\"This is Hyperliquid.\""), "jsonl english text")
    expect(line.contains("\"chineseText\":\"这是 Hyperliquid。\""), "jsonl chinese text")
    expect(TranscriptWriter.timestamp(3661) == "01:01:01", "timestamp formatting")
    expect(writer.markdownHeader(for: manifest).contains("# X Space: SOL / HYPE?"), "markdown header")
    expect(writer.markdownBlock(for: translated).contains("这是 Hyperliquid。"), "markdown block")

    let stereo = AudioChunk(
        samples: [0.2, 0.4, -0.2, -0.4],
        sampleRate: 16_000,
        channelCount: 2,
        startTime: 10
    )
    let mono = stereo.monoDownmixed()
    expect(mono.samples == [0.3, -0.3], "mono downmix")
    expect(abs(mono.duration - 0.000125) < 0.000001, "audio duration")

    var ring = AudioRingBuffer(sampleRate: 10, capacitySeconds: 1)
    ring.append(AudioChunk(samples: Array(repeating: 0.1, count: 8), sampleRate: 10, startTime: 0))
    ring.append(AudioChunk(samples: Array(repeating: 0.2, count: 8), sampleRate: 10, startTime: 0.8))
    expect(ring.samples.count == 10, "ring trims to capacity")
    expect(abs(ring.startTime - 0.6) < 0.000001, "ring advances start time")
    expect(ring.recent(seconds: 0.3).samples.count == 3, "recent audio window")
    expect(ring.slice(from: 1.0, to: 1.3).samples.count == 3, "audio slice")

    let vad = EnergyVoiceActivityDetector(
        speechThreshold: 0.05,
        silenceThreshold: 0.02,
        minimumSpeechDuration: 0.1,
        minimumSilenceDuration: 0.1
    )
    let speech = vad.classify(AudioChunk(samples: Array(repeating: 0.08, count: 10), sampleRate: 100, startTime: 0))
    let silence = vad.classify(AudioChunk(samples: Array(repeating: 0.01, count: 10), sampleRate: 100, startTime: 0), wasSpeech: true)
    expect(speech.isSpeech, "vad detects speech")
    expect(!silence.isSpeech, "vad exits speech on silence")

    var streamingVAD = StreamingVoiceActivityDetector(configuration: vad)
    var streamingDecision = VoiceActivityDecision(isSpeech: false, rms: 0, threshold: 0)
    for index in 0..<2 {
        streamingDecision = streamingVAD.process(AudioChunk(
            samples: Array(repeating: 0.08, count: 5),
            sampleRate: 100,
            startTime: TimeInterval(index) * 0.05
        ))
    }
    expect(streamingDecision.isSpeech, "streaming vad enters speech after accumulated duration")

    for index in 0..<2 {
        streamingDecision = streamingVAD.process(AudioChunk(
            samples: Array(repeating: 0.01, count: 5),
            sampleRate: 100,
            startTime: 0.1 + TimeInterval(index) * 0.05
        ))
    }
    expect(!streamingDecision.isSpeech, "streaming vad exits speech after accumulated silence")

    let segmenterConfig = AudioSegmenterConfiguration(
        sampleRate: 100,
        ringCapacitySeconds: 2,
        partialWindowSeconds: 0.3,
        partialIntervalSeconds: 0.2,
        preRollSeconds: 0.05,
        maxSegmentSeconds: 1.0,
        voiceActivityDetector: vad
    )
    var segmenter = StreamingAudioSegmenter(configuration: segmenterConfig)
    var windows: [SpeechWindow] = []

    for index in 0..<6 {
        windows.append(contentsOf: segmenter.append(AudioChunk(
            samples: Array(repeating: 0.08, count: 5),
            sampleRate: 100,
            startTime: TimeInterval(index) * 0.05
        )))
    }

    for index in 0..<3 {
        windows.append(contentsOf: segmenter.append(AudioChunk(
            samples: Array(repeating: 0.01, count: 5),
            sampleRate: 100,
            startTime: 0.3 + TimeInterval(index) * 0.05
        )))
    }

    expect(windows.contains { $0.kind == .partial }, "segmenter emits partial window")
    expect(windows.contains { $0.kind == .final }, "segmenter emits final window")
    expect(segmenter.currentSegmentIndex == 1, "segmenter advances after final")
}

do {
    try runSmokeTests()
    print("LocalVCore smoke tests passed.")
} catch {
    fputs("Smoke test error: \(error)\n", stderr)
    exit(1)
}

