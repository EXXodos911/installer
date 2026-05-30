#!/bin/bash
set -euo pipefail

DOTFILES="$HOME/.local/share/dotfiles"

rm -rf "$DOTFILES"
git clone https://github.com/EXXodos911/dotfiles "$DOTFILES"
rm -rf "$DOTFILES/.git"


mkdir -p ~/.config

# Backup existing config before overwriting
BACKUP="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
if [[ -d ~/.config && "$(ls -A ~/.config)" ]]; then
  cp -r ~/.config "$BACKUP"
  echo "Existing ~/.config backed up to $BACKUP"
fi

# Deploy: exclude .git and repo metadata, don't clobber unrelated config
rsync -a --exclude='.git' --exclude='.gitignore' --exclude='.gitattributes' "$DOTFILES"/ ~/.config/

# Make all scripts in .config executable (git clone preserves bits, cp does too,
# but repos sometimes have scripts committed without +x)
find ~/.config -name "*.sh" -exec chmod +x {} \;

# Place bashrc
cp ~/.config/bashrc ~/.bashrc
rm ~/.config/bashrc
echo '[[ -f ~/.bashrc ]] && . ~/.bashrc' | tee ~/.bash_profile >/dev/null

# Add New file option to Nautilus right click menu
touch "~/Templates/New File.txt"
