import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import AppKit

// MARK: - 全局状态（顶栏菜单 / Tab 共享）

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var selectedTab: RootView.Tab = .voice
}

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
    func applicationWillFinishLaunching(_ notification: Notification) {
        // 在系统默认菜单出现之前注入中文顶栏
        MainMenuBuilder.install()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// MARK: - 中文顶栏（自定义 NSMainMenu）

private enum MainMenuBuilder {
    static func install() {
        let main = NSMenu()

        // ---- ClipForge（应用菜单，左侧第一项）----
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(make("关于 ClipForge", action: #selector(MenuAction.showAbout), key: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(make("设置…", action: #selector(MenuAction.openSettings), key: ","))
        appMenu.addItem(.separator())
        // 隐藏 / 退出走标准 NSApplication 选择子
        let hide = NSMenuItem(title: "隐藏 ClipForge", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(hide)
        let quit = NSMenuItem(title: "退出 ClipForge", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quit)

        // ---- 文件 ----
        main.addItem(menu("文件") { m in
            // 新建窗口交给系统处理（SwiftUI WindowGroup 自动支持 ⌘N）
            m.addItem(make("新建窗口", action: nil, key: "n"))
            m.addItem(.separator())
            m.addItem(make("关闭", action: #selector(NSWindow.performClose(_:)), key: "w"))
        })

        // ---- 编辑 ----
        main.addItem(menu("编辑") { m in
            let undo = NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
            m.addItem(undo)
            let redo = NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
            redo.keyEquivalentModifierMask = [.command, .shift]
            m.addItem(redo)
            m.addItem(.separator())
            m.addItem(make("剪切", action: #selector(NSText.cut(_:)), key: "x"))
            m.addItem(make("复制", action: #selector(NSText.copy(_:)), key: "c"))
            m.addItem(make("粘贴", action: #selector(NSText.paste(_:)), key: "v"))
            m.addItem(make("全选", action: #selector(NSText.selectAll(_:)), key: "a"))
        })

        // ---- 视图（切换功能 Tab + 打开设置）----
        main.addItem(menu("视图") { m in
            // 功能页 1-5：声音/图片/视频/时间线/账单
            let funcTabs = RootView.Tab.allCases.filter { $0 != .settings }
            for (i, tab) in funcTabs.enumerated() {
                let key = "\(i + 1)"
                let item = NSMenuItem(title: tab.rawValue, action: #selector(MenuAction.switchTab(_:)), keyEquivalent: key)
                item.target = MenuAction.shared
                item.representedObject = tab.rawValue
                m.addItem(item)
            }
            m.addItem(.separator())
            // 设置（⌘,），与顶栏的「设置」胶囊指向同一 tab
            let s = NSMenuItem(title: "设置…", action: #selector(MenuAction.openSettings), keyEquivalent: ",")
            s.target = MenuAction.shared
            m.addItem(s)
        })

        // ---- 窗口 ----
        main.addItem(menu("窗口") { m in
            m.addItem(make("最小化", action: #selector(NSWindow.performMiniaturize(_:)), key: "m"))
            m.addItem(make("缩放",       action: #selector(NSWindow.performZoom(_:)),       key: ""))
        })
        // 让窗口菜单自动填充「窗口列表」
        if let winItem = main.item(withTitle: "窗口"), let winMenu = winItem.submenu {
            NSApp.windowsMenu = winMenu
        }

        // ---- 帮助 ----
        main.addItem(menu("帮助") { m in
            let h = NSMenuItem(title: "ClipForge 帮助", action: nil, keyEquivalent: "?")
            m.addItem(h)
        })
        if let helpItem = main.item(withTitle: "帮助"), let helpMenu = helpItem.submenu {
            NSApp.helpMenu = helpMenu
        }

        NSApp.mainMenu = main
    }

    /// 创建一个顶级菜单项并附上子菜单构造闭包
    private static func menu(_ title: String, build: (NSMenu) -> Void) -> NSMenuItem {
        let item = NSMenuItem()
        let m = NSMenu(title: title)
        build(m)
        item.submenu = m
        return item
    }

    private static func make(_ title: String, action: Selector?, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if let action, NSClassFromString("ClipForgeAI.MenuAction") != nil {
            item.target = MenuAction.shared
        }
        return item
    }
}

/// 菜单动作分发（与 SwiftUI 状态通信）
@MainActor
final class MenuAction: NSObject {
    static let shared = MenuAction()

    @objc func switchTab(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let tab = RootView.Tab(rawValue: raw) else { return }
        AppState.shared.selectedTab = tab
    }

    @objc func openSettings() {
        AppState.shared.selectedTab = .settings
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}

// MARK: - 根视图

struct RootView: View {
    @ObservedObject private var state = AppState.shared

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 14) {
                TopTabBar(selection: $state.selectedTab)
                ZStack {
                    switch state.selectedTab {
                    case .voice:    VoiceStudioView().transition(.opacity)
                    case .image:    ImageStudioView().transition(.opacity)
                    case .video:    VideoStudioView().transition(.opacity)
                    case .timeline: TimelineView().transition(.opacity)
                    case .bill:     BillView().transition(.opacity)
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

extension RootView {
    enum Tab: String, CaseIterable, Identifiable {
        case voice = "声音工作室"
        case image = "图片生成"
        case video = "视频生成"
        case timeline = "剪辑时间线"
        case bill = "账单"
        case settings = "设置"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .voice:    return "waveform"
            case .image:    return "photo.on.rectangle"
            case .video:    return "film"
            case .timeline: return "scissors"
            case .bill:     return "yensign.circle"
            case .settings: return "gearshape"
            }
        }
    }
}

/// 顶部自绘玻璃 TabBar（v1.5 布局）：所有功能页 + 设置 平铺成一条等高铁轨胶囊
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
    /// 某类产物的保存目录：默认系统标准目录（影片/图片/音乐），
    /// 用户在设置里自定义根文件夹后则存到 <根>/ClipForge/<类型>
    static func outputDir(_ kind: MediaKind) -> URL {
        DownloadLocation.shared.dir(for: kind)
    }
}
