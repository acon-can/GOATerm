# GOAT — Greatest of All Terminals

A native macOS terminal emulator built with SwiftUI and [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm), designed for developers who live in the terminal. GOAT integrates an AI assistant powered by Anthropic's Claude API, a Kanban-style project backlog, dev server management, GitHub integration, and a built-in code editor — all in a single, fast, keyboard-driven app.

> Requires macOS 14.0 (Sonoma) or later.

---

## Features

### Terminal Emulator
- Full xterm-256color / truecolor terminal powered by SwiftTerm
- Tabs, split panes (horizontal and vertical), and workspace saving/restoring
- Shell integration for zsh with OSC sequence support (current directory tracking, command detection, git branch display)
- Configurable scrollback buffer (up to 100,000 lines)
- Customisable fonts and font sizes (ships with DM Sans for the UI)
- Option-as-Meta support for emacs/nano/zsh keybindings

### AI Chat Panel
- Chat with Claude (Anthropic API) directly alongside your terminal
- Rich project context is sent automatically: file tree, git status, README, CLAUDE.md, package manifest, environment variable names, dev server state, and backlog
- Drag-and-drop images and files (including PDFs) into the chat
- Claude can start dev servers for you via `goat-action` blocks
- Chat prompt history saved per-project for later review
- Granular toggles for which context sources are included

### Kanban Backlog
- Built-in Kanban board for managing features and bugs
- Persisted as a human-readable `backlog.goat.md` file in your project directory
- Editable both in-app and by hand — changes are synced on load
- Colour-coded boards, checkbox statuses (to-do / in-progress / done)
- Optional `.gitignore` integration to keep the backlog local

### Dev Server Management
- Start, stop, and monitor dev servers from the Servers panel
- Auto-detection of running ports
- Claude can spin up servers on your behalf from the chat panel
- Server discovery for common frameworks

### GitHub Integration
- Authenticate with GitHub to view your repositories
- Pull request and issue status polling
- GitHub panel for at-a-glance project health

### Code Editor
- Lightweight syntax-highlighted editor panel for quick edits
- File tree browser rooted at the terminal's working directory
- Save files directly from the editor (Cmd+S)

### Claude Project Settings
- Per-project CLAUDE.md editing for persistent AI instructions
- Claude Code history viewer for reviewing past Claude Code sessions

### Workspaces
- Save and restore complete window layouts (tabs, panes, directories)
- Manage multiple workspace presets

---

## Getting Started

### Prerequisites
- macOS 14.0 Sonoma or later
- Xcode 15.0+ (for building from source)
- An Anthropic API key (for the AI chat feature)

### Building from Source

Clone the repository and open it in Xcode:

```bash
git clone <your-repo-url>
cd GOAT
open GOAT.xcodeproj
```

Xcode will automatically resolve the Swift Package Manager dependencies (SwiftTerm and Sparkle). Press **Cmd+R** to build and run.

Alternatively, build from the command line:

```bash
cd GOAT
xcodebuild -project GOAT.xcodeproj -scheme GOAT -configuration Debug build
```

Or using Swift Package Manager directly:

```bash
cd GOAT
swift build
```

### Setting Up Your API Key

1. Launch GOAT
2. Open **Settings** (Cmd+,) and go to the **API** tab
3. Paste your Anthropic API key (`sk-ant-...`)
4. Your key is stored securely in the macOS Keychain

Alternatively, the chat panel will prompt you to enter your key on first use.

---

## Keyboard Shortcuts

### Tabs & Panes
| Shortcut | Action |
|---|---|
| `Cmd+T` | New tab |
| `Cmd+W` | Close tab |
| `Cmd+D` | Split pane horizontally |
| `Cmd+Shift+D` | Split pane vertically |
| `Cmd+Shift+W` | Close pane |
| `Cmd+1`–`Cmd+9` | Switch to tab 1–9 |
| `Cmd+Shift+[` | Previous tab |
| `Cmd+Shift+]` | Next tab |
| `Cmd+Option+[` | Previous pane |
| `Cmd+Option+]` | Next pane |

