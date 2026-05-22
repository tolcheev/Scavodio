import AppKit
import CoreGraphics

// Window in AppleScript: {100, 100, 760, 620} = 660 × 520 content
let W = 660, H = 520
let fw = CGFloat(W), fh = CGFloat(H)

let bmp = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)
let ctx = NSGraphicsContext.current!.cgContext
let cs = CGColorSpaceCreateDeviceRGB()

// ── Background ─────────────────────────────────────────────────────────────
let bgColors: [CGFloat] = [0.940, 0.940, 0.948, 1.0,  0.908, 0.908, 0.920, 1.0]
let bg = CGGradient(colorSpace: cs, colorComponents: bgColors, locations: [0,1], count: 2)!
ctx.drawLinearGradient(bg, start: CGPoint(x: fw/2, y: fh), end: CGPoint(x: fw/2, y: 0), options: [])

// Edge vignette
let vigColors: [CGFloat] = [0,0,0,0.0, 0,0,0,0.05]
let vig = CGGradient(colorSpace: cs, colorComponents: vigColors, locations: [0,1], count: 2)!
ctx.drawRadialGradient(vig,
    startCenter: CGPoint(x: fw/2, y: fh/2), startRadius: 0,
    endCenter:   CGPoint(x: fw/2, y: fh/2), endRadius: fw * 0.78,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// ── Helpers ────────────────────────────────────────────────────────────────
let blue   = CGColor(red: 0.20, green: 0.47, blue: 1.00, alpha: 1.0)
let black55 = NSColor(white: 0, alpha: 0.55)
let black35 = NSColor(white: 0, alpha: 0.35)
let black22 = NSColor(white: 0, alpha: 0.22)

func paraLeft()   -> NSMutableParagraphStyle { let p = NSMutableParagraphStyle(); p.alignment = .left;   return p }
func paraCenter() -> NSMutableParagraphStyle { let p = NSMutableParagraphStyle(); p.alignment = .center; return p }

// Draw a filled blue circle with a white number, centred at (cx, cy)
func drawBadge(_ n: String, cx: CGFloat, cy: CGFloat) {
    let r: CGFloat = 12
    let circle = CGRect(x: cx - r, y: cy - r, width: r*2, height: r*2)
    ctx.setFillColor(blue)
    ctx.fillEllipse(in: circle)
    NSAttributedString(string: n, attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paraCenter(),
    ]).draw(in: CGRect(x: cx - r, y: cy - 8, width: r*2, height: 16))
}

// Draw a horizontal divider
func drawDivider(y: CGFloat) {
    ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.08))
    ctx.setLineWidth(1)
    ctx.move(to: CGPoint(x: 32, y: y)); ctx.addLine(to: CGPoint(x: fw - 32, y: y))
    ctx.strokePath()
}

// ── Coordinate map (Finder y from top → CG y from bottom = H - finder_y) ──
// Step 1:   Finder y ≈ 20–180   → CG y ≈ 340–500
// Divider1: Finder y ≈ 210      → CG y ≈ 310
// Step 2:   Finder y ≈ 215–380  → CG y ≈ 140–305
// Divider2: Finder y ≈ 410      → CG y ≈ 110
// Step 3:   Finder y ≈ 415–520  → CG y ≈ 0–105

// ── STEP 1 ─────────────────────────────────────────────────────────────────
// Label row at CG y=488 (finder y=32)
let step1LabelY: CGFloat = 488
drawBadge("1", cx: 48, cy: step1LabelY)
NSAttributedString(string: "Drag Scavodio to Applications", attributes: [
    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
    .foregroundColor: black55,
    .paragraphStyle: paraLeft(),
]).draw(in: CGRect(x: 68, y: step1LabelY - 8, width: 300, height: 18))

NSAttributedString(string: "Перетащи Scavodio в Программы", attributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: black35,
    .paragraphStyle: paraLeft(),
]).draw(in: CGRect(x: 68, y: step1LabelY - 24, width: 300, height: 16))

