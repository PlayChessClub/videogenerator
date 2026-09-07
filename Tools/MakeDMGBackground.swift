import AppKit
import CoreGraphics

// ClipForge DMG 背景图生成器
// 用法: makebg <输出.png>
// 逻辑尺寸 1080x636（= Finder 窗口 1080x660 减去标题栏 24）
// 在 Retina 环境下 lockFocus 会渲染为 2x 像素，build.sh 再合成 hidpi tiff

let args = CommandLine.arguments
let out = args.count > 1 ? args[1] : "dmg_bg@2x.png"

let W = 1080.0
let H = 636.0

// 图标位（与 build.sh 中 AppleScript 的 position 保持一致）
let appX = 300.0
let appY = 300.0
let appsX = 780.0
let appsY = 300.0

let img = NSImage(size: NSSize(width: W, height: H))
// flipped：坐标原点置于左上，Y 向下增长，便于按视觉排版书写
img.lockFocusFlipped(true)
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// MARK: - 底色渐变（深空紫 → 深蓝，斜向）
let baseColors = [
    CGColor(red: 0.120, green: 0.100, blue: 0.190, alpha: 1),
    CGColor(red: 0.150, green: 0.130, blue: 0.250, alpha: 1),
    CGColor(red: 0.065, green: 0.085, blue: 0.165, alpha: 1),
] as CFArray
if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: baseColors, locations: [0, 0.5, 1]) {
    ctx.drawLinearGradient(g, start: CGPoint(x: W * 0.15, y: 0),
                           end: CGPoint(x: W * 0.85, y: H), options: [])
}

// MARK: - 柔光斑
func glow(cx: Double, cy: Double, r: Double, _ color: NSColor, _ alpha: Double) {
    let cs = [
        color.withAlphaComponent(alpha).cgColor,
        color.withAlphaComponent(0).cgColor,
    ] as CFArray
    if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cs, locations: [0, 1]) {
        ctx.drawRadialGradient(g,
                               startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
                               endCenter: CGPoint(x: cx, y: cy), endRadius: r, options: [])
    }
}
glow(cx: 240, cy: 110, r: 470, NSColor(calibratedRed: 0.52, green: 0.36, blue: 0.98, alpha: 1), 0.52)
glow(cx: 880, cy: 540, r: 490, NSColor(calibratedRed: 0.16, green: 0.72, blue: 0.88, alpha: 1), 0.42)
glow(cx: 620, cy: 40, r: 360, NSColor(calibratedRed: 0.98, green: 0.45, blue: 0.62, alpha: 1), 0.16)

// MARK: - 细网格纹理
ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.032))
ctx.setLineWidth(1)
for x in stride(from: 0.0, to: W, by: 36) {
    ctx.move(to: CGPoint(x: x, y: 0)); ctx.addLine(to: CGPoint(x: x, y: H))
}
for y in stride(from: 0.0, to: H, by: 36) {
    ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: W, y: y))
}
ctx.strokePath()

// MARK: - 文本工具
func draw(_ text: String, centerX: Double, topY: Double, width: Double,
          size: CGFloat, weight: NSFont.Weight, color: NSColor, spacing: CGFloat = 0) {
    let para = NSMutableParagraphStyle(); para.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: para,
        .kern: spacing,
    ]
    NSAttributedString(string: text, attributes: attrs).draw(
        with: CGRect(x: centerX - width / 2, y: topY, width: width, height: size * 2.6),
        options: [.usesLineFragmentOrigin], context: nil)
}

draw("ClipForge", centerX: W / 2, topY: 44, width: W, size: 38,
     weight: .bold, color: NSColor(calibratedWhite: 1, alpha: 0.96), spacing: 1.5)
draw("AI 视频编辑助手  ·  驱动于阿里云 DashScope", centerX: W / 2, topY: 98, width: W, size: 15,
     weight: .medium, color: NSColor(calibratedWhite: 1, alpha: 0.60), spacing: 0.6)

// 标题下细分隔线
let sep = NSBezierPath()
sep.move(to: CGPoint(x: W / 2 - 74, y: 134)); sep.line(to: CGPoint(x: W / 2 + 74, y: 134))
NSColor(calibratedWhite: 1, alpha: 0.20).setStroke(); sep.lineWidth = 1.5; sep.stroke()

// MARK: - 虚线弧形箭头：ClipForge → Applications
let fromX = appX + 116
let toX = appsX - 116
let arrowY = (appY + appsY) / 2 - 8

let arc = NSBezierPath()
arc.move(to: CGPoint(x: fromX, y: arrowY))
arc.curve(to: CGPoint(x: toX, y: arrowY),
          controlPoint1: CGPoint(x: fromX + (toX - fromX) * 0.32, y: arrowY - 64),
          controlPoint2: CGPoint(x: fromX + (toX - fromX) * 0.68, y: arrowY - 64))
var dash: [CGFloat] = [11, 9]
arc.setLineDash(&dash, count: 2, phase: 0)
arc.lineWidth = 3.5
arc.lineCapStyle = .round
NSColor(calibratedWhite: 1, alpha: 0.70).setStroke()
arc.stroke()

let head = NSBezierPath()
head.move(to: CGPoint(x: toX - 17, y: arrowY - 15))
head.line(to: CGPoint(x: toX + 7, y: arrowY))
head.line(to: CGPoint(x: toX - 17, y: arrowY + 15))
head.close()
NSColor(calibratedWhite: 1, alpha: 0.88).setFill(); head.fill()

draw("拖 移 安 装", centerX: (fromX + toX) / 2, topY: arrowY - 96, width: 320, size: 15,
     weight: .semibold, color: NSColor(calibratedWhite: 1, alpha: 0.80), spacing: 2)

draw("ClipForge.app", centerX: appX, topY: appY + 96, width: 300, size: 13,
     weight: .medium, color: NSColor(calibratedWhite: 1, alpha: 0.42))
draw("Applications", centerX: appsX, topY: appsY + 96, width: 300, size: 13,
     weight: .medium, color: NSColor(calibratedWhite: 1, alpha: 0.42))

// MARK: - 底部提示卡片
let cardW = 636.0, cardH = 60.0, cardX = (W - cardW) / 2, cardY = H - 116
let card = NSBezierPath(roundedRect: CGRect(x: cardX, y: cardY, width: cardW, height: cardH),
                        xRadius: 16, yRadius: 16)
NSColor(calibratedWhite: 1, alpha: 0.09).setFill(); card.fill()
NSColor(calibratedWhite: 1, alpha: 0.18).setStroke(); card.lineWidth = 1; card.stroke()
draw("将 ClipForge 拖入右侧 Applications 文件夹即可完成安装",
     centerX: W / 2, topY: cardY + 19, width: cardW, size: 14.5,
     weight: .medium, color: NSColor(calibratedWhite: 1, alpha: 0.88))

// 右下角版本信息
let para = NSMutableParagraphStyle(); para.alignment = .right
let verAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11.5, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.36),
    .paragraphStyle: para,
]
NSAttributedString(string: "v1.1.0  ·  macOS 11+  ·  通用二进制 (arm64 / Intel)",
                   attributes: verAttrs).draw(
    with: CGRect(x: W - 330, y: H - 30, width: 310, height: 20),
    options: [.usesLineFragmentOrigin], context: nil)

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: out))
print("背景图已生成: \(out)  (\(rep.pixelsWide)x\(rep.pixelsHigh)px)")
