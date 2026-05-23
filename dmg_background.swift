import AppKit
import CoreGraphics

// Window: {100, 100, 760, 664} → outer height 564
// minus title bar ~22 + bottom status bar ~22 → content ≈ 520
// Image: 660 × 520
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
let bgColors: [CGFloat] = [0.945,0.945,0.952,1.0, 0.912,0.912,0.924,1.0]
let bg = CGGradient(colorSpace: cs, colorComponents: bgColors, locations: [0,1], count: 2)!
ctx.drawLinearGradient(bg, start: CGPoint(x:fw/2,y:fh), end: CGPoint(x:fw/2,y:0), options: [])
let vigC: [CGFloat] = [0,0,0,0.0, 0,0,0,0.045]
let vig = CGGradient(colorSpace: cs, colorComponents: vigC, locations:[0,1], count:2)!
ctx.drawRadialGradient(vig, startCenter:CGPoint(x:fw/2,y:fh/2), startRadius:0,
    endCenter:CGPoint(x:fw/2,y:fh/2), endRadius:fw*0.8,
    options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])

// ── Helpers ────────────────────────────────────────────────────────────────
// Finder y (from content top) → CG y = H - finder_y
let blueColor = CGColor(red:0.20,green:0.47,blue:1.00,alpha:1.0)
let blueNS    = NSColor(red:0.18,green:0.44,blue:1.00,alpha:1.0)
func dark(_ a:CGFloat) -> NSColor { NSColor(white:0,alpha:a) }
func pL() -> NSMutableParagraphStyle { let p=NSMutableParagraphStyle();p.alignment = .left;return p }

func badge(_ n:String, cx:CGFloat, cgY:CGFloat) {
    let r:CGFloat=14
    ctx.setFillColor(blueColor)
    ctx.fillEllipse(in:CGRect(x:cx-r,y:cgY-r,width:r*2,height:r*2))
    let p=NSMutableParagraphStyle();p.alignment = .center
    NSAttributedString(string:n,attributes:[
        .font:NSFont.systemFont(ofSize:14,weight:.bold),
        .foregroundColor:NSColor.white,.paragraphStyle:p
    ]).draw(in:CGRect(x:cx-r,y:cgY-10,width:r*2,height:20))
}

func divider(cgY:CGFloat) {
    ctx.setStrokeColor(CGColor(red:0,green:0,blue:0,alpha:0.10))
    ctx.setLineWidth(1)
    ctx.move(to:CGPoint(x:32,y:cgY)); ctx.addLine(to:CGPoint(x:fw-32,y:cgY))
    ctx.strokePath()
}

// ── Layout (Finder y → CG y = 520 - finder_y) ─────────────────────────────
//
// Step 1 badge:  finder 22  → cg 498   App icons: finder 108 → cg 412
// Divider 1:     finder 182 → cg 338
// Step 2 badge:  finder 200 → cg 320   (no icon — just text)
// Divider 2:     finder 270 → cg 250
// Step 3 badge:  finder 288 → cg 232   PREF icon: finder 368 → cg 152
// Divider 3:     finder 440 → cg  80
// Step 4 badge:  finder 458 → cg  62

// ── STEP 1 — Drag to Applications ─────────────────────────────────────────
badge("1", cx:46, cgY:498)
NSAttributedString(string:"Drag Scavodio to Applications", attributes:[
    .font:NSFont.systemFont(ofSize:13,weight:.bold),
    .foregroundColor:dark(0.82),.paragraphStyle:pL()
]).draw(in:CGRect(x:70,y:490,width:460,height:18))
NSAttributedString(string:"Перетащи Scavodio в Программы", attributes:[
    .font:NSFont.systemFont(ofSize:11,weight:.medium),
    .foregroundColor:dark(0.55),.paragraphStyle:pL()
]).draw(in:CGRect(x:70,y:473,width:460,height:16))

// Arrow at cg 412
do {
    let ay:CGFloat=412,sx:CGFloat=248,ex:CGFloat=412
    let hw:CGFloat=18,hh:CGFloat=22,sh:CGFloat=4.5
    let p=CGMutablePath()
    p.move(to:CGPoint(x:sx,y:ay+sh));p.addLine(to:CGPoint(x:ex-hw,y:ay+sh))
    p.addLine(to:CGPoint(x:ex-hw,y:ay+hh/2));p.addLine(to:CGPoint(x:ex,y:ay))
    p.addLine(to:CGPoint(x:ex-hw,y:ay-hh/2));p.addLine(to:CGPoint(x:ex-hw,y:ay-sh))
    p.addLine(to:CGPoint(x:sx,y:ay-sh));p.closeSubpath()
    ctx.addPath(p)
    ctx.setFillColor(CGColor(red:0.55,green:0.55,blue:0.60,alpha:0.12))
    ctx.setStrokeColor(CGColor(red:0.48,green:0.48,blue:0.54,alpha:0.55))
    ctx.setLineWidth(1.5);ctx.setLineDash(phase:0,lengths:[6,3])
    ctx.drawPath(using:.fillStroke);ctx.setLineDash(phase:0,lengths:[])
}

