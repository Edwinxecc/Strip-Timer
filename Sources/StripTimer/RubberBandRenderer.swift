import AppKit
import QuartzCore

class RubberBandView: NSView {
    private let shapeLayer = CAShapeLayer()
    private let textLayer = CATextLayer()
    private let textBackgroundLayer = CALayer()
    
    override var wantsUpdateLayer: Bool {
        return true
    }
    
    override func makeBackingLayer() -> CALayer {
        return shapeLayer
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        wantsLayer = true
        
        // Setup initial shape layer styles
        shapeLayer.fillColor = NSColor.white.cgColor // fallback
        
        // Subtle premium shadow for the rubber band
        shapeLayer.shadowColor = NSColor.black.cgColor
        shapeLayer.shadowOpacity = 0.25
        shapeLayer.shadowOffset = CGSize(width: 0, height: -2)
        shapeLayer.shadowRadius = 4.0
        
        // High quality scale matching screen backing factor
        shapeLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        
        // Setup text background pill
        textBackgroundLayer.cornerRadius = 11.0
        textBackgroundLayer.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        textBackgroundLayer.borderWidth = 0.5
        textBackgroundLayer.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        textBackgroundLayer.contentsScale = shapeLayer.contentsScale
        
        // Add subtle shadow to the text pill for depth
        textBackgroundLayer.shadowColor = NSColor.black.cgColor
        textBackgroundLayer.shadowOpacity = 0.3
        textBackgroundLayer.shadowOffset = CGSize(width: 0, height: 2)
        textBackgroundLayer.shadowRadius = 2.0
        shapeLayer.addSublayer(textBackgroundLayer)
        
        // Setup text layer
        textLayer.alignmentMode = .center
        textLayer.foregroundColor = NSColor.white.cgColor
        textLayer.contentsScale = shapeLayer.contentsScale
        
        // Load clean system font
        let fontSize: CGFloat = 11.5
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        textLayer.font = font.fontName as CFString
        textLayer.fontSize = fontSize
        shapeLayer.addSublayer(textLayer)
    }
    
    override func layout() {
        super.layout()
        shapeLayer.frame = bounds
    }
    
