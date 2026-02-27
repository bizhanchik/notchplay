import ServiceManagement

enum LaunchAtLoginManager {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func enable() {
        try? SMAppService.mainApp.register()
    }

    static func disable() {
        try? SMAppService.mainApp.unregister()
    }

    static func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }

    static func sync(with preference: Bool) {
        if preference && !isEnabled {
            enable()
        } else if !preference && isEnabled {
            disable()
        }
    }
}
