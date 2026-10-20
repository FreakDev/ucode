#!/usr/bin/env bash
# Désinstalle le skill delegation-native et le sous-agent executant.
# Usage : ./uninstall.sh [chemin_du_projet]   ou   ./uninstall.sh --global
set -euo pipefail

if [ "${1:-}" = "--global" ]; then
  CLAUDE_DIR="$HOME/.claude"
else
  CLAUDE_DIR="$(cd "${1:-$PWD}" && pwd -P)/.claude"
fi

rm -f "$CLAUDE_DIR/agents/executant.md"
rm -rf "$CLAUDE_DIR/skills/delegation-native"
echo "Désinstallé de $CLAUDE_DIR (le journal .delegation/ et le .gitignore sont laissés en place)."
