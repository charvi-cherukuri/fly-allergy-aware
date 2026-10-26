import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Fly Allergy Safe — app icon.
//
// One idea, drawn as vectors and rasterised fresh at every size so nothing is
// ever resampled: a shield with a paper plane cut out of it. Shield for the
// safety half of the product, plane for the flying half, and the plane is
// negative space so the whole mark is a single silhouette — which is what
// survives being 40 points wide on a home screen.

struct RGB {
    let r: CGFloat, g: CGFloat, b: CGFloat
    init(_ hex: UInt32) {
        r = CGFloat((hex >> 16) & 0xFF) / 255
        g = CGFloat((hex >> 8) & 0xFF) / 255
        b = CGFloat(hex & 0xFF) / 255
    }
    var components: [CGFloat] { [r, g, b, 1] }
}

// Teal, sitting either side of the app's seed colour (#00695C). Reads as
// medical and calm rather than alarming — the app is used to avoid an
// emergency far more often than during one.
let topTeal = RGB(0x16B39B)
let bottomTeal = RGB(0x00514A)

func shieldPath(in r: CGRect) -> CGPath {
    let p = CGMutablePath()
    let w = r.width, h = r.height, x = r.minX, y = r.minY
    func pt(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
        CGPoint(x: x + fx * w, y: y + fy * h)
    }
    p.move(to: pt(0.5, 0))
    p.addLine(to: pt(1.0, 0.17))
    p.addLine(to: pt(1.0, 0.47))
    p.addCurve(to: pt(0.5, 1.0), control1: pt(1.0, 0.78), control2: pt(0.75, 0.94))
    p.addCurve(to: pt(0.0, 0.47), control1: pt(0.25, 0.94), control2: pt(0.0, 0.78))
    p.addLine(to: pt(0.0, 0.17))
    p.closeSubpath()
    return p
}

func planePath(in r: CGRect) -> CGPath {
    let p = CGMutablePath()
    let w = r.width, h = r.height, x = r.minX, y = r.minY
    func pt(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
        CGPoint(x: x + fx * w, y: y + fy * h)
    }
    // The classic dart: long edge sweeping up to the tip, back down to the
    // tail, then a crease notch. Four points, no curves — it stays legible
    // when it is only a dozen pixels across.
    p.move(to: pt(0.00, 0.50))
    p.addLine(to: pt(1.00, 0.00))
    p.addLine(to: pt(0.46, 1.00))
    p.addLine(to: pt(0.37, 0.63))
    p.closeSubpath()
    return p
}

func renderIcon(size: CGFloat) -> CGImage? {
    let px = Int(size.rounded())
    guard let ctx = CGContext(
        data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }

    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    // Flip so the geometry above can be written top-left down, like every
    // other design tool.
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)

    let s = size

    // Background: a diagonal gradient rather than a flat fill, so the mark has
    // some depth on a busy wallpaper.
    let cs = CGColorSpaceCreateDeviceRGB()
    let colors = [
        CGColor(colorSpace: cs, components: topTeal.components)!,
        CGColor(colorSpace: cs, components: bottomTeal.components)!,
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) {
        ctx.saveGState()
        ctx.addRect(CGRect(x: 0, y: 0, width: s, height: s))
        ctx.clip()
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: s, y: s),
            options: []
        )
        ctx.restoreGState()
    }

    // Shield, deliberately large. A timid mark with lots of padding reads as
    // a blur at 40pt; iOS already rounds the corners for us.
    let shieldRect = CGRect(x: 0.17 * s, y: 0.135 * s, width: 0.66 * s, height: 0.73 * s)
    ctx.addPath(shieldPath(in: shieldRect))
    ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    ctx.fillPath()

    // Plane knocked out in the darker gradient stop so it reads against the
    // white at any size. Sat above the shield's geometric centre, because a
    // shield's optical centre is higher than its middle.
    // The dart's centroid sits at roughly (0.53, 0.46) of its bounding box,
    // not the middle, so centring the box leaves it looking pushed right and
    // high. Nudge back by the difference.
    let pw = shieldRect.width * 0.72
    let planeRect = CGRect(
        x: shieldRect.midX - pw / 2 - pw * 0.030,
        y: shieldRect.minY + shieldRect.height * 0.155 + pw * 0.020,
        width: pw,
        height: pw
    )
    ctx.addPath(planePath(in: planeRect))
    ctx.setFillColor(
        red: bottomTeal.r, green: bottomTeal.g, blue: bottomTeal.b, alpha: 1
    )
    ctx.fillPath()

    return ctx.makeImage()
}

func write(_ image: CGImage, to path: String) -> Bool {
    let url = URL(fileURLWithPath: path) as CFURL
    guard let dest = CGImageDestinationCreateWithURL(
        url, UTType.png.identifier as CFString, 1, nil
    ) else { return false }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

// ---- entry point ----

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: makeicon <outdir>\n".data(using: .utf8)!)
    exit(1)
}
let outDir = args[1]

// name -> pixel size, straight from the asset catalog's Contents.json.
let targets: [(String, CGFloat)] = [
    ("Icon-App-20x20@1x.png", 20), ("Icon-App-20x20@2x.png", 40), ("Icon-App-20x20@3x.png", 60),
    ("Icon-App-29x29@1x.png", 29), ("Icon-App-29x29@2x.png", 58), ("Icon-App-29x29@3x.png", 87),
    ("Icon-App-40x40@1x.png", 40), ("Icon-App-40x40@2x.png", 80), ("Icon-App-40x40@3x.png", 120),
    ("Icon-App-60x60@2x.png", 120), ("Icon-App-60x60@3x.png", 180),
    ("Icon-App-76x76@1x.png", 76), ("Icon-App-76x76@2x.png", 152),
    ("Icon-App-83.5x83.5@2x.png", 167),
    ("Icon-App-1024x1024@1x.png", 1024),
]

var failed = 0
for (name, size) in targets {
    guard let img = renderIcon(size: size), write(img, to: "\(outDir)/\(name)") else {
        FileHandle.standardError.write("failed: \(name)\n".data(using: .utf8)!)
        failed += 1
        continue
    }
}
print(failed == 0 ? "rendered \(targets.count) icons" : "rendered with \(failed) failures")
exit(failed == 0 ? 0 : 1)
