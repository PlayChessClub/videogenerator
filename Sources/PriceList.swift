import Foundation

// MARK: - 价目表（设置页展示，华北2北京按量付费，仅供参考，以官方账单为准）

struct PriceRow: Identifiable {
    let id = UUID()
    let model: String      // 模型名
    let name: String        // 中文能力名
    let unit: String        // 计费单位
    let price: String       // 单价文案
}

enum PriceList {

    // 视频生成（文生视频 / 图生视频，均按秒计费）
    static let video: [PriceRow] = [
        PriceRow(model: "wan2.6-t2v",       name: "文生视频", unit: "元/秒",
                 price: "720P ¥0.6 · 1080P ¥1.0"),
        PriceRow(model: "wan2.7-t2v",       name: "文生视频", unit: "元/秒",
                 price: "720P ¥0.6 · 1080P ¥1.0"),
        PriceRow(model: "wan2.6-i2v",       name: "图生视频", unit: "元/秒",
                 price: "720P ¥0.6 · 1080P ¥1.0"),
        PriceRow(model: "wan2.7-i2v",       name: "图生视频", unit: "元/秒",
                 price: "720P ¥0.6 · 1080P ¥1.0"),
        PriceRow(model: "wan2.6-i2v-flash", name: "图生视频·Flash", unit: "元/秒",
                 price: "有声 0.3/0.5 · 无声 0.15/0.25"),
    ]

    // 图片生成（按张计费）
    static let image: [PriceRow] = [
        PriceRow(model: "qwen-image-2.0",     name: "文生图", unit: "元/张", price: "¥0.20"),
        PriceRow(model: "qwen-image-2.0-pro", name: "文生图", unit: "元/张", price: "¥0.50"),
        PriceRow(model: "wan2.7-image",       name: "文生图", unit: "元/张", price: "¥0.20"),
        PriceRow(model: "wan2.7-image-pro",   name: "文生图", unit: "元/张", price: "¥0.50"),
    ]

    // 语音（按字符 / 随出账）
    static let audio: [PriceRow] = [
        PriceRow(model: "cosyvoice-v3.5-plus", name: "语音合成", unit: "元/万字符", price: "¥1.50"),
        PriceRow(model: "voice-enrollment",     name: "声音克隆", unit: "按出账",
                 price: "随训练/合成出账"),
    ]

    // 向量（「试试手气 Pro」语义匹配，按输入 token 计费）
    static let vector: [PriceRow] = [
        PriceRow(model: "qwen3.7-text-embedding-flash", name: "文本向量", unit: "元/千token",
                 price: "¥0.000125"),
    ]
}
