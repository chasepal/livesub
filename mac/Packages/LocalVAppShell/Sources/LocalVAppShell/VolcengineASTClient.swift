import Foundation
import LocalVCore

enum VolcengineASTEvent: Sendable {
    case connected
    case sessionStarted
    case sourceSubtitle(CloudSubtitle)
    case translationSubtitle(CloudSubtitle)
    case usage(CloudUsage)
    case finished
    case failed(String)
    case log(String)
}

struct CloudSubtitle: Sendable {
    enum Phase: Equatable, Sendable {
        case start
        case partial
        case final
    }

    var phase: Phase
    var text: String
    var startTime: TimeInterval?
    var endTime: TimeInterval?
}

struct CloudUsage: Sendable {
    var audioDurationMilliseconds: Int64
    var tokenQuantities: [String: Float]

    var estimatedCNY: Double {
        let totalTokens = tokenQuantities.values.reduce(Float(0), +)
        return Double(totalTokens) * 80.0 / 1_000_000.0
    }
}

actor VolcengineASTClient {
    private enum EventType {
        static let startSession = 100
        static let finishSession = 102
        static let sessionStarted = 150
        static let sessionFinished = 152
        static let sessionFailed = 153
        static let usageResponse = 154
        static let taskRequest = 200
        static let audioMuted = 250
        static let sourceSubtitleStart = 650
        static let sourceSubtitleResponse = 651
        static let sourceSubtitleEnd = 652
        static let translationSubtitleStart = 653
        static let translationSubtitleResponse = 654
        static let translationSubtitleEnd = 655
    }

    private enum Constants {
        static let endpoint = URL(string: "wss://openspeech.bytedance.com/api/v4/ast/v2/translate")!
        static let resourceID = "volc.service_type.10053"
        static let inputSampleRate = 16_000
        static let frameBytes = 2_560 // 80ms * 16kHz * 16-bit mono
    }

    private let eventHandler: @Sendable (VolcengineASTEvent) -> Void
    private var session: URLSession?
    private var webSocket: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var startupTimeoutTask: Task<Void, Never>?
    private var startedContinuation: CheckedContinuation<Void, Error>?
    private var sessionID = UUID().uuidString
    private var connectionID = UUID().uuidString
    private var sequence = 0
    private var pcmBuffer = Data()
    private var isStarted = false
    private var authModeDescription = "unknown"

    init(eventHandler: @escaping @Sendable (VolcengineASTEvent) -> Void) {
        self.eventHandler = eventHandler
    }

    func start(
        credentials: VolcengineCredentials,
        sourceLanguage: String = "en",
        targetLanguage: String = "zh",
        timeoutSeconds: TimeInterval = 30
    ) async throws {
        sessionID = UUID().uuidString
        connectionID = UUID().uuidString
        sequence = 0
        pcmBuffer.removeAll(keepingCapacity: true)
        isStarted = false

        var request = URLRequest(url: Constants.endpoint)
        let apiKey = credentials.appKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessToken = credentials.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if accessToken.isEmpty {
            authModeDescription = "X-Api-Key"
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        } else {
            authModeDescription = "X-Api-App-Key + X-Api-Access-Key"
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-App-Key")
            request.setValue(accessToken, forHTTPHeaderField: "X-Api-Access-Key")
        }
        request.setValue(Constants.resourceID, forHTTPHeaderField: "X-Api-Resource-Id")
        request.setValue(connectionID, forHTTPHeaderField: "X-Api-Connect-Id")

        let session = URLSession(configuration: .default)
        self.session = session
        let webSocket = session.webSocketTask(with: request)
        self.webSocket = webSocket
        webSocket.resume()
        eventHandler(.log("Cloud AST connecting with \(authModeDescription), resource \(Constants.resourceID)."))

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            startedContinuation = continuation
            startupTimeoutTask?.cancel()
            startupTimeoutTask = Task { [weak self] in
                let nanoseconds = UInt64(max(1, timeoutSeconds) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                await self?.failStartupAfterTimeout(seconds: timeoutSeconds)
            }
            sendStartSession(
                credentials: credentials,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        }
    }

    func send(_ chunk: AudioChunk) async {
        guard isStarted else { return }

        let mono = chunk.monoDownmixed()
        guard mono.sampleRate == Constants.inputSampleRate else {
            eventHandler(.log("Cloud AST skipped non-16kHz audio chunk: \(mono.sampleRate)Hz"))
            return
        }

        pcmBuffer.append(Self.pcm16Data(from: mono.samples))

        while pcmBuffer.count >= Constants.frameBytes {
            let frame = pcmBuffer.prefix(Constants.frameBytes)
            pcmBuffer.removeFirst(Constants.frameBytes)
            await sendTaskRequest(audioBytes: Data(frame))
        }
    }

    func stop() async {
        startupTimeoutTask?.cancel()
        startupTimeoutTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        if isStarted {
            await sendFinishSession()
        }
        isStarted = false
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session?.invalidateAndCancel()
        session = nil

        if let continuation = startedContinuation {
            startedContinuation = nil
            continuation.resume(throwing: AppError.translationFailed("Cloud AST stopped before the session was ready"))
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard let webSocket else {
                return
            }

            do {
                let message = try await webSocket.receive()
                let data: Data
                switch message {
                case .data(let value):
                    data = value
                case .string(let value):
                    data = Data(value.utf8)
                @unknown default:
                    continue
                }
                handleServerMessage(data)
            } catch {
                guard !Task.isCancelled else { return }
                let message = Self.describeNetworkError(error, authMode: authModeDescription)
                failStartupIfNeeded(message)
                eventHandler(.failed(message))
                return
            }
        }
    }

    private func sendStartSession(
        credentials: VolcengineCredentials,
        sourceLanguage: String,
        targetLanguage: String
    ) {
        let meta = ProtobufWriter.message {
            $0.writeString(field: 1, value: Constants.resourceID)
            $0.writeString(field: 2, value: credentials.appKey)
            $0.writeString(field: 4, value: Constants.resourceID)
            $0.writeString(field: 5, value: connectionID)
            $0.writeString(field: 6, value: sessionID)
            $0.writeInt32(field: 7, value: nextSequence())
        }

        let sourceAudio = ProtobufWriter.message {
            $0.writeString(field: 4, value: "pcm")
            $0.writeString(field: 5, value: "raw")
            $0.writeInt32(field: 7, value: Constants.inputSampleRate)
            $0.writeInt32(field: 8, value: 16)
            $0.writeInt32(field: 9, value: 1)
        }

        let request = ProtobufWriter.message {
            $0.writeString(field: 1, value: "s2t")
            $0.writeString(field: 2, value: sourceLanguage)
            $0.writeString(field: 3, value: targetLanguage)
        }

        let payload = ProtobufWriter.message {
            $0.writeMessage(field: 1, value: meta)
            $0.writeInt32(field: 2, value: EventType.startSession)
            $0.writeMessage(field: 4, value: sourceAudio)
            $0.writeMessage(field: 6, value: request)
            $0.writeBool(field: 7, value: true)
        }

        sendData(payload)
        eventHandler(.connected)
    }

    private func sendTaskRequest(audioBytes: Data) async {
        let meta = ProtobufWriter.message {
            $0.writeString(field: 5, value: connectionID)
            $0.writeString(field: 6, value: sessionID)
            $0.writeInt32(field: 7, value: nextSequence())
        }
        let sourceAudio = ProtobufWriter.message {
            $0.writeBytes(field: 14, value: audioBytes)
        }
        let payload = ProtobufWriter.message {
            $0.writeMessage(field: 1, value: meta)
            $0.writeInt32(field: 2, value: EventType.taskRequest)
            $0.writeMessage(field: 4, value: sourceAudio)
        }
        sendData(payload)
    }

    private func sendFinishSession() async {
        let meta = ProtobufWriter.message {
            $0.writeString(field: 5, value: connectionID)
            $0.writeString(field: 6, value: sessionID)
            $0.writeInt32(field: 7, value: nextSequence())
        }
        let payload = ProtobufWriter.message {
            $0.writeMessage(field: 1, value: meta)
            $0.writeInt32(field: 2, value: EventType.finishSession)
        }
        sendData(payload)
    }

    private func sendData(_ data: Data) {
        guard let webSocket else { return }
        Task {
            do {
                try await webSocket.send(.data(data))
            } catch {
                let message = Self.describeNetworkError(error, authMode: self.authModeDescription)
                self.failStartupIfNeeded(message)
                self.eventHandler(.failed("Cloud AST send failed: \(message)"))
            }
        }
    }

    private func handleServerMessage(_ data: Data) {
        do {
            let response = try VolcengineASTProto.decodeResponse(data)

            if let statusCode = response.statusCode,
               statusCode != 0,
               statusCode != 20_000_000 {
                let message = response.message ?? "Cloud AST status \(statusCode)"
                failStartupIfNeeded(message)
                eventHandler(.failed(message))
                return
            }

            switch response.event {
            case EventType.sessionStarted:
                isStarted = true
                startupTimeoutTask?.cancel()
                startupTimeoutTask = nil
                startedContinuation?.resume(returning: ())
                startedContinuation = nil
                eventHandler(.sessionStarted)
            case EventType.sessionFinished:
                isStarted = false
                eventHandler(.finished)
            case EventType.sessionFailed:
                let message = response.message ?? "Cloud AST session failed"
                failStartupIfNeeded(message)
                eventHandler(.failed(message))
            case EventType.sourceSubtitleStart:
                eventHandler(.sourceSubtitle(.init(
                    phase: .start,
                    text: response.text,
                    startTime: response.startTimeSeconds,
                    endTime: response.endTimeSeconds
                )))
            case EventType.sourceSubtitleResponse:
                eventHandler(.sourceSubtitle(.init(
                    phase: .partial,
                    text: response.text,
                    startTime: response.startTimeSeconds,
                    endTime: response.endTimeSeconds
                )))
            case EventType.sourceSubtitleEnd:
                eventHandler(.sourceSubtitle(.init(
                    phase: .final,
                    text: response.text,
                    startTime: response.startTimeSeconds,
                    endTime: response.endTimeSeconds
                )))
            case EventType.translationSubtitleStart:
                eventHandler(.translationSubtitle(.init(
                    phase: .start,
                    text: response.text,
                    startTime: response.startTimeSeconds,
                    endTime: response.endTimeSeconds
                )))
            case EventType.translationSubtitleResponse:
                eventHandler(.translationSubtitle(.init(
                    phase: .partial,
                    text: response.text,
                    startTime: response.startTimeSeconds,
                    endTime: response.endTimeSeconds
                )))
            case EventType.translationSubtitleEnd:
                eventHandler(.translationSubtitle(.init(
                    phase: .final,
                    text: response.text,
                    startTime: response.startTimeSeconds,
                    endTime: response.endTimeSeconds
                )))
            case EventType.usageResponse:
                if let usage = response.usage {
                    eventHandler(.usage(usage))
                }
            case EventType.audioMuted:
                break
            default:
                if response.event != 0 {
                    eventHandler(.log("Cloud AST event \(response.event)"))
                }
            }
        } catch {
            eventHandler(.log("Cloud AST parse failed: \(error)"))
        }
    }

    private func failStartupIfNeeded(_ message: String) {
        startupTimeoutTask?.cancel()
        startupTimeoutTask = nil
        if let continuation = startedContinuation {
            startedContinuation = nil
            continuation.resume(throwing: AppError.translationFailed(message))
        }
    }

    private func failStartupAfterTimeout(seconds: TimeInterval) {
        let message = "Cloud AST connection timed out after \(Int(seconds))s"
        failStartupIfNeeded(message)
        eventHandler(.failed(message))
    }

    private func nextSequence() -> Int {
        let value = sequence
        sequence += 1
        return value
    }

    private static func pcm16Data(from samples: [Float]) -> Data {
        var data = Data(capacity: samples.count * 2)
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            var value = Int16(clamped < 0 ? clamped * 32768 : clamped * 32767).littleEndian
            withUnsafeBytes(of: &value) { bytes in
                data.append(contentsOf: bytes)
            }
        }
        return data
    }

    private static func describeNetworkError(_ error: Error, authMode: String) -> String {
        let nsError = error as NSError
        var parts = [error.localizedDescription]
        if let failingURL = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
            parts.append("url=\(failingURL.absoluteString)")
        }
        parts.append("auth=\(authMode)")
        if nsError.domain == NSURLErrorDomain {
            parts.append("urlError=\(nsError.code)")
        }
        return parts.joined(separator: " | ")
    }
}

