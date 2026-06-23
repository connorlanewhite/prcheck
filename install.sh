#!/usr/bin/env bash
set -euo pipefail

# prcheck installer
# Downloads and installs prcheck to ~/.local/bin

INSTALL_DIR="${HOME}/.local/bin"
INSTALL_ZSH_COMPLETION="ask"

print_usage() {
  cat <<EOF
Usage: install.sh [options]

Options:
  --with-zsh-completion     Install prcheck zsh completion after installing prcheck
  --without-zsh-completion  Do not ask to install zsh completion
  -h, --help                Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-zsh-completion|--install-zsh-completion)
      INSTALL_ZSH_COMPLETION=true
      shift
      ;;
    --without-zsh-completion|--no-zsh-completion)
      INSTALL_ZSH_COMPLETION=false
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      print_usage >&2
      exit 1
      ;;
  esac
done

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

if [ "$INSTALL_ZSH_COMPLETION" = "ask" ]; then
  INSTALL_ZSH_COMPLETION=false
  if command -v zsh >/dev/null 2>&1; then
    if [[ "${SHELL:-}" == */zsh ]] || [ -f "${HOME}/.zshrc" ]; then
      REPLY=""
      if { printf "Install zsh completion for prcheck? [y/N] " > /dev/tty && read -r REPLY < /dev/tty; } 2>/dev/null; then
        case "$REPLY" in
          [Yy]|[Yy][Ee][Ss]) INSTALL_ZSH_COMPLETION=true ;;
        esac
      fi
    fi
  fi
fi

if [ "$INSTALL_ZSH_COMPLETION" = true ]; then
  if ! "${INSTALL_DIR}/prcheck" --install-zsh-completion; then
    echo "Warning: Failed to install zsh completion. Run 'prcheck --install-zsh-completion' after install." >&2
  fi
fi

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
echo ""
echo "Install them with:"
echo "  brew install gh jq"
echo ""
echo "Run 'prcheck --help' to get started."
