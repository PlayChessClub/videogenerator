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

    // 步骤一：从 URL 创建克隆音色
    func createVoice() async {
        error = nil
        let url = cloningURL.trimmingCharacters(in: .whitespaces)
        if url.isEmpty { error = "请填写公网可访问的音频 URL"; return }
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

    // 从本地音频上传克隆
    func pickLocalAudio() {
        guard let f = FilePicker.pick(types: [.audio, .wav, .mpeg4Audio]) else { return }
        Task { await cloneFromLocal(f) }
    }

    func cloneFromLocal(_ f: URL) async {
        error = nil; busy = true
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

    // 合成
    func synthesize() async {
        error = nil
        let voice = selectedVoice.isEmpty ? newVoiceId : selectedVoice
        if voice.isEmpty { error = "请先选择或创建一个音色"; return }
        if text.trimmingCharacters(in: .whitespaces).isEmpty { error = "请输入要合成的文本"; return }
        busy = true; status = "连接合成服务…"; progress = 0.1
        defer { busy = false }
        do {
            let result = try await CosyVoiceTTS.synthesize(
                text: text, voiceId: voice, apiKey: AppSettings.shared.apiKey,
                speechRate: speechRate, volume: Int(volume), pitch: pitch,
                instruction: instruction)
            progress = 0.9
            let dest = FilePicker.outputDir()
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
                            Button { Task { await m.createVoice() } } label: {
                                Label("开始克隆", systemImage: "wand.and.stars")
                            }.glassButton(prominent: true).disabled(m.busy)
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
                        TextEditor(text: $m.text).frame(height: 90).hideScrollBackground()
                            .padding(8).glassField
                        VStack(alignment: .leading, spacing: 6) {
                            LabeledSlider("音量", value: $m.volume, range: 0...100)
                            LabeledSlider("语速", value: $m.speechRate, range: 0.5...2.0)
                            LabeledSlider("音高", value: $m.pitch, range: 0.5...2.0)
                        }
                        HStack {
                            Button { Task { await m.synthesize() } } label: {
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
