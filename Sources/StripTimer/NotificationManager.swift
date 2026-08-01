import Foundation
import UserNotifications
import AppKit

class NotificationManager {
    static let shared = NotificationManager()
    
    private var hasBundleIdentifier: Bool {
        return Bundle.main.bundleIdentifier != nil
    }
    
    private init() {
        if hasBundleIdentifier {
            requestAuthorization()
        }
    }
    
    func requestAuthorization() {
        guard hasBundleIdentifier else { return }
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            }
        }
    }
    
    func sendTimerCompletedNotification(duration: TimeInterval) {
        let title = "Timer Finished!"
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .full
        
        let durationString = formatter.string(from: duration) ?? "\(Int(duration)) seconds"
        let body = "Your timer for \(durationString) has completed."
        
        if hasBundleIdentifier {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = UNNotificationSound.default
            
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil // Deliver immediately
            )
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error displaying notification: \(error)")
                }
            }
        } else {
            // CLI Fallback: Send native macOS system banner notification via AppleScript
            sendAppleScriptNotification(title: title, body: body)
        }
        
        // Play the selected completion sound
        playCompletionSound()
    }
    
    private func sendAppleScriptNotification(title: String, body: String) {
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let scriptSource = "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\""
        
        if let appleScript = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
    
    func playCompletionSound() {
        let soundName = PreferencesManager.shared.sound
        if let sound = NSSound(named: soundName) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