divider(cgY:338)   // finder 182

// ── STEP 2 — Try to open (triggers the "blocked" notice in Settings) ───────
badge("2", cx:46, cgY:320)
NSAttributedString(string:"Open Scavodio — if blocked, click \u{201C}Done\u{201D}", attributes:[
    .font:NSFont.systemFont(ofSize:13,weight:.bold),
    .foregroundColor:dark(0.82),.paragraphStyle:pL()
]).draw(in:CGRect(x:70,y:312,width:540,height:18))
NSAttributedString(string:"Открой Scavodio \u{2014} если заблокировано, нажми \u{00AB}Готово\u{00BB}", attributes:[
    .font:NSFont.systemFont(ofSize:11,weight:.medium),
    .foregroundColor:dark(0.55),.paragraphStyle:pL()
]).draw(in:CGRect(x:70,y:295,width:540,height:16))

divider(cgY:250)   // finder 270

// ── STEP 3 — Open Privacy Settings ────────────────────────────────────────
badge("3", cx:46, cgY:232)
NSAttributedString(string:"Double-click  \u{201C}Open Privacy Settings\u{201D}", attributes:[
    .font:NSFont.systemFont(ofSize:13,weight:.bold),
    .foregroundColor:dark(0.82),.paragraphStyle:pL()
]).draw(in:CGRect(x:70,y:224,width:540,height:18))
NSAttributedString(string:"\u{414}\u{432}\u{430}\u{436}\u{434}\u{44B} \u{43A}\u{43B}\u{438}\u{43A}\u{43D}\u{438} \u{00AB}Open Privacy Settings\u{00BB}", attributes:[
    .font:NSFont.systemFont(ofSize:11,weight:.medium),
    .foregroundColor:dark(0.55),.paragraphStyle:pL()
]).draw(in:CGRect(x:70,y:207,width:540,height:16))

// PREF icon at finder 368 → cg 152 — rendered by Finder

divider(cgY:80)    // finder 440

// ── STEP 4 — Click Open Anyway ────────────────────────────────────────────
badge("4", cx:46, cgY:62)
let s4en = NSMutableAttributedString(string:"Scroll to Security \u{2192} click ", attributes:[
    .font:NSFont.systemFont(ofSize:13,weight:.bold),
    .foregroundColor:dark(0.82),.paragraphStyle:pL()])
s4en.append(NSAttributedString(string:"\u{201C}Open Anyway\u{201D}", attributes:[
    .font:NSFont.systemFont(ofSize:13,weight:.bold),
    .foregroundColor:blueNS,.paragraphStyle:pL()]))
s4en.draw(in:CGRect(x:70,y:54,width:540,height:18))

let s4ru = NSMutableAttributedString(string:"\u{41F}\u{440}\u{43E}\u{43A}\u{440}\u{443}\u{442}\u{438} \u{434}\u{43E} \u{00AB}\u{411}\u{435}\u{437}\u{43E}\u{43F}\u{430}\u{441}\u{43D}\u{43E}\u{441}\u{442}\u{44C}\u{00BB} \u{2192} \u{43D}\u{430}\u{436}\u{43C}\u{438} ", attributes:[
    .font:NSFont.systemFont(ofSize:11,weight:.medium),
    .foregroundColor:dark(0.55),.paragraphStyle:pL()])
s4ru.append(NSAttributedString(string:"\u{00AB}\u{412}\u{441}\u{451} \u{440}\u{430}\u{432}\u{43D}\u{43E} \u{43E}\u{442}\u{43A}\u{440}\u{44B}\u{442}\u{44C}\u{00BB}", attributes:[
    .font:NSFont.systemFont(ofSize:11,weight:.semibold),
    .foregroundColor:NSColor(red:0.18,green:0.44,blue:1.0,alpha:0.80),.paragraphStyle:pL()]))
s4ru.draw(in:CGRect(x:70,y:37,width:540,height:16))

NSAttributedString(string:"One-time only  \u{00B7}  \u{422}\u{43E}\u{43B}\u{44C}\u{43A}\u{43E} \u{43E}\u{434}\u{438}\u{43D} \u{440}\u{430}\u{437}", attributes:[
    .font:NSFont.systemFont(ofSize:9),.foregroundColor:dark(0.25),.paragraphStyle:pL()
]).draw(in:CGRect(x:70,y:14,width:300,height:12))

let png=bmp.representation(using:.png,properties:[:])!
try! png.write(to:URL(fileURLWithPath:"/tmp/dmg_bg_v12.png"))
print("done 660×520, 4 steps")
