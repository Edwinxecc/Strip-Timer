import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Keep delegate alive for the entire duration of the app run loop
withExtendedLifetime(delegate) {
    app.run()
}