struct VolcengineASTResponse {
    var event: Int = 0
    var text: String = ""
    var startTimeMilliseconds: Int?
    var endTimeMilliseconds: Int?
    var statusCode: Int?
    var message: String?
    var usage: CloudUsage?

    var startTimeSeconds: TimeInterval? {
        startTimeMilliseconds.map { TimeInterval($0) / 1_000 }
    }

    var endTimeSeconds: TimeInterval? {
        endTimeMilliseconds.map { TimeInterval($0) / 1_000 }
    }
}

enum VolcengineASTProto {
    static func decodeResponse(_ data: Data) throws -> VolcengineASTResponse {
        var reader = ProtobufReader(data: data)
        var response = VolcengineASTResponse()

        while !reader.isAtEnd {
            let tag = try reader.readVarint()
            let field = Int(tag >> 3)
            let wireType = Int(tag & 7)
            switch field {
            case 1:
                response.apply(meta: try decodeResponseMeta(reader.readLengthDelimitedData()))
            case 2:
                response.event = Int(try reader.readVarint())
            case 4:
                response.text = try reader.readString()
            case 5:
                response.startTimeMilliseconds = Int(try reader.readVarint())
            case 6:
                response.endTimeMilliseconds = Int(try reader.readVarint())
            default:
                try reader.skip(wireType: wireType)
            }
        }

        return response
    }

