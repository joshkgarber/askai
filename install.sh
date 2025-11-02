#!/usr/bin/env bash

set -e  # Exit on error

# Configuration
SCRIPT_NAME="askai"
INSTALL_DIR="${1:-/home/$USER/.local/bin}"  # Allow custom install directory
SOURCE_SCRIPT="./askai.sh"

# Check if source script exists
if [ ! -f "$SOURCE_SCRIPT" ]; then
    echo "Error: $SOURCE_SCRIPT not found"
    exit 1
fi

# Create directory if needed
mkdir -p "$INSTALL_DIR"

# Copy and make executable
cp "$SOURCE_SCRIPT" "$INSTALL_DIR/$SCRIPT_NAME"
chmod u+x "$INSTALL_DIR/$SCRIPT_NAME"

echo "✓ Installed $SCRIPT_NAME to $INSTALL_DIR"
echo "Make sure $INSTALL_DIR is in your \$PATH"
