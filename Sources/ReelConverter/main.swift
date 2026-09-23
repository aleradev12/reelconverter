import SwiftUI
import UniformTypeIdentifiers
import AppKit

@main
struct ReelConverterApp: App {
    var body: some Scene {
        Window("ReelConverter", id: "main") { ConverterView() }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 750, height: 595)
    }
}

struct VideoItem: Identifiable {
    let id = UUID()
    let url: URL
    var state = "Ready"
    var progress = 0.0
    var outputURL: URL?
}

struct ConverterView: View {
    @State private var videos: [VideoItem] = []
    @State private var codec = "H.264"
    @AppStorage("reelconverter.theme") private var themePreference = "system"
    @Environment(\.colorScheme) private var colorScheme
    @State private var bitrate = "5"
    @State private var customBitrate = ""
    @State private var frameRate = "Original"
    @State private var resolution = "Original"
    @State private var speed = "1"
    @State private var encodingPreset = "faster"
    @State private var customFrameRate = ""
    @State private var customResolution = ""
    @State private var customSpeed = ""
    @State private var keepAudio = true
    @State private var isConverting = false
    @State private var dependenciesAvailable = false
    @State private var homebrewPath: String?
    @State private var showDependencySheet = false
    @State private var isInstallingFFmpeg = false
    @State private var installationMessage = ""
    @State private var installationOutput = ""
    @State private var installerProcess: Process?
    @State private var isHovering = false
    @State private var isDropHover = false
    @State private var isDeveloperHover = false
    @State private var isConvertHover = false
    @State private var showError = false
    @State private var status = "Add videos to get started"
    @State private var sourceFrameRate = "—"
    @State private var sourceHeight = "—"

