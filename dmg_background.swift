import AppKit
import CoreGraphics

let W = 660, H = 380
let fw = CGFloat(W), fh = CGFloat(H)

let bmp = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)
let ctx = NSGraphicsContext.current!.cgContext
let cs = CGColorSpaceCreateDeviceRGB()

// ── Clean light background ─────────────────────────────────────────────────
// Top: #EEEEF0, Bottom: #E6E6E9
let bgColors: [CGFloat] = [
    0.935, 0.935, 0.941, 1.0,
    0.902, 0.902, 0.914, 1.0,
]
let bg = CGGradient(colorSpace: cs, colorComponents: bgColors, locations: [0,1], count: 2)!
ctx.drawLinearGradient(bg, start: CGPoint(x: fw/2, y: fh), end: CGPoint(x: fw/2, y: 0), options: [])

// ── Subtle vignette (darker edges) ────────────────────────────────────────
let vigColors: [CGFloat] = [0,0,0,0.0,  0,0,0,0.06]
let vig = CGGradient(colorSpace: cs, colorComponents: vigColors, locations: [0,1], count: 2)!
ctx.drawRadialGradient(vig,
    startCenter: CGPoint(x: fw/2, y: fh/2), startRadius: 0,
    endCenter:   CGPoint(x: fw/2, y: fh/2), endRadius: fw * 0.72,
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// ── Dashed arrow ──────────────────────────────────────────────────────────
// Arrow runs from x=240 to x=420, centred at y=185
let startX: CGFloat = 248
let endX:   CGFloat = 412
let midY:   CGFloat = 183
let headW:  CGFloat = 18
let headH:  CGFloat = 24
let shaftY: CGFloat = 5   // half shaft height

// Build arrow outline path
let arrowPath = CGMutablePath()
// Shaft top
arrowPath.move(to:    CGPoint(x: startX,          y: midY + shaftY))
arrowPath.addLine(to: CGPoint(x: endX - headW,    y: midY + shaftY))
// Head top-wing
arrowPath.addLine(to: CGPoint(x: endX - headW,    y: midY + headH/2))
// Tip
arrowPath.addLine(to: CGPoint(x: endX,            y: midY))
// Head bottom-wing
arrowPath.addLine(to: CGPoint(x: endX - headW,    y: midY - headH/2))
// Shaft bottom
arrowPath.addLine(to: CGPoint(x: endX - headW,    y: midY - shaftY))
arrowPath.addLine(to: CGPoint(x: startX,          y: midY - shaftY))
arrowPath.closeSubpath()

// Draw as dashed stroke only (hollow)
ctx.addPath(arrowPath)
ctx.setStrokeColor(CGColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 0.70))
ctx.setFillColor(CGColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 0.12))
ctx.setLineWidth(1.5)
ctx.setLineDash(phase: 0, lengths: [6, 3])
ctx.drawPath(using: .fillStroke)
ctx.setLineDash(phase: 0, lengths: [])

// ── Minimal hint at the very bottom ───────────────────────────────────────
let paraStyle = NSMutableParagraphStyle(); paraStyle.alignment = .center
NSAttributedString(string: "Drag to Applications, then double-click \"Open Privacy Settings\" if blocked", attributes: [
    .font: NSFont.systemFont(ofSize: 10, weight: .regular),
    .foregroundColor: NSColor(white: 0, alpha: 0.28),
    .paragraphStyle: paraStyle,
]).draw(in: CGRect(x: 40, y: 14, width: fw - 80, height: 16))

let png = bmp.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: "/tmp/dmg_bg_v7.png"))
print("done")
