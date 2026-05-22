import AppKit
import CoreGraphics

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
let bgColors: [CGFloat] = [0.067, 0.071, 0.102, 1.0,  0.102, 0.106, 0.149, 1.0]
let bg = CGGradient(colorSpace: cs, colorComponents: bgColors, locations: [0, 1], count: 2)!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: fh), end: CGPoint(x: fw, y: 0), options: [])

let vigColors: [CGFloat] = [1,1,1,0.04, 1,1,1,0.0]
let vig = CGGradient(colorSpace: cs, colorComponents: vigColors, locations: [0,1], count: 2)!
ctx.drawRadialGradient(vig,
    startCenter: CGPoint(x: fw/2, y: fh/2+20), startRadius: 0,
    endCenter:   CGPoint(x: fw/2, y: fh/2+20), endRadius: fw * 0.65,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// ── Waveform bars ──────────────────────────────────────────────────────────
let barHeights: [CGFloat] = [28, 52, 72, 88, 72, 52, 28]
let barW: CGFloat = 5, barGap: CGFloat = 8
let totalBarW = CGFloat(barHeights.count) * barW + CGFloat(barHeights.count - 1) * barGap
let barY: CGFloat = 215

func drawBars(centreX: CGFloat, alpha: CGFloat) {
    let startX = centreX - totalBarW / 2
    for (i, bh) in barHeights.enumerated() {
        let t = CGFloat(i) / CGFloat(barHeights.count - 1)
        let bright = 0.55 + 0.45 * sin(t * .pi)
        ctx.setFillColor(CGColor(red: 0.42*bright, green: 0.52*bright, blue: 0.95*bright, alpha: alpha))
        ctx.fill(CGRect(x: startX + CGFloat(i)*(barW+barGap), y: barY - bh/2, width: barW, height: bh))
    }
}
drawBars(centreX: 90,      alpha: 0.26)
drawBars(centreX: fw - 90, alpha: 0.26)

// ── Arrow ──────────────────────────────────────────────────────────────────
let arrowMinX: CGFloat = 237, arrowMaxX: CGFloat = 423, arrowMidY: CGFloat = 213
let shaftH: CGFloat = 10, headH: CGFloat = 26, headW: CGFloat = 22
let arrow = CGMutablePath()
arrow.move(to:    CGPoint(x: arrowMinX,         y: arrowMidY - shaftH/2))
arrow.addLine(to: CGPoint(x: arrowMaxX - headW, y: arrowMidY - shaftH/2))
arrow.addLine(to: CGPoint(x: arrowMaxX - headW, y: arrowMidY - headH/2))
arrow.addLine(to: CGPoint(x: arrowMaxX,         y: arrowMidY))
arrow.addLine(to: CGPoint(x: arrowMaxX - headW, y: arrowMidY + headH/2))
arrow.addLine(to: CGPoint(x: arrowMaxX - headW, y: arrowMidY + shaftH/2))
arrow.addLine(to: CGPoint(x: arrowMinX,         y: arrowMidY + shaftH/2))
arrow.closeSubpath()
ctx.setShadow(offset: .zero, blur: 18, color: CGColor(red:0.42, green:0.52, blue:0.98, alpha:0.55))
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.48))
ctx.addPath(arrow); ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// ── Watermark ──────────────────────────────────────────────────────────────
let wmStyle = NSMutableParagraphStyle(); wmStyle.alignment = .center
NSAttributedString(string: "SCAVODIO", attributes: [
    .font: NSFont.systemFont(ofSize: 88, weight: .black),
    .foregroundColor: NSColor(white: 1, alpha: 0.030),
    .paragraphStyle: wmStyle, .kern: 12.0,
]).draw(in: CGRect(x: 0, y: fh/2 - 20, width: fw, height: 100))

// ── Instruction box ────────────────────────────────────────────────────────
// Rounded rect background for the instruction area
let boxRect = CGRect(x: 24, y: 8, width: fw - 48, height: 122)
let boxPath = CGPath(roundedRect: boxRect, cornerWidth: 10, cornerHeight: 10, transform: nil)
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.04))
ctx.addPath(boxPath); ctx.fillPath()
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
ctx.setLineWidth(1)
ctx.addPath(boxPath); ctx.strokePath()

