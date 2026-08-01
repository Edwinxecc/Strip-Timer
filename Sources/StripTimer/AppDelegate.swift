import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logDebug("AppDelegate: App did finish launching. Initializing StatusBarController...")
        // Set activation policy programmatically to accessory so there's no Dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize status bar controller
        statusBarController = StatusBarController()
    }
}
