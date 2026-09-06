import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class VideoStudioModel: ObservableObject {
    @Published var prompt: String = "一幅都市奇幻艺术的场景。一个由喷漆画成的少年从混凝土墙上活过来，边 rap 边摆出充满活力的说唱姿势，夜晚铁路桥下，街灯孤照，电影感氛围。"
    @Published var imageURL: String = ""
    @Published var audioURL: String = ""
    @Published var resolution: String = "720P"
    @Published var duration: Int = 10
    @Published var shotType: String = "single"
    @Published var promptExtend: Bool = true
    @Published var audioEnabled: Bool = true

    @Published var localImage: URL? = nil
    @Published var localAudio: URL? = nil

    @Published var busy = false
    @Published var status = "就绪"
    @Published var taskId: String = ""
    @Published var error: String? = nil
    @Published var videoLocalURL: URL? = nil
    @Published var elapsed: Int = 0
    @Published var lastJSON: [String: Any]? = nil

    private let client = DashScopeClient.shared

    func pickImage() {
        guard let f = FilePicker.pick(types: [.png, .jpeg, .image]) else { return }
        localImage = f
    }

    func pickAudio() {
        guard let f = FilePicker.pick(types: [.audio, .wav, .mpeg4Audio, .mp3]) else { return }
        localAudio = f
    }

    func useLibraryAudio(_ url: URL) { localAudio = url }

    func submit() async {
        error = nil; videoLocalURL = nil; busy = true; elapsed = 0
        defer { busy = false }
        do {
            // 准备图片 URL
            var img = imageURL.trimmingCharacters(in: .whitespaces)
            if img.isEmpty, let f = localImage {
                status = "上传图片到临时 OSS…"
                img = try await client.uploadToOSS(model: FixedModel.videoI2V, fileURL: f)
            }
            if img.isEmpty { throw APIError("请提供首帧图片（本地选择或填 URL）") }

            // 准备音频 URL（可选）
            var aud = audioURL.trimmingCharacters(in: .whitespaces)
            if aud.isEmpty, let f = localAudio {
                status = "上传配音到临时 OSS…"
                aud = try await client.uploadToOSS(model: FixedModel.videoI2V, fileURL: f)
            }

            let req = DashScopeClient.VideoRequest(
                prompt: prompt, imageURL: img,
                audioURL: aud.isEmpty ? nil : aud,
                resolution: resolution, duration: duration,
                promptExtend: promptExtend, audioEnabled: audioEnabled,
                shotType: shotType)

            status = "提交视频生成任务…"
            let tid = try await client.submitVideoTask(req)
            taskId = tid
            status = "任务已提交，生成中（通常 1-5 分钟）…"
            try await poll(tid)
        } catch {
            self.error = error.localizedDescription
            status = "失败"
        }
    }

    private func poll(_ tid: String) async throws {
        let deadline = Date().addingTimeInterval(60 * 15)
        while Date() < deadline {
            let s = try await client.pollVideoTask(tid)
            lastJSON = s.raw
            switch s.state {
            case "SUCCEEDED":
                status = "生成成功，下载中…"
                guard let vurl = s.videoUrl, let u = URL(string: vurl) else {
                    throw APIError("返回中没有视频地址")
                }
                let dest = FilePicker.outputDir()
                    .appendingPathComponent("视频_\(Int(Date().timeIntervalSince1970)).mp4")
                try await client.download(u, to: dest)
                videoLocalURL = dest
                LibraryStore.shared.add(MediaClip(kind: .video, name: dest.lastPathComponent, url: dest))
                status = "完成 ✓"
                return
            case "FAILED", "CANCELED", "UNKNOWN":
                throw APIError("任务\(s.state)：\(s.message ?? "无详情")")
            default:
                status = "生成中 · \(s.state)（已等待 \(elapsed)s）"
                for _ in 0..<5 { try await Task.sleep(nanoseconds: 1_000_000_000); elapsed += 1 }
            }
        }
        throw APIError("轮询超时（15 分钟）")
    }
}

