import SwiftUI
import UniformTypeIdentifiers

// MARK: - 声音工作室 ViewModel

@MainActor
final class VoiceStudioModel: ObservableObject {
    @Published var cloningURL: String = ""
    @Published var prefix: String = "myvoice"
    @Published var newVoiceId: String = ""
    @Published var voices: [[String: Any]] = []
    @Published var status: String = "就绪"
    @Published var busy = false
    @Published var error: String? = nil

    // 合成参数
    @Published var text: String = "大家好，欢迎来到我的频道，今天我们来聊聊人工智能如何改变视频创作。"
    @Published var selectedVoice: String = ""
    @Published var volume: Double = 50
    @Published var speechRate: Double = 1.0
    @Published var pitch: Double = 1.0
    @Published var instruction: String = ""

    @Published var lastAudioURL: URL? = nil
    @Published var progress: Double = 0

    /// 生成/克隆前 token 消耗确认
    let confirm = TokenConfirmModel()

    private let client = DashScopeClient.shared

    var voiceIds: [String] {
        voices.compactMap { $0["voice_id"] as? String }
    }

    func refreshVoices() async {
        do {
            voices = try await client.listVoices(prefix: prefix)
            status = "已加载 \(voices.count) 个音色"
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - 音色素材（内置样例 + 素材文件夹）

    @Published var samples: [ResolvedSample] = []

    /// 重新扫描内置样例与素材文件夹（同步、轻量）
    func loadSamples() {
        samples = VoiceKit.loadSamples()
    }

    /// 用音色素材（本地文件）发起克隆：与「用本地音频」同一条 上传→OSS→createVoice 链路
    func cloneFromSample(_ rs: ResolvedSample) {
        guard FileManager.default.fileExists(atPath: rs.fileURL.path) else {
            error = "素材文件不存在：\(rs.fileURL.path)"
            return
        }
        confirm.confirmAndRun(TokenEstimator.estimateVoiceClone()) { [weak self] in
            await self?.performCloneFromLocal(rs.fileURL)
        }
    }

    // 步骤一：从 URL 创建克隆音色（先确认再执行）
    func createVoice() {
        let url = cloningURL.trimmingCharacters(in: .whitespaces)
        if url.isEmpty { error = "请填写公网可访问的音频 URL"; return }
        confirm.confirmAndRun(TokenEstimator.estimateVoiceClone()) { [weak self] in
            await self?.performCreateVoice(url: url)
        }
    }

    private func performCreateVoice(url: String) async {
        error = nil
        recordCloneBill()
        busy = true; status = "提交音色克隆请求…"
        defer { busy = false }
        do {
            let vid = try await client.createVoice(targetModel: FixedModel.tts, prefix: prefix, url: url)
            newVoiceId = vid
            status = "已提交，正在轮询状态…"
            await pollUntilReady(vid: vid)
        } catch {
            self.error = error.localizedDescription
            status = "克隆失败"
        }
    }

    // 从本地音频上传克隆（先确认再执行）
    func pickLocalAudio() {
        guard let f = FilePicker.pick(types: [.audio, .wav, .mpeg4Audio]) else { return }
        confirm.confirmAndRun(TokenEstimator.estimateVoiceClone()) { [weak self] in
            await self?.performCloneFromLocal(f)
        }
    }

    private func performCloneFromLocal(_ f: URL) async {
        error = nil; busy = true
        recordCloneBill()
        status = "上传参考音频到临时 OSS…"
        defer { busy = false }
        do {
            let oss = try await client.uploadToOSS(model: FixedModel.tts, fileURL: f)
            cloningURL = oss
            status = "提交音色克隆请求…"
            let vid = try await client.createVoice(targetModel: FixedModel.tts, prefix: prefix, url: oss)
            newVoiceId = vid
            status = "已提交，正在轮询状态…"
            await pollUntilReady(vid: vid)
        } catch {
            self.error = error.localizedDescription
            status = "克隆失败"
        }
    }

    private func pollUntilReady(vid: String) async {
        for attempt in 1...30 {
            do {
                let info = try await client.queryVoice(voiceId: vid)
                let st = info["status"] as? String ?? "UNKNOWN"
                status = "轮询 \(attempt)/30 · 状态 \(st)"
                if st == "OK" {
                    status = "音色已就绪：\(vid)"
                    selectedVoice = vid
                    await refreshVoices()
                    return
                } else if st == "UNDEPLOYED" || st == "FAILED" {
                    error = "音色处理失败（\(st)），请检查音频质量后重试"
                    return
                }
            } catch {
                self.error = error.localizedDescription
            }
            try? await Task.sleep(nanoseconds: 10_000_000_000)
        }
        error = "轮询超时，音色仍未就绪"
    }

    // 删除音色
    func deleteVoice(_ vid: String) async {
        do {
            try await client.deleteVoice(voiceId: vid)
            if selectedVoice == vid { selectedVoice = "" }
            if newVoiceId == vid { newVoiceId = "" }
            await refreshVoices()
        } catch { self.error = error.localizedDescription }
    }

    // 合成（先确认 token 消耗再执行）
    func synthesize() {
        let voice = selectedVoice.isEmpty ? newVoiceId : selectedVoice
        if voice.isEmpty { error = "请先选择或创建一个音色"; return }
        if text.trimmingCharacters(in: .whitespaces).isEmpty { error = "请输入要合成的文本"; return }
        let est = TokenEstimator.estimateTTS(text: text)
        confirm.confirmAndRun(est) { [weak self] in
            await self?.performSynthesize(voice: voice)
        }
    }

    // MARK: - 账单记录

    private func recordTTSBill() {
        let est = TokenEstimator.estimateTTS(text: text)
        let entry = BillEntry(
            action: "语音合成", model: FixedModel.tts,
            summary: String(text.prefix(60)),
            unitName: "字符", unitCount: text.count,
            tokenMin: est.tokenMin, tokenMax: est.tokenMax,
            amountText: est.amount, detail: est.detail)
        BillStore.shared.add(entry)
    }

    private func recordCloneBill() {
        let est = TokenEstimator.estimateVoiceClone()
        let entry = BillEntry(
            action: "声音克隆", model: FixedModel.voiceEnrollment,
            summary: "音色前缀 \(prefix)",
            unitName: "次", unitCount: 1,
            tokenMin: est.tokenMin, tokenMax: est.tokenMax,
            amountText: est.amount, detail: est.detail)
        BillStore.shared.add(entry)
    }

    private func performSynthesize(voice: String) async {
        error = nil
        recordTTSBill()
        busy = true; status = "连接合成服务…"; progress = 0.1
        defer { busy = false }
        do {
            let result = try await CosyVoiceTTS.synthesize(
                text: text, voiceId: voice, apiKey: AppSettings.shared.apiKey,
                speechRate: speechRate, volume: Int(volume), pitch: pitch,
                instruction: instruction)
            progress = 0.9
            let dest = FilePicker.outputDir(.audio)
                .appendingPathComponent("语音_\(Int(Date().timeIntervalSince1970)).mp3")
            try result.audio.write(to: dest)
            lastAudioURL = dest
            LibraryStore.shared.add(MediaClip(kind: .audio, name: dest.lastPathComponent, url: dest))
            status = "合成完成"; progress = 1.0
        } catch {
            self.error = error.localizedDescription
            status = "合成失败"
        }
    }
}

struct VoiceStudioView: View {
    @StateObject private var m = VoiceStudioModel()
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

                GlassCard("第一步 · 创建克隆音色",
                          subtitle: "固定模型 \(FixedModel.tts)｜参考音频需公网可访问") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("粘贴参考音频 URL（如官方示例 .wav）", text: $m.cloningURL)
                            .textFieldStyle(.plain)
                            .padding(10).glassField
                        HStack {
                            Text("前缀").font(.caption).foregroundColor(Pal.muted)
                            TextField("myvoice", text: $m.prefix).frame(width: 140)
                                .textFieldStyle(.plain).padding(8)
                                .glassField
                            Spacer()
                            Button { m.pickLocalAudio() } label: {
                                Label("用本地音频", systemImage: "folder")
                            }.glassButton()
                            Button { m.createVoice() } label: {
                                Label("开始克隆", systemImage: "wand.and.stars")
                            }.glassButton(prominent: true).disabled(m.busy)
                        }
                    }
                }

