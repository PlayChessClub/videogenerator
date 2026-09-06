import SwiftUI

// MARK: - Liquid Glass 组件库

struct GlassPanel: ViewModifier {
    var interactive: Bool = false
    func body(content: Content) -> some View {
        content
            .padding(18)
            .glassEffect(interactive ? .regular.interactive() : .regular, in: .rect(cornerRadius: 22))
    }
}

extension View {
    func glassPanel(interactive: Bool = false) -> some View {
        modifier(GlassPanel(interactive: interactive))
    }
}

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
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel()
    }
}

/// 应用背景：柔和渐变光斑，衬托玻璃折射
struct AuroraBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Circle().fill(Color(red: 0.55, green: 0.45, blue: 0.95).opacity(0.28))
                .frame(width: 520, height: 520).blur(radius: 110)
                .offset(x: -300, y: -220)
            Circle().fill(Color(red: 0.20, green: 0.70, blue: 0.85).opacity(0.25))
                .frame(width: 480, height: 480).blur(radius: 110)
                .offset(x: 330, y: 180)
            Circle().fill(Color(red: 0.95, green: 0.55, blue: 0.40).opacity(0.18))
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
            case .ok: return Color(red: 0.20, green: 0.70, blue: 0.35)
            case .warn: return Color(red: 0.90, green: 0.65, blue: 0.15)
            case .error: return Color(red: 0.85, green: 0.25, blue: 0.25)
            case .idle: return .secondary
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
            .font(.caption.monospaced())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .glassEffect(.identity, in: .capsule)
            .foregroundStyle(.secondary)
    }
}
