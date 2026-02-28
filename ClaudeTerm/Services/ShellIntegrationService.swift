import Foundation

struct ShellEnvironment {
    let environment: [String]
    let workingDirectory: String
}

final class ShellIntegrationService {
    static let shared = ShellIntegrationService()

    private var tempZDOTDIR: String?

    private init() {}

    func prepareEnvironment(workingDirectory: String) -> ShellEnvironment {
        // Build environment from current process
        var env = ProcessInfo.processInfo.environment

        // Set up ZDOTDIR injection for zsh shell integration
        let zdotdir = setupZDOTDIR(originalZDOTDIR: env["ZDOTDIR"])
        if let zdotdir = zdotdir {
            env["ZDOTDIR"] = zdotdir
        }

        // Set TERM
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["TERM_PROGRAM"] = "ClaudeTerm"
        env["TERM_PROGRAM_VERSION"] = "1.0.0"

        // Convert to SwiftTerm's expected format: ["KEY=VALUE"]
        let envArray = env.map { "\($0.key)=\($0.value)" }

        return ShellEnvironment(
            environment: envArray,
            workingDirectory: workingDirectory
        )
    }

    private func setupZDOTDIR(originalZDOTDIR: String?) -> String? {
        // Find the integration script from the bundle
        guard let integrationScript = findIntegrationScript() else {
            return nil
        }

        // Create temporary ZDOTDIR
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("claudeterm-\(ProcessInfo.processInfo.processIdentifier)")
            .appendingPathComponent(UUID().uuidString)

        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            // Create .zshenv that:
            // 1. Restores original ZDOTDIR
            // 2. Sources the original .zshenv if it exists
            // 3. Sources our integration script
            let originalZDOTDIR = originalZDOTDIR ?? NSHomeDirectory()
            let zshenvContent = """
            # ClaudeTerm Shell Integration Bootstrap
            # Restore original ZDOTDIR immediately
            export ZDOTDIR="\(originalZDOTDIR)"

            # Source original .zshenv if it exists
            if [[ -f "$ZDOTDIR/.zshenv" ]]; then
                source "$ZDOTDIR/.zshenv"
            fi

            # Source ClaudeTerm integration
            source "\(integrationScript)"
            """

            let zshenvPath = tempDir.appendingPathComponent(".zshenv")
            try zshenvContent.write(to: zshenvPath, atomically: true, encoding: .utf8)

            self.tempZDOTDIR = tempDir.path
            return tempDir.path
        } catch {
            return nil
        }
    }

    private func findIntegrationScript() -> String? {
        // Check in bundle resources first
        if let bundlePath = Bundle.main.path(forResource: "claudeterm-integration", ofType: "zsh") {
            return bundlePath
        }

        // Check relative to executable for SPM builds
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()

        // SPM puts resources in ClaudeTerm_ClaudeTerm.bundle
        let spmBundlePath = executableURL
            .appendingPathComponent("ClaudeTerm_ClaudeTerm.bundle")
            .appendingPathComponent("claudeterm-integration.zsh")
        if FileManager.default.fileExists(atPath: spmBundlePath.path) {
            return spmBundlePath.path
        }

        // Check alongside the executable
        let adjacentPath = executableURL.appendingPathComponent("claudeterm-integration.zsh")
        if FileManager.default.fileExists(atPath: adjacentPath.path) {
            return adjacentPath.path
        }

        // Fallback: create it inline in temp
        return createFallbackIntegrationScript()
    }

    private func createFallbackIntegrationScript() -> String? {
        let script = integrationScriptContent()
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("claudeterm-integration.zsh")
        do {
            try script.write(to: tempPath, atomically: true, encoding: .utf8)
            return tempPath.path
        } catch {
            return nil
        }
    }

    private func integrationScriptContent() -> String {
        return """
        # ClaudeTerm Shell Integration for zsh
        # Emits OSC sequences for terminal status detection

        # Guard against double-sourcing
        [[ -n "$CLAUDETERM_SHELL_INTEGRATION" ]] && return
        export CLAUDETERM_SHELL_INTEGRATION=1

        # Helper to emit OSC sequence
        __claudeterm_osc() {
            printf '\\e]%s\\a' "$1"
        }

        # Helper to base64 encode
        __claudeterm_b64() {
            printf '%s' "$1" | base64
        }

        # Set user variable (iTerm2-compatible OSC 1337)
        __claudeterm_set_user_var() {
            __claudeterm_osc "1337;SetUserVar=$1=$(__claudeterm_b64 "$2")"
        }

        # Get current git branch
        __claudeterm_git_branch() {
            local branch
            branch=$(git symbolic-ref --short HEAD 2>/dev/null) || branch=$(git rev-parse --short HEAD 2>/dev/null) || return
            printf '%s' "$branch"
        }

        # precmd hook - runs before each prompt
        __claudeterm_precmd() {
            local exit_code=$?

            # OSC 7 - Current working directory
            __claudeterm_osc "7;file://$(hostname)$(pwd)"

            # OSC 133;D - Command finished with exit code
            __claudeterm_osc "133;D;$exit_code"

            # OSC 133;A - Prompt start
            __claudeterm_osc "133;A"

            # Git branch
            local branch=$(__claudeterm_git_branch)
            __claudeterm_set_user_var "gitBranch" "${branch:-}"

            # Clear running command
            __claudeterm_set_user_var "currentCommand" ""
        }

        # preexec hook - runs before each command
        __claudeterm_preexec() {
            # OSC 133;C - Command start (after prompt, before output)
            __claudeterm_osc "133;C"

            # Set running command
            __claudeterm_set_user_var "currentCommand" "$1"
        }

        # Install hooks
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd __claudeterm_precmd
        add-zsh-hook preexec __claudeterm_preexec

        # Initial prompt marker
        __claudeterm_osc "133;A"
        """
    }

    func cleanup() {
        if let tempDir = tempZDOTDIR {
            try? FileManager.default.removeItem(atPath: tempDir)
            tempZDOTDIR = nil
        }
    }

    deinit {
        cleanup()
    }
}