                GlassCard("音色素材", subtitle: "内置风格参考音（随包自带）· 试听满意后一键克隆；也可把自备 wav/mp3/m4a 放进素材夹") {
                    VStack(alignment: .leading, spacing: 10) {
                        if m.samples.isEmpty {
                            Text("暂无素材。打开下方「素材夹」放入 wav / mp3 / m4a，即可作为克隆参考；或稍后重试刷新。")
                                .font(.caption).foregroundColor(Pal.faint)
                        } else {
                            ForEach(m.samples) { rs in
                                VoiceSampleRow(resolved: rs, model: m)
                            }
                        }
                        HStack(spacing: 14) {
                            Button("刷新素材列表") { m.loadSamples() }.buttonStyle(.link)
                            Button("打开素材夹…") { VoiceKit.revealMaterialRoot() }.buttonStyle(.link)
                            Spacer()
                            if m.busy { ProgressView().controlSize(.small) }
                        }
                    }
                }

                GlassCard("音色状态") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack { StatusDot(tone: m.busy ? .warn : (m.error == nil ? .ok : .error)); Text(m.status) }
                        if !m.newVoiceId.isEmpty {
                            HStack {
                                Text("voice_id：").font(.caption).foregroundColor(Pal.muted)
                                Text(m.newVoiceId).monospacedFont(11).selectableText()
                                Button("复制") { NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(m.newVoiceId, forType: .string) }
                                    .buttonStyle(.link)
                            }
                        }
                        if let e = m.error {
                            Text(e).font(.caption).foregroundColor(Pal.red).selectableText()
                        }
                    }
                }

                GlassCard("第二步 · 文本转语音") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("音色").font(.caption).foregroundColor(Pal.muted)
                            if m.voices.isEmpty {
                                Text("（暂无，先创建或使用 voice_id）").font(.caption).foregroundColor(Pal.faint)
                            } else {
                                Picker("", selection: $m.selectedVoice) {
                                    Text("选择音色").tag("")
                                    ForEach(m.voiceIds, id: \.self) { vid in
                                        Text(vid).tag(vid)
                                    }
                                }.labelsHidden().frame(width: 260)
                            }
                            Button("刷新列表") { Task { await m.refreshVoices() } }.buttonStyle(.link)
                            Spacer()
                        }
                        HStack {
                            Text("合成文本").font(.caption).foregroundColor(Pal.muted)
                            Spacer()
                            LuckyPromptButtons(kind: .audio, confirm: m.confirm, text: $m.text)
                        }
                        TextEditor(text: $m.text).frame(height: 90).hideScrollBackground()
                            .padding(8).glassField
                        VStack(alignment: .leading, spacing: 6) {
                            LabeledSlider("音量", value: $m.volume, range: 0...100)
                            LabeledSlider("语速", value: $m.speechRate, range: 0.5...2.0)
                            LabeledSlider("音高", value: $m.pitch, range: 0.5...2.0)
                        }
                        HStack {
                            Button { m.synthesize() } label: {
                                Label("生成语音", systemImage: "speaker.wave.3.fill")
                            }.glassButton(prominent: true).disabled(m.busy)
                            if let url = m.lastAudioURL {
                                Button { Player.shared.play(name: url.lastPathComponent, url: url) } label: {
                                    Label("试听", systemImage: "play.circle")
                                }.glassButton()
                                Button("在访达显示") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                    .buttonStyle(.link)
                            }
                            Spacer()
                        }
                        if m.busy { ProgressView(value: m.progress).accentPurple() }
                    }
                }
            }
            }
            .hideScrollBackground()
            .onAppear { m.loadSamples() }

            TokenConfirmOverlay(model: m.confirm, title: "语音/克隆")
        }
    }
}

struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    init(_ l: String, value: Binding<Double>, range: ClosedRange<Double>) {
        label = l; _value = value; self.range = range
    }
    var body: some View {
        HStack {
            Text(label).font(.caption).frame(width: 34, alignment: .leading).foregroundColor(Pal.muted)
            Slider(value: $value, in: range)
            Text(String(format: "%.1f", value)).monospacedFont(11).frame(width: 34)
        }
    }
}

// MARK: - 音色素材行：试听 / 保存副本 / 克隆 / 重命名

struct VoiceSampleRow: View {
    let resolved: ResolvedSample
    @ObservedObject var model: VoiceStudioModel
    @State private var renameOpen = false
    @State private var editName = ""

    private var sample: VoiceSample { resolved.sample }
    private var displayName: String { VoiceKit.nickname(for: sample) }
    private var isPlaying: Bool {
        Player.shared.playingName == resolved.fileURL.lastPathComponent
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: sample.isBuiltin ? "sparkles" : "folder")
                .foregroundColor(sample.isBuiltin ? Pal.gold : Pal.muted)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName).font(.system(size: 13, weight: .medium))
                    ForEach(sample.tags, id: \.self) { t in
                        Text(t)
                            .font(.system(size: 9))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                    }
                }
                Text(sample.source)
                    .font(.caption2).foregroundColor(Pal.faint)
                    .lineLimit(1).truncationMode(.tail)
                    .help(sample.source)
            }

            Spacer()

            // 试听 / 停止
            Button {
                if isPlaying { Player.shared.stop() }
                else { Player.shared.play(name: resolved.fileURL.lastPathComponent, url: resolved.fileURL) }
            } label: {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle")
                    .foregroundColor(isPlaying ? Pal.red : Pal.green)
            }
            .glassButton().fixedSize()
            .help("试听 / 停止")

            // 保存副本（内置未落盘时）/ 已在素材夹
            if !resolved.materialized && sample.isBuiltin {
                Button {
                    VoiceKit.materialize(resolved)
                    model.loadSamples()
                } label: {
                    Image(systemName: "arrow.down.circle")
                }
                .glassButton().fixedSize()
                .help("保存副本到素材文件夹（文件名用当前昵称）")
            } else {
                Button { VoiceKit.revealMaterialRoot() } label: {
                    Image(systemName: "folder")
                }
                .glassButton().fixedSize()
                .help("在访达中打开素材文件夹")
            }

            // 用作克隆参考
            Button {
                model.cloneFromSample(resolved)
            } label: {
                Label("用作克隆参考", systemImage: "wand.and.stars")
            }
            .glassButton()
            .disabled(model.busy)

            // 重命名
            Button {
                editName = displayName
                renameOpen = true
            } label: {
                Image(systemName: "pencil")
            }
            .glassButton().fixedSize()
            .help(sample.isBuiltin ? "重命名（同时影响素材夹副本的文件名）" : "重命名该素材文件")
            .popover(isPresented: $renameOpen, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("重命名「\(displayName)」").font(.headline)
                    TextField("名称", text: $editName)
                        .textFieldStyle(.plain).padding(8).glassField
                    HStack {
                        Spacer()
                        Button("取消") { renameOpen = false }.buttonStyle(.link)
                        Button("保存") { commitRename() }
                            .glassButton(prominent: true)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(14)
                .frame(width: 260)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .glassRowStyle
    }

    private func commitRename() {
        renameOpen = false
        let name = VoiceKit.sanitize(editName)
        if sample.isBuiltin {
            VoiceKit.setNickname(name, for: sample)
        } else {
            VoiceKit.renameUserFile(resolved, to: name)
        }
        model.loadSamples()
    }
}
