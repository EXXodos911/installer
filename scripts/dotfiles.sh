#!/bin/bash
set -euo pipefail

DOTFILES="$HOME/.local/share/dotfiles"

rm -rf "$DOTFILES"
git clone https://github.com/EXXodos911/dotfiles "$DOTFILES"
rm -rf "$DOTFILES/.git"

mkdir -p ~/.config
cp -R "$DOTFILES"/. ~/.config/

# Make all scripts in .config executable (git clone preserves bits, cp does too,
# but repos sometimes have scripts committed without +x)
find ~/.config -name "*.sh" -exec chmod +x {} \;

# Place bashrc
cp ~/.config/bashrc ~/.bashrc
echo '[[ -f ~/.bashrc ]] && . ~/.bashrc' | tee ~/.bash_profile >/dev/null
