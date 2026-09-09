import SwiftUI

// MARK: - 「试试手气」+「试试手气 Pro」按钮组
//
// · 试试手气：从本地词库随机取一条，不联网、不计费
// · 试试手气 Pro：调用 qwen3.7-text-embedding-flash，把「灵感种子」与词库候选一起向量化，
//   按余弦相似度挑出语义最贴合的一条。与其他生成一样：先弹预计消耗确认，再调用并计入账单。

struct LuckyPromptButtons: View {
    let kind: PromptKind
    /// 所在页的确认弹层（复用，保证与其它生成一致的确认体验）
    var confirm: TokenConfirmModel
    @Binding var text: String

    @State private var busy = false
    @State private var note: String? = nil

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                Button { text = PromptBank.random(kind) } label: {
                    Label("试试手气", systemImage: "dice")
                }.glassButton()

                Button { askThenRun() } label: {
                    HStack(spacing: 6) {
                        if busy {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                            Text("生成中…")
                        } else {
                            Image(systemName: "sparkles")
                            Text("试试手气 Pro")
                        }
                    }
                }
                .goldButton()
                .disabled(busy)
                .help("用 text-embedding 语义匹配，从词库中挑出与灵感种子最贴合的提示词（按输入 token 计费）")
            }
            if let note {
                Text(note).font(.caption2).foregroundColor(Pal.faint)
            }
        }
    }

    // MARK: - 流程

    private func askThenRun() {
        guard !busy else { return }
        let texts = PromptBank.plannedTexts(kind: kind, current: text)
        let tokens = TokenEstimator.embeddingTokens(for: texts)
        let est = TokenEstimator.estimateEmbedding(tokens: tokens, texts: texts.count)
        confirm.confirmAndRun(est) { await runPro() }
    }

    private func runPro() async {
        busy = true
        note = nil
        defer { busy = false }

        let result = await PromptBank.pro(kind: kind, current: text)
        text = result.prompt

        guard result.usedEmbedding else {
            note = "向量调用失败，已改用普通随机（未计费）"
            return
        }

        // 与其他生成同口径：按实际 token 计入账单
        let est = TokenEstimator.estimateEmbedding(tokens: result.tokens, texts: PromptBank.proCandidateCount + 1)
        let entry = BillEntry(
            action: "试试手气 Pro",
            model: FixedModel.embedding,
            summary: String(result.prompt.prefix(60)),
            unitName: "token",
            unitCount: result.tokens,
            tokenMin: est.tokenMin,
            tokenMax: est.tokenMax,
            amountText: est.amount,
            detail: est.detail,
            status: "成功"
        )
        BillStore.shared.add(entry)
        note = "已按语义匹配选中 · \(est.tokenRangeText)"
    }
}
