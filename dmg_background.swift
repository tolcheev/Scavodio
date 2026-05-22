import AppKit
import CoreGraphics

// Window outer bounds {100,100,760,664} → outer height=564
// minus title bar ~22 + bottom status bar ~22 → content height ≈ 520
// Image must match content: 660 × 520
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
let bgColors: [CGFloat] = [0.942,0.942,0.950,1.0, 0.910,0.910,0.922,1.0]
let bg = CGGradient(colorSpace: cs, colorComponents: bgColors, locations: [0,1], count: 2)!
ctx.drawLinearGradient(bg, start: CGPoint(x:fw/2,y:fh), end: CGPoint(x:fw/2,y:0), options: [])
let vigC: [CGFloat] = [0,0,0,0.0, 0,0,0,0.045]
let vig = CGGradient(colorSpace: cs, colorComponents: vigC, locations:[0,1], count:2)!
ctx.drawRadialGradient(vig, startCenter:CGPoint(x:fw/2,y:fh/2), startRadius:0,
    endCenter:CGPoint(x:fw/2,y:fh/2), endRadius:fw*0.8,
    options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])

// ── Coordinate note ────────────────────────────────────────────────────────
// Finder y (from content top) → CG y = H - finder_y
// Badge centre, text rects all in CG space.

// ── Helpers ────────────────────────────────────────────────────────────────
let blueColor  = CGColor(red:0.20,green:0.47,blue:1.00,alpha:1.0)
let blueNS     = NSColor(red:0.18,green:0.44,blue:1.00,alpha:1.0)
func dark(_ a:CGFloat)->NSColor { NSColor(white:0,alpha:a) }
func pL()->NSMutableParagraphStyle { let p=NSMutableParagraphStyle();p.alignment = .left; return p }
func pC()->NSMutableParagraphStyle { let p=NSMutableParagraphStyle();p.alignment = .center; return p }

// Numbered badge at CG (cx, cy)
func badge(_ n:String, cx:CGFloat, cy:CGFloat) {
    let r:CGFloat=14
    ctx.setFillColor(blueColor)
    ctx.fillEllipse(in: CGRect(x:cx-r,y:cy-r,width:r*2,height:r*2))
    NSAttributedString(string:n, attributes:[
        .font: NSFont.systemFont(ofSize:14,weight:.bold),
        .foregroundColor: NSColor.white, .paragraphStyle: pC()
    ]).draw(in:CGRect(x:cx-r,y:cy-10,width:r*2,height:20))
}

func divider(cgY:CGFloat) {
    ctx.setStrokeColor(CGColor(red:0,green:0,blue:0,alpha:0.10))
    ctx.setLineWidth(1)
    ctx.move(to:CGPoint(x:32,y:cgY)); ctx.addLine(to:CGPoint(x:fw-32,y:cgY))
    ctx.strokePath()
}

// Main step text row: badge + bold EN + lighter RU below
// badgeCGY = CG y of badge centre
// enText, ruText: the two lines
// returns the CG y of the bottom of the RU line (for gap calc)
@discardableResult
func stepLabel(num:String, badgeCGY:CGFloat, en:String, ru:String,
               enExtra:((NSMutableAttributedString)->Void)?=nil) -> CGFloat {
    let lx:CGFloat = 70   // text left edge
    let lw:CGFloat = fw - lx - 24

    badge(num, cx:46, cy:badgeCGY)

    // EN line: sits at badgeCGY + 6 … badgeCGY + 6 + 18 = badgeCGY - 6 … badgeCGY + 12
    let enStr: NSAttributedString
    if let extra = enExtra {
        let s = NSMutableAttributedString(string:en, attributes:[
            .font:NSFont.systemFont(ofSize:13,weight:.bold),
            .foregroundColor:dark(0.75), .paragraphStyle:pL()])
        extra(s)
        enStr = s
    } else {
        enStr = NSAttributedString(string:en, attributes:[
            .font:NSFont.systemFont(ofSize:13,weight:.bold),
            .foregroundColor:dark(0.75), .paragraphStyle:pL()])
    }
    enStr.draw(in:CGRect(x:lx, y:badgeCGY-6,  width:lw, height:18))

    // RU line below
    NSAttributedString(string:ru, attributes:[
        .font:NSFont.systemFont(ofSize:11,weight:.medium),
        .foregroundColor:dark(0.45), .paragraphStyle:pL()
    ]).draw(in:CGRect(x:lx, y:badgeCGY-24, width:lw, height:16))

    return badgeCGY - 24   // bottom of RU line
}

