import Foundation
import SwiftUI

// MARK: - 音色素材（Voice Samples）
//
// 两个来源：
//   1) 内置样例：随 .pkg 打进 Bundle（Contents/Resources/VoiceSamples/），只读，可试听 / 克隆；
//   2) 素材文件夹：默认 ~/Library/Application Support/ClipForge/VoiceSamples（设置页可改）。
//      「保存副本」把内置样例按用户昵称拷贝到这里（文件原样保留、可复用、可被用户自备文件扩充）；
//      手动放进该文件夹的 wav/mp3/m4a 会作为「用户素材」列出来。
// 规则：Bundle 永不写盘；写盘一律走素材文件夹拷贝；文件名净化 + 重名自动 -1。

/// 一枚音色素材（内置样例或用户素材文件夹里的音频）
struct VoiceSample: Identifiable, Equatable {
    /// 稳定 id：内置 = "builtin-<key>"；用户素材 = "user-<文件名>"
    let id: String
    /// 展示名（内置样例的默认名；用户素材为文件名去扩展名）
    let name: String
    /// 风格标签，如 ["中文", "女声", "播音"]
    let tags: [String]
    /// 来源与许可说明（内置样例填来源；用户素材填“用户自备”）
    let source: String
    /// 内置文件名（Bundle VoiceSamples/ 下）；nil = 用户素材
    let bundleFile: String?

    var isBuiltin: Bool { bundleFile != nil }
    var builtinKey: String? {
        guard id.hasPrefix("builtin-") else { return nil }
        return String(id.dropFirst("builtin-".count))
    }
}

/// 素材目录里单枚样例的解析结果（内置样例可能尚未/已经落到素材文件夹）
struct ResolvedSample: Identifiable {
    let sample: VoiceSample
    /// 可播放 / 可上传克隆的本地文件 URL（内置未落盘 → Bundle；已落盘或用户素材 → 素材文件夹）
    let fileURL: URL
    /// 是否已存在于素材文件夹（内置样例被保存副本后为 true）
    var materialized: Bool

    var id: String { sample.id }
}

enum VoiceKit {
    // MARK: - 内置样例定义
    //
    // bundleFile 必须与仓库 VoiceSamples/ 下的文件一致（build.sh 会把该目录拷进
    // Contents/Resources/VoiceSamples/）。缺文件的条目会被自动隐藏，不影响启动。
    struct BuiltinDef {
        let key: String          // 唯一 key，持久化昵称/映射用
        let bundleFile: String   // 如 "zh-female-01.wav"
        let name: String         // 默认展示名
        let tags: [String]
        let source: String       // 来源 + 许可证
    }

    /// 内置样音（与仓库 VoiceSamples/ 下的文件一一对应）。
    /// 素材来源：macOS 系统 `say` TTS 本机合成（Apple 系统语音 Reed/Sandy），
    /// 用户提供的《免费中文语音样音包》，无第三方版权、可自由作配音参考。
    static let builtinDefs: [BuiltinDef] = [
        BuiltinDef(key: "zh-male-broadcast",
                   bundleFile: "zh-male-broadcast-reed.wav",
                   name: "沉稳播音男声",
                   tags: ["中文", "男声", "播音"],
                   source: "macOS 系统 TTS（say · Reed）本机合成，可自由作配音/克隆参考（SOURCES.md）"),
        BuiltinDef(key: "zh-female-broadcast",
                   bundleFile: "zh-female-broadcast-sandy.wav",
                   name: "标准播音女声",
                   tags: ["中文", "女声", "播音"],
                   source: "macOS 系统 TTS（say · Sandy）本机合成，可自由作配音/克隆参考（SOURCES.md）"),
    ]

    // MARK: - 持久化 key

    private static let rootKey = "clipforge.voiceMaterialRoot"
    private static let namePrefix = "clipforge.voiceSampleName."   // + builtinKey
    private static let copyPrefix = "clipforge.voiceSampleCopy."   // + builtinKey → 素材夹里的文件名

