#!/bin/sh
# Install chafa, then ask the terminal what it can draw.
set -eu

if command -v brew >/dev/null 2>&1; then
    set -- brew install chafa
elif command -v apt-get >/dev/null 2>&1; then
    set -- sudo apt-get install -y chafa
elif command -v paru >/dev/null 2>&1; then
    set -- paru -S --needed chafa
elif command -v pacman >/dev/null 2>&1; then
    set -- sudo pacman -S --needed chafa
else
    echo "No brew, apt, paru or pacman here. Install chafa by hand." >&2
    exit 1
fi

echo "+ $*"
"$@"

echo
echo "Installed. Now asking this terminal what it can draw:"
echo
"$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/imgprobe.sh" || true
