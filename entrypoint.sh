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
VARIANT=$(grep -oP '"variant"\s*:\s*"\K[^"]+' "$INPUT_PATH" 2>/dev/null || echo "")
JSON_BASE="${JSON_FILE%.json}"

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
  nixConfig = {
    extra-substituters = "https://nixbld.m-labs.hk";
    extra-trusted-public-keys = "nixbld.m-labs.hk-1:5aSRVA5b320xbNvu30tqxVPXpld73bhtOeH6uAjRyHc=";
  };
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
        sudo env PATH="$PATH" \
        nix build "$TMPDIR#kasli_soc-user-${pkg}" \
            --accept-flake-config \
            --impure \
            --option extra-sandbox-paths "/opt /tools/Xilinx" \
            -L \
            --out-link "$TMPDIR/result-${pkg}"
    done

    OUTDIR="/output/${JSON_BASE}"
    mkdir -p "$OUTDIR"
    # Nix store files are read-only; use install to copy with write permissions
    install -m 644 "$TMPDIR/result-gateware/top.bit"        "$OUTDIR/top.bit"
    install -m 644 "$TMPDIR/result-firmware/runtime.bin"    "$OUTDIR/runtime.bin"
    install -m 644 "$TMPDIR/result-firmware/runtime.elf"    "$OUTDIR/runtime.elf"
    install -m 755 -d "$OUTDIR/jtag"
    install -m 644 "$TMPDIR/result-jtag/szl.elf"            "$OUTDIR/jtag/szl.elf"
    install -m 644 "$TMPDIR/result-jtag/runtime.bin"        "$OUTDIR/jtag/runtime.bin"
    install -m 644 "$TMPDIR/result-jtag/top.bit"            "$OUTDIR/jtag/top.bit"
    install -m 755 -d "$OUTDIR/sd"
    install -m 644 "$TMPDIR/result-sd/boot.bin"             "$OUTDIR/sd/boot.bin"

    # ── Flake version record ───────────────────────────────────────────────────
    FLAKE_OUTDIR="/output/nix-flakes/${JSON_BASE}"
    mkdir -p "$FLAKE_OUTDIR"
    {
        echo "build_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "json=${JSON_FILE}"
        echo "target=${TARGET}"
        echo "zynq_flake=${ZYNQ_FLAKE}"
    } > "${FLAKE_OUTDIR}/build-info.txt"
    cp "$TMPDIR/flake.nix" "${FLAKE_OUTDIR}/wrapper-flake.nix"
    sudo env PATH="$PATH" nix flake metadata --json "${ZYNQ_FLAKE}" \
        > "${FLAKE_OUTDIR}/zynq-flake-metadata.json" 2>/dev/null || true

else
    sudo env PATH="$PATH" \
    nix develop "$FLAKE_URL" --accept-flake-config --impure --command bash -c "
        source /tools/Xilinx/Vivado/2024.2/settings64.sh
        export LD_PRELOAD=/usr/local/lib/fake_udev.so
        python3 -m artiq.gateware.targets.${TARGET} ${INPUT_PATH} --output-dir /output
    "

    # The gateware script names the output subdir after the JSON variant field.
    # Rename it to match the JSON filename so output paths are predictable.
    if [ -n "$VARIANT" ] && [ "$VARIANT" != "$JSON_BASE" ] && [ -d "/output/$VARIANT" ]; then
        rm -rf "/output/$JSON_BASE"
        mv "/output/$VARIANT" "/output/$JSON_BASE"
    fi
    OUTDIR="/output/$JSON_BASE"

    # ── Flake version record ───────────────────────────────────────────────────
    FLAKE_OUTDIR="/output/nix-flakes/${JSON_BASE}"
    mkdir -p "$FLAKE_OUTDIR"
    {
        echo "build_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "json=${JSON_FILE}"
        echo "source=${SOURCE}"
        echo "target=${TARGET}"
        echo "flake_url=${FLAKE_URL}"
    } > "${FLAKE_OUTDIR}/build-info.txt"
    sudo env PATH="$PATH" nix flake metadata --json "${FLAKE_URL}" \
        > "${FLAKE_OUTDIR}/flake-metadata.json" 2>/dev/null || true
fi

echo "==> Done. Binaries in $OUTDIR:"
ls "$OUTDIR/"