    @State private var uiScale: CGFloat = 1
    private func scaled(_ value: CGFloat) -> CGFloat { value * uiScale }
    private let codecs = ["H.264", "H.265"]
    private let rates = ["Original", "10", "24", "25", "30", "60"]
    private let bitrates = ["0.025", "0.1", "0.25", "0.5", "2", "5", "8", "12", "20"]
    private let resolutions = ["Original", "2160p", "1440p", "1080p", "720p", "480p"]
    private let encodingPresets = ["ultrafast", "faster", "fast", "medium", "slow", "veryslow"]
    private let validEncodingPresets = ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow"]
    private let speeds = ["0.5", "1", "2", "16"]

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 820, proxy.size.height / 650)
            VStack(spacing: 0) {
                header
                settingsPanel.padding(.horizontal, scaled(24)).padding(.top, scaled(8))
                queuePanel.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, scaled(24)).padding(.top, scaled(10))
                footer.frame(height: scaled(66))
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background {
                pageBackground
                    .contentShape(Rectangle())
                    .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
            }
            .onAppear { uiScale = scale }
            .onChange(of: proxy.size) { size in
                uiScale = min(size.width / 820, size.height / 650)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(primaryText)
        .preferredColorScheme(preferredScheme)
        .background(WindowAspectRatio())
        .onDrop(of: [UTType.fileURL], isTargeted: $isHovering, perform: receiveDrop)
        .onAppear {
            NSApp.keyWindow?.makeFirstResponder(nil)
            let arguments = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--") }
            addFiles(arguments.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) })
        }
        .onOpenURL { addFiles([$0]) }
        .task { checkDependencies() }
        .sheet(isPresented: $showDependencySheet) { dependencySheet }
        .alert("Cannot convert", isPresented: $showError) { Button("OK", role: .cancel) {} } message: { Text(status) }
    }

    private var isDark: Bool {
        if themePreference == "dark" { return true }
        if themePreference == "light" { return false }
        return colorScheme == .dark
    }
    private var preferredScheme: ColorScheme? {
        switch themePreference {
        case "dark": .dark
        case "light": .light
        default: nil
        }
    }
    private func ink(_ opacity: Double) -> Color { isDark ? Color.white.opacity(opacity) : Color.black.opacity(opacity) }
    private var pageBackground: Color { isDark ? Color(red: 0.075, green: 0.082, blue: 0.095) : Color(red: 0.94, green: 0.95, blue: 0.97) }
    private var primaryText: Color { isDark ? Color.white.opacity(0.92) : Color(red: 0.12, green: 0.14, blue: 0.17) }
    private var secondaryText: Color { isDark ? Color.white.opacity(0.62) : Color(red: 0.28, green: 0.31, blue: 0.36) }
    private var tertiaryText: Color { isDark ? Color.white.opacity(0.43) : Color(red: 0.40, green: 0.43, blue: 0.48) }
    private var faintSurface: Color { isDark ? Color.white.opacity(0.025) : Color.black.opacity(0.035) }
    private var buttonSurface: Color { isDark ? Color.white.opacity(0.055) : Color.black.opacity(0.055) }
    private var selectedSurface: Color { isDark ? Color.white.opacity(0.16) : Color.black.opacity(0.11) }
    private var borderColor: Color { isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.14) }

    private func appearanceButton(_ symbol: String, value: String, help: String) -> some View {
        Button {
            NSApp.keyWindow?.makeFirstResponder(nil)
            themePreference = value
        } label: {
            Image(systemName: symbol)
                .font(.system(size: scaled(11), weight: .medium))
                .frame(width: scaled(26), height: scaled(26))
                .background(themePreference == value ? selectedSurface : buttonSurface)
                .clipShape(RoundedRectangle(cornerRadius: scaled(5)))
        }
        .buttonStyle(.plain)
        .modifier(SettingHover())
        .help(help)
        .accessibilityLabel(help)
        .accessibilityValue(themePreference == value ? "Selected" : "")
    }

    private var header: some View {
        HStack(spacing: scaled(10)) {
            Image(systemName: "film.fill").font(.system(size: scaled(16))).foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.35))
            Text("REELCONVERTER").font(.system(size: scaled(13), weight: .bold, design: .rounded)).tracking(1.4)
            Text("BATCH VIDEO").font(.system(size: scaled(9), weight: .medium)).tracking(1).foregroundStyle(tertiaryText)
            Spacer(minLength: 8)
            Text("DEVELOPER ·").font(.system(size: scaled(9), weight: .medium)).tracking(0.5).foregroundStyle(tertiaryText)
            Link("ALERADEV12", destination: URL(string: "https://github.com/aleradev12")!)
                .font(.system(size: scaled(9), weight: .medium)).tracking(0.5)
                .foregroundStyle(isDeveloperHover ? Color(red: 0.95, green: 0.49, blue: 0.35) : secondaryText)
                .onHover { isDeveloperHover = $0 }
                .help("Open GitHub profile")
            HStack(spacing: scaled(3)) {
                appearanceButton("circle.lefthalf.filled", value: "system", help: "System appearance")
                appearanceButton("sun.max.fill", value: "light", help: "Light appearance")
                appearanceButton("moon.fill", value: "dark", help: "Dark appearance")
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Appearance")
        }
        .padding(.horizontal, scaled(24)).frame(height: scaled(42))
        .background(faintSurface).overlay(alignment: .bottom) { Rectangle().fill(borderColor.opacity(0.45)).frame(height: scaled(1)) }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: scaled(6)) {
            HStack(alignment: .top, spacing: scaled(12)) {
                settingGroup("Video codec", icon: "film", values: codecs, selection: $codec, columns: 2, buttonWidth: 48, buttonHeight: 56)
                    .frame(width: scaled(120))
                bitrateGroup.frame(width: scaled(310))
                settingGroup("Frame rate", icon: "speedometer", values: rates, selection: $frameRate, custom: $customFrameRate, columns: 4, buttonWidth: 48) { value in
                    value == "Original" ? (videos.count == 1 ? sourceFrameRate.replacingOccurrences(of: " fps", with: "") : "Source") : value
                }.frame(width: scaled(225))
                audioGroup
            }
            HStack(alignment: .top, spacing: scaled(12)) {
                settingGroup("Height · px", icon: "rectangle.expand.vertical", values: resolutions, selection: $resolution, custom: $customResolution, columns: 4, buttonWidth: 58) {
                    $0 == "Original" ? sourceLabel(sourceHeight).replacingOccurrences(of: "p", with: "") : String($0.dropLast())
                }
                    .frame(width: scaled(275))
                settingGroup("Playback speed · ×", icon: "clock.arrow.circlepath", values: speeds, selection: $speed, custom: $customSpeed, columns: 3, buttonWidth: 48)
                    .frame(width: scaled(190))
                settingGroup("Encoding preset", icon: "gauge.high", values: encodingPresets, selection: $encodingPreset, columns: 3, buttonWidth: 72) { value in
                    value == "ultrafast" ? "Ultra fast" : value == "veryslow" ? "Very slow" : value.capitalized
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var audioGroup: some View {
        Button { NSApp.keyWindow?.makeFirstResponder(nil); keepAudio.toggle() } label: {
            HStack(spacing: scaled(5)) {
                Image(systemName: keepAudio ? "checkmark.circle.fill" : "circle")
                Text(keepAudio ? "On" : "Off")
            }
            .font(.system(size: scaled(12), weight: .medium))
            .frame(maxWidth: .infinity).frame(height: scaled(56))
            .background(keepAudio ? selectedSurface : buttonSurface)
            .clipShape(RoundedRectangle(cornerRadius: scaled(5)))
        }
        .buttonStyle(.plain).modifier(SettingHover())
        .accessibilityLabel("Keep audio").accessibilityValue(keepAudio ? "On" : "Off")
        .help("Keep audio in the converted video")
        .configFrame("Audio", icon: "speaker.wave.2", height: 82, scale: uiScale)
    }

    private func sourceLabel(_ value: String) -> String { videos.count == 1 ? value : "Source" }

    private func settingGroup(_ name: String, icon: String, values: [String], selection: Binding<String>, custom: Binding<String>? = nil, columns: Int, buttonWidth: CGFloat, buttonHeight: CGFloat = 26, title: @escaping (String) -> String = { $0 }) -> some View {
        FlowButtons(scale: uiScale, columns: columns, hasCustom: custom != nil) {
            ForEach(values, id: \.self) { value in
                Button { NSApp.keyWindow?.makeFirstResponder(nil); selection.wrappedValue = value } label: {
                    Text(title(value)).font(.system(size: scaled(14.4), weight: .medium))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(minWidth: scaled(buttonWidth), maxWidth: .infinity).frame(height: scaled(buttonHeight))
                        .background(selection.wrappedValue == value ? selectedSurface : buttonSurface)
                        .clipShape(RoundedRectangle(cornerRadius: scaled(5)))
                }.buttonStyle(.plain).modifier(SettingHover()).help("\(name): \(value)")
            }
            if let custom {
                StableInput(text: custom, scale: uiScale) {
                    if !custom.wrappedValue.isEmpty { selection.wrappedValue = custom.wrappedValue }
                }
                .frame(minWidth: scaled(74), maxWidth: .infinity).frame(height: scaled(26))
                .padding(.horizontal, scaled(6)).background(buttonSurface)
                .clipShape(RoundedRectangle(cornerRadius: scaled(5)))
                .onChange(of: custom.wrappedValue) { value in if !value.isEmpty { selection.wrappedValue = value } }
                .help("Custom \(name.lowercased()) value")
            }
        }
        .configFrame(name, icon: icon, height: 82, scale: uiScale)
    }

    private var bitrateGroup: some View {
        FlowButtons(scale: uiScale, columns: 6, hasCustom: true, spacing: 3) {
            ForEach(bitrates, id: \.self) { value in
                Button { NSApp.keyWindow?.makeFirstResponder(nil); bitrate = value } label: {
                    Text(value).font(.system(size: scaled(14.4), weight: .medium))
                        .minimumScaleFactor(0.85).lineLimit(1)
                        .frame(minWidth: scaled(42), maxWidth: .infinity).frame(height: scaled(26))
                        .background(bitrate == value ? selectedSurface : buttonSurface)
                        .clipShape(RoundedRectangle(cornerRadius: scaled(5)))
                }.buttonStyle(.plain).modifier(SettingHover())
            }
            StableInput(text: $customBitrate, scale: uiScale) {
                if !customBitrate.isEmpty { bitrate = customBitrate }
            }
            .frame(minWidth: scaled(74), maxWidth: .infinity).frame(height: scaled(26))
            .padding(.horizontal, scaled(6)).background(buttonSurface)
            .clipShape(RoundedRectangle(cornerRadius: scaled(5)))
            .onChange(of: customBitrate) { value in if !value.isEmpty { bitrate = value } }
            .help("Custom bitrate in Mbps")
        }
        .configFrame("Bitrate · Mbps", icon: "waveform.path", height: 82, scale: uiScale)
    }

    private var queuePanel: some View {
        VStack(alignment: .leading, spacing: scaled(10)) {
            HStack {
                Text("Files").font(.system(size: scaled(20), weight: .semibold))
                Text("\(videos.count)").font(.system(size: scaled(12))).foregroundStyle(ink(0.4))
                Spacer()
                Button("Clear queue") { videos.removeAll(); status = "Queue cleared" }.buttonStyle(.plain).font(.system(size: scaled(11))).foregroundStyle(ink(0.6)).padding(scaled(6)).modifier(SettingHover()).disabled(videos.isEmpty || isConverting)
                Button { pickFiles() } label: { Image(systemName: "plus").font(.system(size: scaled(12), weight: .semibold)).frame(width: scaled(30), height: scaled(30)).background(ink(0.07)).clipShape(RoundedRectangle(cornerRadius: scaled(6))) }.buttonStyle(.plain).modifier(SettingHover()).help("Add videos")
            }
            if videos.isEmpty { dropZone.frame(maxHeight: .infinity) }
            else {
                ScrollView { fileList.padding(.bottom, scaled(8)) }
                    .scrollIndicators(.hidden)
                    .frame(maxHeight: .infinity)
                    .overlay(alignment: .bottom) { LinearGradient(colors: [Color.clear, pageBackground.opacity(0.92)], startPoint: .top, endPoint: .bottom).frame(height: scaled(42)).allowsHitTesting(false) }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var dropZone: some View {
        Button(action: pickFiles) {
            VStack(spacing: scaled(12)) {
                Image(systemName: "arrow.down.to.line.compact").font(.system(size: scaled(22), weight: .light)).foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.35))
                Text("Drop videos anywhere in this window").font(.system(size: scaled(16), weight: .medium))
                Text("or click to choose files  ·  MP4, MOV, MKV, AVI, M4V").font(.system(size: scaled(12))).foregroundStyle(ink(0.48))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(isHovering || isDropHover ? ink(0.07) : faintSurface)
            .clipShape(RoundedRectangle(cornerRadius: scaled(10))).overlay(RoundedRectangle(cornerRadius: scaled(10)).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 5])).foregroundStyle(isHovering || isDropHover ? Color.orange : borderColor))
        }.buttonStyle(.plain).frame(maxWidth: .infinity, maxHeight: .infinity).onHover { isDropHover = $0 }
    }

    private var fileList: some View {
        VStack(spacing: scaled(0)) {
            ForEach(videos.indices, id: \.self) { index in
                HStack(spacing: scaled(12)) {
                    Image(systemName: "play.rectangle").font(.system(size: scaled(18))).foregroundStyle(Color(red: 0.95, green: 0.49, blue: 0.35))
                    VStack(alignment: .leading, spacing: scaled(5)) {
                        Text(videos[index].url.lastPathComponent).font(.system(size: scaled(13), weight: .medium)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        Text("Original · \(formattedSize(videos[index].url))").font(.system(size: scaled(11))).foregroundStyle(ink(0.45))
                        if let output = videos[index].outputURL {
                            HStack(spacing: scaled(6)) {
                                Text(output.lastPathComponent).font(.system(size: scaled(12), weight: .medium)).lineLimit(1).truncationMode(.middle)
                                Button { revealInFinder(output) } label: { Image(systemName: "folder.badge.plus").font(.system(size: scaled(13))).frame(width: scaled(24), height: scaled(24)) }.buttonStyle(.plain).modifier(FolderHover()).help("Reveal converted video in Finder")
                            }
                            Text("Converted · \(formattedSize(output))").font(.system(size: scaled(11))).foregroundStyle(ink(0.45))
                        } else if isConverting && videos[index].progress > 0 {
                            ProgressView(value: videos[index].progress).tint(Color(red: 0.95, green: 0.49, blue: 0.35)).frame(maxWidth: 200)
                        } else { Text(videos[index].state).font(.system(size: scaled(11))).foregroundStyle(ink(0.4)) }
                    }
                    Spacer(minLength: 8)
                    Button { revealInFinder(videos[index].url) } label: { Image(systemName: "folder").font(.system(size: scaled(15))).frame(width: scaled(34), height: scaled(34)) }.buttonStyle(.plain).modifier(FolderHover()).help("Reveal original in Finder")
                    if !isConverting { Button { videos.remove(at: index) } label: { Image(systemName: "xmark").font(.system(size: scaled(10))).padding(scaled(8)) }.buttonStyle(.plain).foregroundStyle(ink(0.4)) }
                }.padding(.horizontal, scaled(14)).padding(.vertical, scaled(12))
                if index != videos.count - 1 { Divider().overlay(ink(0.07)) }
            }
        }.background(faintSurface).clipShape(RoundedRectangle(cornerRadius: scaled(9)))
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(action: startConversion) {
                HStack(spacing: scaled(10)) {
                    if isConverting { ProgressView().controlSize(.small).tint(primaryText) }
                    Text(isConverting ? "Converting…" : "Convert").font(.system(size: scaled(14), weight: .semibold))
                }.padding(.horizontal, scaled(25)).frame(height: scaled(48))
                    .background(convertButtonColor)
                    .clipShape(RoundedRectangle(cornerRadius: scaled(9)))
                    .shadow(color: isConvertHover && !videos.isEmpty && !isConverting ? Color(red: 0.95, green: 0.36, blue: 0.25).opacity(0.34) : .clear, radius: scaled(8), y: scaled(2))
            }.buttonStyle(.plain)
                .onHover { isConvertHover = $0 }
                .help(videos.isEmpty ? "Add videos to enable conversion" : "Convert queued videos")
                .disabled(videos.isEmpty || isConverting || !dependenciesAvailable)
            Spacer()
        }
        .padding(.horizontal, scaled(24)).padding(.top, scaled(10)).padding(.bottom, scaled(8))
        .background {
            ZStack(alignment: .bottom) {
                Rectangle().fill(.ultraThinMaterial).mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black.opacity(0.2), location: 0.38), .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom))
                Rectangle().fill(.regularMaterial).mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .clear, location: 0.48), .init(color: .black.opacity(0.7), location: 1)], startPoint: .top, endPoint: .bottom))
            }
        }
        .overlay(alignment: .top) { LinearGradient(colors: [ink(0), ink(0.04)], startPoint: .top, endPoint: .bottom).frame(height: scaled(1)) }
    }

    private var dependencySheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("FFmpeg required", systemImage: "film.stack")
                .font(.system(size: 20, weight: .semibold))
            Text("ReelConverter uses FFmpeg and ffprobe to convert videos. They were not found on this Mac.")
                .font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

            if let homebrewPath {
                if isInstallingFFmpeg {
                    ProgressView()
                    Text(installationMessage).font(.system(size: 12, weight: .medium))
                    if !installationOutput.isEmpty {
                        Text(installationOutput).font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary).lineLimit(4).textSelection(.enabled)
                    }
                } else {
                    Button(action: installFFmpeg) {
                        Label("Install FFmpeg", systemImage: "arrow.down.circle.fill")
                            .frame(maxWidth: .infinity).frame(height: 40)
                    }.buttonStyle(.borderedProminent).tint(Color(red: 0.88, green: 0.32, blue: 0.21))
                    Text("Runs `brew install ffmpeg` using Homebrew at \(homebrewPath).")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    if !installationMessage.isEmpty && installationMessage != "FFmpeg is ready." {
                        Text(installationMessage).font(.system(size: 11)).foregroundStyle(.orange)
                    }
                }
            } else {
                Text("Homebrew is not installed. Install it first, then reopen ReelConverter to install FFmpeg.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Link(destination: URL(string: "https://brew.sh")!) {
                    Label("Get Homebrew", systemImage: "safari")
                        .frame(maxWidth: .infinity).frame(height: 40)
                }.buttonStyle(.borderedProminent).tint(Color(red: 0.88, green: 0.32, blue: 0.21))
            }

            HStack {
                Spacer()
                Button(isInstallingFFmpeg ? "Continue in background" : "Later") { showDependencySheet = false }
                    .buttonStyle(.plain)
            }
        }
        .padding(24).frame(width: 410)
        .background(pageBackground)
    }

    private var convertButtonColor: Color {
        if videos.isEmpty || isConverting { return ink(0.12) }
        return isConvertHover ? Color(red: 0.98, green: 0.43, blue: 0.31) : Color(red: 0.88, green: 0.32, blue: 0.21)
    }

    private func checkDependencies() {
        homebrewPath = Self.findHomebrew()
        dependenciesAvailable = Self.findFFmpeg() != nil && Self.findFFprobe() != nil
        if dependenciesAvailable {
            showDependencySheet = false
            installationMessage = "FFmpeg is ready."
        } else {
            showDependencySheet = true
        }
    }

    private func installFFmpeg() {
        guard let homebrewPath else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: homebrewPath)
        process.arguments = ["install", "ffmpeg"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        installationOutput = ""
        installationMessage = "Installing FFmpeg with Homebrew…"
        isInstallingFFmpeg = true
        installerProcess = process

        let outputState = $installationOutput
        let messageState = $installationMessage
        let installingState = $isInstallingFFmpeg
        let processState = $installerProcess
        let availabilityState = $dependenciesAvailable
        let sheetState = $showDependencySheet
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            let text = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async {
                outputState.wrappedValue = String((outputState.wrappedValue + text).suffix(700))
            }
        }
        process.terminationHandler = { finishedProcess in
            pipe.fileHandleForReading.readabilityHandler = nil
            let succeeded = finishedProcess.terminationStatus == 0
            let toolsAvailable = Self.findFFmpeg() != nil && Self.findFFprobe() != nil
            let exitMessage = "Homebrew could not install FFmpeg (exit code \(finishedProcess.terminationStatus))."
            DispatchQueue.main.async {
                processState.wrappedValue = nil
                installingState.wrappedValue = false
                availabilityState.wrappedValue = toolsAvailable
                if succeeded && toolsAvailable {
                    messageState.wrappedValue = "FFmpeg is ready."
                    sheetState.wrappedValue = false
                } else {
                    messageState.wrappedValue = succeeded
                        ? "Installation finished, but ffmpeg or ffprobe is still missing."
                        : exitMessage
                    sheetState.wrappedValue = true
                }
            }
        }
        do {
            try process.run()
        } catch {
            isInstallingFFmpeg = false
            installerProcess = nil
            installationMessage = "Could not start Homebrew: \(error.localizedDescription)"
        }
    }

    private func pickFiles() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        if panel.runModal() == .OK { addFiles(panel.urls) }
    }

    private func receiveDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers { _ = provider.loadObject(ofClass: URL.self) { url, _ in if let url { DispatchQueue.main.async { addFiles([url]) } } } }
        return true
    }

    private func addFiles(_ urls: [URL]) {
        let existing = Set(videos.map { $0.url.standardizedFileURL })
        videos.append(contentsOf: urls.filter { !existing.contains($0.standardizedFileURL) && $0.isFileURL }.map { VideoItem(url: $0) })
        status = videos.isEmpty ? "Add videos to get started" : "Output files will be saved next to the originals"
        if let first = videos.first { probeSource(first.url) }
    }

    private func probeSource(_ url: URL) {
        guard let ffprobe = Self.findFFprobe() else { return }
        let process = Process(); process.executableURL = URL(fileURLWithPath: ffprobe)
        process.arguments = ["-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height,avg_frame_rate", "-of", "default=noprint_wrappers=1", url.path]
        let pipe = Pipe(); process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        do {
            try process.run(); let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
            guard let text = String(data: data, encoding: .utf8) else { return }
            var fields: [String: String] = [:]
            for line in text.split(separator: "\n") {
                let pair = line.split(separator: "=", maxSplits: 1).map(String.init)
                if pair.count == 2 { fields[pair[0]] = pair[1] }
            }
            if let height = fields["height"] { sourceHeight = "\(height)p" }
            if let fps = fields["avg_frame_rate"] {
                let pair = fps.split(separator: "/").compactMap { Double($0) }
                if pair.count == 2, pair[1] != 0 { sourceFrameRate = "\(Int((pair[0] / pair[1]).rounded())) fps" }
            }
        } catch { }
    }

    private func startConversion() {
        guard let ffmpeg = Self.findFFmpeg() else { status = "FFmpeg not found. Install with: brew install ffmpeg"; showError = true; return }
        guard let mbps = Double(bitrate), mbps.isFinite, mbps > 0, mbps <= 10000 else { status = "Enter a valid bitrate in Mbps"; showError = true; return }
        if frameRate != "Original" {
            guard let fps = Double(frameRate), fps.isFinite, fps > 0, fps <= 240 else { status = "Frame rate must be between 0 and 240 fps"; showError = true; return }
        }
        if resolution != "Original" {
            let heightText = resolution.hasSuffix("p") ? String(resolution.dropLast()) : resolution
            guard let height = Int(heightText), height >= 16, height <= 8192 else { status = "Height must be between 16 and 8192 pixels"; showError = true; return }
        }
        guard let playback = Double(speed), playback.isFinite, playback >= 0.1, playback <= 100 else { status = "Playback speed must be between 0.1× and 100×"; showError = true; return }
        guard validEncodingPresets.contains(encodingPreset) else { status = "Choose a valid FFmpeg encoding preset"; showError = true; return }
        isConverting = true
        Task { @MainActor in
            for index in videos.indices {
                videos[index].state = "Converting…"
                do {
                    let output = try await convert(videos[index].url, ffmpeg: ffmpeg, mbps: mbps, index: index)
                    videos[index].outputURL = output; videos[index].state = "Done"; videos[index].progress = 1
                } catch { videos[index].state = "Error"; status = error.localizedDescription; showError = true }
            }
            isConverting = false
            if videos.allSatisfy({ $0.state == "Done" }) { status = "Done · output saved next to the source files" }
        }
    }

    private func convert(_ input: URL, ffmpeg: String, mbps: Double, index: Int) async throws -> URL {
        let codecTag = codec == "H.265" ? "h265" : "h264"
        let rateTag = frameRate == "Original" ? "source" : "\(frameRate)fps"
        let sizeTag = resolution == "Original" ? "source" : (resolution.hasSuffix("p") ? resolution : "\(resolution)p")
        let output = input.deletingLastPathComponent().appendingPathComponent("\(input.deletingPathExtension().lastPathComponent)_\(codecTag)_\(bitrate)Mbps_\(rateTag)_\(sizeTag)_\(speed)x_\(encodingPreset).mp4")
        // Encode beside the source, but never let FFmpeg overwrite an earlier conversion.
        let temporary = output.deletingLastPathComponent().appendingPathComponent(".reelconverter-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: temporary) }
        var args = ["-n", "-i", input.path, "-c:v", codec == "H.265" ? "libx265" : "libx264", "-preset", encodingPreset, "-b:v", "\(Int(mbps * 1000))k", "-maxrate", "\(Int(mbps * 1250))k", "-bufsize", "\(Int(mbps * 2000))k"]
        if codec == "H.265" { args += ["-tag:v", "hvc1"] }
        if frameRate != "Original" { args += ["-r", frameRate] }
        var filters: [String] = []
        if resolution != "Original" {
            let height = resolution.hasSuffix("p") ? String(resolution.dropLast()) : resolution
            filters.append("scale=-2:\(height)")
        }
        if speed != "1" { filters.append("setpts=PTS/\(speed)") }
        if !filters.isEmpty { args += ["-vf", filters.joined(separator: ",")] }
        if keepAudio { args += ["-filter:a", audioTempoFilter(Double(speed) ?? 1), "-c:a", "aac", "-b:a", "192k"] } else { args += ["-an"] }
        args += ["-movflags", "+faststart", "-progress", "pipe:1", "-nostats", temporary.path]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process(); process.executableURL = URL(fileURLWithPath: ffmpeg); process.arguments = args
            let pipe = Pipe(); process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                DispatchQueue.global(qos: .userInitiated).async {
                    let handle = pipe.fileHandleForReading
                    while true {
                        guard let data = try? handle.read(upToCount: 4096), !data.isEmpty else { break }
                        if let text = String(data: data, encoding: .utf8), let line = text.split(separator: "\n").first(where: { $0.hasPrefix("out_time_ms=") }), let micros = Double(line.dropFirst(12)) {
                            DispatchQueue.main.async { if index < self.videos.count { self.videos[index].progress = min(0.92, 0.15 + micros / 1_000_000_000) } }
                        }
                    }
                    process.waitUntilExit()
                    DispatchQueue.main.async {
                        if process.terminationStatus == 0 { continuation.resume() }
                        else { continuation.resume(throwing: ConversionError.message("FFmpeg could not process \(input.lastPathComponent)")) }
                    }
                }
            } catch { continuation.resume(throwing: error) }
        }
        // A hard link claims the final name without replacing an existing file, even if
        // another conversion creates it between the existence check and the link.
        let manager = FileManager.default
        var candidate = output
        var suffix = 1
        while true {
            do {
                try manager.linkItem(at: temporary, to: candidate)
                return candidate
            } catch {
                guard manager.fileExists(atPath: candidate.path) else { throw error }
                candidate = output.deletingLastPathComponent().appendingPathComponent("\(output.deletingPathExtension().lastPathComponent) (\(suffix)).mp4")
                suffix += 1
            }
        }
    }

    private func audioTempoFilter(_ speed: Double) -> String {
        var remaining = speed; var stages: [String] = []
        while remaining > 2 { stages.append("atempo=2"); remaining /= 2 }
        while remaining < 0.5 { stages.append("atempo=0.5"); remaining /= 0.5 }
        stages.append("atempo=\(remaining)"); return stages.joined(separator: ",")
    }

    private func formattedSize(_ url: URL) -> String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private func revealInFinder(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    private static func findHomebrew() -> String? {
        executablePaths(named: "brew").first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    private static func findFFmpeg() -> String? {
        executablePaths(named: "ffmpeg").first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    private static func findFFprobe() -> String? {
        executablePaths(named: "ffprobe").first { FileManager.default.isExecutableFile(atPath: $0) }
    }
    private static func executablePaths(named name: String) -> [String] {
        let standard = ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"]
        let fromPath = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map { String($0) + "/\(name)" }
        return standard + fromPath
    }
}

private struct ConfigFrame: ViewModifier {
    let title: String
    let icon: String
    let height: CGFloat
    let scale: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    private var background: Color { colorScheme == .dark ? Color(red: 0.075, green: 0.082, blue: 0.095) : Color(red: 0.94, green: 0.95, blue: 0.97) }
    private var border: Color { colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.14) }
    private var labelText: Color { colorScheme == .dark ? Color.white.opacity(0.70) : Color.black.opacity(0.68) }

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8 * scale).padding(.top, 16 * scale)
            .frame(height: height * scale, alignment: .top)
            .background(background.opacity(0.01))
            .overlay(RoundedRectangle(cornerRadius: 9 * scale).strokeBorder(border, lineWidth: 1))
            .overlay(alignment: .topLeading) {
                Label(title, systemImage: icon)
                    .font(.system(size: 11 * scale, weight: .medium))
                    .foregroundStyle(labelText)
                    .padding(.horizontal, 5 * scale)
                    .background(background)
                    .offset(x: 10 * scale, y: -7 * scale)
            }
            .padding(.top, 8 * scale)
    }
}

