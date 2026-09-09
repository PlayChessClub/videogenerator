import SwiftUI
import AVFoundation

// MARK: - 语音页（TTS 合成 / 试听 / 素材 / 试试手气 Pro 旁白）
//
// 说明：iOS Phase1 仅做 TTS 合成 + 试听 + 素材管理；声音克隆上传（voice-enrollment）留到 Phase3。
// 因此「合成」需要一个云端 voice_id（由之前克隆得到的音色 ID，粘贴填入）。
// 内置样音（随包 wav）用于本机试听与作为克隆参考，不直接用于云端合成。

struct VoiceView: View {
    @State private var text = "夜色渐深，城市慢慢安静下来。远处的灯火一盏盏熄灭，只剩下风穿过树梢的声音。"
    @State private var keyword = ""
    @State private var voiceId = ""
    @State private var samples: [ResolvedSample] = []
    @State private var selectedSampleID: String?
    @State private var audioData: Data?
    @State private var isPlaying = false
    @State private var busy = false
    @State private var log = "粘贴云端 voice_id，输入文案后点「合成」。内置样音可本机试听。"
    @State private var player: AVAudioPlayer?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("文案 / 旁白").font(.headline)
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

                    Text("目的 / 关键词（试试手气 Pro 用）").font(.subheadline)
                    TextField("如：温柔晚安", text: $keyword)
                        .textFieldStyle(.roundedBorder)

                    Text("云端 voice_id（克隆得到的音色 ID）").font(.subheadline)
                    TextField("粘贴 voice_id", text: $voiceId)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    HStack {
                        Button(action: { Task { await synth() } }) {
                            Label("合成并试听", systemImage: "waveform")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(busy || voiceId.trimmingCharacters(in: .whitespaces).isEmpty)

                        Button(action: { Task { await proNarration() } }) {
                            Label("试试手气 Pro", systemImage: "sparkles")
                        }
                        .buttonStyle(.bordered)
                        .disabled(busy || !AppSettings.shared.hasKey)
                    }

                    if busy { ProgressView("合成中…") }

                    if let data = audioData, isPlaying {
                        Label("播放中…", systemImage: "speaker.wave.2.fill").font(.footnote)
                    }

                    materialsSection
                    Text(log).font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("语音")
            .onAppear { samples = VoiceSampleKit.loadSamples() }
            .onDisappear { player?.stop() }
        }
    }

    private var materialsSection: some View {
        Section {
            DisclosureGroup("音色素材（\(samples.count)）") {
                ForEach(samples) { s in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(VoiceSampleKit.nickname(for: s.sample)).font(.subheadline)
                            Text(s.sample.isBuiltin ? "内置样音" : "用户素材")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: { playLocal(s) }) {
                            Image(systemName: "play.circle").imageScale(.large)
                        }
                        if s.sample.isBuiltin {
                            Button(action: { materialize(s) }) {
                                Image(systemName: "square.and.arrow.down").imageScale(.large)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        } header: { Text("素材库") }
    }

    // MARK: 合成
    private func synth() async {
        guard AppSettings.shared.hasKey else {
            log = "请先在「设置」填写 API Key"; return
        }
        let vid = voiceId.trimmingCharacters(in: .whitespaces)
        guard !vid.isEmpty else { log = "请填写云端 voice_id"; return }
        busy = true; defer { busy = false }
        do {
            log = "调用 CosyVoice 合成…"
            let r = try await CosyVoiceTTS.synthesize(text: text, voiceId: vid, apiKey: AppSettings.shared.apiKey)
            audioData = r.audio
            try await saveAudio(r.audio)
            play(data: r.audio)
            let est = TokenEstimator.estimateTTS(text: text)
            BillStore.shared.add(BillEntry(
                action: "语音合成", model: FixedModel.tts, summary: String(text.prefix(40)),
                unitName: "字符", unitCount: text.count,
                tokenMin: est.tokenMin, tokenMax: est.tokenMax,
                amountText: est.amount, detail: est.detail, taskId: nil))
            log = "合成成功（\(r.format)，已试听并保存到文档）"
        } catch {
            log = "合成失败：\(error.localizedDescription)"
        }
    }

    // MARK: Pro 旁白
    private func proNarration() async {
        guard AppSettings.shared.hasKey else { log = "请先填写 API Key"; return }
        busy = true; defer { busy = false }
        let pro = await PromptBank.pro(kind: .audio, purpose: keyword)
        text = pro.prompt
        log = "Pro 已生成旁白文案（≈\(pro.embedTokens)+\(pro.genTokens) token）"
        if !voiceId.trimmingCharacters(in: .whitespaces).isEmpty {
            await synth()
        }
    }

    // MARK: 播放
    private func play(data: Data) {
        do {
            player = try AVAudioPlayer(data: data)
            player?.play()
            isPlaying = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let p = player, !p.isPlaying { isPlaying = false }
            }
        } catch { log = "播放失败：\(error.localizedDescription)" }
    }

    private func playLocal(_ s: ResolvedSample) {
        do {
            player = try AVAudioPlayer(contentsOf: s.fileURL)
            player?.play()
            isPlaying = true
        } catch { log = "试听失败：\(error.localizedDescription)" }
    }

    private func materialize(_ s: ResolvedSample) {
        if let url = VoiceSampleKit.materialize(s) {
            log = "已保存副本到素材夹：\(url.lastPathComponent)"
        } else {
            log = "保存副本失败"
        }
    }

    private func saveAudio(_ data: Data) async {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipForge/voice", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("tts_\(Int(Date().timeIntervalSince1970)).mp3")
        try? data.write(to: url)
    }
}
