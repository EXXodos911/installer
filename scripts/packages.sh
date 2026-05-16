#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Bootstrap yay if not present
if ! command -v yay &>/dev/null; then
  sudo pacman -S --noconfirm --needed git base-devel
  git clone https://aur.archlinux.org/yay.git /tmp/yay-install
  (cd /tmp/yay-install && makepkg -si --noconfirm)
  rm -rf /tmp/yay-install
fi

# Base packages
mapfile -t base < <(grep -v '^#' "$DIR/../packages/base" | grep -v '^$')
sudo pacman -S --noconfirm --needed "${base[@]}"

# AUR packages
mapfile -t aur < <(grep -v '^#' "$DIR/../packages/aur" | grep -v '^$')
yay -S --noconfirm --needed "${aur[@]}"

# LazyVim
[[ -d ~/.config/nvim ]] && mv ~/.config/nvim ~/.config/nvim.bak
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git
mkdir -p ~/.config/nvim/lua/plugins
cat > ~/.config/nvim/lua/plugins/tokyonight.lua <<'EOF'
return {
  { "folke/tokyonight.nvim", priority = 1000 },
  { "LazyVim/LazyVim", opts = { colorscheme = "tokyonight-night" } },
}
EOF