private extension View {
    func configFrame(_ title: String, icon: String, height: CGFloat, scale: CGFloat) -> some View {
        modifier(ConfigFrame(title: title, icon: icon, height: height, scale: scale))
    }
}

private struct StableInput: NSViewRepresentable {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme
    let scale: CGFloat
    let onFocus: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.lineBreakMode = .byClipping
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        let font = NSFont.monospacedSystemFont(ofSize: 12 * scale, weight: .regular)
        field.font = font
        field.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        field.textColor = colorScheme == .dark ? NSColor.white.withAlphaComponent(0.92) : NSColor.labelColor
        field.placeholderAttributedString = NSAttributedString(string: "Custom", attributes: [
            .font: font,
            .foregroundColor: colorScheme == .dark ? NSColor.white.withAlphaComponent(0.42) : NSColor.secondaryLabelColor
        ])
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: StableInput
        init(_ parent: StableInput) { self.parent = parent }
        func controlTextDidBeginEditing(_ notification: Notification) {
            if let field = notification.object as? NSTextField,
               let editor = field.currentEditor() as? NSTextView {
                editor.font = field.font
                editor.textColor = field.textColor
            }
            parent.onFocus()
        }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            control.window?.makeFirstResponder(nil)
            return true
        }
    }
}

private struct SettingHover: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(hovering ? (colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.07)) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovering = $0 }
    }
}

