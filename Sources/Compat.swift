import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

// MARK: - 兼容调色板（Color.purple 等命名色为 macOS 12+，这里用显式 RGB 以便 macOS 11）

enum Pal {
    static let purple = Color(red: 0.42, green: 0.35, blue: 0.82)
    static let teal   = Color(red: 0.12, green: 0.60, blue: 0.55)
    static let orange = Color(red: 0.90, green: 0.55, blue: 0.15)
    static let green  = Color(red: 0.20, green: 0.70, blue: 0.35)
    static let red    = Color(red: 0.85, green: 0.25, blue: 0.25)
    static let blue   = Color(red: 0.15, green: 0.45, blue: 0.85)
    static let muted  = Color.primary.opacity(0.55)
    static let faint  = Color.primary.opacity(0.34)
}

// MARK: - NSVisualEffectView 毛玻璃（macOS 11 路径）

struct VisualEffectView: NSViewRepresentable {
    enum Kind { case panel, field, chip, prominent }
    var kind: Kind

    private var material: NSVisualEffectView.Material {
        switch kind {
        case .panel:     return .hudWindow
        case .field:     return .underWindowBackground
        case .chip:      return .windowBackground
        case .prominent: return .selection
        }
    }
    private var corner: CGFloat {
        switch kind {
        case .panel: return 22; case .field: return 12; case .chip: return 8; case .prominent: return 14
        }
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .withinWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = corner
        v.layer?.masksToBounds = true
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.layer?.cornerRadius = corner
        v.state = .active
    }
}

// MARK: - 玻璃表面（macOS 26 用真·Liquid Glass，低版本用 NSVisualEffectView）

private enum GlassKind { case panel, field, chip, prominent }

@available(macOS 26.0, *)
private struct GlassSurface26: ViewModifier {
    let kind: GlassKind
    @ViewBuilder func body(content: Content) -> some View {
        switch kind {
        case .panel:
            content.padding(18).glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22))
        case .field:
            content.padding(10).glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12))
        case .chip:
            content.glassEffect(.identity, in: Capsule())
        case .prominent:
            content.padding(18).glassEffect(.regular.tint(Pal.purple.opacity(0.18)), in: RoundedRectangle(cornerRadius: 22))
        }
    }
}

private struct GlassSurfaceLegacy: ViewModifier {
    let kind: GlassKind
    @ViewBuilder func body(content: Content) -> some View {
        switch kind {
        case .panel:
            content.padding(18).background(VisualEffectView(kind: .panel)).overlay(border(22))
        case .field:
            content.padding(10).background(VisualEffectView(kind: .field)).overlay(border(12))
        case .chip:
            content.padding(.horizontal, 8).padding(.vertical, 3)
                .background(VisualEffectView(kind: .chip)).overlay(border(8))
        case .prominent:
            content.padding(18).background(VisualEffectView(kind: .prominent)).overlay(border(22))
        }
    }
    private func border(_ r: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: r).strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
    }
}

extension View {
    private func glassSurface(_ kind: GlassKind) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                modifier(GlassSurface26(kind: kind))
            } else {
                modifier(GlassSurfaceLegacy(kind: kind))
            }
        }
    }
    var glassPanel: some View { glassSurface(.panel) }
    var glassField: some View { glassSurface(.field) }
    var glassChip: some View { glassSurface(.chip) }
    var glassProminent: some View { glassSurface(.prominent) }
    /// 列表行小表面
    var glassRowStyle: some View {
        background(Pal.purple.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    /// 顶部警告条
    var warnBanner: some View {
        background(Pal.orange.opacity(0.12))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Pal.orange.opacity(0.5), lineWidth: 0.8))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    /// 时间线片段卡片
    var glassClipCard: some View {
        background(Pal.purple.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 玻璃按钮样式（26 用 .glass / .glassProminent，低版退化为全版本自绘胶囊）

@available(macOS 26.0, *)
private struct GlassStyle26: ViewModifier {
    let prominent: Bool
    func body(content: Content) -> some View {
        if prominent { content.buttonStyle(.glassProminent) }
        else { content.buttonStyle(.glass) }
    }
}

private struct CapsuleButtonStyle: ButtonStyle {
    let prominent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14).padding(.vertical, 7)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(prominent ? .white : .primary)
            .background(prominent ? AnyView(Pal.purple) : AnyView(VisualEffectView(kind: .chip)))
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5))
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

extension View {
    func glassButton(prominent: Bool = false) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                modifier(GlassStyle26(prominent: prominent))
            } else {
                buttonStyle(CapsuleButtonStyle(prominent: prominent))
            }
        }
    }
    /// 文字链接按钮（全版本 .link 可用）
    func linkStyle() -> some View { self.buttonStyle(.link) }
}

