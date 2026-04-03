#!/bin/bash
# Run this script once to authenticate with AMD and save the auth token
# for use during docker build. You will be prompted for your AMD account
# credentials.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER="$SCRIPT_DIR/FPGAs_AdaptiveSoCs_Unified_2024.2_1113_2356_Lin64.bin"
EXTRACT_DIR="/tmp/vivado_auth_extract"

if [ ! -f "$INSTALLER" ]; then
    echo "ERROR: installer not found at $INSTALLER"
    exit 1
fi

echo "==> Extracting installer..."
rm -rf "$EXTRACT_DIR"
chmod +x "$INSTALLER"
"$INSTALLER" --keep --noexec --target "$EXTRACT_DIR"

echo ""
echo "==> Running AuthTokenGen — enter your AMD account credentials when prompted."
echo ""
"$EXTRACT_DIR/xsetup" -b AuthTokenGen

echo ""
echo "==> Auth complete. Locating token file..."
find /root/.Xilinx "$HOME/.Xilinx" /tmp -name "*.token" -o -name "*auth*" -o -name "*Auth*" 2>/dev/null | grep -v "vivado_auth_extract" || true

echo ""
echo "==> All files in ~/.Xilinx:"
find "$HOME/.Xilinx" 2>/dev/null || echo "(nothing found at ~/.Xilinx)"

echo ""
echo "==> Copying token into Docker build context..."
if [ -f "$HOME/.Xilinx/wi_authentication_key" ]; then
    cp "$HOME/.Xilinx/wi_authentication_key" "$SCRIPT_DIR/wi_authentication_key"
    echo "    Copied to $SCRIPT_DIR/wi_authentication_key"
else
    echo "    WARNING: token file not found at ~/.Xilinx/wi_authentication_key"
fi

echo ""
echo "==> Cleaning up extracted installer..."
rm -rf "$EXTRACT_DIR"
