#!/usr/bin/env bash
set -euo pipefail

# prcheck installer
# Downloads and installs prcheck to ~/.local/bin

INSTALL_DIR="${HOME}/.local/bin"

# Check if prcheck is already installed
if [ -f "${INSTALL_DIR}/prcheck" ]; then
  echo "Updating prcheck to latest version..."
  ACTION="updated"
else
  echo "Installing prcheck..."
  ACTION="installed"
fi

# Create install directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
  echo "Creating $INSTALL_DIR..."
  mkdir -p "$INSTALL_DIR"
fi

# Download prcheck from GitHub
echo "Downloading prcheck from GitHub..."
if ! curl -fsSL "https://raw.githubusercontent.com/connorlanewhite/prcheck/main/bin/prcheck" -o "${INSTALL_DIR}/prcheck"; then
  echo "Error: Failed to download prcheck" >&2
  exit 1
fi

# Make it executable
chmod +x "${INSTALL_DIR}/prcheck"

echo "✓ prcheck ${ACTION} to ${INSTALL_DIR}/prcheck"

# Check if install directory is in PATH
if [[ ":${PATH}:" != *":${INSTALL_DIR}:"* ]]; then
  echo ""
  echo "Note: ${INSTALL_DIR} is not in your PATH."
  echo "Add this line to your ~/.bashrc, ~/.zshrc, or equivalent:"
  echo ""
  echo "  export PATH=\"\${HOME}/.local/bin:\${PATH}\""
  echo ""
fi

echo ""
echo "Installation complete!"
echo ""
echo "prcheck requires the following dependencies:"
echo "  - gh (GitHub CLI)"
echo "  - jq"
echo "  - jtbl"
echo ""
echo "Install them with: brew install gh jq jtbl"
echo ""
echo "Run 'prcheck --help' to get started."
