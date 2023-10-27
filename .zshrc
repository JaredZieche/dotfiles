# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
#   source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
# fi

# If you come from bash you might have to change your $PATH.
if [[ $(uname) == 'Darwin' ]]; then
  export PATH=/opt/homebrew/Cellar/gnu-sed/4.8/bin:/opt/homebrew/opt/curl/bin:/opt/homebrew/bin:$HOME/node_modules/.bin/:$HOME/.luarocks/bin:$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH
  export HOMEBREW_NO_AUTO_UPDATE=1
else
  export PATH=$HOME/node_modules/.bin/:$HOME/.luarocks/bin:$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH
fi
# export TERM="xterm-256color"
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
# ZSH_THEME="powerlevel10k/powerlevel10k"
# # Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM=$HOME/.zsh/

plugins=(git zsh-autosuggestions docker docker-compose gh)


source $ZSH/oh-my-zsh.sh
set -o vi
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
# You may need to manually set your language environment
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='nvim'
fi
# completion
autoload -U compinit
compinit -i
source <(kubectl completion zsh)
complete -F __start_kubectl k
# AWS CLI Completion
if [[ $(uname) == 'Darwin' ]]; then
  complete -C '~/.local/bin/aws_completer' aws
fi
# Policy Sentry completion
# eval "$(_POLICY_SENTRY_COMPLETE=source_zsh policy_sentry)"
# Compilation flags
# export ARCHFLAGS="-arch x86_64"
# Alias
source ~/.zsh/aliases
source ~/.zsh/functions.zsh

source /opt/homebrew/opt/chruby/share/chruby/chruby.sh
source /opt/homebrew/opt/chruby/share/chruby/auto.sh

eval "$(starship init zsh)"

[[ -s "${HOME}/.gvm/scripts/gvm" ]] && source "${HOME}/.gvm/scripts/gvm"