### Panels
| Shortcut | Action |
|---|---|
| `Cmd+Shift+B` | Toggle Kanban board |
| `Cmd+Shift+K` | Toggle bottom panel |
| `Cmd+Shift+E` | Show files |
| `Cmd+Shift+J` | Show servers |
| `Cmd+Shift+N` | Show environment |
| `Cmd+Shift+,` | Claude project settings |

### Other
| Shortcut | Action |
|---|---|
| `Cmd+S` | Save file in editor |

---

## Project Structure

```
GOAT/
├── GOAT/
│   ├── App/
│   │   ├── AppDelegate.swift          # App lifecycle, Sparkle updater, quit confirmation
│   │   └── GOATApp.swift        # SwiftUI App entry point, menu bar commands
│   ├── Fonts/
│   │   ├── DMSans.ttf                 # UI font
│   │   └── DMSans-Italic.ttf
│   ├── Models/
│   │   ├── AgentModel.swift           # Claude agent/tool-use state
│   │   ├── BacklogModel.swift         # Kanban board data models
│   │   ├── ChatModel.swift            # Chat message models
│   │   ├── ClaudeProjectModel.swift   # CLAUDE.md project config
│   │   ├── EditorModel.swift          # Code editor state
│   │   ├── GitHubModel.swift          # GitHub data models
│   │   ├── PaneNode.swift             # Split pane tree structure
│   │   ├── TabModel.swift             # Tab state
│   │   ├── TerminalSession.swift      # Terminal session state
│   │   ├── WindowState.swift          # Global window/tab/pane state
│   │   └── WorkspaceLayout.swift      # Workspace persistence models
│   ├── Services/
│   │   ├── APIKeyManager.swift        # Keychain-based API key storage
│   │   ├── BacklogFileService.swift   # backlog.goat.md parser/serializer
│   │   ├── ClaudeAPIService.swift     # Anthropic API streaming client
│   │   ├── ClaudeCodeHistoryService.swift
│   │   ├── ClaudeProjectService.swift # CLAUDE.md read/write
│   │   ├── DevServerService.swift     # Dev server process management
│   │   ├── GitHubPollingService.swift # GitHub status polling
│   │   ├── GitHubService.swift        # GitHub API client
│   │   ├── GitService.swift           # Local git operations
│   │   ├── GoatActionParser.swift     # Parses goat-action blocks from AI responses
│   │   ├── NotificationService.swift  # macOS notification permissions
│   │   ├── PromptHistoryService.swift # Chat prompt history logging
│   │   ├── PTYManager.swift           # PTY allocation
│   │   ├── ServerDiscoveryService.swift
│   │   ├── SessionRestorationService.swift
│   │   ├── ShellIntegrationService.swift  # ZDOTDIR injection, env setup
│   │   ├── SyntaxHighlighter.swift    # Code syntax colouring
│   │   └── WorkspacePersistenceService.swift
│   ├── Shell/
│   │   └── goat-integration.zsh # Shell integration script (OSC sequences)
│   ├── Views/
│   │   ├── AIChatView.swift           # Chat panel with system prompt builder
│   │   ├── AgentIndicatorView.swift
│   │   ├── AgentPanelView.swift
│   │   ├── BacklogPanelView.swift     # Kanban board UI
│   │   ├── BottomPanelView.swift      # Tabbed bottom panel container
│   │   ├── CodeEditorView.swift
│   │   ├── EditorPanelView.swift
│   │   ├── EnvironmentPanelView.swift
│   │   ├── FileTreeView.swift
│   │   ├── GitGraphView.swift
│   │   ├── GitHubPanelView.swift
│   │   ├── KanbanBoardView.swift
│   │   ├── MainWindowView.swift       # Root window layout
│   │   ├── PreferencesView.swift      # Settings window (General, Appearance, Chat Context, API, About)
│   │   ├── PromptHistoryView.swift
│   │   ├── SettingsPanelView.swift
│   │   ├── SplitContainerView.swift   # Recursive split pane container
│   │   ├── Styles.swift               # Shared SwiftUI styles
│   │   ├── TabBarView.swift
│   │   ├── TerminalNameEditor.swift
│   │   ├── TerminalPaneView.swift     # SwiftTerm ↔ SwiftUI bridge
│   │   ├── TerminalStatusBarView.swift
│   │   └── WorkspaceManagerView.swift
│   ├── Resources/
│   │   └── Assets.xcassets/
│   │       ├── Contents.json
│   │       └── AppIcon.appiconset/
│   ├── Info.plist
│   └── GOAT.entitlements
├── GOATTests/
├── GOAT.xcodeproj/
├── Package.swift
├── Package.resolved
└── project.yml                        # XcodeGen spec (optional)
```

