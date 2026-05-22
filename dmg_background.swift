import AppKit
import CoreGraphics

// Window: {100, 100, 760, 540} → content 660 × 440
// Finder y: from top of content. CG y: from bottom. CG y = 440 - finder_y
let W = 660, H = 440
let fw = CGFloat(W), fh = CGFloat(H)

let bmp = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)
let ctx = NSGraphicsContext.current!.cgContext
let cs = CGColorSpaceCreateDeviceRGB()

// ── Background ─────────────────────────────────────────────────────────────
let bgColors: [CGFloat] = [0.940, 0.940, 0.948, 1.0,  0.910, 0.910, 0.920, 1.0]
let bg = CGGradient(colorSpace: cs, colorComponents: bgColors, locations: [0,1], count: 2)!
ctx.drawLinearGradient(bg, start: CGPoint(x: fw/2, y: fh), end: CGPoint(x: fw/2, y: 0), options: [])
let vigC: [CGFloat] = [0,0,0,0.0, 0,0,0,0.05]
let vig = CGGradient(colorSpace: cs, colorComponents: vigC, locations: [0,1], count: 2)!
ctx.drawRadialGradient(vig, startCenter: CGPoint(x:fw/2,y:fh/2), startRadius: 0,
    endCenter: CGPoint(x:fw/2,y:fh/2), endRadius: fw*0.78,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// ── Helpers ────────────────────────────────────────────────────────────────
let blue = CGColor(red: 0.20, green: 0.47, blue: 1.00, alpha: 1.0)
let blueNS = NSColor(red: 0.18, green: 0.44, blue: 1.0, alpha: 1.0)
func black(_ a: CGFloat) -> NSColor { NSColor(white: 0, alpha: a) }
func pL() -> NSMutableParagraphStyle { let p = NSMutableParagraphStyle(); p.alignment = .left; return p }

// Badge: filled blue circle with white number, centre at (cx, cgY)
func badge(_ n: String, cx: CGFloat, cgY: CGFloat) {
    let r: CGFloat = 13
    ctx.setFillColor(blue)
    ctx.fillEllipse(in: CGRect(x: cx-r, y: cgY-r, width: r*2, height: r*2))
    NSAttributedString(string: n, attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: { let p = NSMutableParagraphStyle(); p.alignment = .center; return p }(),
    ]).draw(in: CGRect(x: cx-r, y: cgY-9, width: r*2, height: 18))
}

func divider(cgY: CGFloat) {
    ctx.setStrokeColor(CGColor(red:0,green:0,blue:0,alpha:0.09))
    ctx.setLineWidth(1)
    ctx.move(to: CGPoint(x: 32, y: cgY))
    ctx.addLine(to: CGPoint(x: fw-32, y: cgY))
    ctx.strokePath()
}

// ── LAYOUT (Finder y from content top, CG y = H - finder_y) ───────────────
//
// Step 1  label:  finder_y = 22   → cg_y = 418
//   sub:          finder_y = 38   → cg_y = 402
// App icons:      finder_y = 108  → cg_y = 332   (icon 96px, top@60, bottom@156, label@171)
// ─ divider ─     finder_y = 185  → cg_y = 255
// Step 2  label:  finder_y = 205  → cg_y = 235
//   sub:          finder_y = 221  → cg_y = 219
// PREF icon:      finder_y = 300  → cg_y = 140   (top@252, bottom@348, label@363)
// ─ divider ─     finder_y = 375  → cg_y = 65
// Step 3  label:  finder_y = 393  → cg_y = 47
//   sub:          finder_y = 409  → cg_y = 31
// fine print:     finder_y = 428  → cg_y = 12

// ── STEP 1 ─────────────────────────────────────────────────────────────────
badge("1", cx: 48, cgY: 418)
NSAttributedString(string: "Drag Scavodio to Applications", attributes: [
    .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
    .foregroundColor: black(0.60), .paragraphStyle: pL(),
]).draw(in: CGRect(x: 70, y: 410, width: 400, height: 18))
NSAttributedString(string: "Перетащи Scavodio в Программы", attributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: black(0.38), .paragraphStyle: pL(),
]).draw(in: CGRect(x: 70, y: 393, width: 400, height: 16))

