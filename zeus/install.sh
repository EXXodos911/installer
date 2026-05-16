#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Packages"
bash "$DIR/scripts/packages.sh"

echo "==> Dotfiles"
bash "$DIR/scripts/dotfiles.sh"

echo "==> System"
bash "$DIR/scripts/system.sh"

echo "==> Hardware"
bash "$DIR/scripts/hardware.sh"

echo "Done. Please reboot."
