#!/bin/bash
# Build wrapper that symlinks nc-server-core into the build context

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Create symlink to nc-server-core if it doesn't exist
if [ ! -L "$SCRIPT_DIR/nc-server-core" ] && [ ! -d "$SCRIPT_DIR/nc-server-core" ]; then
    echo "🔗 Creating symlink to nc-server-core..."
    ln -s "$PROJECT_ROOT/nc-server-core" "$SCRIPT_DIR/nc-server-core"
fi

# Run docker build
cd "$SCRIPT_DIR"
docker build -t "${IMAGE_TAG:-nextcloud-dev-php84}" -f php84/Dockerfile .
