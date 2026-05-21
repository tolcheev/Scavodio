import XCTest
@testable import Scavodio

// MARK: - Helpers

/// Creates a fake executable script in a temp dir and returns the dir path.
func makeFakeBinary(name: String, script: String) throws -> String {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScavodioTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent(name)
    try "#!/bin/sh\n\(script)".write(to: url, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                          ofItemAtPath: url.path)
    return dir.path
}

// MARK: - Binary Detection

final class FFmpegServiceBinaryTests: XCTestCase {

    func test_isMissing_whenNoBinariesFound() {
        let svc = FFmpegService(searchDirs: ["/absolutely/nonexistent"])
        XCTAssertTrue(svc.isMissing)
        XCTAssertEqual(Set(svc.missingBinaries), ["ffmpeg", "ffprobe"])
    }

    func test_isMissing_false_whenBothFound() throws {
        let dir1 = try makeFakeBinary(name: "ffmpeg",  script: "exit 0")
        let dir2 = try makeFakeBinary(name: "ffprobe", script: "exit 0")
        // Both in same dir (dir1 == dir2 in this helper only if we put both in same dir)
        // Workaround: put both in dir1
        let ffprobe = URL(fileURLWithPath: dir1).appendingPathComponent("ffprobe")
        try "#!/bin/sh\nexit 0".write(to: ffprobe, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: ffprobe.path)
        _ = dir2 // suppress unused warning

        let svc = FFmpegService(searchDirs: [dir1])
        XCTAssertFalse(svc.isMissing)
        XCTAssertTrue(svc.missingBinaries.isEmpty)
    }

    func test_missingBinaries_onlyFFmpegMissing() throws {
        let dir = try makeFakeBinary(name: "ffprobe", script: "exit 0")
        let svc = FFmpegService(searchDirs: [dir])
        XCTAssertEqual(svc.missingBinaries, ["ffmpeg"])
    }

    func test_recheckBinaries_updatesAfterInstall() throws {
        let dir = try makeFakeBinary(name: "ffprobe", script: "exit 0")
        let svc = FFmpegService(searchDirs: [dir])
        XCTAssertTrue(svc.missingBinaries.contains("ffmpeg"))

        // Simulate ffmpeg appearing on disk
        let ffmpeg = URL(fileURLWithPath: dir).appendingPathComponent("ffmpeg")
        try "#!/bin/sh\nexit 0".write(to: ffmpeg, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: ffmpeg.path)
        svc.recheckBinaries()
        XCTAssertFalse(svc.isMissing)
    }
}

// MARK: - JSON Parsing

final class FFmpegServiceJSONTests: XCTestCase {

    private var svc: FFmpegService!
    override func setUp() { svc = FFmpegService(searchDirs: []) }

    private func data(_ s: String) -> Data { s.data(using: .utf8)! }

    func test_twoTracks_parsedCorrectly() throws {
        let json = data("""
        {"streams":[
          {"index":2,"codec_name":"aac","bit_rate":"128000",
           "tags":{"language":"jpn","title":"Japanese Stereo"}},
          {"index":3,"codec_name":"ac3","bit_rate":"448000",
           "tags":{"language":"eng"}}
        ]}
        """)
        let tracks = try svc.parseProbeJSON(json)
        XCTAssertEqual(tracks.count, 2)
        // First track
        XCTAssertEqual(tracks[0].streamIndex, 2)
        XCTAssertEqual(tracks[0].audioIndex,  0)
        XCTAssertEqual(tracks[0].codecName,   "aac")
        XCTAssertEqual(tracks[0].language,    "jpn")
        XCTAssertEqual(tracks[0].bitRate,     "128000")
        XCTAssertEqual(tracks[0].title,       "Japanese Stereo")
        // Second track
        XCTAssertEqual(tracks[1].audioIndex,  1)
        XCTAssertEqual(tracks[1].codecName,   "ac3")
        XCTAssertNil(tracks[1].title)
    }

