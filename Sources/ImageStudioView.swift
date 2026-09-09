import SwiftUI
import UniformTypeIdentifiers

// MARK: - 文生图 ViewModel

@MainActor
final class ImageStudioModel: ObservableObject {
    @Published var prompt: String = "一只橘猫坐在窗台上晒太阳，阳光透过纱窗洒下斑驳光影，温暖治愈的风格。"
    @Published var model: String = FixedModel.imageDefault
    @Published var size: String = "1024*1024"
    @Published var count: Int = 1
    @Published var promptExtend: Bool = true

    @Published var busy = false
    @Published var status: String = "就绪"
    @Published var error: String? = nil
    @Published var generated: [URL] = []   // 已下载到本地的图片

    /// 生成前 token 消耗确认
    let confirm = TokenConfirmModel()

    private let client = DashScopeClient.shared

    let sizes = ["1024*1024", "720*1280", "1280*720"]

    /// 入口：先弹额度确认，用户点「继续生成」后才真正调用
    func generate() {
        let p = prompt.trimmingCharacters(in: .whitespaces)
        if p.isEmpty { error = "请输入图片描述"; return }
        let est = TokenEstimator.estimateImage(model: model, size: size, n: count)
        confirm.confirmAndRun(est) { [weak self] in
            await self?.performGenerate(prompt: p)
        }
    }

    /// 确认后写入账单（记录本次估算明细）
    private func recordBill(prompt: String) {
        let est = TokenEstimator.estimateImage(model: model, size: size, n: count)
        let summary = String(prompt.prefix(60))
        let entry = BillEntry(
            action: "文生图", model: model, summary: summary,
            unitName: "张", unitCount: count,
            tokenMin: est.tokenMin, tokenMax: est.tokenMax,
            amountText: est.amount, detail: est.detail)
        BillStore.shared.add(entry)
    }

    private func performGenerate(prompt: String) async {
        error = nil; generated = []; busy = true
        status = "提交生成请求…"
        defer { busy = false }
        recordBill(prompt: prompt)
        do {
            let req = DashScopeClient.ImageRequest(
                prompt: prompt, model: model, size: size,
                n: count, promptExtend: promptExtend, watermark: false)
            let urls = try await client.submitImage(req)
            status = "已生成 \(urls.count) 张，下载中…"

            var saved: [URL] = []
            for (i, u) in urls.enumerated() {
                guard let remote = URL(string: u) else { continue }
                let dest = FilePicker.outputDir()
                    .appendingPathComponent("图片_\(Int(Date().timeIntervalSince1970))_\(i+1).png")
                try await client.download(remote, to: dest)
                saved.append(dest)
                LibraryStore.shared.add(MediaClip(kind: .image, name: dest.lastPathComponent, url: dest))
            }
            generated = saved
            status = saved.isEmpty ? "下载失败" : "完成 ✓ 共 \(saved.count) 张"
        } catch {
            self.error = error.localizedDescription
            status = "生成失败"
        }
    }
}

// MARK: - 文生图页

struct ImageStudioView: View {
    @StateObject private var m = ImageStudioModel()
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !settings.hasKey {
                        Label("尚未配置 API Key，请前往「设置」填写。", systemImage: "exclamationmark.triangle")
                            .foregroundColor(Pal.orange).padding(10)
                            .warnBanner
                    }

                    GlassCard("文生图", subtitle: "按张计费，生成前会提示预计消耗") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("图片描述").font(.caption).foregroundColor(Pal.muted)
                                Spacer()
                                Button {
                                    m.prompt = PromptBank.randomImage()
                                } label: {
                                    Label("试试手气", systemImage: "dice")
                                }.glassButton()
                            }
                            TextEditor(text: $m.prompt).frame(height: 90).hideScrollBackground()
                                .padding(8).glassField

                            // 模型名较长，用菜单避免撑爆布局；尺寸/张数用分段控件
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 10) {
                                    Text("模型").font(.caption).foregroundColor(Pal.muted)
                                        .frame(width: 32, alignment: .leading)
                                    Picker("", selection: $m.model) {
                                        ForEach(FixedModel.imageModels, id: \.self) { Text($0).tag($0) }
                                    }
                                    .pickerStyle(.menu)
                                    .labelsHidden()
                                    .frame(maxWidth: 220, alignment: .leading)
                                    Spacer()
                                }
                                HStack(spacing: 10) {
                                    Text("尺寸").font(.caption).foregroundColor(Pal.muted)
                                        .frame(width: 32, alignment: .leading)
                                    Picker("", selection: $m.size) {
                                        ForEach(m.sizes, id: \.self) { Text($0).tag($0) }
                                    }
                                    .pickerStyle(.segmented)
                                    .labelsHidden()
                                    .frame(maxWidth: 300, alignment: .leading)
                                    Spacer()
                                }
                                HStack(spacing: 10) {
                                    Text("张数").font(.caption).foregroundColor(Pal.muted)
                                        .frame(width: 32, alignment: .leading)
                                    Picker("", selection: $m.count) {
                                        ForEach([1, 2, 3, 4], id: \.self) { Text("\($0)张").tag($0) }
                                    }
                                    .pickerStyle(.segmented)
                                    .labelsHidden()
                                    .frame(maxWidth: 220, alignment: .leading)
                                    Spacer()
                                }
                            }

                            Toggle("智能扩写 prompt_extend", isOn: $m.promptExtend).switchToggle()

                            HStack {
                                Button { m.generate() } label: {
                                    Label("生成图片", systemImage: "photo.badge.plus")
                                }.glassButton(prominent: true).disabled(m.busy)
                                Spacer()
                            }

                            HStack { StatusDot(tone: m.busy ? .warn : (m.error == nil ? .ok : .error)); Text(m.status) }
                            if m.busy { ProgressView().progressViewStyle(.circular) }
                            if let e = m.error {
                                Text(e).font(.caption).foregroundColor(Pal.red).selectableText()
                            }
                        }
                    }

                    if !m.generated.isEmpty {
                        GlassCard("生成结果", subtitle: "已保存到 ~/Downloads/ClipForge 并收录素材库") {
                            ScrollView(.horizontal) {
                                HStack(spacing: 12) {
                                    ForEach(m.generated, id: \.self) { u in
                                        VStack(spacing: 6) {
                                            LocalImageView(url: u)
                                                .frame(width: 220, height: 220)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                            Text(u.lastPathComponent).font(.caption2).lineLimit(1)
                                                .frame(width: 220)
                                            HStack(spacing: 8) {
                                                Button("打开") { NSWorkspace.shared.open(u) }.glassButton()
                                                Button("显示") { NSWorkspace.shared.activateFileViewerSelecting([u]) }.glassButton()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .hideScrollBackground()

            TokenConfirmOverlay(model: m.confirm, title: "文生图")
        }
    }
}

/// 本地图片预览（用 NSImage 兼容 macOS 11，避免 AsyncImage 的版本限制）
private struct LocalImageView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> NSImageView {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        iv.image = NSImage(contentsOf: url)
        return iv
    }
    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSImage(contentsOf: url)
    }
}
