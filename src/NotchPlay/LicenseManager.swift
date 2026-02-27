import Foundation
import Combine

final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    private let prefs = PreferencesManager.shared

    var licenseKey: String { prefs.licenseKey }
    var isProUnlocked: Bool { prefs.isProUnlocked }

    private init() {}

    /// Activate license. Placeholder for LemonSqueezy API integration.
    func activate(key: String) async -> Bool {
        // TODO: Replace with real LemonSqueezy validation
        // POST https://api.lemonsqueezy.com/v1/licenses/activate
        // body: { license_key: key, instance_name: hostname }
        guard !key.trimmingCharacters(in: .whitespaces).isEmpty else { return false }

        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000)

        await MainActor.run {
            prefs.licenseKey = key
            prefs.isProUnlocked = true
            objectWillChange.send()
        }
        return true
    }

    func deactivate() {
        prefs.licenseKey = ""
        prefs.isProUnlocked = false
        objectWillChange.send()
    }
}