    private static func decodeResponseMeta(_ data: Data) throws -> ResponseMeta {
        var reader = ProtobufReader(data: data)
        var meta = ResponseMeta()

        while !reader.isAtEnd {
            let tag = try reader.readVarint()
            let field = Int(tag >> 3)
            let wireType = Int(tag & 7)
            switch field {
            case 3:
                meta.statusCode = Int(try reader.readVarint())
            case 4:
                meta.message = try reader.readString()
            case 5:
                meta.usage = try decodeBilling(reader.readLengthDelimitedData())
            default:
                try reader.skip(wireType: wireType)
            }
        }

        return meta
    }

    private static func decodeBilling(_ data: Data) throws -> CloudUsage {
        var reader = ProtobufReader(data: data)
        var duration: Int64 = 0
        var quantities: [String: Float] = [:]

        while !reader.isAtEnd {
            let tag = try reader.readVarint()
            let field = Int(tag >> 3)
            let wireType = Int(tag & 7)
            switch field {
            case 1:
                let item = try decodeBillingItem(reader.readLengthDelimitedData())
                if !item.unit.isEmpty {
                    quantities[item.unit] = item.quantity
                }
            case 2:
                duration = Int64(try reader.readVarint())
            default:
                try reader.skip(wireType: wireType)
            }
        }

        return CloudUsage(audioDurationMilliseconds: duration, tokenQuantities: quantities)
    }

