# ClaudeTerm Shell Integration for zsh
# Emits OSC sequences for terminal status detection

# Guard against double-sourcing
[[ -n "$CLAUDETERM_SHELL_INTEGRATION" ]] && return
export CLAUDETERM_SHELL_INTEGRATION=1

# Helper to emit OSC sequence
__claudeterm_osc() {
    printf '\e]%s\a' "$1"
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
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || \
        branch=$(git rev-parse --short HEAD 2>/dev/null) || \
        return
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
