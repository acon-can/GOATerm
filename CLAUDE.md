# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is GOAT

GOAT (Greatest of All Terminals) is a native macOS terminal emulator built with SwiftUI and SwiftTerm. It bundles an AI chat panel (Anthropic Claude API), a Kanban backlog, dev server management, GitHub integration, and a code editor into a single app. Requires macOS 14.0+.

## Build & Run

```bash
# Open in Xcode (resolves SPM deps automatically), then Cmd+R
open GOAT.xcodeproj

# Command-line build via Xcode
xcodebuild -project GOAT.xcodeproj -scheme GOAT -configuration Debug build

# Swift Package Manager build
swift build

# Run tests
swift test
```

Dependencies: SwiftTerm (terminal engine), Sparkle (auto-updates). Both resolved via SPM.

There is also a `project.yml` (XcodeGen spec) that can regenerate the Xcode project if needed.

## Architecture

### State Flow

All data models use Swift's `@Observable` macro. State flows top-down:

```
WindowState (root — UI state, tab/pane ops, backlog caching)
├── tabs: [TabModel]
│   ├── rootPane: PaneNode (recursive split-pane tree)
│   ├── chatSession: ChatSession
│   ├── editorState: EditorState
│   ├── serverStore: ServerStore
│   └── envEditorState: EnvironmentEditorState
├── activeBacklog: BacklogStore (per-directory, LRU-cached, max 10)
└── githubState: GitHubState
```

`WindowState` is created in `GOATApp.swift` and passed into `MainWindowView`. Panel visibility and sizing are persisted to UserDefaults via `didSet` blocks.

### Split Pane Tree

`PaneNode` is an indirect recursive enum with two cases:
- `.terminal(TerminalSession)` — leaf node
- `.split(orientation, first, second, ratio)` — branch node

Operations (`replacing`, `removing`) return **new trees** (value semantics). `SplitContainerView` recursively renders the tree. `TabModel` owns `rootPane` and provides split/close/navigate operations.

### Terminal Bridge

`TerminalPaneView` (NSViewRepresentable) bridges SwiftTerm's `LocalProcessTerminalView` into SwiftUI. Its `Coordinator` maintains a **static registry** (`coordinators: [UUID: Coordinator]`) used for global access (e.g., focus management, quit checks).

The coordinator registers OSC handlers for shell integration:
- **OSC 1337** (iTerm2 SetUserVar): git branch, running command
- **OSC 133** (FinalTerm semantic prompt): command completion, exit codes, permission-denied detection

### Shell Integration

`ShellIntegrationService` injects a custom ZDOTDIR pointing to a temp directory containing a `.zshenv` that sources the bundled `goat-integration.zsh`. This script installs `precmd`/`preexec` hooks that emit OSC sequences for directory tracking, git branch, and command detection.

### AI Chat

`AIChatView` dynamically builds a system prompt including: working directory, git branch/status, file tree (3-level), README, CLAUDE.md, package manifests, env var names, dev server state, and backlog. Each context source has a user toggle.

`ClaudeAPIService` streams responses from `POST /v1/messages` (API version 2023-06-01, max 4096 tokens). Supports image, PDF, and text file attachments.

`GoatActionParser` extracts ` ```goat-action` ` JSON blocks from AI responses (e.g., `start_server` action) to let Claude trigger dev servers.

### Backlog Persistence

The Kanban board is stored as `backlog.goat.md` (markdown) in each project directory. `BacklogFileService` handles parsing/serializing with:
- Serialization on main thread (reads @Observable state)
- File I/O on a dedicated serial queue
- 0.5s debounced saves
- Auto-removes file when backlog is empty

### Dev Server Management

`DevServerService` spawns processes via `/bin/zsh -ilc` (interactive login shell to pick up nvm/homebrew). Features port detection via regex, auto-restart (3 retries, 2s delay), and graceful termination (SIGTERM → 2s → SIGKILL via process group).

## Layout

`MainWindowView` uses a hidden titlebar with a custom "island" overlay containing traffic light buttons and the tab bar. Content area is an HStack of terminal panes (with optional bottom panel) and an optional right-side Kanban board. Resize handles use NSViewRepresentable with mouse drag tracking.

## Key Conventions

- Bundle ID: `com.claudeterm.app`
- API key storage: macOS Keychain
- App data: `~/Library/Application Support/GOAT/`
- Per-project files: `backlog.goat.md`, `chat-history.goat.md` (both gitignored)
- Environment: sets `TERM_PROGRAM=GOAT` in spawned shells
