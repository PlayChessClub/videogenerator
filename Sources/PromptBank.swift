import Foundation

// MARK: - 随机提示词库（「试试手气」/「试试手气 Pro」）

/// 提示词类型：视频 / 图片 / 语音（决定用哪个词库与灵感种子）
enum PromptKind: String, CaseIterable {
    case video, image, audio

    var label: String {
        switch self {
        case .video: return "视频"
        case .image: return "图片"
        case .audio: return "语音"
        }
    }
}

enum PromptBank {

    /// 图生视频 / 文生视频的随机 Prompt
    static let video: [String] = [
        "一个由喷漆画成的少年从混凝土墙上活过来，边 rap 边摆出充满活力的说唱姿势，夜晚铁路桥下，街灯孤照，电影感氛围。",
        "一只毛茸茸的小猫戴着宇航员头盔，漂浮在失重的空间站里，慢镜头，柔和灯光。",
        "雨夜霓虹都市，一名撑红伞的女子走过湿漉漉的街道，倒影斑斓，赛博朋克风格。",
        "俯拍视角，沙漠中一辆复古吉普扬尘飞驰，夕阳把沙丘染成金色，长焦压缩感。",
        "一间深夜食堂，热气腾腾的拉面，镜头缓缓推近，蒸汽在暖黄灯光下袅袅升起。",
        "海浪拍打礁石，海鸥掠过，慢动作水花四溅，清晨薄雾，电影感自然光。",
        "一只机械蝴蝶停在一朵盛开的金属花上，特写微距，齿轮转动，蒸汽朋克。",
        "雪山之巅，登山者插下旗帜，风吹雪雾，逆光剪影，史诗感构图。",
        "热闹的夜市摊档，铁板烧师傅翻炒食材，火焰腾起，升格慢镜头。",
        "清晨森林，一束阳光穿透树冠，光柱中尘埃飞舞，镜头缓缓上摇。",
    ]

    /// 文生图随机 Prompt
    static let image: [String] = [
        "一只戴墨镜的柯基犬坐在海滩上，身边放着椰子，阳光明媚，插画风格。",
        "未来主义摩天楼群，悬浮列车穿梭，紫色与青色霓虹，赛博朋克城市。",
        "水彩画，宁静的江南水乡，白墙黛瓦，小桥流水，清晨薄雾。",
        "一只巨大的鲸鱼在云海中游弋，天空之城，梦幻超现实主义。",
        "特写：一杯拉花拿铁，木质桌面，暖色侧光，商业摄影质感。",
        "宫崎骏风格的田园小屋，绿草如茵，蓝天白云，远处风车转动。",
        "一只发光的水母在深海中漂浮，蓝色荧光，神秘幽深。",
        "像素风 8-bit 游戏场景，勇士站在城堡前，勇者斗恶龙。",
        "极简主义海报，一只红色气球飘向天空，大量留白，高级灰背景。",
        "冬日雪景，红色小木屋烟囱冒烟，松树挂雪，温馨童话感。",
    ]

    /// 语音合成的随机文本（适合朗读的短句/旁白）
    static let audio: [String] = [
        "夜色渐深，城市慢慢安静下来。远处的灯火一盏盏熄灭，只剩下风穿过树梢的声音。",
        "欢迎收听今天的节目。我们来聊一个有趣的话题：为什么有些人，天生就更乐观一点？",
        "先把米淘洗干净，加一小撮盐，再滴两滴油，这样煮出来的米饭粒粒分明，还带着光泽。",
        "风从海面上吹来，带着一点咸味。她站在礁石上，看着远处的灯塔，一闪，一闪。",
        "各位旅客您好，本次列车即将到达终点站，请您带好随身物品，准备下车。",
        "小时候，夏天的傍晚总是很长。蝉鸣、蒲扇、冰镇西瓜，还有外婆讲不完的故事。",
        "在这个快节奏的时代，能安静地读完一本书，已经变成了一种小小的奢侈。",
        "雨停了。空气里有泥土的味道，孩子们跑出家门，踩着水洼，笑声传得很远很远。",
        "亲爱的朋友，愿你今天遇到的每一件小事，都刚好合你的心意。晚安，好梦。",
        "他推开门，屋里的灯还亮着。桌上留着一张纸条：饭在锅里，记得热一热再吃。",
    ]

    /// 「试试手气 Pro」的灵感种子（几个特定的词/句）：
    /// 先向量化种子，再与词库候选比相似度，挑出语义最贴合的一条。
    static let seeds: [PromptKind: [String]] = [
        .video: ["雨夜的城市", "孤独的旅人", "时间的流逝", "童年的夏天", "机械与自然共生", "深海的寂静"],
        .image: ["静谧的江南", "未来的都市", "温暖的日常", "梦幻的超现实", "极简的秩序", "荒野与星光"],
        .audio: ["温柔的晚安", "清晨的问候", "旅途的旁白", "安静的独白", "热闹的开场", "深夜电台"],
    ]

    // MARK: - 基础取值

    static func corpus(_ kind: PromptKind) -> [String] {
        switch kind {
        case .video: return video
        case .image: return image
        case .audio: return audio
        }
    }

    static func random(_ kind: PromptKind) -> String {
        let c = corpus(kind)
        return c.randomElement() ?? ""
    }

    // MARK: - Pro：embedding 语义检索

    /// 单次请求最多 20 条文本：1 条种子 + 最多 12 条候选
    static let proCandidateCount = 12

    /// 本次 Pro 将要向量化的文本（首条为种子，其余为候选）
    static func plannedTexts(kind: PromptKind, current: String) -> [String] {
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed = trimmed.isEmpty ? (seeds[kind]?.randomElement() ?? "") : trimmed
        let pool = Array(corpus(kind).shuffled().prefix(proCandidateCount))
        return [seed] + pool
    }

    struct ProResult {
        let prompt: String
        let tokens: Int           // 实际计费 token（0 表示未真正调用）
        let usedEmbedding: Bool   // false = 降级为普通随机
    }

    /// 用 qwen3.7-text-embedding-flash 做语义匹配：
    /// 种子与候选一起向量化，按余弦相似度取 top3 随机一条；失败则降级为普通随机。
    @MainActor
    static func pro(kind: PromptKind, current: String = "") async -> ProResult {
        let texts = plannedTexts(kind: kind, current: current)
        let pool = Array(texts.dropFirst())
        do {
            let (vecs, tokens) = try await DashScopeClient.shared.embed(texts: texts)
            guard vecs.count == texts.count, let query = vecs.first, !query.isEmpty else {
                return ProResult(prompt: random(kind), tokens: 0, usedEmbedding: false)
            }
            var scored: [(String, Double)] = []
            for (i, p) in pool.enumerated() {
                scored.append((p, cosine(query, vecs[i + 1])))
            }
            scored.sort { $0.1 > $1.1 }
            let pick = Array(scored.prefix(3)).randomElement()?.0 ?? random(kind)
            return ProResult(prompt: pick, tokens: tokens, usedEmbedding: true)
        } catch {
            return ProResult(prompt: random(kind), tokens: 0, usedEmbedding: false)
        }
    }

    /// 余弦相似度
    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        let den = sqrt(na) * sqrt(nb)
        return den > 0 ? dot / den : 0
    }
}
