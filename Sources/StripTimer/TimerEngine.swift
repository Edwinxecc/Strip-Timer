import Foundation
import Observation

@Observable
class TimerEngine {
    enum TimerState {
        case idle
        case running
        case paused
    }
    
    var duration: TimeInterval = 0
    var timeRemaining: TimeInterval = 0
    var state: TimerState = .idle
    
    private var timer: Timer?
    private var lastTickTime: Date?
    
    var onTick: ((TimeInterval) -> Void)?
    var onStateChange: ((TimerState) -> Void)?
    var onComplete: (() -> Void)?
    
    func start(duration: TimeInterval) {
        self.duration = duration
        self.timeRemaining = duration
        self.state = .running
        self.lastTickTime = Date()
        
        timer?.invalidate()
        // Use a 0.1s interval to keep the timer responsive and accurate
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        onStateChange?(.running)
    }
    
    func pause() {
        guard state == .running else { return }
        state = .paused
        timer?.invalidate()
        timer = nil
        onStateChange?(.paused)
    }
    
    func resume() {
        guard state == .paused else { return }
        state = .running
        lastTickTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        onStateChange?(.running)
    }
    
    func cancel() {
        state = .idle
        duration = 0
        timeRemaining = 0
        timer?.invalidate()
        timer = nil
        onStateChange?(.idle)
    }
    
    private func tick() {
        guard state == .running else { return }
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTickTime ?? now)
        lastTickTime = now
        
        timeRemaining -= elapsed
        if timeRemaining <= 0 {
            timeRemaining = 0
            state = .idle
            timer?.invalidate()
            timer = nil
            onStateChange?(.idle)
            onComplete?()
        } else {
            onTick?(timeRemaining)
        }
    }
}
