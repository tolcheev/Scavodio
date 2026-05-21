import Foundation
import UniformTypeIdentifiers

/// Video formats Scavodio can open (anything ffmpeg can demux).
enum SupportedFormats {

    static let extensions: Set<String> = [
        // Matroska / WebM
        "mkv", "webm",
        // MPEG-4 family
        "mp4", "m4v",
        // QuickTime / Apple
        "mov",
        // AVI
        "avi",
        // MPEG transport streams (camcorders, TV)
        "ts", "mts", "m2ts",
        // Legacy / other
        "flv", "wmv", "vob", "3gp", "ogv", "rmvb",
    ]

    static func isSupported(_ pathExtension: String) -> Bool {
        extensions.contains(pathExtension.lowercased())
    }

    /// UTTypes for NSOpenPanel. Using .audiovisualContent covers everything.
    static var allowedContentTypes: [UTType] {
        [.audiovisualContent]
    }

    /// Human-readable list for UI hints.
    static var displayList: String {
        "MKV, MP4, MOV, AVI, WebM, M4V, MTS, TS, FLV, WMV…"
    }
}
