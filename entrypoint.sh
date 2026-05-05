#!/bin/bash
set -e

# ── Nix ────────────────────────────────────────────────────────────────────────
. /home/builder/.nix-profile/etc/profile.d/nix.sh
export PATH="/home/builder/.nix-profile/bin:$PATH"

# ── Flake URLs ─────────────────────────────────────────────────────────────────
. /home/builder/sources.conf

# ── Arguments ─────────────────────────────────────────────────────────────────
SOURCE="m-labs"
JSON_FILE=""

for arg in "$@"; do
    case $arg in
        --source=*) SOURCE="${arg#*=}" ;;
        *)          JSON_FILE="$arg"   ;;
    esac
done

if [ -z "$JSON_FILE" ]; then
    echo "Usage: entrypoint.sh [--source=m-labs|--source=ucsb] <system.json>"
    exit 1
fi

case "$SOURCE" in
    m-labs) FLAKE_URL="$MLABS_FLAKE" ;;
    ucsb)   FLAKE_URL="$UCSB_FLAKE"  ;;
    *)
        echo "ERROR: Unknown source '$SOURCE'. Use --source=m-labs or --source=ucsb."
        exit 1
        ;;
esac

# ── Validate input ─────────────────────────────────────────────────────────────
INPUT_PATH="/input/${JSON_FILE}"

if [ ! -f "$INPUT_PATH" ]; then
    echo "ERROR: $INPUT_PATH not found. Mount your JSON with: -v /path/to/system.json:/input/system.json"
    exit 1
fi

TARGET=$(grep -oP '"target"\s*:\s*"\K[^"]+' "$INPUT_PATH" 2>/dev/null || echo "kasli")

# ── Vivado webtalk fix ─────────────────────────────────────────────────────────
# Redundant with Vivado_init.tcl baked into the image by Dockerfile, which is
# the reliable fix. These lines failed originally because nix develop modifies
# $HOME so Vivado couldn't find the file at runtime. Kept as a fallback.
mkdir -p /home/builder/.Xilinx/Vivado
echo "config_webtalk -user disable" > /home/builder/.Xilinx/Vivado/Vivado_init.tcl

# ── Build ──────────────────────────────────────────────────────────────────────
echo "==> Source: $SOURCE"
echo "==> Target: $TARGET"
echo "==> Building..."

if [ "$TARGET" = "kasli_soc" ]; then
    # kasli_soc lives in the separate artiq-zynq repo. It uses nix build with a
    # flake that calls makeArtiqZynqPackage, rather than python3 -m artiq.gateware.
    # artiq-zynq's vivado FHS wrapper expects Vivado at /opt/Xilinx/Vivado/2024.2/
    # (symlinked from /tools/Xilinx by Dockerfile).

    TMPDIR=$(mktemp -d)
    trap "rm -rf $TMPDIR" EXIT

    # Copy the user JSON into the temp dir so it can be referenced by the flake
    cp "$INPUT_PATH" "$TMPDIR/system.json"

    # Generate a wrapper flake that calls makeArtiqZynqPackage with our JSON.
    # makeArtiqZynqPackage is exported at the flake top level (not under .lib)
    # and returns an attrset: { "kasli_soc-user-gateware" = ...; ... }
    cat > "$TMPDIR/flake.nix" << EOF
{
  inputs.artiq-zynq.url = "$ZYNQ_FLAKE";
  outputs = { self, artiq-zynq }:
    let
      pkgSet = artiq-zynq.makeArtiqZynqPackage {
        target = "kasli_soc";
        variant = "user";
        json = ./system.json;
      };
    in {
      packages.x86_64-linux = pkgSet;
    };
}
EOF

    for pkg in gateware firmware jtag sd; do
        nix build "$TMPDIR#kasli_soc-user-${pkg}" \
            --accept-flake-config \
            --impure \
            --option extra-sandbox-paths "/opt /tools/Xilinx" \
            -L \
            --out-link "$TMPDIR/result-${pkg}"
    done

    mkdir -p /output
    # Nix store files are read-only; use install to copy with write permissions
    install -m 644 "$TMPDIR/result-gateware/top.bit"        /output/top.bit
    install -m 644 "$TMPDIR/result-firmware/runtime.bin"    /output/runtime.bin
    install -m 644 "$TMPDIR/result-firmware/runtime.elf"    /output/runtime.elf
    install -m 755 -d /output/jtag
    install -m 644 "$TMPDIR/result-jtag/szl.elf"            /output/jtag/szl.elf
    install -m 644 "$TMPDIR/result-jtag/runtime.bin"        /output/jtag/runtime.bin
    install -m 644 "$TMPDIR/result-jtag/top.bit"            /output/jtag/top.bit
    install -m 755 -d /output/sd
    install -m 644 "$TMPDIR/result-sd/boot.bin"             /output/sd/boot.bin

else
    nix develop "$FLAKE_URL" --accept-flake-config --impure --command bash -c "
        source /tools/Xilinx/Vivado/2024.2/settings64.sh
        export LD_PRELOAD=/usr/local/lib/fake_udev.so
        python3 -m artiq.gateware.targets.${TARGET} ${INPUT_PATH} --output-dir /output
    "
fi

echo "==> Done. Binaries in /output:"
ls /output/
