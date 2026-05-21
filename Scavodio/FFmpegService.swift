import Foundation

// MARK: - Errors

enum FFmpegError: LocalizedError {
    case binaryNotFound(String)
    case probeFailed(String)
    case jsonParseError(String)
    case noAudioTracks
    case extractionFailed(String)
    case processLaunchFailed(String)
    case extractionCancelled

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
            return "Extraction failed: \(msg)"
        case .processLaunchFailed(let msg):
            return "Process launch failed: \(msg)"
        case .extractionCancelled:
            return nil // Handled by the caller — not shown as an error
        }
    }
}

// MARK: - Export format

enum ExportFormat: String, CaseIterable, Identifiable {
    case mp3  = "MP3"
    case mka  = "MKA (copy)"
    case aac  = "AAC"
    case m4a  = "M4A"
    case ogg  = "OGG"
    case flac = "FLAC"
    case opus = "Opus"

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .mp3:  return "mp3"
        case .mka:  return "mka"
        case .aac:  return "aac"
        case .m4a:  return "m4a"
        case .ogg:  return "ogg"
        case .flac: return "flac"
        case .opus: return "opus"
        }
    }
}

// MARK: - Service

final class FFmpegService: ObservableObject {

    // MARK: - Published state

    @Published private(set) var ffmpegPath:     String?
    @Published private(set) var ffprobePath:    String?
    /// Non-nil while ffmpeg extraction is running. Used by UI for the Cancel button.
    @Published private(set) var currentProcess: Process?

    // MARK: - Configuration

    /// Default Homebrew + system install paths.
    static let defaultSearchDirs: [String] = ["/opt/homebrew/bin", "/usr/local/bin"]

    private let searchDirs: [String]

    // MARK: - Init

    /// - Parameter searchDirs: Directories to search for `ffmpeg`, `ffprobe`, and `brew`.
    ///   Defaults to `FFmpegService.defaultSearchDirs`.
    ///   Pass a custom value in tests to avoid touching the real filesystem.
    init(searchDirs: [String] = FFmpegService.defaultSearchDirs) {
        self.searchDirs = searchDirs
        recheckBinaries()
    }

    // MARK: - Binary detection

    var isMissing: Bool { ffmpegPath == nil || ffprobePath == nil }

    var missingBinaries: [String] {
        var missing: [String] = []
        if ffmpegPath  == nil { missing.append("ffmpeg")  }
        if ffprobePath == nil { missing.append("ffprobe") }
        return missing
    }

    private func findBinary(_ name: String) -> String? {
        searchDirs
            .map  { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func recheckBinaries() {
        ffmpegPath  = findBinary("ffmpeg")
        ffprobePath = findBinary("ffprobe")
    }

    // MARK: - Install ffmpeg via brew (async)

    func installFFmpeg(
        logHandler: @escaping (String) -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        guard let brewPath = searchDirs
            .map({ "\($0)/brew" })
            .first(where: { FileManager.default.isExecutableFile(atPath: $0) })
        else {
            DispatchQueue.main.async {
                logHandler("Homebrew not found.\n")
                logHandler("Install it first from https://brew.sh\n")
                completion(false)
            }
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: brewPath)
        process.arguments     = ["install", "ffmpeg"]

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

        process.terminationHandler = { [weak self] proc in
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self?.recheckBinaries()
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

    // MARK: - Probe (blocking — must be called on a background thread)

    /// Runs `ffprobe` and returns detected audio tracks.
    ///
    /// - Parameter url: Path to the video file.
    /// - Throws: `FFmpegError` on failure or timeout (30 s).
    func probeAudioTracks(at url: URL) throws -> [AudioTrack] {
        guard let ffprobePath = ffprobePath else {
            throw FFmpegError.binaryNotFound("ffprobe")
        }

        let runner = ProcessRunner(
            executableURL: URL(fileURLWithPath: ffprobePath),
            arguments: [
                "-v", "error",
                "-select_streams", "a",
                "-show_entries", "stream=index,codec_name,bit_rate:stream_tags=language,title",
                "-of", "json",
                url.path,
            ],
            timeout: 30
        )

        do {
            let data = try runner.run()
            return try parseProbeJSON(data)
        } catch let failure as ProcessRunner.Failure {
            throw FFmpegError.probeFailed(failure.localizedDescription)
        }
    }

    // MARK: - Parse JSON
    //
    // `internal` (not private) so it is accessible in unit tests via @testable import.

    func parseProbeJSON(_ data: Data) throws -> [AudioTrack] {
        guard
            let root    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let streams = root["streams"] as? [[String: Any]]
        else {
            throw FFmpegError.jsonParseError("Could not parse ffprobe JSON output")
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

    // MARK: - Extract (async, non-blocking)

    /// Starts ffmpeg extraction asynchronously.
    ///
    /// Sets `currentProcess` while running; cleared on completion or cancellation.
    /// - Note: Must be called on the **main thread**.
    func extractAudio(
        from inputURL:  URL,
        track:          AudioTrack,
        format:         ExportFormat,
        outputURL:      URL,
        logHandler:     @escaping (String) -> Void,
        completion:     @escaping (Result<Void, Error>) -> Void
    ) {
        guard let ffmpegPath = ffmpegPath else {
            completion(.failure(FFmpegError.binaryNotFound("ffmpeg")))
            return
        }

        var args: [String] = ["-y", "-i", inputURL.path, "-map", "0:a:\(track.audioIndex)"]
        switch format {
        case .mp3:  args += ["-vn", "-c:a", "libmp3lame", "-q:a", "2", "-threads", "0"]
        case .mka:  args += ["-c", "copy"]
        case .aac:  args += ["-vn", "-c:a", "aac", "-b:a", "192k"]
        case .m4a:
            // Copy-remux when source is already AAC; otherwise encode to AAC
            if track.codecName.lowercased() == "aac" {
                args += ["-vn", "-c", "copy"]
            } else {
                args += ["-vn", "-c:a", "aac", "-b:a", "192k"]
            }
        case .ogg:  args += ["-vn", "-c:a", "libvorbis", "-q:a", "5"]
        case .flac: args += ["-vn", "-c:a", "flac"]
        case .opus: args += ["-vn", "-c:a", "libopus", "-b:a", "128k"]
        }
        args.append(outputURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments     = args

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { logHandler(text) }
        }

        process.terminationHandler = { [weak self] proc in
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                self?.currentProcess = nil
                if proc.terminationStatus == 0 {
                    completion(.success(()))
                } else if proc.terminationReason == .uncaughtSignal {
                    // Killed by cancelExtraction() — not an error from the user's perspective
                    completion(.failure(FFmpegError.extractionCancelled))
                } else {
                    completion(.failure(
                        FFmpegError.extractionFailed("Exit code \(proc.terminationStatus)")
                    ))
                }
            }
        }

        do {
            try process.run()
            currentProcess = process // Set on main thread — safe for @Published
        } catch {
            completion(.failure(FFmpegError.processLaunchFailed(error.localizedDescription)))
        }
    }

    // MARK: - Cancel

    /// Terminates the running ffmpeg process, if any.
    /// The `extractAudio` completion will be called with `.failure(.extractionCancelled)`.
    func cancelExtraction() {
        currentProcess?.terminate()
        // currentProcess will be cleared by terminationHandler
    }
}
