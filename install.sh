#!/usr/bin/env sh
branch=$1
shell=$2

shopt -s expand_aliases
alias config='/usr/bin/git --git-dir=$HOME/.cfg --work-tree=$HOME'

dotconfig() {
  cd $HOME
  echo ".cfg" >> .gitignore
  config stash -a
  config init
  config remote add origin https://github.com/jaredzieche/dotfiles.git
  config fetch origin
  config config --local status.showUntrackedFiles no
  config checkout $branch -f
}

zshconfig() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo "oh my zsh already installed"
  else
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    sudo chsh -s $(which zsh) $(whoami)
  fi
}

zshcustom() {
  source $HOME/.zshrc
  git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
}

if [[ ! -d "$HOME/.cfg" ]]; then
  dotconfig
else
  rm -rf .cfg
  dotconfig
fi

if [[ $shell == zsh ]]; then
  zshconfig
  zshcustom
fi

if [[ ! -x $(which ansible) ]]; then
  pip install ansible
fi

if [[ -x $(which ansible) ]]; then
  ansible-playbook install.yml
fi
