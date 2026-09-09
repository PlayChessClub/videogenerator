import SwiftUI
import UniformTypeIdentifiers

struct TimelineView: View {
    @ObservedObject private var lib = LibraryStore.shared
    @State private var mode: ExportEngine.Mode = .concat
    @State private var dubAudio: URL? = nil
    @State private var busy = false
    @State private var status = "就绪"
    @State private var error: String? = nil
    @State private var outputURL: URL? = nil

    private var videoClips: [MediaClip] {
        lib.order.compactMap { lib.clip($0) }.filter { $0.kind == .video }
    }
    private var audioClips: [MediaClip] {
        lib.clips.filter { $0.kind == .audio }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 左：素材库
            GlassCard("素材库", subtitle: "生成结果会自动收录，也可手动导入") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button { importMedia() } label: { Label("导入", systemImage: "plus") }
                            .glassButton()
                        Button {
                            lib.clips.removeAll(); lib.order.removeAll()
                        } label: { Label("清空", systemImage: "trash") }.glassButton()
                        Spacer()
                    }
                    if lib.clips.isEmpty {
                        Text("暂无素材").font(.caption).foregroundColor(Pal.faint)
                    } else {
                        ScrollView {
                            VStack(spacing: 6) {
                                ForEach(lib.clips) { c in
                                    HStack(spacing: 8) {
                                        Image(systemName: c.kind.symbol).frame(width: 18)
                                            .foregroundColor(c.kind == .video ? Pal.purple : (c.kind == .audio ? Pal.teal : Pal.orange))
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(c.name).font(.caption).lineLimit(1)
                                            Text(c.kind.label).font(.caption2).foregroundColor(Pal.faint)
                                        }
                                        Spacer()
                                        Button {
                                            NSWorkspace.shared.activateFileViewerSelecting([c.url])
                                        } label: { Image(systemName: "folder") }.buttonStyle(.link)
                                        Button { withAnimation { lib.remove(c.id) } } label: {
                                            Image(systemName: "xmark.circle")
                                        }.buttonStyle(.link).foregroundColor(Pal.muted)
                                    }
                                    .padding(8)
                                    .glassRowStyle
                                }
                            }
                        }.frame(maxHeight: 380)
                    }
                }
            }
            .frame(width: 320)

            // 右：时间线
            VStack(alignment: .leading, spacing: 16) {
                GlassCard("时间线", subtitle: "按素材库顺序拼接视频轨") {
                    VStack(alignment: .leading, spacing: 10) {
                        if videoClips.isEmpty {
                            Text("还没有视频片段 —— 去「视频生成」产出一段，或导入本地 mp4/mov。")
                                .font(.caption).foregroundColor(Pal.muted)
                        } else {
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    ForEach(videoClips) { c in
                                        VStack(spacing: 4) {
                                            Image(systemName: "film")
                                            Text(c.name).font(.caption2).lineLimit(1).frame(width: 90)
                                        }
                                        .frame(width: 110, height: 64)
                                        .glassPanel
                                    }
                                }
                            }.frame(height: 68)
                        }
                    }
                }

                GlassCard("导出") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("模式", selection: $mode) {
                            ForEach(ExportEngine.Mode.allCases) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)

                        if mode == .dub {
                            HStack {
                                Button {
                                    if let f = FilePicker.pick(types: [.audio]) { dubAudio = f }
                                } label: {
                                    Label(dubAudio?.lastPathComponent ?? "选择替换音轨", systemImage: "music.mic")
                                }.glassButton()
                                if !audioClips.isEmpty {
                                    Menu("从素材库") {
                                        ForEach(audioClips) { c in
                                            Button(c.name) { dubAudio = c.url }
                                        }
                                    }.menuStyle(.borderlessButton).fixedSize()
                                }
                                Spacer()
                            }
                        }

                        HStack {
                            Button { runExport() } label: {
                                Label("导出成片", systemImage: "square.and.arrow.up")
                            }.glassButton(prominent: true).disabled(busy || videoClips.isEmpty)
                            if let u = outputURL {
                                Button("播放成片") { NSWorkspace.shared.open(u) }.glassButton()
                                Button("显示") { NSWorkspace.shared.activateFileViewerSelecting([u]) }
                                    .glassButton()
                            }
                            Spacer()
                        }
                        HStack { StatusDot(tone: busy ? .warn : (error == nil ? .ok : .error)); Text(status) }
                        if let e = error { Text(e).font(.caption).foregroundColor(Pal.red) }
                    }
                }
                Spacer()
            }
        }
        .padding(4)
    }

    private func importMedia() {
        guard let f = FilePicker.pick(types: [.movie, .video, .audio, .image]) else { return }
        let ext = f.pathExtension.lowercased()
        let kind: MediaClip.Kind
        if ["mp4", "mov", "m4v", "avi"].contains(ext) { kind = .video }
        else if ["mp3", "wav", "m4a", "aac", "flac"].contains(ext) { kind = .audio }
        else { kind = .image }
        withAnimation { lib.add(MediaClip(kind: kind, name: f.lastPathComponent, url: f)) }
    }

    private func runExport() {
        busy = true; error = nil; status = "导出中…"
        let dest = FilePicker.outputDir(.video)
            .appendingPathComponent("成片_\(Int(Date().timeIntervalSince1970)).mp4")
        let plan = ExportEngine.Plan(videos: videoClips.map { $0.url }, mode: mode, dubAudio: dubAudio)
        Task {
            do {
                try await ExportEngine.export(plan, to: dest) { p in
                    status = String(format: "导出中… %.0f%%", p * 100)
                }
                outputURL = dest
                LibraryStore.shared.add(MediaClip(kind: .video, name: dest.lastPathComponent, url: dest))
                status = "导出完成 ✓"
            } catch {
                self.error = error.localizedDescription
                status = "导出失败"
            }
            busy = false
        }
    }
}
