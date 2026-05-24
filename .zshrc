# ~/.zshrc — managed by dotfiles repo

# ---------- Path & basics ----------
export PATH="$HOME/.local/bin:$PATH"
export EDITOR="nvim"
export VISUAL="$EDITOR"
export LESS="-R --use-color"

# ---------- History ----------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt EXTENDED_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY

# ---------- Shell behavior ----------
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP
setopt PROMPT_SUBST

# ---------- Zinit bootstrap ----------
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# ---------- Completion system ----------
autoload -Uz compinit
compinit -C

# Style completions
zstyle ':completion:*' menu no
# Fuzzy + substring matching: case-insensitive, partial-anywhere, dash/underscore.
zstyle ':completion:*' matcher-list \
    'm:{a-zA-Z-_}={A-Za-z_-}' \
    'r:|[._-]=* r:|=*' \
    'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false

# ---------- Plugins ----------
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light Aloxaf/fzf-tab

# fzf-tab styling
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons=auto $realpath 2>/dev/null || ls -1 $realpath'
zstyle ':fzf-tab:*' fzf-flags --color=fg:#ebdbb2,bg:#282828,hl:#fabd2f --color=fg+:#fabd2f,bg+:#3c3836,hl+:#fe8019 --color=info:#8ec07c,prompt:#fabd2f,pointer:#fb4934 --color=marker:#b8bb26,spinner:#d3869b,header:#83a598
zstyle ':fzf-tab:*' switch-group ',' '.'

# Autosuggestion color (gruvbox)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#665c54"

# ---------- Key bindings ----------
bindkey -e
bindkey '^[[1;5C' forward-word          # Ctrl+Right
bindkey '^[[1;5D' backward-word         # Ctrl+Left
bindkey '^[[3~'   delete-char           # Del
bindkey '^[[H'    beginning-of-line     # Home
bindkey '^[[F'    end-of-line           # End

# ---------- Aliases ----------
alias ls='eza --icons=auto --group-directories-first'
alias ll='eza -l --icons=auto --group-directories-first'
alias la='eza -la --icons=auto --group-directories-first'
alias lt='eza --tree --level=2 --icons=auto'
alias cat='bat --paging=never --style=plain'
alias grep='grep --color=auto'
alias g='git'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias ..='cd ..'
alias ...='cd ../..'

# Hledger
export LEDGER_FILE="$HOME/financas/journal.ledger"
alias ha='hledger-iadd'
alias hs='hledger-ui'

# ---------- Tools ----------
# Starship prompt
command -v starship >/dev/null && eval "$(starship init zsh)"

# zoxide (smarter cd)
command -v zoxide >/dev/null && eval "$(zoxide init --cmd cd zsh)"

# atuin (history search via ctrl-r + up)
command -v atuin >/dev/null && eval "$(atuin init zsh --disable-up-arrow)"

# fzf keybinds (ctrl-t, alt-c)
[[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -f /usr/share/fzf/completion.zsh ]]   && source /usr/share/fzf/completion.zsh
export FZF_DEFAULT_OPTS="--color=fg:#ebdbb2,bg:#282828,hl:#fabd2f --color=fg+:#fabd2f,bg+:#3c3836,hl+:#fe8019 --color=info:#8ec07c,prompt:#fabd2f,pointer:#fb4934 --color=marker:#b8bb26,spinner:#d3869b,header:#83a598 --height=40% --layout=reverse --border"