struct VideoStudioView: View {
    @StateObject private var m = VideoStudioModel()
    @ObservedObject private var lib = LibraryStore.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !settings.hasKey {
                    Label("尚未配置 API Key，请前往「设置」填写。", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange).padding(10)
                        .glassEffect(.regular.tint(.orange.opacity(0.15)), in: .rect(cornerRadius: 14))
                }

                GlassCard("图生视频 · \(FixedModel.videoI2V)") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prompt").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $m.prompt).frame(height: 84).scrollContentBackground(.hidden)
                            .padding(8).glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))

                        Text("首帧图片（必填）").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button { m.pickImage() } label: {
                                Label(m.localImage?.lastPathComponent ?? "选择本地图片", systemImage: "photo.badge.plus")
                            }.buttonStyle(.glass)
                            TextField("或填公网图片 URL", text: $m.imageURL)
                                .textFieldStyle(.plain).padding(10)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                        }

                        Text("配音音频（可选）").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Button { m.pickAudio() } label: {
                                Label(m.localAudio?.lastPathComponent ?? "选择本地音频", systemImage: "music.note.list")
                            }.buttonStyle(.glass)
                            TextField("或填音频 URL（可从时间线/配音生成）", text: $m.audioURL)
                                .textFieldStyle(.plain).padding(10)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                        }
                        if !lib.clips.filter { $0.kind == .audio }.isEmpty {
                            Menu {
                                ForEach(lib.clips.filter { $0.kind == .audio }) { c in
                                    Button(c.name) { m.useLibraryAudio(c.url) }
                                }
                            } label: {
                                Label("使用素材库配音", systemImage: "waveform.path")
                            }.menuStyle(.borderlessButton).fixedSize()
                        }

                        HStack(spacing: 16) {
                            Picker("分辨率", selection: $m.resolution) {
                                Text("480P").tag("480P"); Text("720P").tag("720P"); Text("1080P").tag("1080P")
                            }
                            Picker("时长", selection: $m.duration) {
                                ForEach([5, 10, 15], id: \.self) { Text("\($0)s").tag($0) }
                            }
                            Picker("镜头", selection: $m.shotType) {
                                Text("单镜头").tag("single"); Text("多镜头").tag("multi")
                            }
                        }.pickerStyle(.segmented)

                        Toggle("智能扩写 prompt_extend", isOn: $m.promptExtend).toggleStyle(.switch)
                        Toggle("生成音频轨 audio", isOn: $m.audioEnabled).toggleStyle(.switch)

                        HStack {
                            Button { Task { await m.submit() } } label: {
                                Label("开始生成视频", systemImage: "video.fill.badge.plus")
                            }.buttonStyle(.glassProminent).disabled(m.busy)
                            Spacer()
                        }
                        if m.busy {
                            ProgressView().progressViewStyle(.circular)
                            HStack { StatusDot(tone: .warn); Text(m.status) }
                        } else {
                            HStack { StatusDot(tone: m.error == nil ? .ok : .error); Text(m.status) }
                        }
                        if !m.taskId.isEmpty {
                            GlassPill(text: "task_id: \(m.taskId)")
                        }
                        if let e = m.error {
                            Text(e).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                        }
                        if let v = m.videoLocalURL {
                            Divider()
                            HStack {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                                Text(v.lastPathComponent).font(.caption).lineLimit(1)
                                Spacer()
                                Button("播放") { NSWorkspace.shared.open(v) }.buttonStyle(.glass)
                                Button("显示") { NSWorkspace.shared.activateFileViewerSelecting([v]) }
                                    .buttonStyle(.glass)
                                VideoPreview(url: v).frame(width: 220, height: 130)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

import AVKit

struct VideoPreview: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.player = AVPlayer(url: url)
        v.controlsStyle = .inline
        v.videoGravity = .resizeAspectFill
        v.player?.play()
        return v
    }
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if (nsView.player?.currentItem?.asset as? AVURLAsset)?.url != url {
            nsView.player = AVPlayer(url: url)
            nsView.player?.play()
        }
    }
}
