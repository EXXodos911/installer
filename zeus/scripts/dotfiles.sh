#!/bin/bash
set -euo pipefail

DOTFILES="$HOME/.local/share/dotfiles"

if [[ -d "$DOTFILES" ]]; then
  git -C "$DOTFILES" pull
else
  git clone https://github.com/EXXodos911/dotfiles "$DOTFILES"
fi

mkdir -p ~/.config
cp -R "$DOTFILES"/. ~/.config/

# Make all scripts in .config executable (git clone preserves bits, cp does too,
# but repos sometimes have scripts committed without +x)
find ~/.config -name "*.sh" -exec chmod +x {} \;

# Place bashrc
cp ~/.config/bashrc ~/.bashrc
echo '[[ -f ~/.bashrc ]] && . ~/.bashrc' | tee ~/.bash_profile >/dev/null

# Walker autostart service
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/walker.desktop <<'EOF'
[Desktop Entry]
Name=Walker
Comment=Walker Service
Exec=walker --gapplication-service
StartupNotify=false
Terminal=false
Type=Application
EOF

mkdir -p ~/.config/systemd/user/app-walker@autostart.service.d
cat > ~/.config/systemd/user/app-walker@autostart.service.d/restart.conf <<'EOF'
[Service]
Restart=always
RestartSec=2
EOF
