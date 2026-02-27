import AppKit

final class HapticManager {

    static let shared = HapticManager()

    private let performer = NSHapticFeedbackManager.defaultPerformer

    private init() {}

    func playTransition() {
        guard PreferencesManager.shared.enableHaptics else { return }
        performer.perform(.generic, performanceTime: .default)
    }

    func playSelection() {
        guard PreferencesManager.shared.enableHaptics else { return }
        performer.perform(.alignment, performanceTime: .default)
    }

    func playImpact() {
        guard PreferencesManager.shared.enableHaptics else { return }
        performer.perform(.levelChange, performanceTime: .default)
    }
}
