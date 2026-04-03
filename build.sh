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

if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    echo "==> Building ARTIQ builder image..."
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
else
    echo "==> Using cached Docker image '$IMAGE_NAME'"
    echo "    (Run 'docker rmi $IMAGE_NAME' to rebuild without touching Vivado)"
fi

echo ""
echo "==> Building ARTIQ binaries..."
echo "    Source: $SOURCE"
echo "    Input:  $JSON_ABS"
echo "    Output: $OUTPUT_DIR"
echo ""

docker run --rm \
    --shm-size=2g \
    --security-opt seccomp=unconfined \
    -v artiq9-nix-store:/nix \
    -v "${JSON_DIR}/${JSON_FILENAME}:/input/${JSON_FILENAME}:ro" \
    -v "${OUTPUT_DIR}:/output" \
    "$IMAGE_NAME" \
    "--source=${SOURCE}" \
    "$JSON_FILENAME"

echo ""
echo "==> Binaries are in: $OUTPUT_DIR"