private struct FolderHover: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false
    func body(content: Content) -> some View {
        content
            .background(hovering ? (colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.10)) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onHover { hovering = $0 }
    }
}

struct FlowButtons: Layout {
    let scale: CGFloat
    let columns: Int
    let hasCustom: Bool
    var spacing: CGFloat = 4
    private var gap: CGFloat { spacing * scale }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for (index, item) in result.items.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + item.point.x, y: bounds.minY + item.point.y),
                                  proposal: ProposedViewSize(width: item.width, height: item.height))
        }
    }
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, items: [(point: CGPoint, width: CGFloat, height: CGFloat)]) {
        let measured = subviews.map { $0.sizeThatFits(.unspecified) }
        let fallback = measured.prefix(columns).reduce(CGFloat(0)) { $0 + $1.width } + gap * CGFloat(max(0, columns - 1))
        let width = proposal.width ?? fallback
        var items: [(point: CGPoint, width: CGFloat, height: CGFloat)] = []
        var index = 0
        var y: CGFloat = 0
        while index < subviews.count {
            var count = min(columns, subviews.count - index)
            while count > 1 && measured[index..<(index + count)].reduce(CGFloat(0), { $0 + $1.width }) + gap * CGFloat(count - 1) > width {
                count -= 1
            }
            let range = index..<(index + count)
            let total = range.reduce(CGFloat(0)) { $0 + measured[$1].width } + gap * CGFloat(count - 1)
            let free = max(0, width - total)
            let expandLast = hasCustom && index + count == subviews.count
            let rowHeight = range.map { measured[$0].height }.max() ?? 0
            var x: CGFloat = 0
            for i in range {
                let extra = expandLast ? (i == subviews.count - 1 ? free : 0) : free / CGFloat(count)
                let itemWidth = measured[i].width + extra
                items.append((CGPoint(x: x, y: y), itemWidth, rowHeight))
                x += itemWidth + gap
            }
            y += rowHeight + gap
            index += count
        }
        return (CGSize(width: width, height: max(0, y - gap)), items)
    }
}

