import AppKit
import SwiftUI

/// Shared reference to the NotchViewModel and window, set by AppDelegate after creating the window.
enum NotchPlayCoordinator {
    static weak var viewModel: NotchViewModel?
    static weak var notchWindow: NSWindow?
}

struct MenuBarMenuView: View {
    @ObservedObject private var prefs = PreferencesManager.shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            Button("Open NotchPlay") {
                NotchPlayCoordinator.viewModel?.openIfCompact()
            }

            Menu("Open Game") {
                ForEach(prefs.enabledGameTypes, id: \.self) { game in
                    Button(game.rawValue) {
                        NotchPlayCoordinator.viewModel?.openAndStartGame(game)
                    }
                }
            }

            Divider()

            Menu("Activation Mode") {
                ForEach(ActivationMode.allCases, id: \.self) { mode in
                    Button {
                        DispatchQueue.main.async { PreferencesManager.shared.activationMode = mode }
                    } label: {
                        if prefs.activationMode == mode {
                            Label(mode.rawValue, systemImage: "checkmark")
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                }
            }

            Divider()

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Label("Settings...", systemImage: "gear")
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Toggle("Launch at Login", isOn: Binding(
                get: { LaunchAtLoginManager.isEnabled },
                set: { newValue in
                    DispatchQueue.main.async {
                        if newValue { LaunchAtLoginManager.enable() }
                        else { LaunchAtLoginManager.disable() }
                        prefs.launchAtLogin = newValue
                    }
                }
            ))

            Divider()

            Button("Quit NotchPlay") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [])
        }
        .onAppear {
            NotchPlayCoordinator.notchWindow?.resignKey()
        }
    }
}

private extension NotchViewModel {
    func openIfCompact() {
        if state == .compact {
            open()
        }
    }

    func openAndStartGame(_ game: GameType) {
        if state == .compact {
            open()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.startGame(game)
        }
    }
}