// MARK: - 常用文本/视图辅助（抹平 foregroundStyle / textSelection / 版本差异）

extension View {
    func selectableText() -> some View {
        Group {
            if #available(macOS 12.0, *) { self.textSelection(.enabled) }
            else { self }
        }
    }
    func hideScrollBackground() -> some View {
        Group {
            if #available(macOS 13.0, *) { self.scrollContentBackground(.hidden) }
            else { self }
        }
    }
    func switchToggle() -> some View {
        Group {
            if #available(macOS 13.0, *) { self.toggleStyle(.switch) }
            else { self.toggleStyle(.automatic) }
        }
    }
    func accentPurple() -> some View {
        Group {
            if #available(macOS 12.0, *) { self.tint(Pal.purple) }
            else { self.accentColor(Pal.purple) }
        }
    }
    func monospacedFont(_ size: CGFloat? = nil) -> some View {
        let f = NSFont.monospacedSystemFont(ofSize: size ?? NSFont.systemFontSize, weight: .regular)
        return self.font(Font(f))
    }
}

// MARK: - 网络兼容（异步 URLSession 方法为 macOS 12+，这里用传统 task + continuation）

enum Net {
    static func data(_ req: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { c in
            let t = URLSession.shared.dataTask(with: req) { d, r, e in
                if let e = e { c.resume(throwing: e) }
                else { c.resume(returning: (d ?? Data(), r!)) }
            }
            t.resume()
        }
    }
    static func upload(_ body: Data, _ req: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { c in
            let t = URLSession.shared.uploadTask(with: req, from: body) { d, r, e in
                if let e = e { c.resume(throwing: e) }
                else { c.resume(returning: (d ?? Data(), r!)) }
            }
            t.resume()
        }
    }
    static func download(_ req: URLRequest) async throws -> (URL, URLResponse) {
        try await withCheckedThrowingContinuation { c in
            let t = URLSession.shared.downloadTask(with: req) { url, r, e in
                if let e = e { c.resume(throwing: e) }
                else if let url = url { c.resume(returning: (url, r!)) }
                else { c.resume(throwing: URLError(.cannotOpenFile)) }
            }
            t.resume()
        }
    }
}

// MARK: - AVFoundation 兼容（异步 load* 为 macOS 12+，15+ 要求显式加载）

enum AVCompat {
    static func videoTrack(_ asset: AVURLAsset) async -> AVAssetTrack? {
        if #available(macOS 12.0, *) {
            return try? await asset.loadTracks(withMediaType: .video).first
        } else {
            return asset.tracks(withMediaType: .video).first
        }
    }
    static func audioTrack(_ asset: AVURLAsset) async -> AVAssetTrack? {
        if #available(macOS 12.0, *) {
            return try? await asset.loadTracks(withMediaType: .audio).first
        } else {
            return asset.tracks(withMediaType: .audio).first
        }
    }
    static func duration(_ asset: AVAsset) async -> CMTime {
        if #available(macOS 12.0, *) {
            return (try? await asset.load(.duration)) ?? .zero
        } else {
            return asset.duration
        }
    }
    static func naturalSize(_ t: AVAssetTrack) async -> CGSize {
        if #available(macOS 12.0, *) {
            return (try? await t.load(.naturalSize)) ?? .zero
        } else {
            return t.naturalSize
        }
    }
    static func preferredTransform(_ t: AVAssetTrack) async -> CGAffineTransform {
        if #available(macOS 12.0, *) {
            return (try? await t.load(.preferredTransform)) ?? .identity
        } else {
            return t.preferredTransform
        }
    }
}

// MARK: - UTType 兼容（避免 webp 等命名差异）

extension UTType {
    static var clipImage: UTType { UTType.image }
}