struct WindowAspectRatio: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { context.coordinator.attach(to: view.window) }
    }

    final class Coordinator {
        private weak var attachedWindow: NSWindow?
        private var resizeObserver: NSObjectProtocol?

        func attach(to window: NSWindow?) {
            guard let window, attachedWindow !== window else { return }
            attachedWindow = window
            window.contentAspectRatio = NSSize(width: 820, height: 650)
            enforceMinimum(on: window)

            // SwiftUI resets NSWindow.minSize after its initial layout and sometimes
            // while resizing. Enforce the minimum on the actual window, not the
            // GeometryReader: the latter must always see the real viewport size.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self, weak window] in
                guard let self, let window else { return }
                self.enforceMinimum(on: window)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self, weak window] in
                guard let self, let window else { return }
                self.enforceMinimum(on: window)
            }
            resizeObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self, weak window] _ in
                DispatchQueue.main.async { [weak self, weak window] in
                    guard let self, let window else { return }
                    self.enforceMinimum(on: window)
                }
            }
            window.makeFirstResponder(nil)
        }

        private func enforceMinimum(on window: NSWindow) {
            let content = NSSize(width: 750, height: 595)
            let minimum = window.frameRect(forContentRect: NSRect(origin: .zero, size: content)).size
            window.contentMinSize = content
            window.minSize = minimum
            let frame = window.frame
            guard frame.width < minimum.width - 1 || frame.height < minimum.height - 1 else { return }
            let width = max(frame.width, minimum.width)
            let height = max(frame.height, minimum.height)
            window.setFrame(NSRect(x: frame.minX, y: frame.maxY - height, width: width, height: height), display: true)
        }

        deinit { if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) } }
    }
}

enum ConversionError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