---

## Auto-Updates (Sparkle)

GOAT uses the [Sparkle](https://sparkle-project.org/) framework for automatic updates.

- A **"Check for Updates..."** menu item is available under the app menu
- The app checks for updates on launch via the appcast feed
- To configure the update URL, edit the `SUFeedURL` key in `Info.plist` to point to your hosted `appcast.xml` file (e.g. on S3)

### Publishing an Update

1. Archive your app in Xcode (Product → Archive)
2. Export the `.app` bundle
3. Use Sparkle's `generate_appcast` tool to create/update your `appcast.xml`
4. Upload the `.app` (or `.zip` / `.dmg`) and `appcast.xml` to your hosting (e.g. S3)

---

## Configuration

### Preferences (Cmd+,)

| Tab | Options |
|---|---|
| **General** | Default directory, Option-as-Meta, scrollback lines, cursor blink, chat history logging, backlog gitignore |
| **Appearance** | Terminal font name, terminal font size, backlog font size |
| **Chat Context** | Toggle which context sources (file tree, git status, README, CLAUDE.md, manifest, env vars, servers, backlog) are included in the AI system prompt |
| **API** | Set or remove your Anthropic API key (stored in Keychain) |
| **About** | Version info, reset all defaults |

### Backlog File

The Kanban backlog is stored as `backlog.goat.md` in each project's root directory. The format is simple Markdown:

```markdown
# Features

## Board Name
<!-- color: blue -->
- [ ] Unstarted item
- [/] In progress item
- [x] Completed item

# Bugs

## Bug Board
- [ ] Some bug to fix
```

You can edit this file by hand — changes are picked up the next time the app loads it.

### Chat History

When enabled in preferences, all chat prompts are logged to `chat-history.goat.md` in your project directory. This file is automatically added to `.gitignore`.

---

## Environment Variables

GOAT sets the following environment variables in spawned shells:

| Variable | Value |
|---|---|
| `TERM` | `xterm-256color` |
| `COLORTERM` | `truecolor` |
| `TERM_PROGRAM` | `GOAT` |
| `TERM_PROGRAM_VERSION` | `1.0.0` |

Shell scripts and tools can detect GOAT via `$TERM_PROGRAM`.

---

## Data Storage

| Data | Location |
|---|---|
| API key | macOS Keychain (`com.claudeterm.app`) |
| Preferences | `~/Library/Preferences/com.claudeterm.app.plist` (UserDefaults) |
| Session restoration | `~/Library/Application Support/GOAT/` |
| Saved workspaces | `~/Library/Application Support/GOAT/` |
| Backlog | `<project>/backlog.goat.md` |
| Chat history | `<project>/chat-history.goat.md` |

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | 1.2.0+ | Terminal emulator engine |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | 2.5.0+ | Auto-update framework |

---

## License

Copyright 2026 Alex Conconi. All rights reserved.

---

## Author

Built by **Alex Conconi**.