    private static func decodeBillingItem(_ data: Data) throws -> (unit: String, quantity: Float) {
        var reader = ProtobufReader(data: data)
        var unit = ""
        var quantity: Float = 0

        while !reader.isAtEnd {
            let tag = try reader.readVarint()
            let field = Int(tag >> 3)
            let wireType = Int(tag & 7)
            switch field {
            case 1:
                unit = try reader.readString()
            case 2:
                quantity = try reader.readFloat()
            default:
                try reader.skip(wireType: wireType)
            }
        }

        return (unit, quantity)
    }

    fileprivate struct ResponseMeta {
        var statusCode: Int?
        var message: String?
        var usage: CloudUsage?
    }
}

private extension VolcengineASTResponse {
    mutating func apply(meta: VolcengineASTProto.ResponseMeta) {
        statusCode = meta.statusCode
        message = meta.message
        usage = meta.usage
    }
}

struct ProtobufWriter {
    private var data = Data()

    static func message(_ build: (inout ProtobufWriter) -> Void) -> Data {
        var writer = ProtobufWriter()
        build(&writer)
        return writer.data
    }

    mutating func writeString(field: Int, value: String) {
        writeTag(field: field, wireType: 2)
        let bytes = Data(value.utf8)
        writeVarint(UInt64(bytes.count))
        data.append(bytes)
    }

