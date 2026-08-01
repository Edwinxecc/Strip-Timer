import AppKit
import SwiftUI

class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    private let timerEngine = TimerEngine()
    private let physicsEngine = PhysicsEngine()
    
    private var overlayWindow: DragOverlayWindow?
    
    private var selectedDuration: TimeInterval = 0
    private var isDragging = false
    private var preferencesWindow: NSWindow?
    
    private let dragThreshold: CGFloat = 8.0
    
    // Polling timer variables
    private var trackingTimer: Timer?
    private var startMousePoint: CGPoint = .zero
    private var isDragActive = false
    
    override init() {
        super.init()
        setupStatusItem()
        setupEngineCallbacks()
    }
    
    deinit {
        trackingTimer?.invalidate()
    }
    
    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        
        button.isBordered = false
        resetButtonToIdle()
        
        // Configure native button to trigger action on left mouse down
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseDown])
    }
    
    @objc func statusBarButtonClicked(_ sender: Any?) {
        startDragTracking()
    }
    
    private func startDragTracking() {
        logDebug("startDragTracking: Mouse down detected. Initializing polling tracking...")
        
        startMousePoint = NSEvent.mouseLocation
        isDragActive = false
        
        // Highlight button
        statusItem.button?.isHighlighted = true
        
        // Start polling timer at 120Hz for high-precision, V-Sync-like updates
        trackingTimer?.invalidate()
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.pollMouse()
        }
        RunLoop.main.add(trackingTimer!, forMode: .common)
    }
    
    private func pollMouse() {
        // Bitmask check: left mouse button is pressed if bit 0 is set
        let isLeftPressed = (NSEvent.pressedMouseButtons & 1) != 0
        
        if isLeftPressed {
            let currentPoint = NSEvent.mouseLocation
            let deltaY = startMousePoint.y - currentPoint.y
            let deltaX = currentPoint.x - startMousePoint.x
            let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
            
            if !isDragActive && distance > dragThreshold {
                isDragActive = true
                
                guard let button = statusItem.button,
                      let window = button.window else { return }
                
                let buttonFrameInWindow = button.convert(button.bounds, to: nil)
                let buttonFrameInScreen = window.convertToScreen(buttonFrameInWindow)
                let anchor = CGPoint(x: buttonFrameInScreen.midX, y: buttonFrameInScreen.minY)
                
                logDebug("pollMouse: Drag threshold crossed. Starting overlay anchor=\(anchor)")
                handleDragStart(anchor: anchor)
            }
            
            if isDragActive {
                handleDragUpdate(currentPoint: currentPoint)
            }
        } else {
            // Left mouse button was released! End tracking
            logDebug("pollMouse: Left mouse button released. Stopping timer.")
            trackingTimer?.invalidate()
            trackingTimer = nil
            
            statusItem.button?.isHighlighted = false
            
            if isDragActive {
                handleDragEnd()
            } else {
                handleButtonClick()
            }
        }
    }
    
    private func setupEngineCallbacks() {
        // Physics engine tick callback (runs up to 120Hz)
        physicsEngine.onUpdate = { [weak self] in
            guard let self = self else { return }
            self.overlayWindow?.rubberBandView?.update(
                anchor: self.physicsEngine.anchorPoint,
                tip: self.physicsEngine.physicsTip,
                mid: self.physicsEngine.physicsMid,
                opacity: self.physicsEngine.opacity,
                time: self.isDragging ? self.selectedDuration : nil
            )
        }
        
        // Physics engine snap-back complete
        physicsEngine.onSettle = { [weak self] in
            guard let self = self else { return }
            logDebug("physicsEngine: settle complete. Ordering out overlay window.")
            self.overlayWindow?.orderOut(nil)
            self.overlayWindow = nil
        }
        
        // Timer engine tick callback
        timerEngine.onTick = { [weak self] remaining in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.statusItem.button?.title = self.formatTime(remaining)
                self.statusItem.button?.image = nil
            }
        }
        
        // Timer completion
        timerEngine.onComplete = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                logDebug("timerEngine: completed. Playing sound/notif and bouncing.")
                NotificationManager.shared.sendTimerCompletedNotification(duration: self.timerEngine.duration)
                self.bounceStatusBarItem()
                self.resetButtonToIdle()
            }
        }
        
        // Timer state transition updates
        timerEngine.onStateChange = { [weak self] state in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch state {
                case .idle:
                    self.resetButtonToIdle()
                case .running:
                    self.statusItem.button?.title = self.formatTime(self.timerEngine.timeRemaining)
                    self.statusItem.button?.image = nil
                case .paused:
                    self.statusItem.button?.title = self.formatTime(self.timerEngine.timeRemaining) + " (II)"
                    self.statusItem.button?.image = nil
                }
            }
        }
    }
    
    private func resetButtonToIdle() {
        statusItem.button?.title = ""
        
        // Use a clean template stopwatch symbol
        if let image = NSImage(systemSymbolName: "circle.inset.filled", accessibilityDescription: "GesTimer") {
            image.isTemplate = true
            statusItem.button?.image = image
        }
    }
    
    // MARK: - Drag Handlers
    
    private func handleDragStart(anchor: CGPoint) {
        logDebug("handleDragStart: anchor=\(anchor)")
        isDragging = true
        selectedDuration = 0
        
        // Find screen containing the status item
        let screen = statusItem.button?.window?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        logDebug("handleDragStart: screen frame=\(screen.frame)")
        
        // Initialize Overlay Window for the rubber band
        overlayWindow = DragOverlayWindow(screen: screen)
        overlayWindow?.orderFrontRegardless()
        logDebug("handleDragStart: overlayWindow frame=\(overlayWindow?.frame ?? .zero)")
        
        // Boot up physics simulation
        physicsEngine.start(anchor: anchor)
    }
    
    private func handleDragUpdate(currentPoint: CGPoint) {
        guard isDragging else { return }
        
        // Update physics target
        physicsEngine.targetTip = currentPoint
        
        // Calculate vertical drag distance downwards
        let distance = physicsEngine.anchorPoint.y - currentPoint.y
        
        // Compute snapped duration from conversion curves
        let rawTime = convertDistanceToTime(distance)
        let snappedTime = snap(time: rawTime)
        selectedDuration = snappedTime
        
        logDebug("handleDragUpdate: currentPoint=\(currentPoint), distance=\(distance), rawTime=\(rawTime), snappedTime=\(snappedTime)")
    }
    
    private func handleDragEnd() {
        guard isDragging else { return }
        isDragging = false
        
        logDebug("handleDragEnd: releasing physics, selectedDuration=\(selectedDuration)")
        
        // Release rubber band
        physicsEngine.releaseAndSnap()
        
        if selectedDuration >= 5.0 {
            // Confirm selection & start countdown
            timerEngine.start(duration: selectedDuration)
        }
    }
    
    // MARK: - Click Actions
    
    private func handleButtonClick() {
        logDebug("handleButtonClick: state=\(timerEngine.state)")
        if timerEngine.state == .idle {
            showIdleMenu()
        } else {
            showTimerControlsMenu()
        }
    }
    
    private func showIdleMenu() {
        let menu = NSMenu()
        
        let headerItem = NSMenuItem(title: "GesTimer", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        let instructionsItem = NSMenuItem(title: "Drag down to set a timer", action: nil, keyEquivalent: "")
        instructionsItem.isEnabled = false
        menu.addItem(instructionsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferencesAction), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        popUpMenu(menu)
    }
    
    private func showTimerControlsMenu() {
        let menu = NSMenu()
        
        if timerEngine.state == .running {
            let pauseItem = NSMenuItem(title: "Pause", action: #selector(pauseTimerAction), keyEquivalent: "p")
            pauseItem.target = self
            menu.addItem(pauseItem)
        } else if timerEngine.state == .paused {
            let resumeItem = NSMenuItem(title: "Resume", action: #selector(resumeTimerAction), keyEquivalent: "r")
            resumeItem.target = self
            menu.addItem(resumeItem)
        }
        
        let cancelItem = NSMenuItem(title: "Cancel Timer", action: #selector(cancelTimerAction), keyEquivalent: "c")
        cancelItem.target = self
        menu.addItem(cancelItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferencesAction), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        popUpMenu(menu)
    }
    
    @objc private func openPreferencesAction() {
        if preferencesWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "GesTimer - Preferences"
            let model = PreferencesModel()
            window.contentView = NSHostingView(rootView: PreferencesView(model: model))
            window.center()
            window.isReleasedWhenClosed = false
            preferencesWindow = window
        }
        
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func popUpMenu(_ menu: NSMenu) {
        guard let button = statusItem.button else { return }
        
        // Popup menu directly beneath status item
        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: button.bounds.height), in: button)
    }
    
    @objc private func pauseTimerAction() {
        timerEngine.pause()
    }
    
    @objc private func resumeTimerAction() {
        timerEngine.resume()
    }
    
    @objc private func cancelTimerAction() {
        timerEngine.cancel()
    }
    
    @objc private func quitAction() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Bounce Animation
    
    private func bounceStatusBarItem() {
        guard let button = statusItem.button else { return }
        let originalFrame = button.frame
        let bounceSequence: [CGFloat] = [0, 4, 6, 4, 0, 2, 3, 2, 0] // pixel offsets
        
        for (index, offset) in bounceSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                var frame = originalFrame
                frame.origin.y = originalFrame.origin.y + offset
                button.frame = frame
            }
        }
    }
    
    private func formatTime(_ t: TimeInterval) -> String {
        let totalSeconds = Int(round(t))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Conversion Curves & Utilities
    
    private func convertDistanceToTime(_ distance: CGFloat) -> TimeInterval {
        let d = Double(max(0, distance))
        let curveType = PreferencesManager.shared.curveType
        
        switch curveType {
        case "linear":
            return d * 1.0
        case "logarithmic":
            return 180.0 * log(1.0 + d / 60.0)
        case "exponential":
            if d <= 80 {
                return d * 0.25
            } else {
                let delta = d - 80.0
                return 20.0 + (delta * 0.25) + (delta * delta * 0.0038)
            }
        default:
            return d * 0.25
        }
    }
    
    private func snap(time: TimeInterval) -> TimeInterval {
        if time < 30 {
            let snapped = round(time / 5.0) * 5.0
            return max(5, snapped)
        } else if time < 120 {
            return round(time / 15.0) * 15.0
        } else if time < 300 {
            return round(time / 30.0) * 30.0
        } else if time < 1800 {
            return round(time / 60.0) * 60.0
        } else {
            return round(time / 300.0) * 300.0
        }
    }
}

// Transparent screen-size borderless window subclass for rubber band drawing
class DragOverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.level = .statusBar
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Essential: enable backing layer on the content view to host transparent layers in AppKit
        self.contentView?.wantsLayer = true
        
        if let contentView = self.contentView {
            let view = RubberBandView(frame: contentView.bounds)
            view.autoresizingMask = [.width, .height]
            contentView.addSubview(view)
        }
    }
    
    var rubberBandView: RubberBandView? {
        return contentView?.subviews.first(where: { $0 is RubberBandView }) as? RubberBandView
    }
}
