# GOAT Shell Integration for zsh
# Emits OSC sequences for terminal status detection

# Guard against double-sourcing
[[ -n "$GOAT_SHELL_INTEGRATION" ]] && return
export GOAT_SHELL_INTEGRATION=1

# Helper to emit OSC sequence
__goat_osc() {
    printf '\e]%s\a' "$1"
}

# Helper to base64 encode
__goat_b64() {
    printf '%s' "$1" | base64
}

# Set user variable (iTerm2-compatible OSC 1337)
__goat_set_user_var() {
    __goat_osc "1337;SetUserVar=$1=$(__goat_b64 "$2")"
}

# Get current git branch
__goat_git_branch() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null) || \
        branch=$(git rev-parse --short HEAD 2>/dev/null) || \
        return
    printf '%s' "$branch"
}

# precmd hook - runs before each prompt
__goat_precmd() {
    local exit_code=$?

    # OSC 7 - Current working directory
    __goat_osc "7;file://$(hostname)$(pwd)"

    # OSC 133;D - Command finished with exit code
    __goat_osc "133;D;$exit_code"

    # OSC 133;A - Prompt start
    __goat_osc "133;A"

    # Git branch
    local branch=$(__goat_git_branch)
    __goat_set_user_var "gitBranch" "${branch:-}"

    # Clear running command
    __goat_set_user_var "currentCommand" ""
}

# preexec hook - runs before each command
__goat_preexec() {
    # OSC 133;C - Command start (after prompt, before output)
    __goat_osc "133;C"

    # Set running command
    __goat_set_user_var "currentCommand" "$1"
}

# Install hooks
autoload -Uz add-zsh-hook
add-zsh-hook precmd __goat_precmd
add-zsh-hook preexec __goat_preexec

# Initial prompt marker
__goat_osc "133;A"
