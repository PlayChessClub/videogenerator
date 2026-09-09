import Foundation
import SwiftUI

// 产物保存位置管理：
// - 默认：按类型落到 macOS 系统标准目录（影片 / 图片 / 音乐）下的 ClipForge 子文件夹
// - 自定义：用户指定一个根文件夹，产物按类型存到 <根>/ClipForge/视频、图片、语音
// 应用为非沙盒，可直接访问用户选择的目录（路径持久化在 UserDefaults）。

enum MediaKind: String, CaseIterable, Identifiable {
    case video, image, audio

    var id: String { rawValue }

    /// 默认使用的系统标准目录
    var systemSearchPath: FileManager.SearchPathDirectory {
        switch self {
        case .video: return .moviesDirectory
        case .image: return .picturesDirectory
        case .audio: return .musicDirectory
        }
    }

    /// 自定义根目录下的子文件夹名
    var folderName: String {
        switch self {
        case .video: return "视频"
        case .image: return "图片"
        case .audio: return "语音"
        }
    }

    var label: String {
        switch self {
        case .video: return "视频"
        case .image: return "图片"
        case .audio: return "语音"
        }
    }

    var symbol: String {
        switch self {
        case .video: return "film"
        case .image: return "photo.on.rectangle"
        case .audio: return "waveform"
        }
    }

    var tint: Color {
        switch self {
        case .video: return Pal.purple
        case .image: return Pal.teal
        case .audio: return Pal.orange
        }
    }
}

final class DownloadLocation: ObservableObject {
    static let shared = DownloadLocation()

    private let rootKey = "clipforge.downloadRoot"

    /// nil 表示使用系统标准目录（默认）
    @Published var customRoot: URL? {
        didSet { persist() }
    }

    var isCustom: Bool { customRoot != nil }

    private init() {
        if let s = UserDefaults.standard.string(forKey: rootKey), !s.isEmpty {
            customRoot = URL(fileURLWithPath: (s as NSString).expandingTildeInPath, isDirectory: true)
        }
    }

    // MARK: - 目录计算

    /// 某类产物的保存目录（自动创建）
    func dir(for kind: MediaKind) -> URL {
        let base: URL
        if let root = customRoot {
            base = root
                .appendingPathComponent("ClipForge", isDirectory: true)
                .appendingPathComponent(kind.folderName, isDirectory: true)
        } else {
            base = FileManager.default.urls(for: kind.systemSearchPath, in: .userDomainMask)[0]
                .appendingPathComponent("ClipForge", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// 用于展示的短路径（家目录缩写为 ~）
    func displayPath(for kind: MediaKind) -> String {
        abbrev(dir(for: kind).path)
    }

    func displayRoot() -> String {
        if let root = customRoot { return abbrev(root.path) }
        return "系统目录（影片 / 图片 / 音乐）"
    }

    private func abbrev(_ path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    // MARK: - 变更

    func setCustom(_ url: URL) {
        customRoot = url
    }

    func resetToDefault() {
        customRoot = nil
    }

    /// 弹出访达选目录面板；返回是否选择了新位置
    @discardableResult
    func chooseViaPanel() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择 ClipForge 产物的保存位置"
        panel.prompt = "选择"
        if let root = customRoot { panel.directoryURL = root }
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        setCustom(url)
        return true
    }

    /// 在访达中显示某类产物的目录
    func reveal(_ kind: MediaKind) {
        NSWorkspace.shared.activateFileViewerSelecting([dir(for: kind)])
    }

    private func persist() {
        if let root = customRoot {
            UserDefaults.standard.set(root.path, forKey: rootKey)
        } else {
            UserDefaults.standard.removeObject(forKey: rootKey)
        }
    }
}
