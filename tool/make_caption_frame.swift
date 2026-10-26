import Foundation
import CoreGraphics
import ImageIO
import CoreText
import UniformTypeIdentifiers

// Composites a screenshot onto a branded canvas with a caption bar beneath.
// This ffmpeg build has no drawtext filter (no libfreetype), so typography
// happens here instead.

let args = CommandLine.arguments
guard args.count >= 4 else {
    FileHandle.standardError.write("usage: caption <in.png> <out.png> <caption>\n".data(using: .utf8)!)
    exit(1)
}
let inPath = args[1], outPath = args[2], caption = args[3]

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: inPath) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    FileHandle.standardError.write("cannot read \(inPath)\n".data(using: .utf8)!)
    exit(1)
}

let targetW: CGFloat = 1080
let scale = targetW / CGFloat(img.width)
let shotH = (CGFloat(img.height) * scale).rounded()
let barH: CGFloat = 210
let canvasH = shotH + barH

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(targetW), height: Int(canvasH),
                          bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }
ctx.interpolationQuality = .high

// Deep teal from the app icon's lower gradient stop.
ctx.setFillColor(red: 0/255, green: 81/255, blue: 74/255, alpha: 1)
ctx.fill(CGRect(x: 0, y: 0, width: targetW, height: canvasH))

// CoreGraphics origin is bottom-left; the screenshot sits above the bar.
ctx.draw(img, in: CGRect(x: 0, y: barH, width: targetW, height: shotH))

// Caption, centred in the bar, wrapping if long.
// Pure CoreText: this is a Foundation-only CLI, so the AppKit attribute
// constants (NSAttributedString.Key.font and friends) do not exist here.
let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 44, nil)

var alignment = CTTextAlignment.center
var lineBreak = CTLineBreakMode.byWordWrapping
let settings = withUnsafeMutableBytes(of: &alignment) { alignPtr in
    withUnsafeMutableBytes(of: &lineBreak) { breakPtr -> [CTParagraphStyleSetting] in
        [
            CTParagraphStyleSetting(spec: .alignment,
                                    valueSize: MemoryLayout<CTTextAlignment>.size,
                                    value: alignPtr.baseAddress!),
            CTParagraphStyleSetting(spec: .lineBreakMode,
                                    valueSize: MemoryLayout<CTLineBreakMode>.size,
                                    value: breakPtr.baseAddress!),
        ]
    }
}
let paraStyle = CTParagraphStyleCreate(settings, settings.count)

let attrs: [CFString: Any] = [
    kCTFontAttributeName: font,
    kCTForegroundColorAttributeName: CGColor(colorSpace: cs, components: [1, 1, 1, 1])!,
    kCTParagraphStyleAttributeName: paraStyle,
]
let attr = CFAttributedStringCreate(nil, caption as CFString, attrs as CFDictionary)!
let framesetter = CTFramesetterCreateWithAttributedString(attr)
let inset: CGFloat = 70
let bounds = CGRect(x: inset, y: 0, width: targetW - inset * 2, height: barH)
let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
    framesetter, CFRangeMake(0, 0), nil,
    CGSize(width: bounds.width, height: barH), nil)
let textRect = CGRect(x: inset,
                      y: (barH - suggested.height) / 2,
                      width: bounds.width,
                      height: suggested.height)
let path = CGPath(rect: textRect, transform: nil)
let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
CTFrameDraw(frame, ctx)

guard let out = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(dest, out, nil)
if !CGImageDestinationFinalize(dest) { exit(1) }
print("wrote \(outPath)")
