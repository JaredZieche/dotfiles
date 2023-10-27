LANG="en_IN.utf8"
export LANG
LC_ALL="en_US.utf8"
export LC_ALL

if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init - zsh)"
fi
