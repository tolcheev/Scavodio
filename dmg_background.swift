import AppKit
import CoreGraphics

// Window bounds in AppleScript: {100, 100, 760, 560} → content 660 × 460
let W = 660, H = 460
let fw = CGFloat(W), fh = CGFloat(H)

let bmp = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)
let ctx = NSGraphicsContext.current!.cgContext
let cs = CGColorSpaceCreateDeviceRGB()

// ── Background ─────────────────────────────────────────────────────────────
let bgColors: [CGFloat] = [0.937, 0.937, 0.945, 1.0,  0.906, 0.906, 0.918, 1.0]
let bg = CGGradient(colorSpace: cs, colorComponents: bgColors, locations: [0,1], count: 2)!
ctx.drawLinearGradient(bg, start: CGPoint(x: fw/2, y: fh), end: CGPoint(x: fw/2, y: 0), options: [])

// Subtle edge vignette
let vigColors: [CGFloat] = [0,0,0,0.0, 0,0,0,0.055]
let vig = CGGradient(colorSpace: cs, colorComponents: vigColors, locations: [0,1], count: 2)!
ctx.drawRadialGradient(vig,
    startCenter: CGPoint(x: fw/2, y: fh/2), startRadius: 0,
    endCenter:   CGPoint(x: fw/2, y: fh/2), endRadius: fw * 0.76,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// ── Dashed arrow (app at x=175, apps at x=485, icon centre y=250 from top → y=210 from bottom) ──
let startX: CGFloat = 252, endX: CGFloat = 410, midY: CGFloat = 212
let headW:  CGFloat = 18,  headH: CGFloat = 22, shaftY: CGFloat = 4.5

let arrowPath = CGMutablePath()
arrowPath.move(to:    CGPoint(x: startX,         y: midY + shaftY))
arrowPath.addLine(to: CGPoint(x: endX - headW,   y: midY + shaftY))
arrowPath.addLine(to: CGPoint(x: endX - headW,   y: midY + headH/2))
arrowPath.addLine(to: CGPoint(x: endX,           y: midY))
arrowPath.addLine(to: CGPoint(x: endX - headW,   y: midY - headH/2))
arrowPath.addLine(to: CGPoint(x: endX - headW,   y: midY - shaftY))
arrowPath.addLine(to: CGPoint(x: startX,         y: midY - shaftY))
arrowPath.closeSubpath()

ctx.addPath(arrowPath)
ctx.setFillColor(CGColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 0.13))
ctx.setStrokeColor(CGColor(red: 0.50, green: 0.50, blue: 0.56, alpha: 0.65))
ctx.setLineWidth(1.5)
ctx.setLineDash(phase: 0, lengths: [6, 3])
ctx.drawPath(using: .fillStroke)
ctx.setLineDash(phase: 0, lengths: [])

// ── Divider between install area and help area ─────────────────────────────
// In CG coords (bottom=0): divider at y=148 from bottom = y=312 from top
let divY: CGFloat = 148
ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.08))
ctx.setLineWidth(1)
ctx.move(to: CGPoint(x: 48, y: divY)); ctx.addLine(to: CGPoint(x: fw - 48, y: divY))
ctx.strokePath()

// ── "If blocked by macOS:" label ──────────────────────────────────────────
// y=148 divider → label just below it, so in CG: y=125..140 range
let paraC = NSMutableParagraphStyle(); paraC.alignment = .center
let paraL = NSMutableParagraphStyle(); paraL.alignment = .left

// Centred subtitle above the shortcut icon
NSAttributedString(string: "If blocked by macOS / Если заблокировано:", attributes: [
    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
    .foregroundColor: NSColor(white: 0, alpha: 0.38),
    .paragraphStyle: paraC,
]).draw(in: CGRect(x: 0, y: 116, width: fw, height: 18))

// Arrow down pointing to the icon
NSAttributedString(string: "↓", attributes: [
    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
    .foregroundColor: NSColor(white: 0, alpha: 0.25),
    .paragraphStyle: paraC,
]).draw(in: CGRect(x: 0, y: 96, width: fw, height: 18))

// Fine print below the icon (very bottom)
NSAttributedString(string: "Double-click to open Privacy & Security — then click \"Open Anyway\"  ·  Дважды кликни — нажми «Открыть всё равно»", attributes: [
    .font: NSFont.systemFont(ofSize: 9, weight: .regular),
    .foregroundColor: NSColor(white: 0, alpha: 0.25),
    .paragraphStyle: paraC,
]).draw(in: CGRect(x: 20, y: 12, width: fw - 40, height: 14))

let png = bmp.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "/tmp/dmg_bg_v8.png"))
print("done → 660×460")