// Dashed arrow at cg_y=332 (between app icons)
do {
    let ay: CGFloat = 332, sx: CGFloat = 248, ex: CGFloat = 412
    let hw: CGFloat = 18, hh: CGFloat = 22, sh: CGFloat = 4.5
    let p = CGMutablePath()
    p.move(to:    CGPoint(x: sx,    y: ay+sh)); p.addLine(to: CGPoint(x: ex-hw, y: ay+sh))
    p.addLine(to: CGPoint(x: ex-hw, y: ay+hh/2)); p.addLine(to: CGPoint(x: ex, y: ay))
    p.addLine(to: CGPoint(x: ex-hw, y: ay-hh/2)); p.addLine(to: CGPoint(x: ex-hw, y: ay-sh))
    p.addLine(to: CGPoint(x: sx,    y: ay-sh)); p.closeSubpath()
    ctx.addPath(p)
    ctx.setFillColor(CGColor(red:0.55,green:0.55,blue:0.60,alpha:0.12))
    ctx.setStrokeColor(CGColor(red:0.50,green:0.50,blue:0.56,alpha:0.60))
    ctx.setLineWidth(1.5); ctx.setLineDash(phase:0, lengths:[6,3])
    ctx.drawPath(using: .fillStroke); ctx.setLineDash(phase:0, lengths:[])
}

// ── Divider 1 at cg_y = 255 ────────────────────────────────────────────────
divider(cgY: 255)

// ── STEP 2 ─────────────────────────────────────────────────────────────────
badge("2", cx: 48, cgY: 235)
NSAttributedString(string: "Double-click  \"Open Privacy Settings\"", attributes: [
    .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
    .foregroundColor: black(0.60), .paragraphStyle: pL(),
]).draw(in: CGRect(x: 70, y: 227, width: 500, height: 18))
NSAttributedString(string: "Дважды кликни «Open Privacy Settings»", attributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: black(0.38), .paragraphStyle: pL(),
]).draw(in: CGRect(x: 70, y: 211, width: 500, height: 16))

// PREF icon is at finder_y=300, cg_y=140 — Finder renders it automatically

// ── Divider 2 at cg_y = 65 ─────────────────────────────────────────────────
divider(cgY: 65)

// ── STEP 3 ─────────────────────────────────────────────────────────────────
badge("3", cx: 48, cgY: 47)

let en3 = NSMutableAttributedString(string: "In System Settings → click  ", attributes: [
    .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
    .foregroundColor: black(0.60), .paragraphStyle: pL(),
])
en3.append(NSAttributedString(string: "\"Open Anyway\"", attributes: [
    .font: NSFont.systemFont(ofSize: 13, weight: .bold),
    .foregroundColor: blueNS, .paragraphStyle: pL(),
]))
en3.draw(in: CGRect(x: 70, y: 39, width: 520, height: 18))

let ru3 = NSMutableAttributedString(string: "В Настройках → нажми  ", attributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: black(0.38), .paragraphStyle: pL(),
])
ru3.append(NSAttributedString(string: "«Открыть всё равно»", attributes: [
    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
    .foregroundColor: NSColor(red:0.18,green:0.44,blue:1.0,alpha:0.72), .paragraphStyle: pL(),
]))
ru3.draw(in: CGRect(x: 70, y: 23, width: 520, height: 16))

NSAttributedString(string: "One-time only  ·  Только один раз", attributes: [
    .font: NSFont.systemFont(ofSize: 8.5),
    .foregroundColor: black(0.20), .paragraphStyle: pL(),
]).draw(in: CGRect(x: 70, y: 6, width: 300, height: 12))

let png = bmp.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "/tmp/dmg_bg_v10.png"))
print("done 660×440")
