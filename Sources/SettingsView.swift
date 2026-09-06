import SwiftUI

struct SettingsView: View {
    @ObservedObject private var s = AppSettings.shared
    @State private var revealKey = false
    @State private var savedFlash = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                GlassCard("API Key", subtitle: "通义千问 / DashScope 密钥，仅存于本机钥匙串") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Group {
                                if revealKey {
                                    TextField("sk-…", text: $s.apiKey)
                                } else {
                                    SecureField("sk-…", text: $s.apiKey)
                                }
                            }
                            .textFieldStyle(.plain)
                            .font(.body.monospaced())
                            .padding(10)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                            Button { revealKey.toggle() } label: {
                                Image(systemName: revealKey ? "eye.slash" : "eye")
                            }.buttonStyle(.glass).fixedSize()
                        }
                        HStack {
                            Button {
                                s.save()
                                savedFlash = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedFlash = false }
                            } label: {
                                Label("保存到钥匙串", systemImage: "lock.badge.checkmark")
                            }.buttonStyle(.glassProminent)
                            if savedFlash {
                                Label("已保存", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                            Spacer()
                            Link("获取 API Key ↗",
                                 destination: URL(string: "https://bailian.console.aliyun.com/?apiKey=1")!)
                        }
                        Text("提示：在阿里云百炼控制台创建 DashScope API Key（sk- 开头）。更换 Key 后立即生效，无需重启。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                GlassCard("接入端点", subtitle: "默认指向中国区公共端点") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledValue("HTTP", DashScope.httpBase)
                        LabeledValue("WebSocket", DashScope.wsBase)
                    }
                }
            }

            GlassCard("固定模型（不可更改）", subtitle: "ClipForge 锁定以下模型以保证兼容性") {
                VStack(spacing: 8) {
                    ModelRow(symbol: "waveform.circle.fill", tint: .teal, name: "语音合成", model: FixedModel.tts)
                    ModelRow(symbol: "video.fill", tint: .purple, name: "图生视频", model: FixedModel.videoI2V)
                    ModelRow(symbol: "person.crop.circle.badge.checkmark", tint: .orange, name: "音色复刻", model: FixedModel.voiceEnrollment)
                }
            }

            Spacer()
        }
        .padding(4)
    }
}

struct LabeledValue: View {
    let label: String; let value: String
    init(_ l: String, _ v: String) { label = l; value = v }
    var body: some View {
        HStack(alignment: .top) {
            Text(label).font(.caption).frame(width: 76, alignment: .leading).foregroundStyle(.secondary)
            Text(value).font(.caption.monospaced()).textSelection(.enabled)
            Spacer()
        }
    }
}

struct ModelRow: View {
    let symbol: String; let tint: Color; let name: String; let model: String
    var body: some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(tint).frame(width: 24)
            Text(name).frame(width: 80, alignment: .leading)
            Text(model).font(.body.monospaced())
            Spacer()
            Image(systemName: "lock.fill").foregroundStyle(.secondary).font(.caption)
        }
        .padding(10)
        .glassEffect(.identity, in: .rect(cornerRadius: 12))
    }
}
