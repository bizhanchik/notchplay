import Foundation
import SwiftUI
import Combine


// MARK: - Activation Mode

enum ActivationMode: String, CaseIterable {
    case hover = "Hover to Open"
    case disabled = "Open from Menu Only"
}

// MARK: - Preferences Manager

final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    // MARK: - Keys
    private enum Key {
        static let activationMode = "activationMode"
        static let launchAtLogin = "launchAtLogin"
        static let enableHaptics = "enableHaptics"
        static let enableSounds = "enableSounds"
        static let enabledGames = "enabledGames"
        static let defaultGame = "defaultGame"
        static let licenseKey = "licenseKey"
        static let isProUnlocked = "isProUnlocked"
        static let shadowStrength = "shadowStrength"
        static let animationSpeed = "animationSpeed"
    }

    private let defaults = UserDefaults.standard

    // MARK: - Published Properties

    @Published var activationMode: ActivationMode {
        didSet { defaults.set(activationMode.rawValue, forKey: Key.activationMode) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    @Published var enableHaptics: Bool {
        didSet { defaults.set(enableHaptics, forKey: Key.enableHaptics) }
    }

    @Published var enableSounds: Bool {
        didSet { defaults.set(enableSounds, forKey: Key.enableSounds) }
    }

    @Published var shadowStrength: Double {
        didSet { defaults.set(shadowStrength, forKey: Key.shadowStrength) }
    }

    @Published var animationSpeed: Double {
        didSet { defaults.set(animationSpeed, forKey: Key.animationSpeed) }
    }

    @Published var licenseKey: String {
        didSet { defaults.set(licenseKey, forKey: Key.licenseKey) }
    }

    @Published var isProUnlocked: Bool {
        didSet { defaults.set(isProUnlocked, forKey: Key.isProUnlocked) }
    }

    @Published var defaultGame: String {
        didSet { defaults.set(defaultGame, forKey: Key.defaultGame) }
    }

    // Enabled games stored as JSON array of rawValues
    @Published var enabledGames: Set<String> {
        didSet {
            if let data = try? JSONEncoder().encode(Array(enabledGames)) {
                defaults.set(data, forKey: Key.enabledGames)
            }
        }
    }

    // MARK: - Init

    private init() {
        // Load with defaults (migrate legacy "Click to Open" -> "Open from Menu Only")
        let raw = defaults.string(forKey: Key.activationMode) ?? ActivationMode.hover.rawValue
        if let mode = ActivationMode(rawValue: raw) {
            self.activationMode = mode
        } else if raw == "Click to Open" {
            self.activationMode = .disabled
        } else {
            self.activationMode = .hover
        }

        self.launchAtLogin = defaults.object(forKey: Key.launchAtLogin) as? Bool ?? false
        self.enableHaptics = defaults.object(forKey: Key.enableHaptics) as? Bool ?? true
        self.enableSounds = defaults.object(forKey: Key.enableSounds) as? Bool ?? true
        self.shadowStrength = defaults.object(forKey: Key.shadowStrength) as? Double ?? 0.5
        self.animationSpeed = defaults.object(forKey: Key.animationSpeed) as? Double ?? 0.4
        self.licenseKey = defaults.string(forKey: Key.licenseKey) ?? ""
        self.isProUnlocked = defaults.object(forKey: Key.isProUnlocked) as? Bool ?? false
        self.defaultGame = defaults.string(forKey: Key.defaultGame) ?? GameType.dino.rawValue

        // Load enabled games
        if let data = defaults.data(forKey: Key.enabledGames),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            self.enabledGames = Set(arr)
        } else {
            // Default: all games enabled
            self.enabledGames = Set(GameType.allCases.map(\.rawValue))
        }
    }

    // MARK: - Helpers

    func isGameEnabled(_ game: GameType) -> Bool {
        enabledGames.contains(game.rawValue)
    }

    var enabledGameTypes: [GameType] {
        GameType.allCases.filter { enabledGames.contains($0.rawValue) }
    }

    func toggleGame(_ game: GameType) {
        if enabledGames.contains(game.rawValue) {
            enabledGames.remove(game.rawValue)
        } else {
            enabledGames.insert(game.rawValue)
        }
    }

    func resetAll() {
        let domain = Bundle.main.bundleIdentifier ?? "com.bizhan.NotchPlay"
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()

        // Reload defaults
        activationMode = .hover
        launchAtLogin = false
        enableHaptics = true
        enableSounds = true
        shadowStrength = 0.5
        animationSpeed = 0.4
        licenseKey = ""
        isProUnlocked = false
        defaultGame = GameType.dino.rawValue
        enabledGames = Set(GameType.allCases.map(\.rawValue))
    }
}
