import Foundation
import CoreVideo
import Observation
import QuartzCore

@Observable
class PhysicsEngine {
    struct PhysicsPoint {
        var position: CGPoint
        var velocity: CGVector = .zero
        
        mutating func update(target: CGPoint, stiffness: CGFloat, damping: CGFloat, mass: CGFloat, dt: CGFloat) {
            let forceX = (target.x - position.x) * stiffness
            let forceY = (target.y - position.y) * stiffness
            
            let dampingForceX = velocity.dx * damping
            let dampingForceY = velocity.dy * damping
            
            let accelX = (forceX - dampingForceX) / mass
            let accelY = (forceY - dampingForceY) / mass
            
            velocity.dx += accelX * dt
            velocity.dy += accelY * dt
            
            position.x += velocity.dx * dt
            position.y += velocity.dy * dt
        }
    }
    
    var anchorPoint: CGPoint = .zero
    var targetTip: CGPoint = .zero
    
    var physicsTip: CGPoint = .zero
    var physicsMid: CGPoint = .zero
    
    // Physics variables - tuned for rubbery feel
    var stiffnessTip: CGFloat = 300
    var dampingTip: CGFloat = 18
    var massTip: CGFloat = 1.0
    
    var stiffnessMid: CGFloat = 200
    var dampingMid: CGFloat = 12
    var massMid: CGFloat = 1.0
    
    var isSnapped: Bool = false
    var opacity: CGFloat = 1.0
    
    private var tipPoint = PhysicsPoint(position: .zero)
    private var midPoint = PhysicsPoint(position: .zero)
    
    private var displayLink: CVDisplayLink?
    private var lastTickTime: Double = 0
    private var fallbackTimer: Timer?
    
    var onUpdate: (() -> Void)?
    var onSettle: (() -> Void)?
    
    func start(anchor: CGPoint) {
        self.anchorPoint = anchor
        self.targetTip = anchor
        self.tipPoint = PhysicsPoint(position: anchor)
        self.midPoint = PhysicsPoint(position: anchor)
        self.physicsTip = anchor
        self.physicsMid = anchor
        self.opacity = 1.0
        self.isSnapped = false
        self.lastTickTime = CACurrentMediaTime()
        
        // Dynamically load stiffness and damping from user preferences
        self.stiffnessTip = CGFloat(PreferencesManager.shared.stiffness)
        self.dampingTip = CGFloat(PreferencesManager.shared.damping)
        self.stiffnessMid = self.stiffnessTip * 0.67
        self.dampingMid = self.dampingTip * 0.67
        
        startDisplayLink()
    }
    
    func stop() {
        stopDisplayLink()
    }
    
    func releaseAndSnap() {
        isSnapped = true
        // Set target to anchor so it retracts
        targetTip = anchorPoint
    }
    
    private func startDisplayLink() {
        stopDisplayLink()
        
        var link: CVDisplayLink?
        let result = CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard result == kCVReturnSuccess, let displayLink = link else {
            // Fallback to high-frequency timer if CVDisplayLink fails
            startFallbackTimer()
            return
        }
        
        self.displayLink = displayLink
        
        let callback: CVDisplayLinkOutputCallback = { (_, _, _, _, _, displayLinkContext) -> CVReturn in
            let engine = Unmanaged<PhysicsEngine>.fromOpaque(displayLinkContext!).takeUnretainedValue()
            engine.tick()
            return kCVReturnSuccess
        }
        
        logDebug("PhysicsEngine: CVDisplayLink created, starting...")
        CVDisplayLinkSetOutputCallback(displayLink, callback, Unmanaged.passUnretained(self).toOpaque())
        let startResult = CVDisplayLinkStart(displayLink)
        logDebug("PhysicsEngine: CVDisplayLinkStart returned \(startResult)")
    }
    
    private func stopDisplayLink() {
        logDebug("PhysicsEngine: stopping display link")
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
            self.displayLink = nil
        }
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }
    
    private func startFallbackTimer() {
        logDebug("PhysicsEngine: starting fallback 120Hz timer")
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func tick() {
        let now = CACurrentMediaTime()
        let dt = CGFloat(now - lastTickTime)
        lastTickTime = now
        
        // Dispatch UI/State updates to main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Clamp dt to avoid physics engine instability during lag spikes
            let clampedDt = min(0.1, max(0.001, dt))
            self.updatePhysics(dt: clampedDt)
        }
    }
    
    private func updatePhysics(dt: CGFloat) {
        let tipTarget = isSnapped ? anchorPoint : targetTip
        logDebug("PhysicsEngine updatePhysics: target=\(tipTarget), isSnapped=\(isSnapped)")
        
        // Update physics tip
        tipPoint.update(
            target: tipTarget,
            stiffness: stiffnessTip,
            damping: dampingTip,
            mass: massTip,
            dt: dt
        )
        physicsTip = tipPoint.position
        
        // Update physics midpoint
        let midTarget = CGPoint(
            x: (anchorPoint.x + physicsTip.x) / 2.0,
            y: (anchorPoint.y + physicsTip.y) / 2.0
        )
        midPoint.update(
            target: midTarget,
            stiffness: stiffnessMid,
            damping: dampingMid,
            mass: massMid,
            dt: dt
        )
        physicsMid = midPoint.position
        
        if isSnapped {
            // Fade out opacity during snap back
            opacity = max(0, opacity - dt * 5.0)
            
            let distTip = distance(physicsTip, anchorPoint)
            let velTip = length(tipPoint.velocity)
            
            if (distTip < 1.0 && velTip < 5.0) || opacity <= 0 {
                stop()
                opacity = 0
                onSettle?()
            }
        }
        
        onUpdate?()
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
    }
    
    private func length(_ v: CGVector) -> CGFloat {
        return sqrt(v.dx * v.dx + v.dy * v.dy)
    }
}
