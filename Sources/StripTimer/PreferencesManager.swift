import Foundation

class PreferencesManager {
    static let shared = PreferencesManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let curveType = "curveType"
        static let stiffness = "physicsStiffness"
        static let damping = "physicsDamping"
        static let sound = "completionSound"
    }
    
    private init() {
        // Register default configurations
        defaults.register(defaults: [
            Keys.curveType: "exponential",
            Keys.stiffness: 300.0,
            Keys.damping: 18.0,
            Keys.sound: "Glass"
        ])
    }
    
    var curveType: String {
        get { defaults.string(forKey: Keys.curveType) ?? "exponential" }
        set { defaults.set(newValue, forKey: Keys.curveType) }
    }
    
    var stiffness: Double {
        get { defaults.double(forKey: Keys.stiffness) }
        set { defaults.set(newValue, forKey: Keys.stiffness) }
    }
    
    var damping: Double {
        get { defaults.double(forKey: Keys.damping) }
        set { defaults.set(newValue, forKey: Keys.damping) }
    }
    
    var sound: String {
        get { defaults.string(forKey: Keys.sound) ?? "Glass" }
        set { defaults.set(newValue, forKey: Keys.sound) }
    }
}
