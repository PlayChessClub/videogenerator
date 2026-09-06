import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

@main
struct ClipForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup("ClipForge · AI 视频编辑助手") {
            RootView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 1120, height: 740)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct RootView: View {
    @State private var selection: Tab = .voice
    enum Tab: String, CaseIterable, Identifiable {
        case voice = "声音工作室"
        case video = "视频生成"
        case timeline = "剪辑时间线"
        case settings = "设置"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .voice: return "waveform"
            case .video: return "film"
            case .timeline: return "scissors"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        ZStack {
            AuroraBackground()
            TabView(selection: $selection) {
                VoiceStudioView().tabItem { Label(Tab.voice.rawValue, systemImage: Tab.voice.symbol) }.tag(Tab.voice)
                VideoStudioView().tabItem { Label(Tab.video.rawValue, systemImage: Tab.video.symbol) }.tag(Tab.video)
                TimelineView().tabItem { Label(Tab.timeline.rawValue, systemImage: Tab.timeline.symbol) }.tag(Tab.timeline)
                SettingsView().tabItem { Label(Tab.settings.rawValue, systemImage: Tab.settings.symbol) }.tag(Tab.settings)
            }
            .padding(24)
        }
    }
}

// MARK: - 通用小件

@MainActor
final class Player: ObservableObject {
    static let shared = Player()
    private var player: AVAudioPlayer?
    @Published var playingName: String? = nil

    func play(name: String, data: Data) {
        stop()
        do {
            player = try AVAudioPlayer(data: data)
            player?.delegate = helper
            player?.play()
            playingName = name
        } catch {
            playingName = nil
        }
    }

    func play(name: String, url: URL) {
        stop()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = helper
            player?.play()
            playingName = name
        } catch {
            playingName = nil
        }
    }

    func stop() {
        player?.stop(); player = nil; playingName = nil
    }

    private let helper = PlayerHelper()
}

final class PlayerHelper: NSObject, AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in Player.shared.playingName = nil }
    }
}

struct FilePicker {
    static func pick(types: [UTType]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = types
        return panel.runModal() == .OK ? panel.url : nil
    }
    static func save(types: [UTType], suggestion: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestion
        panel.allowedContentTypes = types
        return panel.runModal() == .OK ? panel.url : nil
    }
    static func outputDir() -> URL {
        let base = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipForge", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
}
