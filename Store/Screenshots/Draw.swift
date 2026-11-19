// The slides' drawing script. compose.py builds it once per run (swiftc -Onone) and runs it:
//
//   draw frame <bezel.png> <shot.png> <out.png>
//       Puts a screenshot into Apple's bezel picture: the screen is the clear hole in the
//       middle of the bezel, found by a flood fill from its centre. The shot must be the
//       hole's size, so nothing scales. The output keeps alpha (it is not a slide).
//   draw slide <spec.json> <out.png>
//       Draws one slide from its spec: an opaque sRGB canvas, the devices with one soft
//       shadow, then the captions. A caption that does not fit its box stops the draw.

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func load(_ path: String) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(filePath: path) as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw Failure("cannot read \(path)") }
    return image
}

func save(_ image: CGImage, _ path: String) throws {
    guard let destination = CGImageDestinationCreateWithURL(URL(filePath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw Failure("cannot write \(path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw Failure("cannot write \(path)") }
}

/// RGBA bytes of an image, premultiplied, rows from the top.
func rgba(_ image: CGImage) -> (bytes: [UInt8], width: Int, height: Int) {
    let width = image.width, height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(
            data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return (bytes, width, height)
}

func frame(bezelPath: String, shotPath: String, outPath: String) throws {
    let bezel = try load(bezelPath)
    let shot = try load(shotPath)
    let (bytes, width, height) = rgba(bezel)
    // Flood fill the clear screen from the centre: alpha under 250 counts as the hole,
    // so the bezel's soft inner edge is covered by the screen under it.
    var hole = [Bool](repeating: false, count: width * height)
    var stack = [(width / 2) + (height / 2) * width]
    guard bytes[stack[0] * 4 + 3] < 250 else { throw Failure("\(bezelPath): its centre is not clear") }
    var minX = width, minY = height, maxX = 0, maxY = 0
    while let index = stack.popLast() {
        if hole[index] || bytes[index * 4 + 3] >= 250 { continue }
        hole[index] = true
        let x = index % width, y = index / width
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        if x > 0 { stack.append(index - 1) }
        if x < width - 1 { stack.append(index + 1) }
        if y > 0 { stack.append(index - width) }
        if y < height - 1 { stack.append(index + width) }
    }
    let holeWidth = maxX - minX + 1, holeHeight = maxY - minY + 1
    guard holeWidth == shot.width, holeHeight == shot.height else {
        throw Failure("the bezel's screen is \(holeWidth) × \(holeHeight), the shot \(shot.width) × \(shot.height): use the simulator whose screen this bezel is")
    }
    // The mask: the hole, grown by 2 px so no seam shows between screen and bezel.
    var mask = [UInt8](repeating: 0, count: width * height)
    for y in max(0, minY - 2)...min(height - 1, maxY + 2) {
        for x in max(0, minX - 2)...min(width - 1, maxX + 2) {
            var inside = false
            for dy in -2...2 where !inside {
                for dx in -2...2 {
                    let nx = x + dx, ny = y + dy
                    if nx >= 0, ny >= 0, nx < width, ny < height, hole[nx + ny * width] { inside = true; break }
                }
            }
            if inside { mask[x + y * width] = 255 }
        }
    }
    let maskImage = mask.withUnsafeBytes { buffer in
        CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
            provider: CGDataProvider(data: Data(buffer) as CFData)!, decode: nil, shouldInterpolate: false,
            intent: .defaultIntent)!
    }
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let full = CGRect(x: 0, y: 0, width: width, height: height)
    context.saveGState()
    context.clip(to: full, mask: maskImage)
    // CoreGraphics counts y from the bottom.
    context.draw(shot, in: CGRect(x: minX, y: height - 1 - maxY, width: shot.width, height: shot.height))
    context.restoreGState()
    context.draw(bezel, in: full)
    try save(context.makeImage()!, outPath)
    print("framed: hole \(holeWidth) × \(holeHeight) at \(minX), \(minY)")
}

struct Spec: Decodable {
    struct Device: Decodable {
        let image: String
        let rect: [Double]
    }
    struct Caption: Decodable {
        let text: String
        let box: [Double]
        let fontSize: Double
        let color: String?
        let weight: String?
    }
    let size: [Int]
    let background: String
    let text: String
    let devices: [Device]
    let captions: [Caption]
}

func color(_ hex: String) throws -> NSColor {
    let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard digits.count == 6, let value = UInt32(digits, radix: 16) else { throw Failure("bad color \(hex)") }
    return NSColor(
        srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
        blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

func slide(specPath: String, outPath: String) throws {
    let spec = try JSONDecoder().decode(Spec.self, from: Data(contentsOf: URL(filePath: specPath)))
    let width = spec.size[0], height = spec.size[1]
    // Opaque: App Store Connect refuses a picture with alpha.
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.interpolationQuality = .high
    context.setFillColor(try color(spec.background).cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let scale = Double(width) / 886
    for device in spec.devices {
        let image = try load(device.image)
        let r = device.rect
        let rect = CGRect(x: r[0], y: Double(height) - r[1] - r[3], width: r[2], height: r[3])
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -16 * scale), blur: 40 * scale,
            color: NSColor.black.withAlphaComponent(0.4).cgColor)
        context.draw(image, in: rect)
        context.restoreGState()
    }
    let graphics = NSGraphicsContext(cgContext: context, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    for caption in spec.captions {
        let weight: NSFont.Weight = caption.weight == "medium" ? .medium : .bold
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byWordWrapping
        let text = NSAttributedString(
            string: caption.text,
            attributes: [
                .font: NSFont.systemFont(ofSize: caption.fontSize, weight: weight),
                .foregroundColor: try color(caption.color ?? spec.text), .paragraphStyle: style,
            ])
        let box = caption.box
        // Measure with an unlimited height, or a header that does not fit is never seen.
        let measured = text.boundingRect(
            with: CGSize(width: box[2], height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading])
        guard measured.height <= box[3] + 0.5 else {
            throw Failure("“\(caption.text)” is \(Int(measured.height)) px tall, its box \(Int(box[3])) px: shorten it or give it room")
        }
        // Centre it in its box; CoreGraphics counts y from the bottom.
        let top = box[1] + (box[3] - measured.height) / 2
        text.draw(
            with: CGRect(x: box[0], y: Double(height) - top - measured.height, width: box[2], height: measured.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading])
        print("caption: “\(caption.text)” \(Int(measured.height)) px in \(Int(box[3])) px")
    }
    NSGraphicsContext.restoreGraphicsState()
    try save(context.makeImage()!, outPath)
}

do {
    let words = CommandLine.arguments.dropFirst().map { $0 }
    switch words.first {
    case "frame" where words.count == 4: try frame(bezelPath: words[1], shotPath: words[2], outPath: words[3])
    case "slide" where words.count == 3: try slide(specPath: words[1], outPath: words[2])
    default:
        FileHandle.standardError.write(Data("usage: draw frame <bezel> <shot> <out> | draw slide <spec.json> <out>\n".utf8))
        exit(2)
    }
} catch {
    FileHandle.standardError.write(Data("draw: \(error)\n".utf8))
    exit(3)
}
