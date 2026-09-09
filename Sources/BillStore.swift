import Foundation
import AppKit

// MARK: - 生成账单
//
// 记录每次「确认生成」的估算明细（时间/操作/模型/内容摘要/计量/token 区间/金额），
// 持久化到 ~/Library/Application Support/ClipForge/bill.jsonl（append-only，每行一条 JSON）。
// 用途：核对 DashScope 实际扣费、导出 CSV 留档。

struct BillEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var time: Date = Date()
    var action: String            // 文生图 / 语音合成 / 图生视频 / 声音克隆
    var model: String             // 模型 ID
    var summary: String           // prompt 或内容摘要（前 60 字）
    var unitName: String          // 计量单位：张 / 字符 / 秒 / 次
    var unitCount: Int            // 计量数量
    var tokenMin: Int             // 估算 token 下限（-30%）
    var tokenMax: Int             // 估算 token 上限（+30%）
    var amountText: String        // 预估金额文案
    var detail: String            // 计费口径
    var taskId: String?           // 任务 ID（视频/克隆有）
    var status: String = "已提交"  // 已提交 / 成功 / 失败

    enum CodingKeys: String, CodingKey {
        case id, time, action, model, summary, unitName, unitCount
        case tokenMin, tokenMax, amountText, detail, taskId, status
    }
}

@MainActor
final class BillStore: ObservableObject {
    static let shared = BillStore()

    @Published private(set) var entries: [BillEntry] = []

    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipForge", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("bill.jsonl")
    }()

    /// 待落盘缓冲：累计 5 条写一次；退出/关窗前强制 flush
    private var pending: [BillEntry] = []
    private let flushThreshold = 5

    private init() {
        load()
        // 关窗/退出前把缓冲中的条目落盘，避免最后不足 5 条的记录丢失
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.flush() }
        }
    }

    // MARK: - 读写

    /// 新增一条：先进内存 + 缓冲，累计 flushThreshold 条才真正落盘（减少频繁写盘）
    func add(_ e: BillEntry) {
        entries.insert(e, at: 0)
        pending.append(e)
        if pending.count >= flushThreshold { flush() }
    }

    /// 把缓冲中的条目一次性追加写入磁盘；不足一批时由退出钩子兜底
    func flush() {
        guard !pending.isEmpty else { return }
        var text = ""
        for e in pending {
            guard let data = try? JSONEncoder().encode(e),
                  let line = String(data: data, encoding: .utf8) else { continue }
            text += line + "\n"
        }
        appendRaw(text)
        pending.removeAll()
    }

    /// 回填任务 ID / 状态（异步任务拿到 task_id 后调用）
    func update(id: UUID, taskId: String? = nil, status: String? = nil) {
        guard let idx = entries.firstIndex(where: { $0.id == id }) else { return }
        if let t = taskId { entries[idx].taskId = t }
        if let s = status { entries[idx].status = s }
        rewriteDisk()
        pending.removeAll()   // 全量重写已包含缓冲条目
    }

    /// 全量重写磁盘（条目不多，简单可靠）
    private func rewriteDisk() {
        var text = ""
        for e in entries.reversed() {
            guard let data = try? JSONEncoder().encode(e),
                  let line = String(data: data, encoding: .utf8) else { continue }
            text += line + "\n"
        }
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    private func appendRaw(_ text: String) {
        guard !text.isEmpty else { return }
        let row = text.hasSuffix("\n") ? text : text + "\n"
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            handle.seekToEndOfFile()
            handle.write(Data(row.utf8))
            handle.closeFile()
        } else {
            try? row.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }

    private func load() {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return }
        var list: [BillEntry] = []
        for line in text.split(separator: "\n") {
            if let d = line.data(using: .utf8),
               let e = try? JSONDecoder().decode(BillEntry.self, from: d) {
                list.append(e)
            }
        }
        entries = list.reversed()   // 最新的在前
    }

    func clear() {
        entries = []
        pending.removeAll()
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - 汇总

    struct Summary {
        var count: Int
        var amount: Double      // 从 amountText 解析的金额合计
        var tokenMin: Int
        var tokenMax: Int
    }

    func summary(of list: [BillEntry]) -> Summary {
        var amount = 0.0, tMin = 0, tMax = 0
        for e in list {
            amount += parseAmount(e.amountText)
            tMin += e.tokenMin
            tMax += e.tokenMax
        }
        return Summary(count: list.count, amount: amount, tokenMin: tMin, tokenMax: tMax)
    }

    /// 从「预估金额 ≈ ¥6.00」这类文案里抓数字
    private func parseAmount(_ s: String) -> Double {
        let digits = s.replacingOccurrences(
            of: "[^0-9.]", with: "", options: .regularExpression)
        return Double(digits) ?? 0
    }

    var todayEntries: [BillEntry] {
        let cal = Calendar.current
        return entries.filter { cal.isDateInToday($0.time) }
    }

    var monthEntries: [BillEntry] {
        let cal = Calendar.current
        let now = Date()
        return entries.filter {
            cal.isDate($0.time, equalTo: now, toGranularity: .month)
                && cal.isDate($0.time, equalTo: now, toGranularity: .year)
        }
    }

    // MARK: - CSV 导出

    /// 生成 CSV 文本（含 BOM 以便 Excel 正确识别 UTF-8）
    func csvText(_ list: [BillEntry]) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var out = "\u{FEFF}时间,操作,模型,内容摘要,计量单位,数量,token下限,token上限,预估金额,任务ID,状态,计费口径\n"
        for e in list {
            out += csvRow([
                df.string(from: e.time),
                e.action,
                e.model,
                e.summary,
                e.unitName,
                String(e.unitCount),
                String(e.tokenMin),
                String(e.tokenMax),
                e.amountText,
                e.taskId ?? "",
                e.status,
                e.detail,
            ])
        }
        return out
    }

    /// 单个 CSV 字段转义：含逗号/引号/换行则加引号，内部引号翻倍
    private func csvRow(_ fields: [String]) -> String {
        fields.map { f in
            let needsQuote = f.contains(",") || f.contains("\"") || f.contains("\n")
            let escaped = f.replacingOccurrences(of: "\"", with: "\"\"")
            return needsQuote ? "\"\(escaped)\"" : escaped
        }.joined(separator: ",") + "\n"
    }
}