// ── Positions (Finder y / CG y pairs) ────────────────────────────────────
// App icons:   finder 110 → cg 410
// PREF icon:   finder 298 → cg 222
//
// Step 1 badge finder 22 → cg 498
// Divider1     finder 188 → cg 332
// Step 2 badge finder 208 → cg 312
// Divider2     finder 388 → cg 132
// Step 3 badge finder 408 → cg 112
// Fine print   finder 500 → cg  20

// ── STEP 1 ────────────────────────────────────────────────────────────────
stepLabel(num:"1", badgeCGY:498,
          en:"Drag Scavodio to Applications",
          ru:"Перетащи Scavodio в Программы")

// Dashed arrow between icons at cg_y=410 (finder 110)
do {
    let ay:CGFloat=410, sx:CGFloat=248, ex:CGFloat=412
    let hw:CGFloat=18, hh:CGFloat=22, sh:CGFloat=4.5
    let p=CGMutablePath()
    p.move(to:CGPoint(x:sx,y:ay+sh)); p.addLine(to:CGPoint(x:ex-hw,y:ay+sh))
    p.addLine(to:CGPoint(x:ex-hw,y:ay+hh/2)); p.addLine(to:CGPoint(x:ex,y:ay))
    p.addLine(to:CGPoint(x:ex-hw,y:ay-hh/2)); p.addLine(to:CGPoint(x:ex-hw,y:ay-sh))
    p.addLine(to:CGPoint(x:sx,y:ay-sh)); p.closeSubpath()
    ctx.addPath(p)
    ctx.setFillColor(CGColor(red:0.55,green:0.55,blue:0.60,alpha:0.12))
    ctx.setStrokeColor(CGColor(red:0.48,green:0.48,blue:0.54,alpha:0.55))
    ctx.setLineWidth(1.5); ctx.setLineDash(phase:0,lengths:[6,3])
    ctx.drawPath(using:.fillStroke); ctx.setLineDash(phase:0,lengths:[])
}

// ── Divider 1 ─────────────────────────────────────────────────────────────
divider(cgY:332)   // finder 188

// ── STEP 2 ────────────────────────────────────────────────────────────────
stepLabel(num:"2", badgeCGY:312,
          en:"Double-click  \"Open Privacy Settings\"",
          ru:"Дважды кликни «Open Privacy Settings»")

// ── Divider 2 ─────────────────────────────────────────────────────────────
divider(cgY:132)   // finder 388

// ── STEP 3 ────────────────────────────────────────────────────────────────
stepLabel(num:"3", badgeCGY:112,
          en:"In System Settings → click ",
          ru:"В Настройках → нажми «Открыть всё равно»") { s in
    s.append(NSAttributedString(string:"\"Open Anyway\"", attributes:[
        .font:NSFont.systemFont(ofSize:13,weight:.bold),
        .foregroundColor:blueNS, .paragraphStyle:pL()]))
}

// Fine print
NSAttributedString(string:"One-time only  ·  Только один раз", attributes:[
    .font:NSFont.systemFont(ofSize:9), .foregroundColor:dark(0.25), .paragraphStyle:pL()
]).draw(in:CGRect(x:70,y:8,width:300,height:12))

let png=bmp.representation(using:.png,properties:[:])!
try! png.write(to:URL(fileURLWithPath:"/tmp/dmg_bg_v11.png"))
print("done 660×520")
