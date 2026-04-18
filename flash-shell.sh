#!/bin/bash
# Opens a nix shell with artiq_flash and openocd-bscanspi available.
# Usage: ./flash-shell.sh [--source=m-labs|--source=ucsb]

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sources.conf"

SOURCE="m-labs"

for arg in "$@"; do
    case $arg in
        --source=*) SOURCE="${arg#*=}" ;;
    esac
done

case "$SOURCE" in
    m-labs) FLAKE_URL="$MLABS_FLAKE" ;;
    ucsb)   FLAKE_URL="$UCSB_FLAKE"  ;;
    *)
        echo "ERROR: Unknown source '$SOURCE'. Use --source=m-labs or --source=ucsb."
        exit 1
        ;;
esac

# Strip the #boards fragment — flash tools come from the top-level packages,
# not the boards devShell.
BASE_URL="${FLAKE_URL%#*}"

echo "==> Opening flash shell (source: $SOURCE)"
echo "    artiq_flash and openocd are available once inside."
echo ""

nix shell "${BASE_URL}#artiq" "${BASE_URL}#openocd-bscanspi"
