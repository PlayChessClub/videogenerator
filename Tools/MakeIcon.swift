import AppKit

// ClipForge 应用图标生成器：紫青渐变 + 液态玻璃卡片 + 播放键 + 声波
let S = 1024.0
let image = NSImage(size: NSSize(width: S, height: S))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// 背景圆角方块 + 渐变
let bgRect = CGRect(x: 0, y: 0, width: S, height: S)
let clipPath = NSBezierPath(roundedRect: bgRect, xRadius: S * 0.22, yRadius: S * 0.22)
clipPath.addClip()
let colors = [NSColor(calibratedRed: 0.50, green: 0.38, blue: 0.95, alpha: 1).cgColor,
              NSColor(calibratedRed: 0.15, green: 0.68, blue: 0.82, alpha: 1).cgColor] as CFArray
if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])
}

// 液态玻璃卡片
let glass = NSBezierPath(roundedRect: CGRect(x: S * 0.13, y: S * 0.42, width: S * 0.74, height: S * 0.44),
                         xRadius: S * 0.10, yRadius: S * 0.10)
NSColor(calibratedWhite: 1, alpha: 0.28).setFill(); glass.fill()
NSColor(calibratedWhite: 1, alpha: 0.75).setStroke(); glass.lineWidth = 6; glass.stroke()
// 玻璃高光条
let gloss = NSBezierPath(roundedRect: CGRect(x: S * 0.16, y: S * 0.76, width: S * 0.68, height: S * 0.055),
                         xRadius: S * 0.03, yRadius: S * 0.03)
NSColor(calibratedWhite: 1, alpha: 0.22).setFill(); gloss.fill()

// 卡片内播放三角
let tri = NSBezierPath()
tri.move(to: CGPoint(x: S * 0.44, y: S * 0.52))
tri.line(to: CGPoint(x: S * 0.44, y: S * 0.76))
tri.line(to: CGPoint(x: S * 0.64, y: S * 0.64))
tri.close()
NSColor.white.setFill(); tri.fill()

// 底部声波
let heights = [0.10, 0.17, 0.12, 0.21, 0.09, 0.15, 0.11]
for (i, h) in heights.enumerated() {
    let b = NSBezierPath(roundedRect: CGRect(x: S * 0.17 + Double(i) * S * 0.10, y: S * 0.14,
                                             width: S * 0.05, height: S * h),
                         xRadius: S * 0.022, yRadius: S * 0.022)
    NSColor(calibratedWhite: 1, alpha: 0.9).setFill(); b.fill()
}

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try! png.write(to: URL(fileURLWithPath: out))
