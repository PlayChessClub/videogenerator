import SwiftUI

struct SettingsView: View {
    @ObservedObject private var s = AppSettings.shared
    @State private var revealKey = false
    @State private var savedFlash = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !AppSettings.shared.hasKey {
                    Label("尚未配置 API Key，生成功能将不可用。", systemImage: "exclamationmark.triangle")
                        .foregroundColor(Pal.orange).padding(10)
                        .warnBanner
                }

                GlassCard("API Key", subtitle: "通义千问 / DashScope 密钥，仅存于本机钥匙串") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Group {
                                if revealKey {
                                    TextField("sk-…", text: $s.apiKey)
                                } else {
                                    SecureField("sk-…", text: $s.apiKey)
                                }
                            }
                            .textFieldStyle(.plain)
                            .monospacedFont(13)
                            .padding(10)
                            .glassField
                            Button { revealKey.toggle() } label: {
                                Image(systemName: revealKey ? "eye.slash" : "eye")
                            }.glassButton().fixedSize()
                        }
                        HStack(spacing: 10) {
                            Button {
                                s.save()
                                savedFlash = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedFlash = false }
                            } label: {
                                Label("保存到钥匙串", systemImage: "lock.badge.checkmark")
                            }.glassButton(prominent: true)
                            if savedFlash {
                                Label("已保存", systemImage: "checkmark.circle.fill").foregroundColor(Pal.green)
                            }
                            Spacer()
                            Link("获取 API Key ↗",
                                 destination: URL(string: "https://bailian.console.aliyun.com/?apiKey=1")!)
                        }
                        Text("提示：在阿里云百炼控制台创建 DashScope API Key（sk- 开头）。更换 Key 后立即生效，无需重启。")
                            .font(.caption).foregroundColor(Pal.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(alignment: .top, spacing: 20) {
                    GlassCard("接入端点", subtitle: "默认指向中国区公共端点") {
                        VStack(alignment: .leading, spacing: 8) {
                            LabeledValue("HTTP", DashScope.httpBase)
                            LabeledValue("WebSocket", DashScope.wsBase)
                        }
                    }
                    GlassCard("固定模型（不可更改）", subtitle: "锁定以下模型以保证兼容性") {
                        VStack(spacing: 8) {
                            ModelRow(symbol: "photo.on.rectangle", tint: Pal.teal, name: "文生图", model: FixedModel.imageModels[0])
                            ModelRow(symbol: "waveform.circle.fill", tint: Pal.teal, name: "语音合成", model: FixedModel.tts)
                            ModelRow(symbol: "video.fill", tint: Pal.purple, name: "图生视频", model: FixedModel.videoI2V)
                            ModelRow(symbol: "person.crop.circle.badge.checkmark", tint: Pal.orange, name: "音色复刻", model: FixedModel.voiceEnrollment)
                        }
                    }
                }

                Spacer(minLength: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(4)
        }
        .hideScrollBackground()
    }
}

struct LabeledValue: View {
    let label: String; let value: String
    init(_ l: String, _ v: String) { label = l; value = v }
    var body: some View {
        HStack(alignment: .top) {
            Text(label).font(.caption).frame(width: 76, alignment: .leading).foregroundColor(Pal.muted)
            Text(value).monospacedFont(11).selectableText()
            Spacer()
        }
    }
}

struct ModelRow: View {
    let symbol: String; let tint: Color; let name: String; let model: String
    var body: some View {
        HStack {
            Image(systemName: symbol).foregroundColor(tint).frame(width: 24)
            Text(name).frame(width: 80, alignment: .leading)
            Text(model).monospacedFont(13)
            Spacer()
            Image(systemName: "lock.fill").foregroundColor(Pal.muted).font(.caption)
        }
        .padding(10)
        .glassRowStyle
    }
}
