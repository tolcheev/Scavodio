import Foundation

struct AudioTrack: Identifiable, Hashable {
    let id: UUID = UUID()

    // Absolute stream index from ffprobe (display only)
    let streamIndex: Int

    // Index among audio streams, 0-based — used for `ffmpeg -map 0:a:N`
    let audioIndex: Int

    let codecName: String
    let language: String?
    let bitRate: String?
    let title: String?

    var displayName: String {
        var parts: [String] = []
        parts.append("Track \(audioIndex)")
        if let lang = language, !lang.isEmpty { parts.append("[\(lang)]") }
        parts.append(codecName.uppercased())
        if let br = bitRate, let bps = Int(br), bps > 0 {
            parts.append("\(bps / 1000) kbps")
        }
        if let t = title, !t.isEmpty { parts.append("\u{201C}\(t)\u{201D}") }
        return parts.joined(separator: " \u{00B7} ")
    }
}
