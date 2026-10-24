#!/usr/bin/env bash
# Lance l'exécutant avec pi coding agent, sur un modèle local servi par colibri.
# Usage :
#   executant-pi.sh --sonder                                  vérifie que pi et colibri sont disponibles
#   executant-pi.sh <worktree> <fichier_spec> [delai_secondes]  implémente la tâche décrite dans la spec
# Variables : UCODE_PI_URL (défaut http://127.0.0.1:8000/v1), UCODE_PI_MODELE (défaut qwen3.6-colibri),
#             UCODE_PI_BIN (défaut pi).
# Codes de sortie : 0 succès, 2 erreur d'usage, 3 pi introuvable, 4 colibri injoignable ou modèle absent,
#                   124 délai dépassé, sinon le code de sortie de pi.
set -u

URL="${UCODE_PI_URL:-http://127.0.0.1:8000/v1}"
MODELE="${UCODE_PI_MODELE:-qwen3.6-colibri}"
PI="${UCODE_PI_BIN:-pi}"
DOSSIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Vérifie que pi est installé et que colibri répond avec le modèle demandé.
sonder() {
  if ! command -v "$PI" >/dev/null 2>&1; then
    echo "ERREUR: pi introuvable (installez-le : npm install -g @mariozechner/pi-coding-agent)" >&2
    exit 3
  fi
  local reponse
  if ! reponse=$(curl -fsS -m 5 "$URL/models") || ! printf '%s' "$reponse" | grep -qF "\"$MODELE\""; then
    echo "ERREUR: colibri injoignable sur $URL ou modèle $MODELE absent" >&2
    exit 4
  fi
}

# Mode sonde : --sonder
if [ "$#" -eq 1 ] && [ "$1" = "--sonder" ]; then
  sonder
  echo "OK: pi et $MODELE disponibles sur $URL"
  exit 0
fi

# Mode exécution : <worktree> <fichier_spec> [delai_secondes]
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage : executant-pi.sh --sonder" >&2
  echo "        executant-pi.sh <worktree> <fichier_spec> [delai_secondes]" >&2
  exit 2
fi
if [ ! -d "$1" ]; then
  echo "ERREUR: worktree introuvable (pas un dossier) : $1" >&2
  exit 2
fi
if [ ! -f "$2" ]; then
  echo "ERREUR: fichier spec introuvable : $2" >&2
  exit 2
fi

WT="$(cd "$1" && pwd -P)"
SPEC="$(cd "$(dirname "$2")" && pwd -P)/$(basename "$2")"
DELAI="${3:-1800}"

sonder

CONF="$(mktemp -d)"
trap 'rm -rf "$CONF"' EXIT

cat > "$CONF/models.json" <<EOF
{"providers":{"colibri":{"baseUrl":"$URL","api":"openai-completions","apiKey":"colibri","compat":{"supportsDeveloperRole":false,"supportsReasoningEffort":false},"models":[{"id":"$MODELE"}]}}}
EOF

# Consignes : contenu de executant.md après le frontmatter (après la 2e ligne ---)
CONSIGNES="$(awk 'n>=2{print} /^---$/{n++}' "$DOSSIER/executant.md")"

# Délai : timeout si disponible (Git Bash fournit timeout avec coreutils)
if command -v timeout >/dev/null 2>&1; then TO="timeout $DELAI"; else TO=""; fi

# Pas d'exec : le trap doit pouvoir supprimer la configuration temporaire.
(cd "$WT" && PI_CODING_AGENT_DIR="$CONF" PI_OFFLINE=1 $TO "$PI" -p --no-session --no-extensions --no-skills --no-prompt-templates --no-context-files --tools read,edit,write,bash,grep,find,ls --model "colibri/$MODELE" --append-system-prompt "$CONSIGNES" "@$SPEC" "Implémente la tâche décrite dans cette spec." < /dev/null)
CODE=$?

if [ "$CODE" -eq 124 ]; then
  echo "STATUT_EXECUTANT: delai_depasse"
fi
exit "$CODE"
