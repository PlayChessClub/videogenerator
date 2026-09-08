import Foundation

// MARK: - 费用 / Token 估算
//
// 说明：DashScope 的多模态模型并非按 token 计费，官方口径：
//   - cosyvoice-v3.5-plus（语音合成）  ：按输入文本「字符数」计费，¥1.5 / 万字符
//   - voice-enrollment（声音克隆）     ：按样本训练/合成随首用出账，金额波动较大
//   - wan2.6-i2v（图生视频）          ：按生成「秒数」计费，720P ¥0.6/s，1080P ¥1.0/s
//
// 为贴合用户「预计消耗 token」的表达习惯，这里把金额换算成一个直观的
// 「token 当量」作为主显示（仅帮助量级直觉，非精确计量），金额作为准确依据。
// 换算系数集中定义在下方 costTable，便于后续按实际账单校准。

enum TokenEstimator {

    /// 各操作的成本描述与换算系数。
    /// priceValue / priceUnit：官方单价；tokenPerUnit：把 1 个计费单位换算成 token 当量。
    struct Rate {
        let priceValue: Double          // 官方单价数值
        let priceUnit: String           // 官方计费单位说明（用于文案）
        let tokenPerUnit: Double        // 每个官方计费单位 ≈ 多少 token 当量
        let billedBy: Billable          // 本次操作的计费口径
    }

    enum Billable {
        case chars(Int)                 // 按输入字符数
        case videoSeconds(Int, String)  // 按生成秒数（含分辨率）
        case voiceClone(Double?)        // 声音克隆：给不定金额或 nil 表示纯提醒
    }

    /// 一次估算的结果
    struct Estimate {
        let model: String               // 模型名
        let action: String              // 操作中文名
        let tokenMin: Int               // 区间下限（-30%）
        let tokenEst: Int               // 主估算
        let tokenMax: Int               // 区间上限（+30%）
        let amount: String              // 预估金额（字符串，便于含 ¥ / 免费提示）
        let detail: String              // 计费口径明细，如「输入 245 字符 · ¥1.5/万字符」

        var tokenRangeText: String { "\(fmt(tokenMin))–\(fmt(tokenMax)) token" }
        var tokenEstText: String { fmt(tokenEst) }

        private func fmt(_ n: Int) -> String {
            if n >= 1_000_000 { return String(format: "%.1f万", Double(n) / 1_000_000) }
            if n >= 10_000   { return String(format: "%.1f万", Double(n) / 10_000) }
            return "\(n)"
        }
    }

    /// 官方单价表（华北2北京，含人民币）。token 当量为近似换算。
    private static let costTable: [String: Rate] = [
        FixedModel.tts: Rate(
            priceValue: 1.5, priceUnit: "元/万字符",
            tokenPerUnit: 15_000,  // 1 万字符 ≈ 1.5 万 token（按 1 汉字≈1.5 token 折算）
            billedBy: .chars(0)),
        FixedModel.voiceEnrollment: Rate(
            priceValue: 0, priceUnit: "随训练/合成出账",
            tokenPerUnit: 0,
            billedBy: .voiceClone(nil)),
        FixedModel.videoI2V: Rate(
            priceValue: 0.6, priceUnit: "元/秒(720P)",
            tokenPerUnit: 120_000,  // 1 秒 720P 视频的视觉 token 量级参考（非官方，仅供量级直觉）
            billedBy: .videoSeconds(0, "720P")),
    ]

    /// 720P/1080P 各自的单价（元/秒）
    private static func videoRate(forResolution res: String) -> Double {
        res == "1080P" ? 1.0 : 0.6
    }

    /// 估算一次语音合成（文本 → mp3）
    static func estimateTTS(text: String) -> Estimate {
        let chars = text.count
        let amount = Double(chars) / 10000.0 * (costTable[FixedModel.tts]?.priceValue ?? 1.5)
        let tokenEst = Int(Double(chars) / 10000.0 * (costTable[FixedModel.tts]?.tokenPerUnit ?? 15_000))
        return makeEstimate(model: FixedModel.tts, action: "语音合成",
                            tokenEst: tokenEst, amount: amount,
                            detail: "输入 \(chars) 字符 · ¥1.5/万字符")
    }

    /// 估算一次图生视频
    static func estimateVideo(prompt: String, resolution: String, duration: Int) -> Estimate {
        let rate = videoRate(forResolution: resolution)
        let amount = rate * Double(duration)
        // 视觉 token 当量：以 720P 的 tokenPerUnit 为基准，按单价比例放大到 1080P
        let base = costTable[FixedModel.videoI2V]?.tokenPerUnit ?? 120_000
        let tokenPerSecond = Int(Double(base) * rate / 0.6)
        let tokenEst = tokenPerSecond * duration
        return makeEstimate(model: FixedModel.videoI2V, action: "图生视频",
                            tokenEst: tokenEst, amount: amount,
                            detail: "\(resolution) · \(duration)s · ¥\(rateTrunc(rate))/秒")
    }

    /// 估算一次声音克隆（金额波动大，纯提醒为主）
    static func estimateVoiceClone() -> Estimate {
        makeEstimate(model: FixedModel.voiceEnrollment, action: "声音克隆",
                     tokenEst: nil, amount: nil,
                     detail: "费用随样本训练与首次合成出账，金额波动较大")
    }

    // MARK: - 内部

    private static func rateTrunc(_ v: Double) -> String {
        v == Double(Int(v)) ? String(Int(v)) : String(v)
    }

    private static func makeEstimate(model: String, action: String,
                                     tokenEst: Int?, amount: Double?, detail: String) -> Estimate {
        let est = tokenEst ?? 0
        let lower = max(0, Int(Double(est) * 0.7))   // -30%
        let upper = Int(Double(est) * 1.3)           // +30%

        var amountText: String
        if let a = amount {
            if a >= 0.005 {
                amountText = String(format: "预估金额 ≈ ¥%.2f", a)
            } else if a > 0 {
                amountText = "预估金额 ≈ <¥0.01"
            } else {
                amountText = "预估金额 ≈ ¥0"
            }
        } else {
            amountText = "费用随出账波动（约 ¥0.3–¥2）"
        }
        // 若 token 当量为 0（纯提醒型，如克隆），金额文案直接作为主提示，不带误导区间
        if est == 0 {
            amountText = "此操作将产生费用，随出账扣除"
        }
        return Estimate(model: model, action: action,
                        tokenMin: lower, tokenEst: est, tokenMax: upper,
                        amount: amountText, detail: detail)
    }
}