// Vertical divider
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
ctx.move(to: CGPoint(x: fw/2, y: 16)); ctx.addLine(to: CGPoint(x: fw/2, y: 122))
ctx.strokePath()

// ── Helpers ────────────────────────────────────────────────────────────────
let yellow  = NSColor(red: 1.00, green: 0.80, blue: 0.20, alpha: 0.90)
let accent  = NSColor(red: 0.40, green: 0.65, blue: 1.00, alpha: 0.95)
let white70 = NSColor(white: 1, alpha: 0.70)
let white40 = NSColor(white: 1, alpha: 0.40)
let white22 = NSColor(white: 1, alpha: 0.22)

func L() -> NSMutableParagraphStyle { let p = NSMutableParagraphStyle(); p.alignment = .left; return p }

let col: CGFloat = 18   // padding inside each half
let colW: CGFloat = fw/2 - col*2 - 4

// ── EN (left) ──────────────────────────────────────────────────────────────
let ex = col + 6

// Header with lock icon
NSAttributedString(string: "🔐 FIRST LAUNCH", attributes: [
    .font: NSFont.systemFont(ofSize: 9, weight: .bold),
    .foregroundColor: yellow,
    .paragraphStyle: L(), .kern: 1.5,
]).draw(in: CGRect(x: ex, y: 100, width: colW, height: 16))

// Step 1
NSAttributedString(string: "① Drag Scavodio to Applications", attributes: [
    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
    .foregroundColor: white70, .paragraphStyle: L(),
]).draw(in: CGRect(x: ex, y: 80, width: colW, height: 16))

// Step 2 - two lines
NSAttributedString(string: "② System Settings →", attributes: [
    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
    .foregroundColor: white70, .paragraphStyle: L(),
]).draw(in: CGRect(x: ex, y: 60, width: colW, height: 16))

let en2 = NSMutableAttributedString(string: "   Privacy & Security → ", attributes: [
    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
    .foregroundColor: white70, .paragraphStyle: L(),
])
en2.append(NSAttributedString(string: "Open Anyway", attributes: [
    .font: NSFont.systemFont(ofSize: 10, weight: .bold),
    .foregroundColor: accent, .paragraphStyle: L(),
]))
en2.draw(in: CGRect(x: ex, y: 42, width: colW, height: 16))

NSAttributedString(string: "One-time · never asked again", attributes: [
    .font: NSFont.systemFont(ofSize: 8.5),
    .foregroundColor: white22, .paragraphStyle: L(),
]).draw(in: CGRect(x: ex, y: 20, width: colW, height: 14))

// ── RU (right) ─────────────────────────────────────────────────────────────
let rx = fw/2 + col + 2

NSAttributedString(string: "🔐 ПЕРВЫЙ ЗАПУСК", attributes: [
    .font: NSFont.systemFont(ofSize: 9, weight: .bold),
    .foregroundColor: yellow,
    .paragraphStyle: L(), .kern: 1.5,
]).draw(in: CGRect(x: rx, y: 100, width: colW, height: 16))

NSAttributedString(string: "① Перетащи Scavodio в Программы", attributes: [
    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
    .foregroundColor: white70, .paragraphStyle: L(),
]).draw(in: CGRect(x: rx, y: 80, width: colW, height: 16))

NSAttributedString(string: "② Настройки → Конфиден. и безоп. →", attributes: [
    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
    .foregroundColor: white70, .paragraphStyle: L(),
]).draw(in: CGRect(x: rx, y: 60, width: colW, height: 16))

let ru2 = NSMutableAttributedString(string: "   → ", attributes: [
    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
    .foregroundColor: white70, .paragraphStyle: L(),
])
ru2.append(NSAttributedString(string: "Открыть всё равно", attributes: [
    .font: NSFont.systemFont(ofSize: 10, weight: .bold),
    .foregroundColor: accent, .paragraphStyle: L(),
]))
ru2.draw(in: CGRect(x: rx, y: 42, width: colW, height: 16))

NSAttributedString(string: "Только один раз · больше не спросит", attributes: [
    .font: NSFont.systemFont(ofSize: 8.5),
    .foregroundColor: white22, .paragraphStyle: L(),
]).draw(in: CGRect(x: rx, y: 20, width: colW, height: 14))

let png = bmp.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "/tmp/dmg_bg_v6.png"))
print("done")
