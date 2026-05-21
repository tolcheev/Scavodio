import XCTest

/// Regression tests that verify the production .app stays within size budgets.
/// Run after every Release build.
final class SizeBudgetTests: XCTestCase {

    // MARK: - Budgets

    private let maxReleaseBinaryKB = 512   // With -Osize + strip
    private let maxDebugBinaryKB   = 900   // Without optimizations
    private let maxICNSKB          = 1500  // Uncompressed iconset
    private let maxBundleMB        = 3.0   // Total .app

    // MARK: - Helpers

    private func bundlePath() -> String? {
        let env = ProcessInfo.processInfo.environment
        if let built = env["BUILT_PRODUCTS_DIR"] {
            return "\(built)/Scavodio.app"
        }
        // Fallback for local runs
        let local = "\(NSHomeDirectory())/projects/Scavodio/build/Scavodio.app"
        return FileManager.default.fileExists(atPath: local) ? local : nil
    }

    private func fileSize(_ path: String) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int
    }

    // MARK: - Tests

    func test_binarySize_withinBudget() throws {
        guard let bundle = bundlePath() else { throw XCTSkip("No .app found") }
        let binary = "\(bundle)/Contents/MacOS/Scavodio"
        guard let bytes = fileSize(binary) else { throw XCTSkip("Binary not found") }
        let kb = bytes / 1024

        let isRelease = ProcessInfo.processInfo.environment["CONFIGURATION"] == "Release"
        let limit     = isRelease ? maxReleaseBinaryKB : maxDebugBinaryKB
        XCTAssertLessThanOrEqual(
            kb, limit,
            "Binary \(kb)KB > \(limit)KB budget. Use -Osize -Xlinker -S for Release."
        )
    }

    func test_icnsSize_withinBudget() throws {
        guard let bundle = bundlePath() else { throw XCTSkip("No .app found") }
        let icns = "\(bundle)/Contents/Resources/AppIcon.icns"
        guard let bytes = fileSize(icns) else { throw XCTSkip("ICNS not found") }
        let kb = bytes / 1024
        XCTAssertLessThanOrEqual(
            kb, maxICNSKB,
            "AppIcon.icns \(kb)KB > \(maxICNSKB)KB. Run pngcrush on iconset PNGs."
        )
    }

    func test_bundleTotal_withinBudget() throws {
        guard let bundle = bundlePath() else { throw XCTSkip("No .app found") }
        var total: Int64 = 0
        FileManager.default.enumerator(atPath: bundle)?.forEach { item in
            if let s = try? FileManager.default
                .attributesOfItem(atPath: "\(bundle)/\(item as! String)")[.size] as? Int64 {
                total += s
            }
        }
        let mb = Double(total) / 1_048_576
        XCTAssertLessThanOrEqual(
            mb, maxBundleMB,
            ".app is \(String(format:"%.1f", mb))MB > \(maxBundleMB)MB budget"
        )
    }

    func test_noSourceFilesInBundle() throws {
        guard let bundle = bundlePath() else { throw XCTSkip("No .app found") }
        let devExtensions = [".swift", ".o", ".d", ".xctest"]
        var found: [String] = []
        FileManager.default.enumerator(atPath: bundle)?.forEach { item in
            let path = item as! String
            if devExtensions.contains(where: { path.hasSuffix($0) }) {
                found.append(path)
            }
        }
        XCTAssertTrue(found.isEmpty,
                      "Dev artifacts in bundle: \(found.joined(separator: ", "))")
    }

    func test_noTestDirectoriesInBundle() throws {
        guard let bundle = bundlePath() else { throw XCTSkip("No .app found") }
        let testMarkers = ["Tests", "test", "Spec", "Mock", "stub"]
        var found: [String] = []
        FileManager.default.enumerator(atPath: bundle)?.forEach { item in
            let path = item as! String
            if testMarkers.contains(where: { path.contains($0) }) {
                found.append(path)
            }
        }
        XCTAssertTrue(found.isEmpty,
                      "Test artifacts in bundle: \(found.joined(separator: ", "))")
    }

    func test_noSecretsInTextFiles() throws {
        guard let bundle = bundlePath() else { throw XCTSkip("No .app found") }
        let secretKeywords = ["password=", "secret=", "api_key=", "private_key"]
        var matches: [String] = []

        FileManager.default.enumerator(atPath: bundle)?.forEach { item in
            let path = "\(bundle)/\(item as! String)"
            guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }
            let lower = content.lowercased()
            for kw in secretKeywords {
                if lower.contains(kw) { matches.append("\(item as! String): '\(kw)'") }
            }
        }
        // Filter known-safe system keys in plists
        let real = matches.filter {
            !$0.contains("Info.plist") && !$0.contains("entitlements")
        }
        XCTAssertTrue(real.isEmpty,
                      "Potential secrets in bundle: \(real.joined(separator: ", "))")
    }
}
