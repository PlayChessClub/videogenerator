import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

@main
struct ClipForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 960, idealWidth: 1120, minHeight: 640, idealHeight: 740)
        }
        .windowStyle(.hiddenTitleBar)
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
        case image = "图片生成"
        case video = "视频生成"
        case timeline = "剪辑时间线"
        case settings = "设置"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .voice: return "waveform"
            case .image: return "photo.on.rectangle"
            case .video: return "film"
            case .timeline: return "scissors"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 14) {
                TopTabBar(selection: $selection)
                ZStack {
                    switch selection {
                    case .voice: VoiceStudioView().transition(.opacity)
                    case .image: ImageStudioView().transition(.opacity)
                    case .video: VideoStudioView().transition(.opacity)
                    case .timeline: TimelineView().transition(.opacity)
                    case .settings: SettingsView().transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .frame(minWidth: 980, minHeight: 640)
    }
}

/// 顶部自绘玻璃 TabBar：呼吸空间 + 容器阴影 + 选中态高亮
private struct TopTabBar: View {
    @Binding var selection: RootView.Tab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(RootView.Tab.allCases) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selection = tab }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab.symbol).font(.system(size: 13, weight: .medium))
                        Text(tab.rawValue).font(.system(size: 13.5, weight: .medium))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .foregroundColor(selection == tab ? .white : .primary.opacity(0.78))
                    .background(
                        Group {
                            if selection == tab {
                                Capsule().fill(Pal.purple)
                            } else {
                                Capsule().fill(Color.primary.opacity(0.05))
                            }
                        }
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            selection == tab ? Color.clear : Color.primary.opacity(0.08),
                            lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .padding(6)
        .background(tabBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
    }

    /// 26 用 Liquid Glass；低版本用 NSVisualEffectView 毛玻璃
    @ViewBuilder
    private var tabBarBackground: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: 14).fill(.clear)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14))
        } else {
            VisualEffectView(kind: .chip)
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
