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
    var gitignoreBacklog: Bool {
        didSet { UserDefaults.standard.set(gitignoreBacklog, forKey: "gitignoreBacklog") }
    }

    // Chat context toggles
    var contextFileTree: Bool {
        didSet { UserDefaults.standard.set(contextFileTree, forKey: "contextFileTree") }
    }
    var contextGitStatus: Bool {
        didSet { UserDefaults.standard.set(contextGitStatus, forKey: "contextGitStatus") }
    }
    var contextReadme: Bool {
        didSet { UserDefaults.standard.set(contextReadme, forKey: "contextReadme") }
    }
    var contextClaudeMd: Bool {
        didSet { UserDefaults.standard.set(contextClaudeMd, forKey: "contextClaudeMd") }
    }
    var contextManifest: Bool {
        didSet { UserDefaults.standard.set(contextManifest, forKey: "contextManifest") }
    }
    var contextEnvVars: Bool {
        didSet { UserDefaults.standard.set(contextEnvVars, forKey: "contextEnvVars") }
    }
    var contextServers: Bool {
        didSet { UserDefaults.standard.set(contextServers, forKey: "contextServers") }
    }
    var contextBacklog: Bool {
        didSet { UserDefaults.standard.set(contextBacklog, forKey: "contextBacklog") }
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
        self.gitignoreBacklog = defaults.object(forKey: "gitignoreBacklog") as? Bool ?? true
        self.contextFileTree = defaults.object(forKey: "contextFileTree") as? Bool ?? true
        self.contextGitStatus = defaults.object(forKey: "contextGitStatus") as? Bool ?? true
        self.contextReadme = defaults.object(forKey: "contextReadme") as? Bool ?? true
        self.contextClaudeMd = defaults.object(forKey: "contextClaudeMd") as? Bool ?? true
        self.contextManifest = defaults.object(forKey: "contextManifest") as? Bool ?? true
        self.contextEnvVars = defaults.object(forKey: "contextEnvVars") as? Bool ?? true
        self.contextServers = defaults.object(forKey: "contextServers") as? Bool ?? true
        self.contextBacklog = defaults.object(forKey: "contextBacklog") as? Bool ?? true
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

            ChatContextPreferencesView(prefs: prefs)
                .tabItem {
                    Label("Chat Context", systemImage: "brain")
                }

            APIPreferencesView()
                .tabItem {
                    Label("API", systemImage: "key")
                }
        }
        .frame(width: 450, height: 360)
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

            Section("Backlog") {
                Toggle("Add backlog to .gitignore", isOn: $prefs.gitignoreBacklog)
                    .help("When enabled, backlog.goat.md is added to .gitignore so it stays local. Disable to sync it with Git.")
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

struct ChatContextPreferencesView: View {
    @Bindable var prefs: PreferencesManager

    var body: some View {
        Form {
            Section("Context Sources") {
                Toggle("File Tree", isOn: $prefs.contextFileTree)
                    .help("Include project file tree in chat context")
                Toggle("Git Status", isOn: $prefs.contextGitStatus)
                    .help("Include git branch, staged files, and recent commits")
                Toggle("README.md", isOn: $prefs.contextReadme)
                    .help("Include project README contents")
                Toggle("CLAUDE.md", isOn: $prefs.contextClaudeMd)
                    .help("Include CLAUDE.md project instructions")
                Toggle("Project Manifest", isOn: $prefs.contextManifest)
                    .help("Include package.json, Package.swift, etc.")
                Toggle("Environment Variables", isOn: $prefs.contextEnvVars)
                    .help("Include .env variable names (values hidden)")
                Toggle("Dev Servers", isOn: $prefs.contextServers)
                    .help("Include running dev server status")
                Toggle("Backlog", isOn: $prefs.contextBacklog)
                    .help("Include backlog prompts in chat context")
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
