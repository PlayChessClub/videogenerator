import SwiftUI

// MARK: - Liquid Glass 组件库（兼容 macOS 11+；26 上为真·Liquid Glass）

/// 卡片容器：标题 + 内容，浮于液态玻璃面板上
struct GlassCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundColor(Pal.muted)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel
    }
}

/// 应用背景：柔和渐变光斑，衬托玻璃折射
struct AuroraBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Pal.purple.opacity(0.10), Pal.teal.opacity(0.08)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(Pal.purple.opacity(0.28))
                .frame(width: 520, height: 520).blur(radius: 110)
                .offset(x: -300, y: -220)
            Circle().fill(Pal.teal.opacity(0.25))
                .frame(width: 480, height: 480).blur(radius: 110)
                .offset(x: 330, y: 180)
            Circle().fill(Pal.orange.opacity(0.18))
                .frame(width: 420, height: 420).blur(radius: 120)
                .offset(x: 60, y: 320)
        }
        .ignoresSafeArea()
    }
}

/// 状态点（绿/黄/红）
struct StatusDot: View {
    enum Tone { case ok, warn, error, idle
        var color: Color {
            switch self {
            case .ok: return Pal.green
            case .warn: return Pal.orange
            case .error: return Pal.red
            case .idle: return Pal.muted
            }
        }
    }
    let tone: Tone
    var body: some View {
        Circle().fill(tone.color).frame(width: 8, height: 8)
    }
}

struct GlassPill: View {
    let text: String
    var body: some View {
        Text(text)
            .monospacedFont(11)
            .foregroundColor(Pal.muted)
            .glassChip
    }
}

/// 行内小表面（列表行、chip 行）
struct GlassRow<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(10)
            .background(VisualEffectView(kind: .chip))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// 顶部提示条
struct WarnBanner: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
            Text(text)
        }
        .foregroundColor(Pal.orange)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Pal.orange.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Pal.orange.opacity(0.5), lineWidth: 0.8))
    }
}
