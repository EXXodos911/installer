#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# DNS (Quad9)
sudo tee /etc/systemd/resolved.conf >/dev/null <<'EOF'
[Resolve]
DNS=9.9.9.9
FallbackDNS=9.9.9.9 149.112.112.112
EOF
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl enable --now systemd-resolved

# Patch any systemd-networkd .network files to not override our DNS
for file in /etc/systemd/network/*.network; do
  [[ -f $file ]] || continue
  grep -q '^\[DHCPv4\]' "$file" || continue
  grep -q '^UseDNS=' <(sed -n '/^\[DHCPv4\]/,/^\[/p' "$file") || sudo sed -i '/^\[DHCPv4\]/a UseDNS=no' "$file"
  if grep -q '^\[IPv6AcceptRA\]' "$file"; then
    grep -q '^UseDNS=' <(sed -n '/^\[IPv6AcceptRA\]/,/^\[/p' "$file") || sudo sed -i '/^\[IPv6AcceptRA\]/a UseDNS=no' "$file"
  fi
done

# Docker
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
    "log-driver": "json-file",
    "log-opts": { "max-size": "10m", "max-file": "5" },
    "dns": ["172.17.0.1"],
    "bip": "172.17.0.1/16"
}
EOF
sudo mkdir -p /etc/systemd/resolved.conf.d
printf '[Resolve]\nDNSStubListenerExtra=172.17.0.1\n' | sudo tee /etc/systemd/resolved.conf.d/20-docker-dns.conf >/dev/null
sudo systemctl enable docker.socket
sudo usermod -aG docker "$USER"
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/no-block-boot.conf >/dev/null <<'EOF'
[Unit]
DefaultDependencies=no
EOF

# Firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns'
sudo ufw --force enable
sudo systemctl enable ufw
sudo ufw-docker install
sudo ufw reload

# Faster shutdown (5s instead of 90s default)
sudo mkdir -p /etc/systemd/system.conf.d
sudo tee /etc/systemd/system.conf.d/10-faster-shutdown.conf >/dev/null <<'EOF'
[Manager]
DefaultTimeoutStopSec=5s
EOF
sudo mkdir -p /etc/systemd/system/user@.service.d
sudo tee /etc/systemd/system/user@.service.d/faster-shutdown.conf >/dev/null <<'EOF'
[Manager]
DefaultTimeoutStopSec=5s
EOF

# Sysctl tweaks
echo 'fs.inotify.max_user_watches=524288' | sudo tee /etc/sysctl.d/90-file-watchers.conf >/dev/null
echo 'net.ipv4.tcp_mtu_probing=1' | sudo tee -a /etc/sysctl.d/99-sysctl.conf >/dev/null
sudo sysctl --system >/dev/null

# Groups
sudo usermod -aG input "$USER"

# More sudo tries
echo 'Defaults passwd_tries=5' | sudo tee /etc/sudoers.d/passwd-tries >/dev/null
sudo chmod 440 /etc/sudoers.d/passwd-tries
sudo sed -i 's/^# *deny = .*/deny = 5/' /etc/security/faillock.conf
sudo sed -i 's|^\(auth\s\+required\s\+pam_faillock.so\)\s\+preauth.*$|\1 preauth silent deny=5 unlock_time=120|' /etc/pam.d/system-auth
sudo sed -i 's|^\(auth\s\+\[default=die\]\s\+pam_faillock.so\)\s\+authfail.*$|\1 authfail deny=5 unlock_time=120|' /etc/pam.d/system-auth

# SDDM
sudo rm -rf /usr/share/sddm/themes/where-is-my-sddm-theme
sudo cp -r "$DIR/../system/sddm/where_is_my_sddm_theme" /usr/share/sddm/themes/where-is-my-sddm-theme
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/theme.conf >/dev/null <<'EOF'
[Theme]
Current=where-is-my-sddm-theme
EOF

