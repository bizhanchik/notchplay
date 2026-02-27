import SwiftUI

@main
struct NotchPlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("NotchPlay", systemImage: "gamecontroller.fill") {
            MenuBarMenuView()
        }
        Settings {
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = NotchWindowController()
        windowController = controller
        NotchPlayCoordinator.viewModel = controller.viewModel
        NotchPlayCoordinator.notchWindow = controller.window
        controller.showWindow(nil)

        LaunchAtLoginManager.sync(with: PreferencesManager.shared.launchAtLogin)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
