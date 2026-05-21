import XCTest
@testable import Scavodio

final class ProcessRunnerTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a temporary executable script and returns the path to it.
    private func makeScript(name: String, body: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScavodioTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try "#!/bin/sh\n\(body)".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: url.path)
        return url
    }

    // MARK: - Success

    func test_run_capturesStdout() throws {
        let script = try makeScript(name: "echo_test", body: "echo 'hello scavodio'")
        let runner = ProcessRunner(executableURL: script, arguments: [], timeout: 5)
        let data   = try runner.run()
        let output = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(output.contains("hello scavodio"))
    }

    func test_run_emptyOutput_succeeds() throws {
        let script = try makeScript(name: "empty", body: "exit 0")
        let runner = ProcessRunner(executableURL: script, arguments: [], timeout: 5)
        XCTAssertNoThrow(try runner.run())
    }

    // MARK: - Non-zero exit

    func test_run_nonZeroExit_throwsNonZeroExit() throws {
        let script = try makeScript(name: "fail", body: "echo 'oops' >&2\nexit 42")
        let runner = ProcessRunner(executableURL: script, arguments: [], timeout: 5)
        XCTAssertThrowsError(try runner.run()) { error in
            guard case ProcessRunner.Failure.nonZeroExit(let code, let stderr) = error else {
                XCTFail("Expected nonZeroExit, got \(error)"); return
            }
            XCTAssertEqual(code, 42)
            XCTAssertTrue(stderr.contains("oops"), "Stderr should be captured: \(stderr)")
        }
    }

    // MARK: - Timeout (requires Finding #1 implementation)

    func test_run_timesOut_onHangingProcess() throws {
        let script = try makeScript(name: "hang", body: "sleep 999")
        var runner  = ProcessRunner(executableURL: script, arguments: [], timeout: 2)
        runner.timeout = 2

        let start = Date()
        XCTAssertThrowsError(try runner.run()) { error in
            guard case ProcessRunner.Failure.timedOut(let seconds) = error else {
                XCTFail("Expected timedOut, got \(error)"); return
            }
            XCTAssertEqual(seconds, 2, accuracy: 0.5)
        }

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 5, "Should time out within ~2s, took \(elapsed)s")
    }

    func test_run_processTerminatesCleanly_afterTimeout() throws {
        let script = try makeScript(name: "hang2", body: "sleep 999")
        var runner  = ProcessRunner(executableURL: script, arguments: [], timeout: 1)
        runner.timeout = 1
        _ = try? runner.run() // expect throw

        // Verify no orphan processes (process should be dead after timeout)
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/bash")
        ps.arguments = ["-c", "pgrep -f 'sleep 999' | wc -l | tr -d ' '"]
        let pipe = Pipe()
        ps.standardOutput = pipe
        try ps.run(); ps.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                            encoding: .utf8) ?? "0"
        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "0",
                       "Hanging process should be terminated after timeout")
    }

    // MARK: - Launch failure

    func test_run_nonExistentBinary_throwsLaunchFailed() {
        let runner = ProcessRunner(
            executableURL: URL(fileURLWithPath: "/nonexistent/binary"),
            arguments: [],
            timeout: 5
        )
        XCTAssertThrowsError(try runner.run()) { error in
            guard case ProcessRunner.Failure.launchFailed = error else {
                XCTFail("Expected launchFailed, got \(error)"); return
            }
        }
    }

    // MARK: - Arguments passthrough

    func test_run_argumentsPassedCorrectly() throws {
        let echo   = URL(fileURLWithPath: "/bin/echo")
        let runner = ProcessRunner(executableURL: echo, arguments: ["foo", "bar baz"], timeout: 5)
        let data   = try runner.run()
        let output = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(output.contains("foo"), "First arg should appear in output")
        XCTAssertTrue(output.contains("bar baz"), "Arg with spaces should be a single token")
    }
}
