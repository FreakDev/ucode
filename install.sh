#!/usr/bin/env bash
# Installation manuelle (sans plugin ni npx skills) du skill delegation-native
# et du sous-agent executant pour Claude Code.
#
# Usage :
#   ./install.sh [options] [chemin_du_projet]   installation dans un projet (par défaut : dossier courant)
#   ./install.sh --global [options]             installation pour l'utilisateur (~/.claude)
#
# Options :
#   --modele <nom>   modèle du sous-agent executant (défaut : haiku)
#   --sans-agent     n'installe que le skill (il créera l'agent à la première utilisation)
#   --force          remplace une installation existante
#   -h, --help       affiche cette aide
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/skills/delegation-native"
GLOBAL=0; FORCE=0; AGENT=1; MODELE="haiku"; CIBLE=""

aide() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --global) GLOBAL=1 ;;
    --force) FORCE=1 ;;
    --sans-agent) AGENT=0 ;;
    --modele) shift; MODELE="${1:?--modele demande une valeur}" ;;
    -h|--help) aide; exit 0 ;;
    -*) echo "Option inconnue : $1" >&2; aide >&2; exit 2 ;;
    *) CIBLE="$1" ;;
  esac
  shift
done

command -v git >/dev/null 2>&1 || { echo "git est requis." >&2; exit 2; }

if [ "$GLOBAL" -eq 1 ]; then
  [ -n "$CIBLE" ] && { echo "--global ne prend pas de chemin de projet." >&2; exit 2; }
  CLAUDE_DIR="$HOME/.claude"
else
  CIBLE="${CIBLE:-$PWD}"
  [ -d "$CIBLE" ] || { echo "Dossier introuvable : $CIBLE" >&2; exit 2; }
  CIBLE="$(cd "$CIBLE" && pwd -P)"
  git -C "$CIBLE" rev-parse --show-toplevel >/dev/null 2>&1 \
    || echo "Attention : $CIBLE n'est pas un dépôt git. Le skill en a besoin pour fonctionner." >&2
  CLAUDE_DIR="$CIBLE/.claude"
fi

AGENT_DEST="$CLAUDE_DIR/agents/executant.md"
SKILL_DEST="$CLAUDE_DIR/skills/delegation-native"

if [ "$FORCE" -eq 0 ] && { [ -e "$SKILL_DEST" ] || { [ "$AGENT" -eq 1 ] && [ -e "$AGENT_DEST" ]; }; }; then
  echo "Une installation existe déjà dans $CLAUDE_DIR. Relance avec --force pour la remplacer." >&2
  exit 1
fi

mkdir -p "$CLAUDE_DIR/skills"
rm -rf "$SKILL_DEST"
cp -R "$SRC" "$SKILL_DEST"
chmod +x "$SKILL_DEST/verifier.sh"
TMP="$(mktemp)"
sed -e "s|^model: .*|model: $MODELE|" "$SRC/executant.md" > "$TMP" && mv "$TMP" "$SKILL_DEST/executant.md"

if [ "$AGENT" -eq 1 ]; then
  mkdir -p "$CLAUDE_DIR/agents"
  cp "$SKILL_DEST/executant.md" "$AGENT_DEST"
fi

if [ "$GLOBAL" -eq 0 ]; then
  GI="$CIBLE/.gitignore"
  if ! { [ -f "$GI" ] && grep -qx '\.delegation/' "$GI"; }; then
    printf '.delegation/\n' >> "$GI"
  fi
fi

echo "Installé dans $CLAUDE_DIR"
echo "  - skill      : $SKILL_DEST"
if [ "$AGENT" -eq 1 ]; then
  echo "  - sous-agent : $AGENT_DEST (modèle : $MODELE)"
else
  echo "  - sous-agent : créé par le skill à la première utilisation (modèle : $MODELE)"
fi
echo "Redémarrez Claude Code pour qu'il prenne en compte le skill et le sous-agent."