    mutating func writeBytes(field: Int, value: Data) {
        writeTag(field: field, wireType: 2)
        writeVarint(UInt64(value.count))
        data.append(value)
    }

    mutating func writeMessage(field: Int, value: Data) {
        writeBytes(field: field, value: value)
    }

    mutating func writeInt32(field: Int, value: Int) {
        writeTag(field: field, wireType: 0)
        writeVarint(UInt64(value))
    }

    mutating func writeBool(field: Int, value: Bool) {
        writeTag(field: field, wireType: 0)
        writeVarint(value ? 1 : 0)
    }

    private mutating func writeTag(field: Int, wireType: Int) {
        writeVarint(UInt64((field << 3) | wireType))
    }

    private mutating func writeVarint(_ value: UInt64) {
        var value = value
        while value >= 0x80 {
            data.append(UInt8(value & 0x7F | 0x80))
            value >>= 7
        }
        data.append(UInt8(value))
    }
}

struct ProtobufReader {
    enum ReaderError: Error {
        case truncated
        case invalidUTF8
        case unsupportedWireType(Int)
    }

    private let bytes: [UInt8]
    private var offset = 0

    init(data: Data) {
        self.bytes = Array(data)
    }

    var isAtEnd: Bool {
        offset >= bytes.count
    }

    mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0

        while shift < 64 {
            guard offset < bytes.count else {
                throw ReaderError.truncated
            }
            let byte = bytes[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
        }

        throw ReaderError.truncated
    }

    mutating func readLengthDelimitedData() throws -> Data {
        let length = Int(try readVarint())
        guard offset + length <= bytes.count else {
            throw ReaderError.truncated
        }
        let slice = bytes[offset..<(offset + length)]
        offset += length
        return Data(slice)
    }

    mutating func readString() throws -> String {
        let data = try readLengthDelimitedData()
        guard let value = String(data: data, encoding: .utf8) else {
            throw ReaderError.invalidUTF8
        }
        return value
    }

    mutating func readFloat() throws -> Float {
        guard offset + 4 <= bytes.count else {
            throw ReaderError.truncated
        }
        var bits: UInt32 = 0
        for index in 0..<4 {
            bits |= UInt32(bytes[offset + index]) << UInt32(index * 8)
        }
        offset += 4
        return Float(bitPattern: bits)
    }

    mutating func skip(wireType: Int) throws {
        switch wireType {
        case 0:
            _ = try readVarint()
        case 1:
            try skipBytes(8)
        case 2:
            let length = Int(try readVarint())
            try skipBytes(length)
        case 5:
            try skipBytes(4)
        default:
            throw ReaderError.unsupportedWireType(wireType)
        }
    }

    private mutating func skipBytes(_ count: Int) throws {
        guard offset + count <= bytes.count else {
            throw ReaderError.truncated
        }
        offset += count
    }
}