# Don't let SDDM create a password-locked keyring (we use a passwordless Default_keyring)
sudo sed -i '/-auth.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
sudo sed -i '/-password.*pam_gnome_keyring\.so/d' /etc/pam.d/sddm
sudo systemctl enable sddm.service

# GNOME keyring (passwordless unlock for autologin)
KEYRING_DIR="$HOME/.local/share/keyrings"
mkdir -p "$KEYRING_DIR"
cat > "$KEYRING_DIR/Default_keyring.keyring" <<EOF
[keyring]
display-name=Default keyring
ctime=$(date +%s)
mtime=0
lock-on-idle=false
lock-after=false
EOF
echo 'Default_keyring' > "$KEYRING_DIR/default"
chmod 700 "$KEYRING_DIR"
chmod 600 "$KEYRING_DIR/Default_keyring.keyring"
chmod 644 "$KEYRING_DIR/default"

# Power profile
sudo systemctl enable --now power-profiles-daemon.service
powerprofilesctl set performance || true

# Kernel modules cleanup
sudo systemctl enable linux-modules-cleanup.service

# Screen recordings directory
mkdir -p "${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
chmod +x ~/.config/hypr/scripts/screenrecord-menu.sh
chmod +x ~/.config/hypr/scripts/screenrecord.sh

# Brave theme
sudo mkdir -p /etc/brave/policies/managed
echo '{"BrowserThemeColor": "#1a1b26"}' | sudo tee /etc/brave/policies/managed/color.json >/dev/null

# Nautilus icon symlinks
sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-previous-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-previous-symbolic.svg
sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-next-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-next-symbolic.svg

# Default MIME associations
xdg-mime default org.gnome.Nautilus.desktop inode/directory

xdg-mime default imv.desktop image/png
xdg-mime default imv.desktop image/jpeg
xdg-mime default imv.desktop image/gif
xdg-mime default imv.desktop image/webp
xdg-mime default imv.desktop image/bmp
xdg-mime default imv.desktop image/tiff

xdg-settings set default-web-browser brave-browser.desktop
xdg-mime default brave-browser.desktop x-scheme-handler/http
xdg-mime default brave-browser.desktop x-scheme-handler/https
xdg-mime default brave-browser.desktop x-scheme-handler/mailto
xdg-mime default brave-browser.desktop application/pdf

xdg-mime default mpv.desktop video/mp4
xdg-mime default mpv.desktop video/x-msvideo
xdg-mime default mpv.desktop video/x-matroska
xdg-mime default mpv.desktop video/x-flv
xdg-mime default mpv.desktop video/x-ms-wmv
xdg-mime default mpv.desktop video/mpeg
xdg-mime default mpv.desktop video/ogg
xdg-mime default mpv.desktop video/webm
xdg-mime default mpv.desktop video/quicktime
xdg-mime default mpv.desktop video/3gpp
xdg-mime default mpv.desktop video/3gpp2
xdg-mime default mpv.desktop video/x-ms-asf
xdg-mime default mpv.desktop video/x-ogm+ogg
xdg-mime default mpv.desktop video/x-theora+ogg
xdg-mime default mpv.desktop application/ogg

xdg-mime default nvim.desktop text/plain
xdg-mime default nvim.desktop text/english
xdg-mime default nvim.desktop text/x-makefile
xdg-mime default nvim.desktop text/x-c++hdr
xdg-mime default nvim.desktop text/x-c++src
xdg-mime default nvim.desktop text/x-chdr
xdg-mime default nvim.desktop text/x-csrc
xdg-mime default nvim.desktop text/x-java
xdg-mime default nvim.desktop text/x-moc
xdg-mime default nvim.desktop text/x-pascal
xdg-mime default nvim.desktop text/x-tcl
xdg-mime default nvim.desktop text/x-tex
xdg-mime default nvim.desktop application/x-shellscript
xdg-mime default nvim.desktop text/x-c
xdg-mime default nvim.desktop text/x-c++
xdg-mime default nvim.desktop text/x-csharp
xdg-mime default nvim.desktop application/xml
xdg-mime default nvim.desktop text/xml

sudo systemctl daemon-reload