    func test_emptyStreams_throwsNoAudioTracks() {
        XCTAssertThrowsError(try svc.parseProbeJSON(data(#"{"streams":[]}"#))) {
            guard case FFmpegError.noAudioTracks = $0 else {
                XCTFail("Expected noAudioTracks, got \($0)"); return
            }
        }
    }

    func test_invalidJSON_throwsParseError() {
        XCTAssertThrowsError(try svc.parseProbeJSON(data("not json"))) {
            guard case FFmpegError.jsonParseError = $0 else {
                XCTFail("Expected jsonParseError, got \($0)"); return
            }
        }
    }

    func test_missingOptionalFields_nocrash() throws {
        let tracks = try svc.parseProbeJSON(
            data(#"{"streams":[{"index":0,"codec_name":"opus"}]}"#)
        )
        XCTAssertNil(tracks[0].language)
        XCTAssertNil(tracks[0].bitRate)
        XCTAssertNil(tracks[0].title)
    }

    func test_naBitrate_storedAsString_notShownAsKbps() throws {
        let tracks = try svc.parseProbeJSON(
            data(#"{"streams":[{"index":0,"codec_name":"aac","bit_rate":"N/A"}]}"#)
        )
        XCTAssertEqual(tracks[0].bitRate, "N/A")
        XCTAssertFalse(tracks[0].displayName.contains("kbps"))
    }

    /// Critical: values from ffprobe metadata must NEVER be executed as shell commands.
    /// This test is impossible to exploit as long as Process.arguments[] is used.
    func test_maliciousMetadata_storedAsIs_notExecuted() throws {
        let shellPayload = "$(rm -rf /tmp/scavodio_pwned); echo pwned"
        let json = data("""
        {"streams":[{
          "index": 0,
          "codec_name": "\(shellPayload)",
          "tags": {
            "language": "$(whoami)",
            "title": "<script>alert(document.cookie)</script>"
          }
        }]}
        """)
        let tracks = try svc.parseProbeJSON(json)
        // Values are stored as raw strings
        XCTAssertEqual(tracks[0].codecName, shellPayload)
        XCTAssertEqual(tracks[0].language, "$(whoami)")
        // No side effects — /tmp/scavodio_pwned was not created
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: "/tmp/scavodio_pwned"),
            "Payload was executed! Metadata should never be passed to a shell."
        )
    }
}

// MARK: - Cancel extraction

final class FFmpegServiceCancelTests: XCTestCase {

    func test_cancelExtraction_terminatesProcess() throws {
        // Fake ffmpeg that hangs indefinitely
        let dir = try makeFakeBinary(name: "ffmpeg",  script: "sleep 999")
        _       = try makeFakeBinary(name: "ffprobe", script: "exit 0")

        // Put both in same dir
        let ffprobe = URL(fileURLWithPath: dir).appendingPathComponent("ffprobe")
        try "#!/bin/sh\nexit 0".write(to: ffprobe, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: ffprobe.path)

        let svc   = FFmpegService(searchDirs: [dir])
        let track = AudioTrack(streamIndex: 0, audioIndex: 0, codecName: "aac",
                               language: nil, bitRate: nil, title: nil)

        let cancelledExp = XCTestExpectation(description: "extraction cancelled")
        svc.extractAudio(
            from:      URL(fileURLWithPath: "/tmp/fake.mkv"),
            track:     track,
            format:    .mka,
            outputURL: URL(fileURLWithPath: "/tmp/fake_out.mka"),
            logHandler: { _ in }
        ) { result in
            if case .failure(FFmpegError.extractionCancelled) = result {
                cancelledExp.fulfill()
            } else {
                XCTFail("Expected extractionCancelled, got \(result)")
            }
        }

        // Wait briefly then cancel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            svc.cancelExtraction()
        }

        wait(for: [cancelledExp], timeout: 5)
        XCTAssertNil(svc.currentProcess, "currentProcess should be nil after cancel")
    }
}

// MARK: - SupportedFormats

final class SupportedFormatsTests: XCTestCase {

    func test_coreFormatsSupported() {
        for fmt in ["mkv", "mp4", "mov", "avi", "webm", "ts", "mts", "m2ts",
                    "flv", "wmv", "m4v", "vob", "3gp"] {
            XCTAssertTrue(SupportedFormats.isSupported(fmt), "\(fmt) should be supported")
        }
    }

    func test_caseInsensitive() {
        XCTAssertTrue(SupportedFormats.isSupported("MKV"))
        XCTAssertTrue(SupportedFormats.isSupported("MP4"))
        XCTAssertTrue(SupportedFormats.isSupported("MOV"))
    }

    func test_dangerousExtensions_rejected() {
        for ext in ["exe", "sh", "dmg", "app", "pdf", "zip", "", "js", "py", "command", "bash"] {
            XCTAssertFalse(SupportedFormats.isSupported(ext), "\(ext) should NOT be supported")
        }
    }
}

// MARK: - AudioTrack display

final class AudioTrackDisplayTests: XCTestCase {

    func test_fullDisplayName() {
        let t = AudioTrack(streamIndex: 2, audioIndex: 0, codecName: "aac",
                           language: "jpn", bitRate: "128000", title: "Japanese")
        XCTAssertTrue(t.displayName.contains("Track 0"))
        XCTAssertTrue(t.displayName.contains("[jpn]"))
        XCTAssertTrue(t.displayName.contains("AAC"))
        XCTAssertTrue(t.displayName.contains("128 kbps"))
        XCTAssertTrue(t.displayName.contains("Japanese"))
    }

    func test_missingOptionals_nocrash() {
        let t = AudioTrack(streamIndex: 0, audioIndex: 2, codecName: "ac3",
                           language: nil, bitRate: nil, title: nil)
        XCTAssertTrue(t.displayName.contains("Track 2"))
        XCTAssertFalse(t.displayName.contains("["))
        XCTAssertFalse(t.displayName.contains("kbps"))
    }

    func test_zeroBitrate_notShown() {
        let t = AudioTrack(streamIndex: 0, audioIndex: 0, codecName: "aac",
                           language: nil, bitRate: "0", title: nil)
        XCTAssertFalse(t.displayName.contains("kbps"))
    }

    func test_naBitrate_notShown() {
        let t = AudioTrack(streamIndex: 0, audioIndex: 0, codecName: "aac",
                           language: nil, bitRate: "N/A", title: nil)
        XCTAssertFalse(t.displayName.contains("kbps"))
    }
}
