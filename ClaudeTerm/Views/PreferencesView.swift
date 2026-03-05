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
    var logChatHistory: Bool {
        didSet { UserDefaults.standard.set(logChatHistory, forKey: "logChatHistory") }
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

    func resetAllDefaults() {
        let keys = [
            "fontName", "fontSize", "scrollbackLines", "cursorBlink",
            "optionAsMeta", "backlogFontSize", "defaultDirectory", "gitignoreBacklog",
            "logChatHistory",
            "contextFileTree", "contextGitStatus", "contextReadme", "contextClaudeMd",
            "contextManifest", "contextEnvVars", "contextServers", "contextBacklog",
            "panelBacklogVisible", "panelBacklogWidthRatio",
            "panelBottomExpanded", "panelBottomHeightRatio", "panelBottomSavedRatio"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        fontName = Self.defaultFontName
        fontSize = 14.0
        scrollbackLines = 10000
        cursorBlink = true
        optionAsMeta = true
        backlogFontSize = 14.0
        defaultDirectory = nil
        gitignoreBacklog = true
        contextFileTree = true
        contextGitStatus = true
        contextReadme = true
        contextClaudeMd = true
        contextManifest = true
        contextEnvVars = true
        contextServers = true
        contextBacklog = true
        logChatHistory = true
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
        self.logChatHistory = defaults.object(forKey: "logChatHistory") as? Bool ?? true
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

            AboutPreferencesView(prefs: prefs)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 480)
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
                VStack(alignment: .leading, spacing: 4) {
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
                    Text("New terminal tabs will open in this directory by default.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Shell") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Option key as Meta", isOn: $prefs.optionAsMeta)
                    Text("Sends Option key as Meta for programs like emacs, nano, and zsh keybindings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Scrollback") {
                VStack(alignment: .leading, spacing: 4) {
                    Stepper(
                        "Scrollback lines: \(prefs.scrollbackLines)",
                        value: $prefs.scrollbackLines,
                        in: 1000...100000,
                        step: 1000
                    )
                    Text("Number of lines of terminal output kept in memory for scrolling back.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Cursor") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Cursor blink", isOn: $prefs.cursorBlink)
                    Text("Makes the terminal cursor blink to help locate it on screen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Chat") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Log chat history", isOn: $prefs.logChatHistory)
                    Text("Saves chat prompts to chathistory.goat.md in your project directory for later review. This file is always added to .gitignore automatically.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Backlog") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Add backlog to .gitignore", isOn: $prefs.gitignoreBacklog)
                    Text("Keeps backlog.goat.md out of version control so it stays local to your machine.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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
            Section {
                if hasKey {
                    TextField("", text: .constant(String(repeating: "\u{2022}", count: 24)))
                        .textFieldStyle(.roundedBorder)
                        .disabled(true)
                } else {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }

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
            } header: {
                Text("Anthropic API")
            } footer: {
                Text("Your API key is stored securely in the macOS Keychain and used to power the Chat panel.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
            Section {
                Toggle("File Tree", isOn: $prefs.contextFileTree)
                Toggle("Git Status", isOn: $prefs.contextGitStatus)
                Toggle("README.md", isOn: $prefs.contextReadme)
                Toggle("CLAUDE.md", isOn: $prefs.contextClaudeMd)
                Toggle("Project Manifest", isOn: $prefs.contextManifest)
                Toggle("Environment Variables (names only, values are never shared)", isOn: $prefs.contextEnvVars)
                Toggle("Dev Servers", isOn: $prefs.contextServers)
                Toggle("Backlog", isOn: $prefs.contextBacklog)
            } header: {
                Text("Context Sources")
            } footer: {
                Text("Each toggle controls whether that source is included in the system prompt sent to Claude when you chat. More context gives better answers but uses more tokens.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Font name", text: $prefs.fontName)
                        .textFieldStyle(.roundedBorder)
                    Text("The monospace font used in the terminal (e.g. Maple Mono, JetBrains Mono, SF Mono).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $prefs.fontSize, in: 9...24, step: 1) {
                        Text("Terminal size: \(Int(prefs.fontSize))pt")
                    }
                    Text("Controls the font size of text displayed in the terminal.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $prefs.backlogFontSize, in: 9...24, step: 1) {
                        Text("Backlog size: \(Int(prefs.backlogFontSize))pt")
                    }
                    Text("Controls the font size of prompts and text in the backlog panel.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutPreferencesView: View {
    @Bindable var prefs: PreferencesManager
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "terminal")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("GOAT Terminal")
                .font(.system(size: 18, weight: .bold))

            Text("Version 0.5 Beta")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("by Alex Conconi")
                .font(.system(size: 13))

            Text("Copyright \u{00A9} 2026 Alex Conconi")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()

            Divider()

            Button(action: { showResetConfirmation = true }) {
                Text("Reset All Defaults")
                    .font(.system(size: 12))
            }
            .alert("Reset All Defaults?", isPresented: $showResetConfirmation) {
                Button("Reset", role: .destructive) {
                    prefs.resetAllDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will restore all preferences to their default values. This cannot be undone.")
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
