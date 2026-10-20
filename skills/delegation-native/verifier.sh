#!/usr/bin/env bash
# Vérification déterministe d'une tâche déléguée.
# Usage : verifier.sh <worktree> <commit_base> <fichiers_autorises separes par des virgules> <commande_tests> [delai_secondes]
# Codes de sortie : 0 succes, 1 echec (tests, perimetre ou delai), 2 refus ou erreur d'usage.
set -u

if [ "$#" -lt 4 ]; then
  echo "Usage : verifier.sh <worktree> <commit_base> <fichiers_autorises> <commande_tests> [delai_secondes]" >&2
  exit 2
fi

WT="$1"; BASE="$2"; AUTORISES="$(printf '%s' "$3" | tr -d ' ')"; TESTS="$4"; DELAI="${5:-600}"

# 1. Le chemin doit etre un worktree secondaire, jamais le depot principal
if ! GIT_DIR_ABS=$(git -C "$WT" rev-parse --absolute-git-dir 2>/dev/null); then
  echo "STATUT: refus (pas un depot git : $WT)"; exit 2
fi
GIT_DIR_ABS=$(cd "$GIT_DIR_ABS" && pwd -P)
COMMON_DIR=$(cd "$WT" && cd "$(git rev-parse --git-common-dir)" && pwd -P)
if [ "$GIT_DIR_ABS" = "$COMMON_DIR" ]; then
  echo "STATUT: refus (depot principal, pas un worktree)"; exit 2
fi
if ! git -C "$WT" rev-parse --verify --quiet "$BASE^{commit}" >/dev/null; then
  echo "STATUT: refus (commit de base introuvable : $BASE)"; exit 2
fi

# 2. Fichiers reellement modifies : suivis (par rapport a BASE, commits compris) + nouveaux non suivis.
#    Les artefacts generes par les tests (caches) sont ignores, en plus du .gitignore du projet.
#    Motifs supplementaires possibles via VERIFIER_IGNORER="motif1 motif2".
IGNORES="__pycache__ *.pyc .pytest_cache .mypy_cache .ruff_cache .tox .coverage node_modules ${VERIFIER_IGNORER:-}"
set -f
# Vrai si un des elements du chemin correspond a un motif ignore
est_ignore() {
  local comp m parts
  IFS=/ read -ra parts <<< "$1"
  for comp in "${parts[@]}"; do
    for m in $IGNORES; do
      case "$comp" in $m) return 0 ;; esac
    done
  done
  return 1
}
MODIFIES=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  est_ignore "$f" || MODIFIES="$MODIFIES $f"
done < <( { git -C "$WT" diff --name-only "$BASE"; git -C "$WT" ls-files --others --exclude-standard; } | sort -u )
HORS=""
for f in $MODIFIES; do
  case ",$AUTORISES," in *",$f,"*) ;; *) HORS="$HORS $f" ;; esac
done
set +f

# 3. Tests relances ici, independamment de l'executant
if command -v timeout >/dev/null 2>&1; then TO="timeout $DELAI"
elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout $DELAI"
else TO=""; fi
SORTIE=$(cd "$WT" && $TO bash -c "$TESTS" 2>&1); CODE=$?

if [ -n "$HORS" ]; then STATUT="perimetre_viole"
elif [ -n "$TO" ] && [ "$CODE" -eq 124 ]; then STATUT="delai_depasse"
elif [ "$CODE" -ne 0 ]; then STATUT="tests_en_echec"
else STATUT="succes"; fi

echo "STATUT: $STATUT"
echo "FICHIERS_MODIFIES: $(echo $MODIFIES)"
echo "HORS_PERIMETRE:${HORS:- aucun}"
echo "CODE_TESTS: $CODE"
echo "--- FIN DE SORTIE DES TESTS ---"
printf '%s\n' "$SORTIE" | tail -n 40

[ "$STATUT" = "succes" ] && exit 0 || exit 1
