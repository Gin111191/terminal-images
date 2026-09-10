#!/bin/sh
# Install the two binaries that draw images in a terminal, then probe the terminal.
#
#   chafa       draws an image in the shell, picking the protocol itself
#   imagemagick gives `magick`, which Neovim's snacks.image shells out to
#
# The package is called "imagemagick" on brew, apt and paru alike, so there is
# nothing to translate per platform beyond the install verb.
set -eu

PKGS='chafa imagemagick'

if command -v brew >/dev/null 2>&1; then
    set -- brew install $PKGS
elif command -v apt-get >/dev/null 2>&1; then
    set -- sudo apt-get install -y $PKGS
elif command -v paru >/dev/null 2>&1; then
    set -- paru -S --needed $PKGS
elif command -v pacman >/dev/null 2>&1; then
    set -- sudo pacman -S --needed $PKGS
else
    echo "No brew, apt, paru or pacman here. Install chafa and imagemagick by hand." >&2
    exit 1
fi

echo "+ $*"
"$@"

echo
echo "Installed. Now asking this terminal what it can draw:"
echo
exec "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/imgprobe.sh"
