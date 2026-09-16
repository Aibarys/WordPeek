import AppKit

// Renders the WordPeek app icon: a word card on a deep-teal ground, echoing
// the widget and the web prototype's palette (teal accent, paper card, serif
// headword). Output: 1024x1024 PNG, full-bleed (iOS masks its own corners).

let S: CGFloat = 1024
let image = NSImage(size: NSSize(width: S, height: S))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError() }

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

// Background: diagonal teal gradient, dark lower-right.
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [color(0x2F8E86).cgColor, color(0x14443F).cgColor] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: S), end: CGPoint(x: S, y: 0), options: [])

// Card: white rounded rect, slightly above centre, soft shadow.
let cardSize: CGFloat = 660
let cardRect = CGRect(x: (S - cardSize) / 2, y: (S - cardSize) / 2, width: cardSize, height: cardSize)
let cardPath = CGPath(roundedRect: cardRect, cornerWidth: 104, cornerHeight: 104, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 60, color: color(0x0A2320, 0.45).cgColor)
ctx.addPath(cardPath)
ctx.setFillColor(color(0xFDFDFC).cgColor)
ctx.fillPath()
ctx.restoreGState()

// Headword "W" in a serif face, ink colour from the prototype.
let font = NSFont(name: "Georgia-Bold", size: 380) ?? NSFont.systemFont(ofSize: 380, weight: .bold)
let word = NSAttributedString(string: "W", attributes: [
    .font: font,
    .foregroundColor: color(0x101720)
])
let wordBounds = word.boundingRect(with: NSSize(width: S, height: S), options: [.usesLineFragmentOrigin])
let wordX = cardRect.midX - wordBounds.width / 2
let wordY = cardRect.minY + 225
word.draw(at: NSPoint(x: wordX, y: wordY))

// Two "translation" bars under the headword: teal accent + muted grey,
// the blurred-translation motif from the widget.
func bar(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, fill: NSColor) {
    let r = CGRect(x: x, y: y, width: w, height: h)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil))
    ctx.setFillColor(fill.cgColor)
    ctx.fillPath()
}
bar(x: cardRect.midX - 170, y: cardRect.minY + 150, w: 340, h: 56, fill: color(0x226F6B))
bar(x: cardRect.midX - 110, y: cardRect.minY + 62, w: 220, h: 44, fill: color(0xC9D2DA))

image.unlockFocus()

let dest = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff) else { fatalError("no bitmap") }
rep.size = NSSize(width: S, height: S)
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("no png") }
try! png.write(to: URL(fileURLWithPath: dest))
print("written \(dest) \(rep.pixelsWide)x\(rep.pixelsHigh)")
