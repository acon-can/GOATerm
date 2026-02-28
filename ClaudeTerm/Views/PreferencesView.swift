import SwiftUI

@Observable
final class PreferencesManager {
    static let shared = PreferencesManager()

    static var defaultFontName: String {
        // Prefer Maple Mono, fall back to JetBrains Mono, then SF Mono
        for name in ["Maple Mono", "MapleMono-Regular", "JetBrains Mono", "JetBrainsMono-Regular"] {
            if NSFont(name: name, size: 13) != nil { return name }
        }
        return "SF Mono"
    }

    var fontName: String {
        didSet { UserDefaults.standard.set(fontName, forKey: "fontName") }
    }
    var fontSize: CGFloat {
        didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
    }
    var scrollbackLines: Int {
        didSet { UserDefaults.standard.set(scrollbackLines, forKey: "scrollbackLines") }
    }
    var cursorBlink: Bool {
        didSet { UserDefaults.standard.set(cursorBlink, forKey: "cursorBlink") }
    }
    var optionAsMeta: Bool {
        didSet { UserDefaults.standard.set(optionAsMeta, forKey: "optionAsMeta") }
    }
    var backlogFontSize: CGFloat {
        didSet { UserDefaults.standard.set(backlogFontSize, forKey: "backlogFontSize") }
    }

    var backlogFont: Font {
        .custom(fontName, size: backlogFontSize)
    }

    var backlogTitleFont: Font {
        .custom(fontName, size: backlogFontSize).weight(.semibold)
    }

    private init() {
        let defaults = UserDefaults.standard
        self.fontName = defaults.string(forKey: "fontName") ?? Self.defaultFontName
        self.fontSize = defaults.object(forKey: "fontSize") as? CGFloat ?? 14.0
        self.scrollbackLines = defaults.object(forKey: "scrollbackLines") as? Int ?? 10000
        self.cursorBlink = defaults.object(forKey: "cursorBlink") as? Bool ?? true
        self.optionAsMeta = defaults.object(forKey: "optionAsMeta") as? Bool ?? true
        self.backlogFontSize = defaults.object(forKey: "backlogFontSize") as? CGFloat ?? 14.0
    }
}

struct PreferencesView: View {
    @State private var prefs = PreferencesManager.shared

    var body: some View {
        TabView {
            GeneralPreferencesView(prefs: prefs)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearancePreferencesView(prefs: prefs)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            APIPreferencesView()
                .tabItem {
                    Label("API", systemImage: "key")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralPreferencesView: View {
    @Bindable var prefs: PreferencesManager

    var body: some View {
        Form {
            Section("Shell") {
                Toggle("Option key as Meta", isOn: $prefs.optionAsMeta)
                    .help("Use Option key as Meta key for terminal shortcuts")
            }

            Section("Scrollback") {
                Stepper(
                    "Scrollback lines: \(prefs.scrollbackLines)",
                    value: $prefs.scrollbackLines,
                    in: 1000...100000,
                    step: 1000
                )
            }

            Section("Cursor") {
                Toggle("Cursor blink", isOn: $prefs.cursorBlink)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct APIPreferencesView: View {
    @State private var apiKey: String = ""
    @State private var hasKey: Bool = APIKeyManager.load() != nil
    @State private var showSaved = false

    var body: some View {
        Form {
            Section("Anthropic API") {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save") {
                        if APIKeyManager.save(key: apiKey) {
                            hasKey = true
                            showSaved = true
                            apiKey = ""
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSaved = false }
                        }
                    }
                    .disabled(apiKey.isEmpty)

                    if hasKey {
                        Button("Remove", role: .destructive) {
                            APIKeyManager.delete()
                            hasKey = false
                        }
                    }

                    if showSaved {
                        Text("Saved")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if hasKey {
                        Text("Key stored in Keychain")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AppearancePreferencesView: View {
    @Bindable var prefs: PreferencesManager

    var body: some View {
        Form {
            Section("Font") {
                TextField("Font name", text: $prefs.fontName)
                    .textFieldStyle(.roundedBorder)
                    .help("e.g. Maple Mono, JetBrains Mono, SF Mono, Menlo")

                Slider(value: $prefs.fontSize, in: 9...24, step: 1) {
                    Text("Terminal size: \(Int(prefs.fontSize))pt")
                }

                Slider(value: $prefs.backlogFontSize, in: 9...24, step: 1) {
                    Text("Backlog size: \(Int(prefs.backlogFontSize))pt")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
