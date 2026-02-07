# --- history ---

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
setopt sharehistory
setopt hist_ignore_dups

# --- timezone (for SSH forwarding via SendEnv TZ) ---

if [[ -z "$TZ" ]]; then
  if [[ -f /etc/timezone ]]; then
    export TZ=$(cat /etc/timezone)
  elif [[ -L /etc/localtime ]]; then
    export TZ=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')
  fi
fi

# --- homebrew (mac only) ---

if [[ -f ~/.dotfiles/.platform ]] && [[ "$(cat ~/.dotfiles/.platform)" == "mac" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- path ---

export PATH="$HOME/.local/bin:$PATH"

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
alias gcl='git clone'
alias glog='git log --oneline --graph'
alias lg='lazygit'

# --- sparse clone ---

gcs() {
  if [[ $# -lt 2 ]]; then
    echo "usage: gcs <repo-url> <folder1> [folder2] ..."
    return 1
  fi

  local repo=$1
  shift

  local name=$(basename "$repo" .git)

  git clone --filter=blob:none --sparse "$repo" &&
    git -C "$name" sparse-checkout set --no-cone "$@"
}

alias gsa='git sparse-checkout add'
alias gsl='git sparse-checkout list'
alias gsd='git sparse-checkout disable'

ghelp() {
  local bold='\033[1m' dim='\033[2m' cyan='\033[36m' reset='\033[0m'

  echo ""
  echo "${bold} Git Aliases${reset}"
  echo "${dim} ──────────────────────────────────────${reset}"
  echo "  ${cyan}gs${reset}    git status"
  echo "  ${cyan}ga${reset}    git add"
  echo "  ${cyan}gc${reset}    git commit"
  echo "  ${cyan}gp${reset}    git push"
  echo "  ${cyan}gl${reset}    git pull"
  echo "  ${cyan}gd${reset}    git diff"
  echo "  ${cyan}gco${reset}   git checkout"
  echo "  ${cyan}gb${reset}    git branch"
  echo "  ${cyan}gcl${reset}   git clone"
  echo "  ${cyan}glog${reset}  git log --oneline --graph"
  echo "  ${cyan}lg${reset}    lazygit"
  echo ""
  echo "${bold} Sparse Checkout${reset}"
  echo "${dim} ──────────────────────────────────────${reset}"
  echo "  ${cyan}gcs${reset}   clone sparse  ${dim}<repo> <folder> ...${reset}"
  echo "  ${cyan}gsa${reset}   sparse-checkout add"
  echo "  ${cyan}gsl${reset}   sparse-checkout list"
  echo "  ${cyan}gsd${reset}   sparse-checkout disable"
  echo ""
}

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

# --- docker helpers ---

docks() {
  local bold='\033[1m' dim='\033[2m' cyan='\033[36m' reset='\033[0m'

  echo ""
  echo "${bold} Docker Containers${reset}"
  echo "${dim} ──────────────────────────────────────${reset}"

  docker ps --format '{{.Names}}\t{{.Ports}}' | while IFS=$'\t' read -r name ports; do
    echo "$ports" | grep -oE '127\.0\.0\.1:[0-9]+' | while read -r addr; do
      local port="${addr#127.0.0.1:}"
      printf "  ${cyan}%-30s${reset} http://localhost:%s\n" "$name" "$port"
    done
  done

  echo ""
}

# --- editor ---

export EDITOR=nvim
export VISUAL=nvim
