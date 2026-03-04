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
    var defaultDirectory: String? {
        didSet { UserDefaults.standard.set(defaultDirectory, forKey: "defaultDirectory") }
    }

    static func uiFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("DM Sans", size: size).weight(weight)
    }

    var backlogFont: Font {
        .custom("DM Sans", size: backlogFontSize)
    }

    var backlogTitleFont: Font {
        .custom("DM Sans", size: backlogFontSize)
    }

    /// Returns the default directory for new terminals, falling back to home.
    var effectiveDefaultDirectory: String {
        if let dir = defaultDirectory, !dir.isEmpty,
           FileManager.default.fileExists(atPath: dir) {
            return dir
        }
        return NSHomeDirectory()
    }

    private init() {
        let defaults = UserDefaults.standard
        self.fontName = defaults.string(forKey: "fontName") ?? Self.defaultFontName
        self.fontSize = defaults.object(forKey: "fontSize") as? CGFloat ?? 14.0
        self.scrollbackLines = defaults.object(forKey: "scrollbackLines") as? Int ?? 10000
        self.cursorBlink = defaults.object(forKey: "cursorBlink") as? Bool ?? true
        self.optionAsMeta = defaults.object(forKey: "optionAsMeta") as? Bool ?? true
        self.backlogFontSize = defaults.object(forKey: "backlogFontSize") as? CGFloat ?? 14.0
        self.defaultDirectory = defaults.string(forKey: "defaultDirectory")
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

    private var directoryDisplay: String {
        guard let dir = prefs.defaultDirectory, !dir.isEmpty else {
            return "Home (~)"
        }
        let home = NSHomeDirectory()
        if dir == home { return "Home (~)" }
        if dir.hasPrefix(home + "/") {
            return "~/" + String(dir.dropFirst(home.count + 1))
        }
        return dir
    }

    var body: some View {
        Form {
            Section("Startup") {
                HStack {
                    Text("Default directory:")
                    Spacer()
                    Text(directoryDisplay)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choose...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        panel.message = "Choose the default directory for new terminals"
                        if let dir = prefs.defaultDirectory, !dir.isEmpty {
                            panel.directoryURL = URL(fileURLWithPath: dir)
                        }
                        if panel.runModal() == .OK, let url = panel.url {
                            prefs.defaultDirectory = url.path
                        }
                    }
                    if prefs.defaultDirectory != nil {
                        Button("Reset") {
                            prefs.defaultDirectory = nil
                        }
                    }
                }
                .help("New terminal tabs will start in this directory")
            }

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
                SecureField(hasKey ? "Key stored in Keychain" : "API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .disabled(hasKey)

                HStack {
                    if hasKey {
                        Button("Remove", role: .destructive) {
                            APIKeyManager.delete()
                            hasKey = false
                            apiKey = ""
                        }
                    } else {
                        Button("Save") {
                            if APIKeyManager.save(key: apiKey) {
                                hasKey = true
                                showSaved = true
                                apiKey = ""
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSaved = false }
                            }
                        }
                        .disabled(apiKey.isEmpty)
                    }

                    if showSaved {
                        Text("Saved")
                            .font(.caption)
                            .foregroundColor(.green)
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
