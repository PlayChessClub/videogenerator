import SwiftUI

struct SettingsView: View {
    @ObservedObject private var s = AppSettings.shared
    @ObservedObject private var dl = DownloadLocation.shared
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

                GlassCard("下载位置", subtitle: "整体设置一次，视频 / 图片 / 语音自动在同一根下分目录") {
                    VStack(alignment: .leading, spacing: 12) {
                        // 顶部：唯一入口，一次更改整个根目录
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "externaldrive.fill")
                                .foregroundColor(Pal.purple).frame(width: 20)
                            Text("保存根目录").font(.caption).foregroundColor(Pal.muted)
                                .frame(width: 76, alignment: .leading)
                            Text(dl.saveRootDisplay())
                                .monospacedFont(11).lineLimit(1).truncationMode(.middle).selectableText()
                            Spacer()
                            Button { dl.chooseViaPanel() } label: {
                                Label("更改…", systemImage: "folder")
                            }.glassButton(prominent: true)
                            if dl.isCustom {
                                Button { dl.resetToDefault() } label: {
                                    Label("恢复默认", systemImage: "arrow.uturn.left")
                                }.glassButton()
                            }
                        }
                        Divider().opacity(0.3)
                        // 派生预览：只读展示，跟随同一根目录，不可单类修改
                        ForEach(MediaKind.allCases) { k in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: k.symbol).foregroundColor(k.tint).frame(width: 20)
                                Text(k.label).font(.caption).foregroundColor(Pal.muted)
                                    .frame(width: 32, alignment: .leading)
                                Text(dl.displayPath(for: k))
                                    .monospacedFont(11).lineLimit(1).truncationMode(.middle).selectableText()
                                Spacer()
                                Button { dl.reveal(k) } label: {
                                    Image(systemName: "arrow.right.circle")
                                }.glassButton().fixedSize().help("在访达中显示")
                            }
                        }
                        Text(dl.isCustom
                             ? "视频 / 图片 / 语音始终一起保存在所选根目录下的 ClipForge / 视频、图片、语音 子目录，不能按类型分开设置；更改或恢复默认时三类会同时切换。"
                             : "默认使用系统标准目录：~/Movies、~/Pictures、~/Music 下的 ClipForge 文件夹；不能单独更改某一类。")
                            .font(.caption).foregroundColor(Pal.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                GlassCard("音色素材文件夹", subtitle: "内置样音副本与自备参考音频的存放处") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "waveform.path")
                                .foregroundColor(Pal.orange).frame(width: 20)
                            Text("素材目录").font(.caption).foregroundColor(Pal.muted)
                                .frame(width: 76, alignment: .leading)
                            Text(VoiceKit.materialRootDisplay())
                                .monospacedFont(11).lineLimit(1).truncationMode(.middle).selectableText()
                            Spacer()
                            Button { VoiceKit.chooseMaterialRootViaPanel() } label: {
                                Label("更改…", systemImage: "folder")
                            }.glassButton(prominent: true)
                            if !VoiceKit.isMaterialRootDefault {
                                Button { VoiceKit.resetMaterialRoot() } label: {
                                    Label("恢复默认", systemImage: "arrow.uturn.left")
                                }.glassButton()
                            }
                            Button { VoiceKit.revealMaterialRoot() } label: {
                                Image(systemName: "arrow.right.circle")
                            }.glassButton().fixedSize().help("在访达中显示")
                        }
                        Text("音色素材保存目录只影响「将来保存 / 导出」的位置，已有文件不会被搬移；默认：~/Library/Application Support/ClipForge/VoiceSamples。")
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
                    GlassCard("模型选择", subtitle: "语音合成与视频生成可在各工作室下拉选择；文生图与音色复刻为固定模型") {
                        VStack(spacing: 8) {
                            ModelRow(symbol: "photo.on.rectangle", tint: Pal.teal, name: "文生图（固定）", model: FixedModel.imageModels[0])
                            ModelRow(symbol: "waveform.circle.fill", tint: Pal.teal, name: "语音合成（可选，默认）", model: FixedModel.ttsDefault)
                            ModelRow(symbol: "video.fill", tint: Pal.purple, name: "视频生成（可选，默认）", model: FixedModel.videoI2V)
                            ModelRow(symbol: "person.crop.circle.badge.checkmark", tint: Pal.orange, name: "音色复刻（固定）", model: FixedModel.voiceEnrollment)
                        }
                    }
                }

                GlassCard("价目表", subtitle: "华北2（北京）按量付费 · 仅供参考，以官方账单为准") {
                    VStack(alignment: .leading, spacing: 16) {
                        PriceSection(title: "视频生成", symbol: "film",
                                     tint: Pal.purple, rows: PriceList.video,
                                     unitLabel: "元/秒")
                        PriceSection(title: "图片生成", symbol: "photo.on.rectangle",
                                     tint: Pal.teal, rows: PriceList.image,
                                     unitLabel: "元/张")
                        PriceSection(title: "语音", symbol: "waveform",
                                     tint: Pal.orange, rows: PriceList.audio,
                                     unitLabel: "元/万字符 · 按出账")
                        PriceSection(title: "向量 + 文本生成（试试手气 Pro）", symbol: "sparkles",
                                     tint: Pal.gold, rows: PriceList.vector,
                                     unitLabel: "元/千token")
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

// 价目表分组
struct PriceSection: View {
    let title: String; let symbol: String; let tint: Color; let rows: [PriceRow]
    /// 各小节统一单位（如「元/秒」「元/张」）；nil 表示由 row 自带
    let unitLabel: String?
    init(title: String, symbol: String, tint: Color, rows: [PriceRow], unitLabel: String? = nil) {
        self.title = title; self.symbol = symbol; self.tint = tint; self.rows = rows
        self.unitLabel = unitLabel
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol).foregroundColor(tint)
                Text(title).font(.subheadline).bold()
                if let u = unitLabel {
                    Text("（\(u)）")
                        .font(.caption).foregroundColor(Pal.muted)
                }
            }
            VStack(spacing: 0) {
                ForEach(rows) { r in
                    HStack(alignment: .firstTextBaseline) {
                        Text(r.name).frame(width: 92, alignment: .leading)
                            .font(.caption).foregroundColor(Pal.muted)
                        Text(r.model).monospacedFont(12)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(r.price).font(.caption).foregroundColor(Pal.green)
                    }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 10)
                    if r.id != rows.last?.id {
                        Divider().opacity(0.3)
                    }
                }
            }
            .glassRowStyle
        }
    }
}
