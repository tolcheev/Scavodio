import AppKit
import CoreGraphics

// Generates both 1× (660×520) and 2× (1320×1040) PNGs.
// tiffutil then merges them into a HiDPI-aware TIFF that Finder uses.

func render(scale: Int) -> NSBitmapImageRep {
    let logW: CGFloat = 660, logH: CGFloat = 520
    let s = CGFloat(scale)
    let physW = Int(logW * s), physH = Int(logH * s)

    let bmp = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: physW, pixelsHigh: physH,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)
    let ctx = NSGraphicsContext.current!.cgContext
    let cs = CGColorSpaceCreateDeviceRGB()

    // Scale CG coordinate space so all coords are in logical pixels
    ctx.scaleBy(x: s, y: s)
    let fw = logW, fh = logH

    // ── Background ─────────────────────────────────────────────────────────
    let bgC: [CGFloat] = [0.945,0.945,0.952,1.0, 0.912,0.912,0.924,1.0]
    let bg = CGGradient(colorSpace:cs, colorComponents:bgC, locations:[0,1], count:2)!
    ctx.drawLinearGradient(bg, start:CGPoint(x:fw/2,y:fh), end:CGPoint(x:fw/2,y:0), options:[])
    let vigC: [CGFloat] = [0,0,0,0.0, 0,0,0,0.045]
    let vig = CGGradient(colorSpace:cs, colorComponents:vigC, locations:[0,1], count:2)!
    ctx.drawRadialGradient(vig, startCenter:CGPoint(x:fw/2,y:fh/2), startRadius:0,
        endCenter:CGPoint(x:fw/2,y:fh/2), endRadius:fw*0.8,
        options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])

    // ── Helpers ────────────────────────────────────────────────────────────
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
        ctx.setLineWidth(1/s)  // always 1 physical pixel regardless of scale
        ctx.move(to:CGPoint(x:32,y:cgY)); ctx.addLine(to:CGPoint(x:fw-32,y:cgY))
        ctx.strokePath()
    }

    // ── STEP 1 ─────────────────────────────────────────────────────────────
    badge("1", cx:46, cgY:498)
    NSAttributedString(string:"Drag Scavodio to Applications", attributes:[
        .font:NSFont.systemFont(ofSize:13,weight:.bold),
        .foregroundColor:dark(0.82),.paragraphStyle:pL()
    ]).draw(in:CGRect(x:70,y:490,width:460,height:18))
    NSAttributedString(string:"Перетащи Scavodio в Программы", attributes:[
        .font:NSFont.systemFont(ofSize:11,weight:.medium),
        .foregroundColor:dark(0.55),.paragraphStyle:pL()
    ]).draw(in:CGRect(x:70,y:473,width:460,height:16))

    // Dashed arrow at cg_y=412
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
        ctx.setLineWidth(1.5/s);ctx.setLineDash(phase:0,lengths:[6,3])
        ctx.drawPath(using:.fillStroke);ctx.setLineDash(phase:0,lengths:[])
    }

    divider(cgY:338)

    // ── STEP 2 ─────────────────────────────────────────────────────────────
    badge("2", cx:46, cgY:320)
    NSAttributedString(string:"Open Scavodio — if blocked, click \u{201C}Done\u{201D}", attributes:[
        .font:NSFont.systemFont(ofSize:13,weight:.bold),
        .foregroundColor:dark(0.82),.paragraphStyle:pL()
    ]).draw(in:CGRect(x:70,y:312,width:540,height:18))
    NSAttributedString(string:"Открой Scavodio — если заблокировано, нажми «Готово»", attributes:[
        .font:NSFont.systemFont(ofSize:11,weight:.medium),
        .foregroundColor:dark(0.55),.paragraphStyle:pL()
    ]).draw(in:CGRect(x:70,y:295,width:540,height:16))

    divider(cgY:250)

    // ── STEP 3 ─────────────────────────────────────────────────────────────
    badge("3", cx:46, cgY:232)
    NSAttributedString(string:"Double-click  \u{201C}Open Privacy Settings\u{201D}", attributes:[
        .font:NSFont.systemFont(ofSize:13,weight:.bold),
        .foregroundColor:dark(0.82),.paragraphStyle:pL()
    ]).draw(in:CGRect(x:70,y:224,width:540,height:18))
    NSAttributedString(string:"Дважды кликни «Open Privacy Settings»", attributes:[
        .font:NSFont.systemFont(ofSize:11,weight:.medium),
        .foregroundColor:dark(0.55),.paragraphStyle:pL()
    ]).draw(in:CGRect(x:70,y:207,width:540,height:16))

    divider(cgY:80)

    // ── STEP 4 ─────────────────────────────────────────────────────────────
    badge("4", cx:46, cgY:62)
    let s4en = NSMutableAttributedString(string:"Scroll to Security \u{2192} click ", attributes:[
        .font:NSFont.systemFont(ofSize:13,weight:.bold),
        .foregroundColor:dark(0.82),.paragraphStyle:pL()])
    s4en.append(NSAttributedString(string:"\u{201C}Open Anyway\u{201D}", attributes:[
        .font:NSFont.systemFont(ofSize:13,weight:.bold),
        .foregroundColor:blueNS,.paragraphStyle:pL()]))
    s4en.draw(in:CGRect(x:70,y:54,width:540,height:18))

    let s4ru = NSMutableAttributedString(string:"Прокрути до «Безопасность» → нажми ", attributes:[
        .font:NSFont.systemFont(ofSize:11,weight:.medium),
        .foregroundColor:dark(0.55),.paragraphStyle:pL()])
    s4ru.append(NSAttributedString(string:"«Всё равно открыть»", attributes:[
        .font:NSFont.systemFont(ofSize:11,weight:.semibold),
        .foregroundColor:NSColor(red:0.18,green:0.44,blue:1.0,alpha:0.80),.paragraphStyle:pL()]))
    s4ru.draw(in:CGRect(x:70,y:37,width:540,height:16))

    NSAttributedString(string:"One-time only  ·  Только один раз", attributes:[
        .font:NSFont.systemFont(ofSize:9),.foregroundColor:dark(0.25),.paragraphStyle:pL()
    ]).draw(in:CGRect(x:70,y:14,width:300,height:12))

    return bmp
}

// Render both scales
let rep1x = render(scale: 1)
let rep2x = render(scale: 2)

let png1x = rep1x.representation(using:.png, properties:[:])!
let png2x = rep2x.representation(using:.png, properties:[:])!

try! png1x.write(to:URL(fileURLWithPath:"/tmp/dmg_bg_1x.png"))
try! png2x.write(to:URL(fileURLWithPath:"/tmp/dmg_bg_2x.png"))

print("1x: \(rep1x.pixelsWide)×\(rep1x.pixelsHigh)")
print("2x: \(rep2x.pixelsWide)×\(rep2x.pixelsHigh)")
print("Run: tiffutil -cathidpicheck /tmp/dmg_bg_1x.png /tmp/dmg_bg_2x.png -out /tmp/dmg_bg.tiff")
