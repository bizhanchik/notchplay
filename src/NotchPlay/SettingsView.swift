import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gear") }
            GamesSettingsTab()
                .tabItem { Label("Games", systemImage: "gamecontroller") }
            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
            ControlsSettingsTab()
                .tabItem { Label("Controls", systemImage: "hand.tap") }
            AdvancedSettingsTab()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 420, height: 280)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    var body: some View {
        Form {
            Picker("Activation Mode", selection: Binding(
                get: { prefs.activationMode },
                set: { newValue in
                    DispatchQueue.main.async { prefs.activationMode = newValue }
                }
            )) {
                ForEach(ActivationMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

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

            Picker("Default Game", selection: Binding(
                get: { prefs.defaultGame },
                set: { newValue in DispatchQueue.main.async { prefs.defaultGame = newValue } }
            )) {
                ForEach(GameType.allCases, id: \.self) { game in
                    Text(game.rawValue).tag(game.rawValue)
                }
            }
        }
        .padding()
    }
}

// MARK: - Games

private struct GamesSettingsTab: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    var body: some View {
        Form {
            ForEach(GameType.allCases, id: \.self) { game in
                Toggle(game.rawValue, isOn: Binding(
                    get: { prefs.isGameEnabled(game) },
                    set: { _ in DispatchQueue.main.async { prefs.toggleGame(game) } }
                ))
            }
        }
        .padding()
    }
}

// MARK: - Appearance

private struct AppearanceSettingsTab: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    var body: some View {
        Form {
            HStack {
                Text("Shadow Strength")
                Slider(value: Binding(
                    get: { prefs.shadowStrength },
                    set: { newValue in DispatchQueue.main.async { prefs.shadowStrength = newValue } }
                ), in: 0...1)
            }

            HStack {
                Text("Animation Speed")
                Slider(value: Binding(
                    get: { prefs.animationSpeed },
                    set: { newValue in DispatchQueue.main.async { prefs.animationSpeed = newValue } }
                ), in: 0.2...1.0)
            }
        }
        .padding()
    }
}

// MARK: - Controls

private struct ControlsSettingsTab: View {
    @ObservedObject private var prefs = PreferencesManager.shared

    var body: some View {
        Form {
            Toggle("Enable Haptics", isOn: Binding(
                get: { prefs.enableHaptics },
                set: { newValue in DispatchQueue.main.async { prefs.enableHaptics = newValue } }
            ))
            Toggle("Enable Sounds", isOn: Binding(
                get: { prefs.enableSounds },
                set: { newValue in DispatchQueue.main.async { prefs.enableSounds = newValue } }
            ))
        }
        .padding()
    }
}

// MARK: - License

private struct LicenseSettingsTab: View {
    @ObservedObject private var license = LicenseManager.shared
    @State private var keyInput = ""
    @State private var isActivating = false

    var body: some View {
        Form {
            if license.isProUnlocked {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Pro Unlocked")
                        .fontWeight(.medium)
                }

                Text("License: \(license.licenseKey)")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Button("Deactivate License") {
                    DispatchQueue.main.async { license.deactivate() }
                }
            } else {
                TextField("License Key", text: $keyInput)
                    .textFieldStyle(.roundedBorder)

                Button("Activate") {
                    isActivating = true
                    Task {
                        _ = await license.activate(key: keyInput)
                        isActivating = false
                    }
                }
                .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty || isActivating)
            }
        }
        .padding()
    }
}

// MARK: - Advanced

private struct AdvancedSettingsTab: View {
    @ObservedObject private var prefs = PreferencesManager.shared
    @State private var showResetAlert = false

    var body: some View {
        Form {
            Button("Reset All Settings") {
                showResetAlert = true
            }
            .alert("Reset All Settings?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    DispatchQueue.main.async { prefs.resetAll() }
                }
            } message: {
                Text("This will restore all settings to their defaults.")
            }
        }
        .padding()
    }
}
