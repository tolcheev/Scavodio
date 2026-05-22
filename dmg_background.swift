import AppKit
import CoreGraphics

let W = 660, H = 430
let fw = CGFloat(W), fh = CGFloat(H)

let bmp = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)
let ctx = NSGraphicsContext.current!.cgContext
let cs = CGColorSpaceCreateDeviceRGB()

// ── Background ─────────────────────────────────────────────────────────────
let bgColors: [CGFloat] = [0.067, 0.071, 0.102, 1.0,  0.102, 0.106, 0.149, 1.0]
let bg = CGGradient(colorSpace: cs, colorComponents: bgColors, locations: [0, 1], count: 2)!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: fh), end: CGPoint(x: fw, y: 0), options: [])

let vigColors: [CGFloat] = [1,1,1,0.04, 1,1,1,0.0]
let vig = CGGradient(colorSpace: cs, colorComponents: vigColors, locations: [0,1], count: 2)!
ctx.drawRadialGradient(vig,
    startCenter: CGPoint(x: fw/2, y: fh/2), startRadius: 0,
    endCenter:   CGPoint(x: fw/2, y: fh/2), endRadius: fw * 0.65,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// ── Waveform bars ──────────────────────────────────────────────────────────
let barHeights: [CGFloat] = [28, 52, 72, 88, 72, 52, 28]
let barW: CGFloat = 5, barGap: CGFloat = 8
let totalBarW = CGFloat(barHeights.count) * barW + CGFloat(barHeights.count - 1) * barGap
let barY: CGFloat = 205

func drawBars(centreX: CGFloat, alpha: CGFloat) {
    let startX = centreX - totalBarW / 2
    for (i, bh) in barHeights.enumerated() {
        let x = startX + CGFloat(i) * (barW + barGap)
        let t = CGFloat(i) / CGFloat(barHeights.count - 1)
        let bright = 0.55 + 0.45 * sin(t * .pi)
        ctx.setFillColor(CGColor(red: 0.42*bright, green: 0.52*bright, blue: 0.95*bright, alpha: alpha))
        ctx.fill(CGRect(x: x, y: barY - bh/2, width: barW, height: bh))
    }
}
drawBars(centreX: 90,      alpha: 0.28)
drawBars(centreX: fw - 90, alpha: 0.28)

// ── Arrow ──────────────────────────────────────────────────────────────────
let arrowMinX: CGFloat = 237, arrowMaxX: CGFloat = 423, arrowMidY: CGFloat = 203
let shaftH: CGFloat = 10, headH: CGFloat = 26, headW: CGFloat = 22
let arrow = CGMutablePath()
arrow.move(to:    CGPoint(x: arrowMinX,            y: arrowMidY - shaftH/2))
arrow.addLine(to: CGPoint(x: arrowMaxX - headW,    y: arrowMidY - shaftH/2))
arrow.addLine(to: CGPoint(x: arrowMaxX - headW,    y: arrowMidY - headH/2))
arrow.addLine(to: CGPoint(x: arrowMaxX,            y: arrowMidY))
arrow.addLine(to: CGPoint(x: arrowMaxX - headW,    y: arrowMidY + headH/2))
arrow.addLine(to: CGPoint(x: arrowMaxX - headW,    y: arrowMidY + shaftH/2))
arrow.addLine(to: CGPoint(x: arrowMinX,            y: arrowMidY + shaftH/2))
arrow.closeSubpath()
ctx.setShadow(offset: .zero, blur: 18, color: CGColor(red:0.42, green:0.52, blue:0.98, alpha:0.55))
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.50))
ctx.addPath(arrow); ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// ── Watermark ──────────────────────────────────────────────────────────────
let wmStyle = NSMutableParagraphStyle(); wmStyle.alignment = .center
NSAttributedString(string: "SCAVODIO", attributes: [
    .font: NSFont.systemFont(ofSize: 88, weight: .black),
    .foregroundColor: NSColor(white: 1, alpha: 0.033),
    .paragraphStyle: wmStyle, .kern: 12.0,
]).draw(in: CGRect(x: 0, y: fh/2 - 30, width: fw, height: 100))

// ── Divider ────────────────────────────────────────────────────────────────
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.09))
ctx.setLineWidth(1)
ctx.move(to: CGPoint(x: 40, y: 118)); ctx.addLine(to: CGPoint(x: fw-40, y: 118))
ctx.strokePath()

