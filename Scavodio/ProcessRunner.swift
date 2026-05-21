import Foundation

/// Runs a subprocess synchronously with a configurable timeout.
///
/// Uses `DispatchSemaphore` + `terminationHandler` to avoid data races
/// that would occur with a timer-based approach.
///
/// Call only from a **background** thread — `run()` blocks until the
/// process finishes or the timeout fires.
struct ProcessRunner {

    // MARK: - Error

    enum Failure: LocalizedError {
        case launchFailed(Error)
        case timedOut(TimeInterval)
        case nonZeroExit(code: Int32, stderr: String)

        var errorDescription: String? {
            switch self {
            case .launchFailed(let e):
                return "Failed to launch process: \(e.localizedDescription)"
            case .timedOut(let s):
                return "Process timed out after \(Int(s))s"
            case .nonZeroExit(let code, let stderr):
                return stderr.isEmpty ? "Exit code \(code)" : stderr
            }
        }
    }

    // MARK: - Properties

    let executableURL: URL
    let arguments:     [String]

    /// Seconds before the process is forcefully terminated.
    var timeout: TimeInterval = 30

    // MARK: - Run

    /// Runs the process, captures stdout, and returns it on success.
    ///
    /// - Throws: `Failure.launchFailed`, `.timedOut`, or `.nonZeroExit`.
    func run() throws -> Data {
        let process    = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL  = executableURL
        process.arguments      = arguments
        process.standardOutput = stdoutPipe
        process.standardError  = stderrPipe

        // Signal when the process exits (normal or killed).
        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }

        do {
            try process.run()
        } catch {
            throw Failure.launchFailed(error)
        }

        // Block until done or timeout.
        let timedOut = done.wait(timeout: .now() + timeout) == .timedOut

        if timedOut {
            process.terminate()
            process.waitUntilExit() // ensure cleanup before we return
            throw Failure.timedOut(timeout)
        }

        // Process has already exited — pipes are at EOF.
        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr  = String(data: errData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw Failure.nonZeroExit(code: process.terminationStatus, stderr: stderr)
        }

        return stdout
    }
}
