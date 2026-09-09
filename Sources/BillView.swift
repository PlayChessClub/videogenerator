import SwiftUI

// MARK: - 账单页

struct BillView: View {
    @ObservedObject private var store = BillStore.shared
    @State private var exportMessage: String? = nil

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 汇总
                    HStack(alignment: .top, spacing: 20) {
                        SummaryCard(title: "今日", s: store.summary(of: store.todayEntries))
                        SummaryCard(title: "本月", s: store.summary(of: store.monthEntries))
                        SummaryCard(title: "累计", s: store.summary(of: store.entries))
                    }

                    GlassCard("生成账单", subtitle: "每次确认生成时记录估算明细，可导出 CSV 核对扣费") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Button { exportCSV() } label: {
                                    Label("导出 CSV", systemImage: "square.and.arrow.up")
                                }.glassButton(prominent: true)
                                Button { revealInFinder() } label: {
                                    Label("在访达显示", systemImage: "folder")
                                }.glassButton()
                                Spacer()
                                Text("共 \(store.entries.count) 条")
                                    .font(.caption).foregroundColor(Pal.muted)
                            }

                            if let m = exportMessage {
                                Text(m).font(.caption).foregroundColor(Pal.green).selectableText()
                            }

                            if store.entries.isEmpty {
                                Text("暂无记录 —— 去「图片生成」「声音工作室」「视频生成」里生成一次，这里就会记录。")
                                    .font(.caption).foregroundColor(Pal.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                ForEach(Array(store.entries.prefix(200).enumerated()), id: \.element.id) { idx, e in
                                    BillRow(entry: e, timeText: df.string(from: e.time))
                                    if idx < min(store.entries.count, 200) - 1 { Divider() }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .hideScrollBackground()
        }
    }

    // MARK: - 导出

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "ClipForge-账单-\(todayStamp()).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.csvText(store.entries).write(to: url, atomically: true, encoding: .utf8)
            exportMessage = "✓ 已导出：\(url.lastPathComponent)"
        } catch {
            exportMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func revealInFinder() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipForge", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([base.appendingPathComponent("bill.jsonl")])
    }

    private func todayStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - 数值格式化（兼容 macOS 11，避免 .formatted()）

enum BillFormat {
    static func fmt(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - 汇总小卡

private struct SummaryCard: View {
    let title: String
    let s: BillStore.Summary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundColor(Pal.muted)
            Text("\(s.count) 次").font(.system(size: 20, weight: .semibold))
            Text(String(format: "≈ ¥%.2f", s.amount))
                .font(.callout).foregroundColor(Pal.teal)
            Text("token \(BillFormat.fmt(s.tokenMin))–\(BillFormat.fmt(s.tokenMax))")
                .font(.caption2).foregroundColor(Pal.faint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPanel
    }
}

// MARK: - 单条记录

private struct BillRow: View {
    let entry: BillEntry
    let timeText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeText).font(.caption2).monospacedFont(11).foregroundColor(Pal.faint)
                Text(entry.action).font(.caption).foregroundColor(Pal.purple)
            }
            .frame(width: 92, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.summary.isEmpty ? "—" : entry.summary)
                    .font(.caption).lineLimit(2)
                Text("\(entry.model) · \(entry.unitCount) \(entry.unitName)")
                    .font(.caption2).foregroundColor(Pal.faint)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.amountText)
                    .font(.caption).foregroundColor(Pal.teal)
                Text("token \(BillFormat.fmt(entry.tokenMin))–\(BillFormat.fmt(entry.tokenMax))")
                    .font(.caption2).foregroundColor(Pal.faint)
            }
        }
        .padding(.vertical, 6)
    }
}
