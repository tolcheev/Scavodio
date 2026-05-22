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
            return "\(name) is not installed. Use the \"Install ffmpeg\" button to set it up."
        case .probeFailed:
            return "Couldn't read this file's audio tracks. It may be corrupt or access may be blocked."
        case .jsonParseError:
            return "Couldn't read audio track info — the file may be corrupt or in an unsupported format."
        case .noAudioTracks:
            return "No audio tracks found. This file may be video-only."
        case .extractionFailed:
            return "Extraction failed — expand the log below for details."
        case .processLaunchFailed:
            return "Couldn't launch ffmpeg. Try reinstalling it: brew reinstall ffmpeg"
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

        // Pre-check readability before spawning ffprobe — gives a cleaner error
        // than a cryptic "exit 1" when macOS TCC blocks the file.
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw FFmpegError.probeFailed("Permission denied: \(url.lastPathComponent)")
        }

        let runner = ProcessRunner(
            executableURL: URL(fileURLWithPath: ffprobePath),
            arguments: [
                "-v", "error",
                "-select_streams", "a",
                "-show_entries", "stream=index,codec_name,bit_rate,duration:stream_tags=language,title",
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
            let durStr = stream["duration"] as? String
            let duration: TimeInterval? = durStr.flatMap(Double.init).flatMap { $0 > 0 ? $0 : nil }
            tracks.append(AudioTrack(
                streamIndex: stream["index"] as? Int ?? audioIndex,
                audioIndex:  audioIndex,
                codecName:   stream["codec_name"] as? String ?? "unknown",
                language:    (stream["tags"] as? [String: String])?["language"],
                bitRate:     stream["bit_rate"] as? String,
                title:       (stream["tags"] as? [String: String])?["title"],
                duration:    duration
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
        // Encoding formats — -threads 0 lets ffmpeg use all available CPU cores.
        case .mp3:  args += ["-vn", "-c:a", "libmp3lame", "-q:a", "2",  "-threads", "0"]
        case .aac:  args += ["-vn", "-c:a", "aac",        "-b:a", "192k", "-threads", "0"]
        case .m4a:
            // Copy-remux when source is already AAC; otherwise encode to AAC
            if track.codecName.lowercased() == "aac" {
                args += ["-vn", "-c", "copy"]
            } else {
                args += ["-vn", "-c:a", "aac", "-b:a", "192k", "-threads", "0"]
            }
        case .ogg:  args += ["-vn", "-c:a", "libvorbis", "-q:a", "5",   "-threads", "0"]
        case .flac: args += ["-vn", "-c:a", "flac",                      "-threads", "0"]
        case .opus: args += ["-vn", "-c:a", "libopus",   "-b:a", "128k", "-threads", "0"]
        // Lossless remux — copy is already instant, no threads needed
        case .mka:  args += ["-c", "copy"]
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

    // MARK: - Split extraction (async, non-blocking)

    /// Extracts an audio track split into multiple parts of `partDuration` seconds each.
    ///
    /// Runs ffmpeg sequentially for every part; calls `partProgress` before each part starts.
    /// Must be called on the **main thread**.
    func extractAudioParts(
        from inputURL:   URL,
        track:           AudioTrack,
        format:          ExportFormat,
        partDuration:    TimeInterval,          // seconds per part
        baseOutputURL:   URL,                   // part suffixes are added automatically
        logHandler:      @escaping (String) -> Void,
        partProgress:    @escaping (Int, Int) -> Void,  // (currentPart, totalParts)
        completion:      @escaping (Result<[URL], Error>) -> Void
    ) {
        guard let ffmpegPath = ffmpegPath else {
            completion(.failure(FFmpegError.binaryNotFound("ffmpeg")))
            return
        }

        let totalDuration = track.duration ?? partDuration
        let partCount     = max(1, Int(ceil(totalDuration / partDuration)))

        // Build output URLs: strip extension, add _part01.ext etc.
        let dir  = baseOutputURL.deletingLastPathComponent()
        let ext  = baseOutputURL.pathExtension
        let stem = baseOutputURL.deletingPathExtension().lastPathComponent

        let outputURLs: [URL] = (0..<partCount).map { i in
            let suffix = String(format: "_part%02d", i + 1)
            return dir.appendingPathComponent("\(stem)\(suffix).\(ext)")
        }

        // Run parts sequentially
        runPart(
            index:      0,
            total:      partCount,
            inputURL:   inputURL,
            track:      track,
            format:     format,
            partDuration: partDuration,
            outputURLs: outputURLs,
            ffmpegPath: ffmpegPath,
            logHandler: logHandler,
            partProgress: partProgress,
            accumulated: [],
            completion:  completion
        )
    }

    private func runPart(
        index:        Int,
        total:        Int,
        inputURL:     URL,
        track:        AudioTrack,
        format:       ExportFormat,
        partDuration: TimeInterval,
        outputURLs:   [URL],
        ffmpegPath:   String,
        logHandler:   @escaping (String) -> Void,
        partProgress: @escaping (Int, Int) -> Void,
        accumulated:  [URL],
        completion:   @escaping (Result<[URL], Error>) -> Void
    ) {
        guard index < total else {
            completion(.success(accumulated))
            return
        }

        partProgress(index + 1, total)

        let startSec = Double(index) * partDuration
        let outputURL = outputURLs[index]

        var args: [String] = [
            "-y",
            "-i", inputURL.path,
            "-map", "0:a:\(track.audioIndex)",
            "-ss", String(format: "%.3f", startSec),
            "-t",  String(format: "%.3f", partDuration),
        ]
        switch format {
        case .mp3:  args += ["-vn", "-c:a", "libmp3lame", "-q:a", "2",    "-threads", "0"]
        case .mka:  args += ["-c", "copy"]
        case .aac:  args += ["-vn", "-c:a", "aac",        "-b:a", "192k", "-threads", "0"]
        case .m4a:
            args += track.codecName.lowercased() == "aac"
                ? ["-vn", "-c", "copy"]
                : ["-vn", "-c:a", "aac", "-b:a", "192k", "-threads", "0"]
        case .ogg:  args += ["-vn", "-c:a", "libvorbis", "-q:a", "5",    "-threads", "0"]
        case .flac: args += ["-vn", "-c:a", "flac",                       "-threads", "0"]
        case .opus: args += ["-vn", "-c:a", "libopus",   "-b:a", "128k", "-threads", "0"]
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
                if proc.terminationReason == .uncaughtSignal {
                    completion(.failure(FFmpegError.extractionCancelled))
                } else if proc.terminationStatus != 0 {
                    completion(.failure(FFmpegError.extractionFailed("Part \(index+1) exit code \(proc.terminationStatus)")))
                } else {
                    self?.runPart(
                        index:        index + 1,
                        total:        total,
                        inputURL:     inputURL,
                        track:        track,
                        format:       format,
                        partDuration: partDuration,
                        outputURLs:   outputURLs,
                        ffmpegPath:   ffmpegPath,
                        logHandler:   logHandler,
                        partProgress: partProgress,
                        accumulated:  accumulated + [outputURL],
                        completion:   completion
                    )
                }
            }
        }

        do {
            try process.run()
            currentProcess = process
        } catch {
            completion(.failure(FFmpegError.processLaunchFailed(error.localizedDescription)))
        }
    }
}
