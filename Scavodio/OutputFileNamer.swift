import Foundation

/// Constructs safe output file URLs for extracted audio tracks.
///
/// Handles:
/// - Forbidden filesystem characters
/// - HFS+ filename limit (255 UTF-8 bytes)
/// - Empty components
enum OutputFileNamer {

    // MARK: - Constants

    /// Characters forbidden in filenames on macOS HFS+ and common cross-platform targets.
    private static let forbidden = CharacterSet(charactersIn: "/:\\*?\"<>|\0")

    /// Maximum UTF-8 bytes for a single filename component before joining.
    private static let maxComponentBytes = 64

    // MARK: - Public API

    /// Builds the output URL next to the input file.
    ///
    /// Format: `{BaseName}_audio{N}[_{lang}]_{codec}.{ext}`
    ///
    /// - Parameters:
    ///   - input:      URL of the source video file.
    ///   - audioIndex: 0-based index among audio streams (used in ffmpeg `-map 0:a:N`).
    ///   - language:   Optional BCP-47 language tag from ffprobe metadata.
    ///   - codecName:  Codec name from ffprobe (e.g. "aac", "ac3").
    ///   - format:     Export format that determines the file extension.
    static func makeURL(
        input:      URL,
        audioIndex: Int,
        language:   String?,
        codecName:  String,
        format:     ExportFormat
    ) -> URL {
        let base = sanitize(input.deletingPathExtension().lastPathComponent)

        var parts = [base.isEmpty ? "audio" : base,
                     "audio\(audioIndex)"]
        if let lang = language, !lang.isEmpty { parts.append(sanitize(lang)) }
        parts.append(sanitize(codecName.isEmpty ? "track" : codecName))

        let stem     = parts.joined(separator: "_")
        let filename = truncated(stem: stem, ext: format.fileExtension)

        return input.deletingLastPathComponent().appendingPathComponent(filename)
    }

    // MARK: - Helpers

    /// Removes forbidden characters and truncates to `maxComponentBytes`.
    static func sanitize(_ s: String) -> String {
        let cleaned = s.unicodeScalars
            .filter { !forbidden.contains($0) }
            .map(String.init)
            .joined()
        // Truncate to byte limit while keeping valid UTF-8
        return byteTruncated(cleaned, maxBytes: maxComponentBytes)
    }

    /// Produces `stem.ext` such that the full string fits in 255 UTF-8 bytes (HFS+ limit).
    private static func truncated(stem: String, ext: String) -> String {
        let dot     = "."
        let maxStem = 255 - dot.utf8.count - ext.utf8.count
        guard maxStem > 0 else { return "output.\(ext)" }
        let s = byteTruncated(stem, maxBytes: maxStem)
        return s.isEmpty ? "output.\(ext)" : "\(s).\(ext)"
    }

    /// Truncates a UTF-8 string to at most `maxBytes` bytes without splitting multi-byte characters.
    private static func byteTruncated(_ s: String, maxBytes: Int) -> String {
        guard s.utf8.count > maxBytes else { return s }
        var result = s
        while result.utf8.count > maxBytes, !result.isEmpty {
            result = String(result.dropLast())
        }
        return result
    }
}
