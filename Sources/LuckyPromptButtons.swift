import SwiftUI

// MARK: - 「试试手气」+「试试手气 Pro」按钮组
//
// · 试试手气：从本地整句词库随机取一条，不联网、不计费
// · 试试手气 Pro：两阶段
//     阶段 1 选句：qwen3.7-text-embedding-flash 把「目的/关键词」与候选句（整句 + 词库随机组合）
//                  一起向量化，取语义最贴近的 top3 作参照
//     阶段 2 扩写：qwen-plus 按媒介定制指令，扩写成 ~500 字全新提示词（禁止复读原句）
//   与其他生成一致：先弹两阶段合并的预计消耗，确认后执行，并按实际 token 计入账单。

struct LuckyPromptButtons: View {
    let kind: PromptKind
    /// 所在页的确认弹层（复用，保证与其它生成一致的确认体验）
    var confirm: TokenConfirmModel
    @Binding var text: String

    @State private var purpose: String = ""
    @State private var theme: String = ""
    @State private var busy = false
    @State private var note: String? = nil

    private var themes: [String] { PromptBank.purposeSeeds[kind] ?? [] }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 8) {
                TextField("目的 / 关键词（可留空）", text: $purpose)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(width: 150)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .glassField
                    .help("留空则自动使用该媒介的默认主题种子")

                Menu {
                    Button("自动（随机主题）") { theme = "" }
                    Divider()
                    ForEach(themes, id: \.self) { t in
                        Button(t) { theme = t; purpose = t }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tag").font(.system(size: 10))
                        Text(theme.isEmpty ? "主题" : theme).font(.system(size: 12))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

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
                .help("先用向量模型挑出最贴合目的的词库句子，再让 qwen-plus 扩写成 ~500 字新提示词（按 token 计费）")
            }
            if let note {
                Text(note).font(.caption2).foregroundColor(Pal.faint)
                    .lineLimit(1).truncationMode(.tail)
            }
        }
    }

    // MARK: - 流程

    private func askThenRun() {
        guard !busy else { return }
        let seedPurpose = theme.isEmpty ? purpose : theme
        let texts = PromptBank.plannedTexts(kind: kind, purpose: seedPurpose)
        let embedTokens = TokenEstimator.embeddingTokens(for: texts)
        let est = TokenEstimator.estimateProTotal(kind: kind,
                                                  embedTokens: embedTokens,
                                                  genTokens: kind.maxGenTokens)
        confirm.confirmAndRun(est) { await runPro(purpose: seedPurpose) }
    }

    private func runPro(purpose seedPurpose: String) async {
        busy = true
        note = nil
        defer { busy = false }

        let result = await PromptBank.pro(kind: kind, purpose: seedPurpose)
        text = result.prompt

        guard result.usedPro else {
            note = "Pro 调用失败，已改用普通随机（未计费）"
            return
        }

        // 两阶段实际 token 合并记一条账
        let est = TokenEstimator.estimateProTotal(kind: kind,
                                                  embedTokens: result.embedTokens,
                                                  genTokens: result.genTokens)
        let entry = BillEntry(
            action: "试试手气 Pro",
            model: "\(FixedModel.textGeneration)+\(FixedModel.embedding)",
            summary: String(result.prompt.prefix(60)),
            unitName: "token",
            unitCount: result.totalTokens,
            tokenMin: est.tokenMin,
            tokenMax: est.tokenMax,
            amountText: est.amount,
            detail: "向量选句 \(result.embedTokens) + 扩写 \(result.genTokens) token",
            status: "成功"
        )
        BillStore.shared.add(entry)
        note = "已扩写 ~\(result.prompt.count) 字 · \(est.tokenRangeText)"
    }
}
