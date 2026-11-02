import AppKit
import CoreText

// Outline the presentation typography so exported SVGs need no installed fonts.
let samples: [(String, String, String, CGFloat, CGFloat)] = [
    ("wordmark", "StillTyping", "AvenirNext-Bold", 100, -3.5),
    ("punctuation", "!!!", "AvenirNext-Bold", 100, -3.5),
    ("header", "STILLTYPING!!!  /  VISUAL IDENTITY", "Menlo-Regular", 14, 0.5),
    ("edition", "01 — CURSOR + RETURN", "Menlo-Regular", 14, 0.5),
    ("tagline", "I'm still typing.", "AvenirNext-Medium", 30, -0.5),
    ("description", "Keep typing. Send when you're ready.", "AvenirNext-Regular", 19, 0),
    ("primary", "01 / THE MARK", "Menlo-Regular", 12, 0.5),
    ("reversed", "02 / REVERSED", "Menlo-Regular", 12, 0.5),
    ("sizes", "03 / SMALL, STILL CLEAR", "Menlo-Regular", 12, 0.5),
    ("sizeLabels", "64          32       16", "Menlo-Regular", 11, 0),
    ("palette", "GRAPHITE  #202321       CURSOR  #C5F36B       PAPER  #F7F7F2", "Menlo-Regular", 11, 0),
    ("note", "A cursor that holds the Return. A little room to finish your thought.", "AvenirNext-Regular", 16, 0)
]

func number(_ value: CGFloat) -> String {
    String(format: "%.3f", Double(value))
}

var result: [String: [String: Any]] = [:]
for (key, text, name, size, tracking) in samples {
    let font = NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
    let line = CTLineCreateWithAttributedString(NSAttributedString(
        string: text, attributes: [.font: font, .kern: tracking]
    ))
    var commands: [String] = []
    let runs = CTLineGetGlyphRuns(line) as! [CTRun]
    for run in runs {
        let attributes = CTRunGetAttributes(run) as NSDictionary
        let runFont = attributes[kCTFontAttributeName] as! CTFont
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
        for index in 0..<count {
            guard let path = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) else { continue }
            let origin = positions[index]
            func point(_ p: CGPoint) -> String {
                "\(number(p.x + origin.x)),\(number(-p.y - origin.y))"
            }
            path.applyWithBlock { element in
                let e = element.pointee
                switch e.type {
                case .moveToPoint: commands.append("M\(point(e.points[0]))")
                case .addLineToPoint: commands.append("L\(point(e.points[0]))")
                case .addQuadCurveToPoint: commands.append("Q\(point(e.points[0])) \(point(e.points[1]))")
                case .addCurveToPoint: commands.append("C\(point(e.points[0])) \(point(e.points[1])) \(point(e.points[2]))")
                case .closeSubpath: commands.append("Z")
                @unknown default: break
                }
            }
        }
    }
    result[key] = ["d": commands.joined(separator: " "), "width": CTLineGetTypographicBounds(line, nil, nil, nil)]
}
let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
FileHandle.standardOutput.write(data)
