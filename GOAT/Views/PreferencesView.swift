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
    var dynamicWindowColor: Bool {
        didSet { UserDefaults.standard.set(dynamicWindowColor, forKey: "dynamicWindowColor") }
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

    var chatModel: String {
        didSet { UserDefaults.standard.set(chatModel, forKey: "chatModel") }
    }

    /// Chat response tone: "detailed", "balanced", or "concise"
    var chatTone: String {
        didSet { UserDefaults.standard.set(chatTone, forKey: "chatTone") }
    }

    var saveChatHistory: Bool {
        didSet { UserDefaults.standard.set(saveChatHistory, forKey: "saveChatHistory") }
    }
    var gitignoreChatHistory: Bool {
        didSet { UserDefaults.standard.set(gitignoreChatHistory, forKey: "gitignoreChatHistory") }
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
            "dynamicWindowColor",
            "chatModel", "chatTone", "saveChatHistory", "gitignoreChatHistory",
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
        chatModel = "claude-opus-4-6"
        chatTone = "balanced"
        saveChatHistory = true
        gitignoreChatHistory = true
        dynamicWindowColor = true
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
        self.dynamicWindowColor = defaults.object(forKey: "dynamicWindowColor") as? Bool ?? true
        self.chatModel = defaults.string(forKey: "chatModel") ?? "claude-opus-4-6"
        self.chatTone = defaults.string(forKey: "chatTone") ?? "balanced"
        self.saveChatHistory = defaults.object(forKey: "saveChatHistory") as? Bool ?? true
        self.gitignoreChatHistory = defaults.object(forKey: "gitignoreChatHistory") as? Bool ?? true
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
        .frame(width: 450, height: 480)
    }
}

struct GeneralPreferencesView: View {
    @Bindable var prefs: PreferencesManager
    @State private var showResetConfirmation = false

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

            Section("Backlog") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Add backlog to .gitignore", isOn: $prefs.gitignoreBacklog)
                    Text("Keeps backlog.goat.md out of version control so it stays local to your machine.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button("Reset All Defaults", role: .destructive) {
                    showResetConfirmation = true
                }
                .alert("Reset All Defaults?", isPresented: $showResetConfirmation) {
                    Button("Reset", role: .destructive) {
                        prefs.resetAllDefaults()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will restore all preferences to their default values. This cannot be undone.")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct APIPreferencesView: View {
    @State private var prefs = PreferencesManager.shared
    @State private var apiKey: String = ""
    @State private var hasKey: Bool = APIKeyManager.load() != nil
    @State private var showSaved = false

    private let availableModels: [(id: String, label: String)] = [
        ("claude-opus-4-6", "Claude Opus 4.6"),
        ("claude-sonnet-4-6", "Claude Sonnet 4.6"),
        ("claude-haiku-4-5-20251001", "Claude Haiku 4.5"),
    ]

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

            Section {
                Picker("Model", selection: $prefs.chatModel) {
                    ForEach(availableModels, id: \.id) { model in
                        Text(model.label).tag(model.id)
                    }
                }
            } header: {
                Text("Chat Model")
            } footer: {
                Text("The Anthropic model used for chat responses. Opus is the most capable; Haiku is the fastest and cheapest.")
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

    private let toneOptions: [(id: String, label: String)] = [
        ("detailed", "Detailed"),
        ("balanced", "Balanced"),
        ("concise", "Concise"),
    ]

    var body: some View {
        Form {
            Section {
                Picker("Response style", selection: $prefs.chatTone) {
                    ForEach(toneOptions, id: \.id) { option in
                        Text(option.label).tag(option.id)
                    }
                }
            } header: {
                Text("Tone")
            } footer: {
                Text("Detailed gives thorough explanations. Concise gives short, direct answers. Balanced is in between.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("Save chat history", isOn: $prefs.saveChatHistory)
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("Add chat history to .gitignore", isOn: $prefs.gitignoreChatHistory)
                    Text("Keeps chat-history.goat.md out of version control.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
            } header: {
                Text("History")
            } footer: {
                Text("When enabled, chat messages are saved to chat-history.goat.md in the terminal's working directory and restored on next launch.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("File Tree", isOn: $prefs.contextFileTree)
                Toggle("Git Status", isOn: $prefs.contextGitStatus)
                Toggle("README.md", isOn: $prefs.contextReadme)
                Toggle("CLAUDE.md", isOn: $prefs.contextClaudeMd)
                Toggle("Project Manifest", isOn: $prefs.contextManifest)
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("Environment Variables", isOn: $prefs.contextEnvVars)
                    Text("Names only, values are never shared.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 20)
                }
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
            Section("Window") {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Dynamic window color", isOn: $prefs.dynamicWindowColor)
                    Text("Tints the window background to match the active terminal's color. Each tab is assigned a color automatically, giving you a visual cue for which terminal is focused.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

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

struct AboutPanelView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            Text("GOAT")
                .font(.system(size: 18, weight: .bold))

            Text("Greatest of All Terminals")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("Version 0.5 Beta")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("by acon-can")
                .font(.system(size: 13))

            Text("Copyright \u{00A9} 2026 acon-can")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(width: 300, height: 300)
    }
}
