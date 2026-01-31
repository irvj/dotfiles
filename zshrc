# --- history ---

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt hist_ignore_dups

# --- path ---

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# --- plugins ---

source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# --- starship prompt ---

eval "$(starship init zsh)"

# --- sudo esc-esc ---

sudo-command-line() {
  BUFFER="sudo $BUFFER"
  zle end-of-line
}
zle -N sudo-command-line
bindkey '\e\e' sudo-command-line

# --- git aliases ---

alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph'
alias lg='lazygit'

# --- general aliases ---

alias ll='ls -la'
alias la='ls -a'
alias ..='cd ..'
alias ...='cd ../..'
alias v='nvim'
alias vim='nvim'
alias dotup='~/.dotfiles/update.sh'

# --- extract function ---

extract() {
  case $1 in
    *.tar.gz|*.tgz) tar xzf $1 ;;
    *.tar.bz2|*.tbz2) tar xjf $1 ;;
    *.tar.xz) tar xJf $1 ;;
    *.tar) tar xf $1 ;;
    *.zip) unzip $1 ;;
    *.gz) gunzip $1 ;;
    *.bz2) bunzip2 $1 ;;
    *.7z) 7z x $1 ;;
    *) echo "unknown format: $1" ;;
  esac
}

# --- editor ---

export EDITOR=nvim
export VISUAL=nvim
