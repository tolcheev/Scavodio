import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - App status

enum AppStatus {
    case idle
    case probing
    case ready
    case extracting
    case success(URL)
    case failed(String)

    var label: String {
        switch self {
        case .idle:             return "Drop a video file or click Choose Video\u{2026}"
        case .probing:          return "Probing audio tracks\u{2026}"
        case .ready:            return "Ready. Select a track and format, then extract."
        case .extracting:       return "Extracting audio\u{2026}"
        case .success(let url): return "Done: \(url.lastPathComponent)"
        case .failed(let msg):  return "Error: \(msg)"
        }
    }

    var labelColor: Color {
        switch self {
        case .idle, .ready:         return .secondary
        case .probing, .extracting: return .blue
        case .success:              return .green
        case .failed:               return .red
        }
    }
}

// MARK: - Track row

struct TrackRow: View {
    let track: AudioTrack
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.displayName).font(.body)
            HStack(spacing: 14) {
                Label("Stream \(track.streamIndex)", systemImage: "number")
                Label("Audio \(track.audioIndex)",   systemImage: "waveform")
            }
            .font(.caption).foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Content view

struct ContentView: View {

    @StateObject private var service = FFmpegService()

    @State private var selectedFileURL:  URL?
    @State private var audioTracks:      [AudioTrack] = []
    @State private var selectedTrackID:  AudioTrack.ID?
    @State private var selectedFormat:   ExportFormat = .mka
    @State private var appStatus:        AppStatus = .idle
    @State private var logText:          String = ""
    @State private var showLog:          Bool = false
    @State private var isDropTargeted:   Bool = false
    @State private var isInstallingBrew: Bool = false
    @State private var progressInfo:     String = ""  // "5:23 at 18.8×"

    // MARK: Derived

    /// True while ffmpeg is running. Derived from service so it's always in sync.
    private var isExtracting: Bool { service.currentProcess != nil }

    private var selectedTrack: AudioTrack? {
        audioTracks.first { $0.id == selectedTrackID }
    }

    private var availableFormats: [ExportFormat] {
        guard let track = selectedTrack else { return [.mka, .mp3] }
        return track.codecName.lowercased() == "aac" ? ExportFormat.allCases : [.mka, .mp3]
    }

