import XCTest
@testable import Scavodio

final class OutputFileNamerTests: XCTestCase {

    // MARK: - Basic output

    func test_makeURL_basicFormat() {
        let url = OutputFileNamer.makeURL(
            input:      URL(fileURLWithPath: "/Movies/film.mkv"),
            audioIndex: 0,
            language:   "eng",
            codecName:  "aac",
            format:     .mka
        )
        XCTAssertEqual(url.deletingLastPathComponent().path, "/Movies")
        XCTAssertEqual(url.lastPathComponent, "film_audio0_eng_aac.mka")
    }

    func test_makeURL_noLanguage_omitField() {
        let url = OutputFileNamer.makeURL(
            input: URL(fileURLWithPath: "/tmp/video.mp4"),
            audioIndex: 2, language: nil, codecName: "ac3", format: .mp3
        )
        XCTAssertEqual(url.lastPathComponent, "video_audio2_ac3.mp3")
    }

    func test_makeURL_emptyLanguage_omitField() {
        let url = OutputFileNamer.makeURL(
            input: URL(fileURLWithPath: "/tmp/video.mp4"),
            audioIndex: 0, language: "", codecName: "mp3", format: .mp3
        )
        XCTAssertFalse(url.lastPathComponent.hasPrefix("video_audio0__"))
        XCTAssertTrue(url.lastPathComponent.hasPrefix("video_audio0_mp3"))
    }

    func test_makeURL_sameDirectoryAsInput() {
        let url = OutputFileNamer.makeURL(
            input: URL(fileURLWithPath: "/Users/test/archive/movie.mkv"),
            audioIndex: 1, language: "jpn", codecName: "aac", format: .m4a
        )
        XCTAssertEqual(url.deletingLastPathComponent().path, "/Users/test/archive")
    }

    // MARK: - Security: path traversal

    func test_makeURL_pathTraversalInLanguage_blocked() {
        let url = OutputFileNamer.makeURL(
            input: URL(fileURLWithPath: "/tmp/test.mkv"),
            audioIndex: 0, language: "../../etc/passwd", codecName: "aac", format: .mka
        )
        // Directory must not change
        XCTAssertEqual(url.deletingLastPathComponent().path, "/tmp")
        // Slashes must be removed from filename
        XCTAssertFalse(url.lastPathComponent.contains("/"))
    }

    func test_makeURL_nullBytesInCodec_sanitized() {
        let url = OutputFileNamer.makeURL(
            input: URL(fileURLWithPath: "/tmp/t.mkv"),
            audioIndex: 0, language: nil, codecName: "aac\0malicious", format: .mka
        )
        XCTAssertFalse(url.lastPathComponent.contains("\0"))
    }

    func test_makeURL_colonInLanguage_removed() {
        // Colon is forbidden in HFS+ filenames
        let url = OutputFileNamer.makeURL(
            input: URL(fileURLWithPath: "/tmp/t.mkv"),
            audioIndex: 0, language: "en:US", codecName: "aac", format: .mp3
        )
        XCTAssertFalse(url.lastPathComponent.contains(":"))
    }

    // MARK: - HFS+ limit: 255 UTF-8 bytes

    func test_makeURL_longLanguage_truncated_under255Bytes() {
        let longLang = String(repeating: "x", count: 500)
        let url = OutputFileNamer.makeURL(
            input: URL(fileURLWithPath: "/tmp/f.mkv"),
            audioIndex: 0, language: longLang, codecName: "aac", format: .mka
        )
        XCTAssertLessThanOrEqual(
            url.lastPathComponent.utf8.count, 255,
            "Filename exceeds HFS+ 255-byte limit: \(url.lastPathComponent.utf8.count) bytes"
        )
    }

    func test_makeURL_longCodecName_truncated_under255Bytes() {
        let longCodec = String(repeating: "a", count: 300)
        let url = OutputFileNamer.makeURL(
            input: URL(fileURLWithPath: "/tmp/f.mkv"),
            audioIndex: 0, language: nil, codecName: longCodec, format: .mp3
        )
        XCTAssertLessThanOrEqual(url.lastPathComponent.utf8.count, 255)
    }

    func test_makeURL_longBaseNameAndLang_truncated_under255Bytes() {
        let longName = String(repeating: "文", count: 200) // Cyrillic-range UTF-8 multi-byte
        let url = OutputFileNamer.makeURL(
            input: URL(fileURLWithPath: "/tmp/\(longName).mkv"),
            audioIndex: 0, language: "jpn", codecName: "aac", format: .mka
        )
        XCTAssertLessThanOrEqual(url.lastPathComponent.utf8.count, 255)
    }

    // MARK: - Edge cases

    func test_makeURL_emptyBase_fallback() {
        // File called ".mkv" — lastPathComponent after deletingPathExtension is ""
        let url = OutputFileNamer.makeURL(
            input: URL(fileURLWithPath: "/tmp/.mkv"),
            audioIndex: 0, language: nil, codecName: "aac", format: .mka
        )
        XCTAssertFalse(url.lastPathComponent.isEmpty)
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".mka"))
    }

    func test_makeURL_unicodeFilename_preserved() {
        let url = OutputFileNamer.makeURL(
            input: URL(fileURLWithPath: "/tmp/Фильм.mkv"),
            audioIndex: 0, language: "rus", codecName: "aac", format: .mp3
        )
        XCTAssertTrue(url.lastPathComponent.contains("Фильм"))
    }

    // MARK: - sanitize helper

    func test_sanitize_removesSlash() {
        XCTAssertFalse(OutputFileNamer.sanitize("a/b").contains("/"))
    }

    func test_sanitize_removesNull() {
        XCTAssertFalse(OutputFileNamer.sanitize("a\0b").contains("\0"))
    }

    func test_sanitize_preservesUnicode() {
        let result = OutputFileNamer.sanitize("Привет мир")
        XCTAssertTrue(result.contains("Привет"))
    }

    func test_sanitize_emptyInput_returnsEmpty() {
        XCTAssertEqual(OutputFileNamer.sanitize(""), "")
    }
}
