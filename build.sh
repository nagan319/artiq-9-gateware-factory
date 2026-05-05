#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="artiq9-builder"
SOURCE="m-labs"
JSON_PATH=""

for arg in "$@"; do
    case $arg in
        --source=*) SOURCE="${arg#*=}" ;;
        *)          JSON_PATH="$arg"   ;;
    esac
done

if [ -z "$JSON_PATH" ]; then
    echo "Usage: $0 [--source=m-labs|--source=ucsb] <system.json>"
    exit 1
fi

if [ ! -f "$JSON_PATH" ]; then
    echo "ERROR: JSON file not found: $JSON_PATH"
    exit 1
fi

JSON_ABS="$(realpath "$JSON_PATH")"
JSON_FILENAME="$(basename "$JSON_ABS")"
JSON_DIR="$(dirname "$JSON_ABS")"
OUTPUT_DIR="${SCRIPT_DIR}/output"

mkdir -p "$OUTPUT_DIR"

if ! docker image inspect "vivado-2024.2-env" &>/dev/null; then
    echo "ERROR: Base image 'vivado-2024.2-env' not found."
    echo "This image contains Vivado and must be built or restored manually."
    echo "See Dockerfile.vivado-base for instructions."
    exit 1
fi

echo "==> Building ARTIQ builder image (uses Docker layer cache, only changed layers rebuilt)..."
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"

# Seed the Nix store volume from the base image on first use.
# The volume is mounted at /nix inside the container, which shadows the Nix
# store baked into the image. On a fresh volume, ~/.nix-profile symlinks and
# the nix binary itself are both broken.
if ! docker run --rm \
        --entrypoint /bin/sh \
        -v artiq9-nix-store:/nix \
        vivado-2024.2-env \
        -c "test -d /nix/var/nix/profiles/per-user/builder" \
        &>/dev/null; then
    echo "==> Seeding Nix store volume from image (first run — may take a few minutes)..."
    docker run --rm \
        --user root \
        --entrypoint /bin/sh \
        -v artiq9-nix-store:/nix-target \
        vivado-2024.2-env \
        -c "cp -a /nix/. /nix-target/"
fi

echo ""
echo "==> Building ARTIQ binaries..."
echo "    Source: $SOURCE"
echo "    Input:  $JSON_ABS"
echo "    Output: $OUTPUT_DIR"
echo ""

docker run --rm \
    --privileged \
    --shm-size=2g \
    -v artiq9-nix-store:/nix \
    -v "${JSON_DIR}/${JSON_FILENAME}:/input/${JSON_FILENAME}:ro" \
    -v "${OUTPUT_DIR}:/output" \
    "$IMAGE_NAME" \
    "--source=${SOURCE}" \
    "$JSON_FILENAME"

echo ""
echo "==> Binaries are in: $OUTPUT_DIR"