    /// Auto-falls back to .mka when the current selection becomes unavailable
    /// (e.g. user picks a non-AAC track after selecting .m4a). No `onChange` needed.
    private var formatBinding: Binding<ExportFormat> {
        Binding(
            get: { availableFormats.contains(selectedFormat) ? selectedFormat : .mka },
            set: { selectedFormat = $0 }
        )
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if service.isMissing    { missingBanner }
            dropZone
            if !audioTracks.isEmpty { tracksSection }
            if selectedTrack != nil { controlsSection }
            Divider()
            statusBar
            logSection
        }
        .padding()
        .frame(minWidth: 700, minHeight: 540)
    }

    // MARK: - Missing banner

    private var missingBanner: some View {
        HStack(spacing: 12) {
            if isInstallingBrew {
                ProgressView().scaleEffect(0.8)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange).font(.title2)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(isInstallingBrew
                     ? "Installing ffmpeg via Homebrew\u{2026}"
                     : "Missing: \(service.missingBinaries.joined(separator: ", "))")
                    .fontWeight(.semibold)
                if !isInstallingBrew {
                    Text("brew install ffmpeg")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button { confirmAndInstallFFmpeg() } label: {
                Label(isInstallingBrew ? "Installing\u{2026}" : "Install ffmpeg",
                      systemImage: "arrow.down.circle.fill")
            }
            .buttonStyle(.borderedProminent).tint(.orange)
            .disabled(isInstallingBrew)
        }
        .padding(10)
        .background(Color.orange.opacity(0.10))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(Color.orange.opacity(0.35), lineWidth: 1))
    }

    // MARK: - Drop zone

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2, dash: [6]))
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(isDropTargeted
                          ? Color.accentColor.opacity(0.07)
                          : Color(NSColor.controlBackgroundColor)))

            VStack(spacing: 8) {
                Image(systemName: "film.stack")
                    .font(.system(size: 32)).foregroundColor(.secondary)

                if let url = selectedFileURL {
                    Text(url.lastPathComponent)
                        .font(.headline).lineLimit(1).truncationMode(.middle)
                    Text(url.deletingLastPathComponent().path)
                        .font(.caption).foregroundColor(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                } else {
                    Text("Drop a video file here").foregroundColor(.secondary)
                    Text(SupportedFormats.displayList)
                        .font(.caption).foregroundColor(.secondary)
                }

                Button("Choose Video\u{2026}") { openFilePicker() }
                    .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(height: 140)
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted, perform: handleDrop(_:))
    }

    // MARK: - Tracks

    private var tracksSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audio Tracks").font(.headline)
            List(audioTracks, selection: $selectedTrackID) { track in
                TrackRow(track: track).tag(track.id)
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .frame(minHeight: 52, maxHeight: min(CGFloat(audioTracks.count) * 52 + 8, 240))
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export Format").font(.subheadline).foregroundColor(.secondary)
                Picker("", selection: formatBinding) {
                    ForEach(availableFormats) { fmt in Text(fmt.rawValue).tag(fmt) }
                }
                .pickerStyle(.segmented).frame(maxWidth: 360).labelsHidden()
            }
            Spacer()

            // Cancel button — visible only while extracting
            if isExtracting {
                Button(role: .destructive) {
                    service.cancelExtraction()
                    appStatus = .ready
                    logText  += "\n[Cancelled]\n"
                } label: {
                    Label("Cancel", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Button { startExtraction() } label: {
                Label("Extract Audio", systemImage: "waveform.badge.plus")
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(isExtracting || service.isMissing)
        }
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 8) {
            if case .extracting = appStatus { ProgressView().scaleEffect(0.7) }
            VStack(alignment: .leading, spacing: 2) {
                Text(appStatus.label)
                    .foregroundColor(appStatus.labelColor)
                    .lineLimit(2)
                // Progress line: "5:23 at 18.8×  ·  est. 2 min left"
                if case .extracting = appStatus, !progressInfo.isEmpty {
                    Text(progressInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if case .success(let url) = appStatus {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Log

    private var logSection: some View {
        DisclosureGroup(isExpanded: $showLog) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(logText.isEmpty ? "(no output yet)" : logText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(6)
                        .id("logBottom")
                }
                .frame(height: 140)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .onChange(of: logText) { _ in
                    withAnimation { proxy.scrollTo("logBottom", anchor: .bottom) }
                }
            }
        } label: {
            Text("ffmpeg log").font(.subheadline)
        }
    }

    // MARK: - Actions

    private func confirmAndInstallFFmpeg() {
        let alert = NSAlert()
        alert.messageText     = "Install ffmpeg via Homebrew?"
        alert.informativeText =
            "This will download ~300 MB of software from brew.sh and install it on your Mac.\n\n" +
            "Homebrew must already be installed at /opt/homebrew or /usr/local."
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        startBrewInstall()
    }

    private func startBrewInstall() {
        isInstallingBrew = true
        showLog          = true
        logText          = ""
        appStatus        = .idle

        service.installFFmpeg(
            logHandler: { [self] line in logText += line },
            completion: { [self] success in
                isInstallingBrew = false
                if success {
                    appStatus  = .ready
                    logText   += "\nffmpeg installed successfully!\n"
                } else {
                    appStatus = .failed("Installation failed — see log for details")
                }
            }
        )
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories    = false
        panel.canChooseFiles          = true
        panel.allowedContentTypes     = SupportedFormats.allowedContentTypes
        panel.title                   = "Choose a video file"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        loadFile(url: url)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else { return false }

        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async {
                if SupportedFormats.isSupported(url.pathExtension) {
                    self.loadFile(url: url)
                } else {
                    self.appStatus = .failed(
                        "Unsupported format .\(url.pathExtension.lowercased()). " +
                        "Supported: \(SupportedFormats.displayList)"
                    )
                }
            }
        }
        return true
    }

    private func loadFile(url: URL) {
        selectedFileURL = url
        audioTracks     = []
        selectedTrackID = nil
        logText         = ""
        appStatus       = .probing

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let tracks = try self.service.probeAudioTracks(at: url)
                DispatchQueue.main.async {
                    self.audioTracks     = tracks
                    self.selectedTrackID = tracks.first?.id
                    self.appStatus       = .ready
                }
            } catch {
                DispatchQueue.main.async {
                    self.appStatus = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func startExtraction() {
        guard let inputURL = selectedFileURL else {
            appStatus = .failed("No file selected"); return
        }
        guard let track = selectedTrack else {
            appStatus = .failed("No track selected"); return
        }

        let format    = formatBinding.wrappedValue
        let outputURL = OutputFileNamer.makeURL(
            input:      inputURL,
            audioIndex: track.audioIndex,
            language:   track.language,
            codecName:  track.codecName,
            format:     format
        )

        if FileManager.default.fileExists(atPath: outputURL.path) {
            let alert = NSAlert()
            alert.messageText     = "File Already Exists"
            alert.informativeText = "\(outputURL.lastPathComponent)\n\nOverwrite?"
            alert.addButton(withTitle: "Overwrite")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else {
                appStatus = .ready; return
            }
        }

        logText      = ""
        progressInfo = ""
        appStatus    = .extracting

        service.extractAudio(
            from:      inputURL,
            track:     track,
            format:    format,
            outputURL: outputURL,
            logHandler: { [self] line in
                logText += line
                if let p = parseFFmpegProgress(line) { progressInfo = p }
            },
            completion: { [self] result in
                progressInfo = ""
                switch result {
                case .success:
                    appStatus = .success(outputURL)
                case .failure(FFmpegError.extractionCancelled):
                    break
                case .failure(let error):
                    // Auto-expand log so user sees what went wrong
                    showLog = true
                    // Try to show the last meaningful ffmpeg error line
                    let hint = lastFFmpegError(in: logText)
                    let msg  = hint ?? error.localizedDescription
                    appStatus = .failed(msg)
                }
            }
        )
    }

    // MARK: - Progress / error parsing

    /// Parses ffmpeg stderr lines like:
    /// `size=   2048kB time=00:05:23.10 bitrate= 51.7kbits/s speed=18.8x`
    /// Returns a human-readable string like "5m 23s  ·  18.8×"
    private func parseFFmpegProgress(_ line: String) -> String? {
        guard line.contains("time="), line.contains("speed=") else { return nil }

        var timeStr = ""
        if let r = line.range(of: #"time=(\d{2}):(\d{2}):(\d{2})"#,
                               options: .regularExpression) {
            let raw = String(line[r]).dropFirst("time=".count)
            let parts = raw.split(separator: ":")
            if parts.count == 3,
               let h = Int(parts[0]), let m = Int(parts[1]), let s = Int(parts[2]) {
                timeStr = h > 0
                    ? "\(h)h \(m)m \(s)s"
                    : (m > 0 ? "\(m)m \(s)s" : "\(s)s")
            }
        }

        var speedStr = ""
        if let r = line.range(of: #"speed=\s*[\d.]+"#, options: .regularExpression) {
            speedStr = String(line[r])
                .replacingOccurrences(of: "speed=", with: "")
                .trimmingCharacters(in: .whitespaces) + "\u{00D7}"
        }

        guard !timeStr.isEmpty else { return nil }
        return speedStr.isEmpty ? timeStr : "\(timeStr)  \u{00B7}  \(speedStr)"
    }

    /// Returns the last line in ffmpeg output that looks like an actual error.
    private func lastFFmpegError(in log: String) -> String? {
        let keywords = ["error", "invalid", "no such file", "permission denied",
                        "unknown encoder", "failed", "could not", "unable to"]
        return log
            .components(separatedBy: "\n")
            .filter { line in
                let l = line.lowercased()
                return keywords.contains(where: { l.contains($0) })
                    && line.count > 10
            }
            .last?
            .trimmingCharacters(in: .whitespaces)
    }
}