// ── Vertical divider between EN and RU columns ─────────────────────────────
ctx.move(to: CGPoint(x: fw/2, y: 16)); ctx.addLine(to: CGPoint(x: fw/2, y: 108))
ctx.strokePath()

// ── Text helpers ───────────────────────────────────────────────────────────
let accent = NSColor(red: 0.42, green: 0.62, blue: 1.0, alpha: 0.90)
let dim    = NSColor(white: 1, alpha: 0.50)
let faint  = NSColor(white: 1, alpha: 0.22)
let label  = NSColor(red: 0.42, green: 0.52, blue: 0.95, alpha: 0.65)

func leftStyle()  -> NSMutableParagraphStyle { let p = NSMutableParagraphStyle(); p.alignment = .left;  return p }
func rightStyle() -> NSMutableParagraphStyle { let p = NSMutableParagraphStyle(); p.alignment = .right; return p }
func centStyle()  -> NSMutableParagraphStyle { let p = NSMutableParagraphStyle(); p.alignment = .center; return p }

let colPad: CGFloat = 18
let colW = fw/2 - colPad * 2

// ── EN column (left) ───────────────────────────────────────────────────────
// Header
NSAttributedString(string: "FIRST LAUNCH", attributes: [
    .font: NSFont.systemFont(ofSize: 8.5, weight: .semibold),
    .foregroundColor: label, .paragraphStyle: leftStyle(), .kern: 2.0,
]).draw(in: CGRect(x: colPad, y: 93, width: colW, height: 16))

// Step 1
NSAttributedString(string: "1  Drag Scavodio to Applications", attributes: [
    .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
    .foregroundColor: dim, .paragraphStyle: leftStyle(),
]).draw(in: CGRect(x: colPad, y: 72, width: colW, height: 16))

// Step 2
let en2 = NSMutableAttributedString(string: "2  System Settings → Privacy & Security\n    → ", attributes: [
    .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
    .foregroundColor: dim, .paragraphStyle: leftStyle(),
])
en2.append(NSAttributedString(string: "Open Anyway", attributes: [
    .font: NSFont.systemFont(ofSize: 10.5, weight: .semibold),
    .foregroundColor: accent, .paragraphStyle: leftStyle(),
]))
en2.draw(in: CGRect(x: colPad, y: 38, width: colW, height: 32))

// Fine print EN
NSAttributedString(string: "One-time only", attributes: [
    .font: NSFont.systemFont(ofSize: 8.5, weight: .regular),
    .foregroundColor: faint, .paragraphStyle: leftStyle(),
]).draw(in: CGRect(x: colPad, y: 20, width: colW, height: 14))

// ── RU column (right) ─────────────────────────────────────────────────────
let rx = fw/2 + colPad

// Header
NSAttributedString(string: "ПЕРВЫЙ ЗАПУСК", attributes: [
    .font: NSFont.systemFont(ofSize: 8.5, weight: .semibold),
    .foregroundColor: label, .paragraphStyle: leftStyle(), .kern: 2.0,
]).draw(in: CGRect(x: rx, y: 93, width: colW, height: 16))

// Step 1
NSAttributedString(string: "1  Перетащи Scavodio в Программы", attributes: [
    .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
    .foregroundColor: dim, .paragraphStyle: leftStyle(),
]).draw(in: CGRect(x: rx, y: 72, width: colW, height: 16))

// Step 2
let ru2 = NSMutableAttributedString(string: "2  Настройки → Конфид. и безопасность\n    → ", attributes: [
    .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
    .foregroundColor: dim, .paragraphStyle: leftStyle(),
])
ru2.append(NSAttributedString(string: "Открыть всё равно", attributes: [
    .font: NSFont.systemFont(ofSize: 10.5, weight: .semibold),
    .foregroundColor: accent, .paragraphStyle: leftStyle(),
]))
ru2.draw(in: CGRect(x: rx, y: 38, width: colW, height: 32))

// Fine print RU
NSAttributedString(string: "Только один раз", attributes: [
    .font: NSFont.systemFont(ofSize: 8.5, weight: .regular),
    .foregroundColor: faint, .paragraphStyle: leftStyle(),
]).draw(in: CGRect(x: rx, y: 20, width: colW, height: 14))

let png = bmp.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "/tmp/dmg_bg_v5.png"))
print("done")
