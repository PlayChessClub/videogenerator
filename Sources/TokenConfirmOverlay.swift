import SwiftUI

// MARK: - Token 消耗确认弹层
//
// 在真正发起生成（音/视频/克隆）前弹出，展示预计消耗的 token 区间（±30%）与金额，
// 让用户确认后再执行。估算仅供量级参考，实际以 DashScope 账单为准。

/// 供 ViewModel 持有的确认弹层状态
@MainActor
final class TokenConfirmModel: ObservableObject {
    @Published var estimate: TokenEstimator.Estimate? = nil

    var isPresented: Bool { estimate != nil }

    /// 弹出确认；用户确认后回调 confirm
    func confirmAndRun(_ e: TokenEstimator.Estimate, _ action: @escaping () async -> Void) {
        estimate = e
        pending = action
    }

    func dismiss() { estimate = nil; pending = nil }

    // 用户点「继续」→ 收起弹层并执行
    private var pending: (() async -> Void)?

    func proceed() {
        let p = pending
        estimate = nil; pending = nil
        if let p { Task { await p() } }
    }
}

/// 通用确认浮层：叠加在内容之上，点击遮罩/取消可关闭
struct TokenConfirmOverlay: View {
    @ObservedObject var model: TokenConfirmModel
    var title: String = "确认生成"

    var body: some View {
        ZStack {
            if let e = model.estimate {
                // 遮罩
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                    .onTapGesture { model.dismiss() }
                    .transition(.opacity)

                VStack(alignment: .leading, spacing: 16) {
                    // 标题
                    HStack(spacing: 10) {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(Pal.orange)
                            .font(.system(size: 15, weight: .semibold))
                        Text("\(title) · 预计消耗")
                            .font(.headline)
                        Spacer()
                        Button { model.dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Pal.muted)
                        }.buttonStyle(.plain)
                    }

                    Divider()

                    // token 主数值（区间 ±30%）
                    VStack(alignment: .leading, spacing: 6) {
                        Text(e.action)
                            .font(.subheadline)
                            .foregroundColor(Pal.muted)
                        if e.tokenEst > 0 {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(e.tokenEstText)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(Pal.purple)
                                Text("token")
                                    .font(.subheadline)
                                    .foregroundColor(Pal.muted)
                            }
                            HStack(spacing: 6) {
                                Text("区间 ±30%")
                                    .font(.caption)
                                    .foregroundColor(Pal.faint)
                                Text(e.tokenRangeText)
                                    .font(.caption)
                                    .monospacedFont(11)
                                    .foregroundColor(Pal.muted)
                            }
                        } else {
                            // token 当量无意义的操作（如克隆）只给提醒
                            Text("将消耗模型推理额度")
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    .padding(.vertical, 4)

                    // 金额辅助
                    HStack(spacing: 8) {
                        Image(systemName: "yensign.circle")
                            .foregroundColor(Pal.teal)
                        Text(e.amount)
                            .font(.callout)
                            .foregroundColor(Pal.teal)
                        Spacer()
                    }
                    .padding(10)
                    .background(Pal.teal.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Pal.teal.opacity(0.35), lineWidth: 0.8))

                    // 计费口径明细
                    Text("计费口径：" + e.detail)
                        .font(.caption2)
                        .foregroundColor(Pal.faint)
                        .selectableText()

                    Text("以上为预估值，仅供参考，实际以 DashScope 账单为准。")
                        .font(.caption2)
                        .foregroundColor(Pal.orange)

                    // 操作按钮
                    HStack {
                        Spacer()
                        Button("取消") { model.dismiss() }
                            .glassButton()
                        Button("继续生成") { model.proceed() }
                            .glassButton(prominent: true)
                    }
                    .padding(.top, 4)
                }
                .padding(22)
                .frame(width: 420)
                .background(confirmPanelBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 10)
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.16), value: model.isPresented)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var confirmPanelBackground: some View {
        if #available(macOS 26.0, *) {
            Rectangle().fill(.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
        } else {
            VisualEffectView(kind: .prominent)
        }
    }
}