    func update(anchor: CGPoint, tip: CGPoint, mid: CGPoint, opacity: CGFloat, time: TimeInterval?) {
        shapeLayer.frame = bounds
        
        guard let window = self.window else {
            logDebug("RubberBandView update: window is nil!")
            return
        }
        
        // Robust 2-step conversion from screen coordinates to window coordinates, then view coordinates
        let windowAnchor = window.convertPoint(fromScreen: anchor)
        let windowTip = window.convertPoint(fromScreen: tip)
        let windowMid = window.convertPoint(fromScreen: mid)
        
        let localAnchor = self.convert(windowAnchor, from: nil)
        let localTip = self.convert(windowTip, from: nil)
        let localMid = self.convert(windowMid, from: nil)
        
        logDebug("RubberBandView update: bounds=\(bounds), windowFrame=\(window.frame), anchor=\(anchor) -> localAnchor=\(localAnchor), tip=\(tip) -> localTip=\(localTip)")
        
        // Calculate direction vector and distance
        let dx = localTip.x - localAnchor.x
        let dy = localTip.y - localAnchor.y
        let distance = sqrt(dx*dx + dy*dy)
        
        // Disable implicit Core Animation actions/transitions so it updates instantly without visual lag
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if distance < 1.0 {
            shapeLayer.path = nil
            textBackgroundLayer.isHidden = true
            textLayer.isHidden = true
            CATransaction.commit()
            return
        }
        
        // Calculate perpendicular normal vector
        let nx = -dy / distance
        let ny = dx / distance
        
        // Calculate variable widths based on distance (thins as it stretches)
        let wAnchor = max(4.0, 10.0 - (distance / 40.0))
        let wTip = max(3.0, 7.0 - (distance / 60.0))
        let wMid = max(1.5, 6.0 - (distance / 30.0))
        
        // Calculate outer border points
        let la = CGPoint(x: localAnchor.x - nx * (wAnchor / 2.0), y: localAnchor.y - ny * (wAnchor / 2.0))
        let ra = CGPoint(x: localAnchor.x + nx * (wAnchor / 2.0), y: localAnchor.y + ny * (wAnchor / 2.0))
        
        let lm = CGPoint(x: localMid.x - nx * (wMid / 2.0), y: localMid.y - ny * (wMid / 2.0))
        let rm = CGPoint(x: localMid.x + nx * (wMid / 2.0), y: localMid.y + ny * (wMid / 2.0))
        
        let lt = CGPoint(x: localTip.x - nx * (wTip / 2.0), y: localTip.y - ny * (wTip / 2.0))
        let rt = CGPoint(x: localTip.x + nx * (wTip / 2.0), y: localTip.y + ny * (wTip / 2.0))
        
        // Build path
        let path = CGMutablePath()
        path.move(to: la)
        path.addQuadCurve(to: lt, control: lm)
        path.addQuadCurve(to: rt, control: localTip) // Rounded tip cap
        path.addQuadCurve(to: ra, control: rm)
        path.addQuadCurve(to: la, control: localAnchor) // Rounded anchor cap
        
        shapeLayer.path = path
        
        // Update layer color and opacity dynamically
        shapeLayer.opacity = Float(opacity)
        
        // Determine effective appearance of the current application instance
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        
        // Base color maps to light/dark system text styling but using raw device RGB spaces
        let baseColor = isDark ? NSColor.white.withAlphaComponent(0.85) : NSColor.black.withAlphaComponent(0.85)
        let accentColor = NSColor.controlAccentColor.usingColorSpace(.deviceRGB) ?? NSColor.systemBlue
        
        let tension = min(1.0, distance / 300.0)
        let blendedColor = blend(color1: baseColor, color2: accentColor, factor: tension)
        shapeLayer.fillColor = blendedColor.cgColor
        
        // Render Floating Time Text at the tip of the rubber band
        if let time = time, time > 0 {
            let timeString = formatTime(time)
            
            // Measure text width roughly based on characters
            let textWidth: CGFloat = 60.0
            let textHeight: CGFloat = 22.0
            let yOffset: CGFloat = -26.0 // 26 pixels below the tip to clear the rounded cap
            
            let pillFrame = CGRect(
                x: localTip.x - textWidth / 2.0,
                y: localTip.y + yOffset - textHeight / 2.0,
                width: textWidth,
                height: textHeight
            )
            
            textBackgroundLayer.frame = pillFrame
            textLayer.frame = pillFrame.offsetBy(dx: 0, dy: -3) // Fine-tune vertical text alignment inside the pill
            textLayer.string = timeString
            
            textBackgroundLayer.isHidden = false
            textLayer.isHidden = false
        } else {
            textBackgroundLayer.isHidden = true
            textLayer.isHidden = true
        }
        
        CATransaction.commit()
    }
    
    private func blend(color1: NSColor, color2: NSColor, factor: CGFloat) -> NSColor {
        // Safe conversion to RGB color spaces, resolving dynamic system colors
        guard let c1 = color1.usingColorSpace(.deviceRGB) ?? color1.usingColorSpace(.sRGB),
              let c2 = color2.usingColorSpace(.deviceRGB) ?? color2.usingColorSpace(.sRGB) else {
            return color1 // Safe non-optional fallback
        }
        
        let r = c1.redComponent + (c2.redComponent - c1.redComponent) * factor
        let g = c1.greenComponent + (c2.greenComponent - c1.greenComponent) * factor
        let b = c1.blueComponent + (c2.blueComponent - c1.blueComponent) * factor
        let a = c1.alphaComponent + (c2.alphaComponent - c1.alphaComponent) * factor
        
        return NSColor(deviceRed: r, green: g, blue: b, alpha: a)
    }
    
    private func formatTime(_ t: TimeInterval) -> String {
        let totalSeconds = Int(round(t))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
