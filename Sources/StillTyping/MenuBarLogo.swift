import AppKit

enum MenuBarLogo {
    // Keep the source logo's proportions, with tighter padding for a 16 pt
    // status item. A drawing representation stays sharp on Retina displays.
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            defer { context.restoreGState() }
            context.translateBy(x: bounds.minX, y: bounds.minY)
            context.scaleBy(x: bounds.width / 200, y: bounds.height / 200)
            context.translateBy(x: -28, y: -28)

            context.setFillColor(NSColor.black.cgColor)
            context.addPath(CGPath(
                roundedRect: CGRect(x: 38, y: 46, width: 22, height: 164),
                cornerWidth: 11, cornerHeight: 11, transform: nil
            ))
            context.fillPath()

            let arrow = CGMutablePath()
            arrow.move(to: CGPoint(x: 207, y: 68))
            arrow.addLine(to: CGPoint(x: 207, y: 117))
            arrow.addQuadCurve(to: CGPoint(x: 184, y: 140), control: CGPoint(x: 207, y: 140))
            arrow.addLine(to: CGPoint(x: 100, y: 140))
            arrow.move(to: CGPoint(x: 135, y: 105))
            arrow.addLine(to: CGPoint(x: 100, y: 140))
            arrow.addLine(to: CGPoint(x: 135, y: 175))
            context.addPath(arrow)
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(22)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
