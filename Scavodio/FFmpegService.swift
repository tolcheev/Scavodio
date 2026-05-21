import Foundation

// MARK: - Errors

enum FFmpegError: LocalizedError {
    case binaryNotFound(String)
    case probeFailed(String)
    case jsonParseError(String)
    case noAudioTracks
    case extractionFailed(String)
    case processLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let name):
            return "\(name) not found. Install with:  brew install ffmpeg"
        case .probeFailed(let msg):
            return "ffprobe failed: \(msg)"
        case .jsonParseError(let msg):
            return "JSON parse error: \(msg)"
        case .noAudioTracks:
            return "No audio tracks found in this file."
        case .extractionFailed(let msg):
            return "ffmpeg failed: \(msg)"
        case .processLaunchFailed(let msg):
            return "Process launch failed: \(msg)"
        }
    }
}

// MARK: - Export format

enum ExportFormat: String, CaseIterable, Identifiable {
    case mka = "MKA (copy)"
    case mp3 = "MP3"
    case m4a = "M4A (AAC copy)"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .mka: return "mka"
        case .mp3: return "mp3"
        case .m4a: return "m4a"
        }
    }
}

// MARK: - Service

final class FFmpegService: ObservableObject {

    @Published private(set) var ffmpegPath:  String?
    @Published private(set) var ffprobePath: String?

    private let searchDirs = ["/opt/homebrew/bin", "/usr/local/bin"]

    init() { recheckBinaries() }

    // MARK: Binary detection

    var isMissing: Bool { ffmpegPath == nil || ffprobePath == nil }

    var missingBinaries: [String] {
        var m: [String] = []
        if ffmpegPath  == nil { m.append("ffmpeg")  }
        if ffprobePath == nil { m.append("ffprobe") }
        return m
    }

    private func findBinary(_ name: String) -> String? {
        searchDirs
            .map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func recheckBinaries() {
        ffmpegPath  = findBinary("ffmpeg")
        ffprobePath = findBinary("ffprobe")
    }

    // MARK: Install ffmpeg via brew

    func installFFmpeg(
        logHandler: @escaping (String) -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        guard let brew = searchDirs.map({ "\($0)/brew" })
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
        else {
            DispatchQueue.main.async {
                logHandler("Homebrew not found.\n")
                logHandler("Install from https://brew.sh first.\n")
                completion(false)
            }
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brew)
        process.arguments = ["install", "ffmpeg"]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError  = stderrPipe

        let readHandler: (FileHandle) -> Void = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { logHandler(text) }
        }
        stdoutPipe.fileHandleForReading.readabilityHandler = readHandler
        stderrPipe.fileHandleForReading.readabilityHandler = readHandler

        process.terminationHandler = { proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self.recheckBinaries()
                completion(proc.terminationStatus == 0)
            }
        }

        do {
            try process.run()
        } catch {
            DispatchQueue.main.async {
                logHandler("Failed to launch brew: \(error.localizedDescription)\n")
                completion(false)
            }
        }
    }

    // MARK: Probe (blocking — call on background thread)

    func probeAudioTracks(at url: URL) throws -> [AudioTrack] {
        guard let ffprobe = ffprobePath else {
            throw FFmpegError.binaryNotFound("ffprobe")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffprobe)
        process.arguments = [
            "-v", "error",
            "-select_streams", "a",
            "-show_entries", "stream=index,codec_name,bit_rate:stream_tags=language,title",
            "-of", "json",
            url.path
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError  = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw FFmpegError.processLaunchFailed(error.localizedDescription)
        }

        if process.terminationStatus != 0 {
            let msg = String(
                data: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? "unknown error"
            throw FFmpegError.probeFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return try parseProbeJSON(
            stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        )
    }

    private func parseProbeJSON(_ data: Data) throws -> [AudioTrack] {
        guard
            let root    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let streams = root["streams"] as? [[String: Any]]
        else {
            throw FFmpegError.jsonParseError("Could not parse ffprobe JSON")
        }

        var tracks: [AudioTrack] = []
        for (audioIndex, stream) in streams.enumerated() {
            tracks.append(AudioTrack(
                streamIndex: stream["index"] as? Int ?? audioIndex,
                audioIndex:  audioIndex,
                codecName:   stream["codec_name"] as? String ?? "unknown",
                language:    (stream["tags"] as? [String: String])?["language"],
                bitRate:     stream["bit_rate"] as? String,
                title:       (stream["tags"] as? [String: String])?["title"]
            ))
        }

        guard !tracks.isEmpty else { throw FFmpegError.noAudioTracks }
        return tracks
    }

    // MARK: Extract (async, non-blocking)

    func extractAudio(
        from inputURL:  URL,
        track:          AudioTrack,
        format:         ExportFormat,
        outputURL:      URL,
        logHandler:     @escaping (String) -> Void,
        completion:     @escaping (Result<Void, Error>) -> Void
    ) {
        guard let ffmpeg = ffmpegPath else {
            completion(.failure(FFmpegError.binaryNotFound("ffmpeg")))
            return
        }

        var args: [String] = ["-y", "-i", inputURL.path, "-map", "0:a:\(track.audioIndex)"]
        switch format {
        case .mka: args += ["-c", "copy"]
        case .mp3: args += ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]
        case .m4a: args += ["-vn", "-c", "copy"]
        }
        args.append(outputURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = args

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { logHandler(text) }
        }

        process.terminationHandler = { proc in
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                proc.terminationStatus == 0
                    ? completion(.success(()))
                    : completion(.failure(FFmpegError.extractionFailed("Exit code \(proc.terminationStatus)")))
            }
        }

        do { try process.run() }
        catch { completion(.failure(FFmpegError.processLaunchFailed(error.localizedDescription))) }
    }
}