// Dashed arrow between app icons (Finder y=155 → CG y=365)
let arrowY: CGFloat = 365
let startX: CGFloat = 252, endX: CGFloat = 410
let headW: CGFloat = 18, headH: CGFloat = 22, shaftH2: CGFloat = 4.5
let arrowPath = CGMutablePath()
arrowPath.move(to:    CGPoint(x: startX,         y: arrowY + shaftH2))
arrowPath.addLine(to: CGPoint(x: endX - headW,   y: arrowY + shaftH2))
arrowPath.addLine(to: CGPoint(x: endX - headW,   y: arrowY + headH/2))
arrowPath.addLine(to: CGPoint(x: endX,           y: arrowY))
arrowPath.addLine(to: CGPoint(x: endX - headW,   y: arrowY - headH/2))
arrowPath.addLine(to: CGPoint(x: endX - headW,   y: arrowY - shaftH2))
arrowPath.addLine(to: CGPoint(x: startX,         y: arrowY - shaftH2))
arrowPath.closeSubpath()
ctx.addPath(arrowPath)
ctx.setFillColor(CGColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 0.13))
ctx.setStrokeColor(CGColor(red: 0.50, green: 0.50, blue: 0.56, alpha: 0.60))
ctx.setLineWidth(1.5)
ctx.setLineDash(phase: 0, lengths: [6, 3])
ctx.drawPath(using: .fillStroke)
ctx.setLineDash(phase: 0, lengths: [])

// ── Divider 1 at CG y=308 (Finder y=212) ──────────────────────────────────
drawDivider(y: 308)

// ── STEP 2 ─────────────────────────────────────────────────────────────────
// Label at CG y=292 (Finder y=228)
let step2LabelY: CGFloat = 292
drawBadge("2", cx: 48, cy: step2LabelY)
NSAttributedString(string: "Double-click  \"Open Privacy Settings\"", attributes: [
    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
    .foregroundColor: black55,
    .paragraphStyle: paraLeft(),
]).draw(in: CGRect(x: 68, y: step2LabelY - 8, width: 400, height: 18))

NSAttributedString(string: "Дважды кликни «Open Privacy Settings»", attributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: black35,
    .paragraphStyle: paraLeft(),
]).draw(in: CGRect(x: 68, y: step2LabelY - 24, width: 400, height: 16))

// Icon at Finder y=360 → CG y=160  (icon rendered by Finder, no drawing needed)

// ── Divider 2 at CG y=108 (Finder y=412) ──────────────────────────────────
drawDivider(y: 108)

// ── STEP 3 ─────────────────────────────────────────────────────────────────
let step3LabelY: CGFloat = 88
drawBadge("3", cx: 48, cy: step3LabelY)

// EN
let step3en = NSMutableAttributedString(string: "In System Settings, click  ", attributes: [
    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
    .foregroundColor: black55, .paragraphStyle: paraLeft(),
])
step3en.append(NSAttributedString(string: "\"Open Anyway\"", attributes: [
    .font: NSFont.systemFont(ofSize: 12, weight: .bold),
    .foregroundColor: NSColor(red: 0.18, green: 0.44, blue: 1.0, alpha: 1.0),
    .paragraphStyle: paraLeft(),
]))
step3en.append(NSAttributedString(string: "  for Scavodio", attributes: [
    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
    .foregroundColor: black55, .paragraphStyle: paraLeft(),
]))
step3en.draw(in: CGRect(x: 68, y: step3LabelY - 8, width: 560, height: 18))

// RU
let step3ru = NSMutableAttributedString(string: "В настройках нажми  ", attributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: black35, .paragraphStyle: paraLeft(),
])
step3ru.append(NSAttributedString(string: "«Открыть всё равно»", attributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
    .foregroundColor: NSColor(red: 0.18, green: 0.44, blue: 1.0, alpha: 0.75),
    .paragraphStyle: paraLeft(),
]))
step3ru.append(NSAttributedString(string: "  для Scavodio", attributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: black35, .paragraphStyle: paraLeft(),
]))
step3ru.draw(in: CGRect(x: 68, y: step3LabelY - 24, width: 560, height: 16))

// Fine print
NSAttributedString(string: "One-time only · Только один раз", attributes: [
    .font: NSFont.systemFont(ofSize: 9),
    .foregroundColor: black22,
    .paragraphStyle: paraLeft(),
]).draw(in: CGRect(x: 68, y: 14, width: 300, height: 14))

let png = bmp.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "/tmp/dmg_bg_v9.png"))
print("done → 660×520")
