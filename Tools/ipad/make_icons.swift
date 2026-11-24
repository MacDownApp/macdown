// Makes the iOS app icons from MacDown's macOS icon.
//   swift Tools/ipad/make_icons.swift MacDown/Images.xcassets/AppIcon.appiconset/icon_512x512@2x.png Viewer/App/Assets.xcassets/AppIcon.appiconset
//
// The macOS icon is a rounded square with empty space around it. iOS wants a full-bleed square (it rounds the
// corners itself), so the artwork is cropped and its corners are filled with the gradient. Then:
//   icon-1024.png         the same look as MacDown's icon
//   icon-1024-dark.png    the dark appearance: a deep background, the white glyph unchanged
//   icon-1024-tinted.png  the tinted appearance: grayscale, which iOS colors with the user's chosen tint
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3, let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    FileHandle.standardError.write(Data("usage: make_icons.swift <macos icon png> <output folder>\n".utf8)); exit(1)
}
let outFolder = URL(fileURLWithPath: args[2])
let colorSpace = CGColorSpaceCreateDeviceRGB()

func pixels(of image: CGImage, size: Int? = nil, crop: CGRect? = nil) -> (data: [UInt8], width: Int, height: Int) {
    let w = size ?? image.width, h = size ?? image.height
    var data = [UInt8](repeating: 0, count: w * h * 4)
    let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    if let crop = crop, let part = image.cropping(to: crop) {
        ctx.draw(part, in: CGRect(x: 0, y: 0, width: w, height: h))
    } else {
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return (data, w, h)
}

// 1. Find the rounded square (where the pixels are solid) and crop to it.
let full = pixels(of: image)
var minX = full.width, maxX = 0, minY = full.height, maxY = 0
for y in 0..<full.height { for x in 0..<full.width where full.data[(y * full.width + x) * 4 + 3] > 200 {
    minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
} }
let side = min(maxX - minX, maxY - minY) + 1
let N = 1024
var art = pixels(of: image, size: N, crop: CGRect(x: minX, y: minY, width: side, height: side)).data

// 2. Fill the rounded corners: extend each row's gradient sideways.
func idx(_ x: Int, _ y: Int) -> Int { (y * N + x) * 4 }
for y in 0..<N {
    var left = 0; while left < N && art[idx(left, y) + 3] < 250 { left += 1 }
    var right = N - 1; while right >= 0 && art[idx(right, y) + 3] < 250 { right -= 1 }
    if left >= N || right < 0 {   // A row with no solid pixel: copy the row below or above.
        let from = y > 0 ? y - 1 : min(y + 1, N - 1)
        for x in 0..<N { for c in 0..<4 { art[idx(x, y) + c] = art[idx(x, from) + c] } }
        continue
    }
    let l = min(left + 4, right), r = max(right - 4, left)
    for x in 0..<left { for c in 0..<3 { art[idx(x, y) + c] = art[idx(l, y) + c] }; art[idx(x, y) + 3] = 255 }
    for x in (right + 1)..<N { for c in 0..<3 { art[idx(x, y) + c] = art[idx(r, y) + c] }; art[idx(x, y) + 3] = 255 }
    for x in left...right where art[idx(x, y) + 3] < 255 { art[idx(x, y) + 3] = 255 }   // Anti-aliased edge pixels.
}

func write(_ data: [UInt8], _ name: String) {
    var bytes = data
    let ctx = CGContext(data: &bytes, width: N, height: N, bitsPerComponent: 8, bytesPerRow: N * 4, space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let url = outFolder.appendingPathComponent(name)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(name)")
}

// Colors: "whiteness" is how close a pixel is to white, so the glyph is kept and the background is changed.
func whiteness(_ r: Double, _ g: Double, _ b: Double) -> Double { min(r, g, b) / 255 }

var dark = art, tinted = art
for i in stride(from: 0, to: art.count, by: 4) {
    let r = Double(art[i]), g = Double(art[i + 1]), b = Double(art[i + 2])
    let w = whiteness(r, g, b)
    // Dark: the background becomes a deep version of itself; white stays white.
    let keep = w * w * w
    let darkScale = 0.22 + 0.78 * keep
    dark[i] = UInt8(min(255, r * darkScale)); dark[i + 1] = UInt8(min(255, g * darkScale)); dark[i + 2] = UInt8(min(255, b * darkScale))
    // Tinted: grayscale. A dark gray background and a bright glyph give the system tint something to work with.
    let lum = 0.299 * Double(dark[i]) + 0.587 * Double(dark[i + 1]) + 0.114 * Double(dark[i + 2])
    let gray = UInt8(min(255, lum * (0.55 + 0.9 * keep)))
    tinted[i] = gray; tinted[i + 1] = gray; tinted[i + 2] = gray
}
try? FileManager.default.createDirectory(at: outFolder, withIntermediateDirectories: true)
write(art, "icon-1024.png")
write(dark, "icon-1024-dark.png")
write(tinted, "icon-1024-tinted.png")