    // MARK: - 素材文件夹（整体可自定义；只影响将来写入位置，不搬移旧文件）

    static var defaultMaterialRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipForge/VoiceSamples", isDirectory: true)
    }

    static var materialRoot: URL {
        if let s = UserDefaults.standard.string(forKey: rootKey), !s.isEmpty {
            return URL(fileURLWithPath: (s as NSString).expandingTildeInPath, isDirectory: true)
        }
        return defaultMaterialRoot
    }

    static var isMaterialRootDefault: Bool {
        materialRoot.standardizedFileURL.path == defaultMaterialRoot.standardizedFileURL.path
    }

    static func setMaterialRoot(_ url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        UserDefaults.standard.set(url.path, forKey: rootKey)
    }

    static func resetMaterialRoot() {
        UserDefaults.standard.removeObject(forKey: rootKey)
    }

    @discardableResult
    static func chooseMaterialRootViaPanel() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择音色素材保存目录（只影响将来保存的位置）"
        panel.prompt = "选择"
        panel.directoryURL = materialRoot
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        setMaterialRoot(url)
        return true
    }

    static func materialRootDisplay() -> String {
        abbrev(materialRoot.path)
    }

    static func revealMaterialRoot() {
        ensureMaterialDir()
        NSWorkspace.shared.activateFileViewerSelecting([materialRoot])
    }

    static func ensureMaterialDir() {
        try? FileManager.default.createDirectory(at: materialRoot, withIntermediateDirectories: true)
    }

    // MARK: - 昵称（仅内置样例持久化；用户素材直接改文件名）

    static func nickname(for sample: VoiceSample) -> String {
        guard let k = sample.builtinKey else { return sample.name }
        let s = UserDefaults.standard.string(forKey: namePrefix + k)
        return (s?.isEmpty ?? true) ? sample.name : s!
    }

    static func setNickname(_ nick: String, for sample: VoiceSample) {
        guard let k = sample.builtinKey else { return }
        let t = nick.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            UserDefaults.standard.removeObject(forKey: namePrefix + k)
            return
        }
        UserDefaults.standard.set(t, forKey: namePrefix + k)
        // 若已落盘到素材夹，同步把文件名改成新昵称
        if let mapped = mappedFileName(for: sample) {
            renameMaterialized(sample, from: mapped, to: t)
        }
    }

    /// 内置样例在素材夹中已保存的文件名（若有）
    private static func mappedFileName(for sample: VoiceSample) -> String? {
        guard let k = sample.builtinKey else { return nil }
        guard let f = UserDefaults.standard.string(forKey: copyPrefix + k) else { return nil }
        let url = materialRoot.appendingPathComponent(f)
        return FileManager.default.fileExists(atPath: url.path) ? f : nil
    }

    private static func renameMaterialized(_ sample: VoiceSample, from old: String, to newName: String) {
        let fm = FileManager.default
        let oldURL = materialRoot.appendingPathComponent(old)
        guard fm.fileExists(atPath: oldURL.path) else { return }
        let ext = (old as NSString).pathExtension
        let target = uniqueURL(in: materialRoot, base: newName, ext: ext)
        try? fm.moveItem(at: oldURL, to: target)
        if let k = sample.builtinKey {
            UserDefaults.standard.set(target.lastPathComponent, forKey: copyPrefix + k)
        }
    }

    // MARK: - 解析：内置（含落盘状态）+ 素材文件夹里的用户素材

    static func loadSamples() -> [ResolvedSample] {
        ensureMaterialDir()
        let fm = FileManager.default
        var out: [ResolvedSample] = []
        var mappedNames = Set<String>()

        for def in builtinDefs {
            let sample = VoiceSample(id: "builtin-\(def.key)", name: def.name,
                                     tags: def.tags, source: def.source,
                                     bundleFile: def.bundleFile)
            // 已落盘：用素材夹里的文件
            if let mapped = mappedFileName(for: sample) {
                mappedNames.insert(mapped)
                let url = materialRoot.appendingPathComponent(mapped)
                out.append(ResolvedSample(sample: sample, fileURL: url, materialized: true))
                continue
            }
            // 未落盘：用 Bundle（缺文件则跳过该条内置定义）
            guard let bundleURL = bundleURL(def.bundleFile) else { continue }
            out.append(ResolvedSample(sample: sample, fileURL: bundleURL, materialized: false))
        }

        // 素材文件夹：未在内置映射里的音频 → 用户素材
        if let files = try? fm.contentsOfDirectory(at: materialRoot,
                                                   includingPropertiesForKeys: nil) {
            let exts: Set<String> = ["wav", "mp3", "m4a", "aac", "caf"]
            for f in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard exts.contains(f.pathExtension.lowercased()),
                      !mappedNames.contains(f.lastPathComponent) else { continue }
                let base = f.deletingPathExtension().lastPathComponent
                let sample = VoiceSample(id: "user-\(f.lastPathComponent)", name: base,
                                         tags: ["本地"], source: "用户自备",
                                         bundleFile: nil)
                out.append(ResolvedSample(sample: sample, fileURL: f, materialized: true))
            }
        }
        return out
    }

    private static func bundleURL(_ file: String) -> URL? {
        Bundle.main.url(forResource: file, withExtension: nil)
            ?? Bundle.main.url(forResource: (file as NSString).deletingPathExtension,
                               withExtension: (file as NSString).pathExtension,
                               subdirectory: "VoiceSamples")
    }

    // MARK: - 保存副本到素材文件夹

    /// 把内置样例拷到素材文件夹，文件名 = 昵称（净化 + 重名去重 -1）
    @discardableResult
    static func materialize(_ resolved: ResolvedSample) -> URL? {
        let fm = FileManager.default
        ensureMaterialDir()
        let sample = resolved.sample
        guard let k = sample.builtinKey else { return resolved.fileURL }
        // 已落盘：直接返回
        if resolved.materialized, let mapped = mappedFileName(for: sample) {
            return materialRoot.appendingPathComponent(mapped)
        }
        let ext = resolved.fileURL.pathExtension.isEmpty ? "wav" : resolved.fileURL.pathExtension
        let target = uniqueURL(in: materialRoot, base: nickname(for: sample), ext: ext)
        do {
            try fm.copyItem(at: resolved.fileURL, to: target)
            UserDefaults.standard.set(target.lastPathComponent, forKey: copyPrefix + k)
            return target
        } catch {
            return nil
        }
    }

    /// 重命名用户素材（素材夹里的文件直接改名）
    @discardableResult
    static func renameUserFile(_ resolved: ResolvedSample, to newName: String) -> Bool {
        guard !resolved.sample.isBuiltin else { return false }
        let fm = FileManager.default
        let src = resolved.fileURL
        guard fm.fileExists(atPath: src.path) else { return false }
        let ext = src.pathExtension
        let target = uniqueURL(in: materialRoot, base: newName, ext: ext)
        return (try? fm.moveItem(at: src, to: target)) != nil
    }

    // MARK: - 工具

    private static func abbrev(_ path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private static func uniqueURL(in dir: URL, base rawBase: String, ext: String) -> URL {
        let base = sanitize(rawBase)
        let fm = FileManager.default
        var url = dir.appendingPathComponent(base + "." + ext)
        var n = 1
        while fm.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent("\(base)-\(n).\(ext)")
            n += 1
        }
        return url
    }

    /// 文件名净化：去掉 / : 控制字符与首尾空白（跨平台安全命名）
    static func sanitize(_ name: String) -> String {
        var t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbidden = CharacterSet(charactersIn: "/:\\")
            .union(.controlCharacters)
        t = t.components(separatedBy: forbidden).joined()
        return t.isEmpty ? "素材" : t
    }
}
