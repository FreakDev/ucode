#!/usr/bin/env bash
# Auto-test de executant-pi.sh, avec de faux pi et curl (ni pi ni colibri ne sont nécessaires).
# Usage : ./tests/test_executant_pi.sh
set -u
PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
E="$PKG/skills/ucode/executant-pi.sh"
TMPD="$(mktemp -d)"; TMPD="$(cd "$TMPD" && pwd -P)"; trap 'rm -rf "$TMPD"' EXIT
OK=0; KO=0
verifie() { if [ "$2" = "$3" ]; then echo "  ok   $1"; OK=$((OK+1)); else echo "  ÉCHEC $1 (attendu : $3, obtenu : $2)"; KO=$((KO+1)); fi; }

# Faux binaires
mkdir -p "$TMPD/bin" "$TMPD/trace" "$TMPD/wt"
cat > "$TMPD/bin/curl" <<'EOF'
#!/usr/bin/env bash
[ "${FAUX_COLIBRI:-}" = "absent" ] && exit 7
echo '{"object":"list","data":[{"id":"qwen3.6-colibri","object":"model"}]}'
EOF
cat > "$TMPD/bin/pi" <<'EOF'
#!/usr/bin/env bash
T="$FAUX_TRACE"
pwd -P > "$T/cwd"
printf '%s\n' "$@" > "$T/args"
echo "$PI_CODING_AGENT_DIR" > "$T/confdir"
cp "$PI_CODING_AGENT_DIR/models.json" "$T/models.json" 2>/dev/null
echo "${PI_OFFLINE:-}" > "$T/offline"
[ -n "${FAUX_PI_DORT:-}" ] && sleep "$FAUX_PI_DORT"
echo "fini"
exit "${FAUX_PI_CODE:-0}"
EOF
chmod +x "$TMPD/bin/curl" "$TMPD/bin/pi"
export PATH="$TMPD/bin:$PATH" FAUX_TRACE="$TMPD/trace"
unset UCODE_PI_URL UCODE_PI_MODELE UCODE_PI_BIN
WT="$TMPD/wt"; SPEC="$TMPD/spec.md"; printf 'WORKTREE : %s\nOBJECTIF : test\n' "$WT" > "$SPEC"

echo "Erreurs d'usage"
"$E" >/dev/null 2>&1; verifie "sans argument" "$?" 2
"$E" "$TMPD/absent" "$SPEC" >/dev/null 2>&1; verifie "worktree introuvable" "$?" 2
"$E" "$WT" "$TMPD/absent.md" >/dev/null 2>&1; verifie "spec introuvable" "$?" 2

echo "Disponibilité"
UCODE_PI_BIN=pi-introuvable "$E" "$WT" "$SPEC" >/dev/null 2>&1; verifie "pi introuvable" "$?" 3
UCODE_PI_BIN=pi-introuvable "$E" --sonder >/dev/null 2>&1; verifie "sonde : pi introuvable" "$?" 3
FAUX_COLIBRI=absent "$E" "$WT" "$SPEC" >/dev/null 2>&1; verifie "colibri injoignable" "$?" 4
UCODE_PI_MODELE=autre-modele "$E" --sonder >/dev/null 2>&1; verifie "modèle absent de colibri" "$?" 4
"$E" --sonder >/dev/null 2>&1; verifie "sonde OK" "$?" 0
[ ! -e "$TMPD/trace/args" ]; verifie "pi non lancé par les sondes et refus" "$?" 0

echo "Lancement nominal"
SORTIE=$(cd "$TMPD" && "$E" wt spec.md 2>/dev/null); CODE=$?
verifie "code de sortie" "$CODE" 0
printf '%s' "$SORTIE" | grep -q "fini"; verifie "sortie de pi relayée" "$?" 0
verifie "pi lancé dans le worktree" "$(cat "$TMPD/trace/cwd")" "$WT"
grep -qx -- "-p" "$TMPD/trace/args"; verifie "mode non interactif (-p)" "$?" 0
grep -qx -- "--no-session" "$TMPD/trace/args"; verifie "--no-session" "$?" 0
grep -A1 -x -- "--model" "$TMPD/trace/args" | tail -n1 | grep -qx "colibri/qwen3.6-colibri"; verifie "--model colibri/qwen3.6-colibri" "$?" 0
SPEC_PI="$SPEC"; command -v cygpath >/dev/null 2>&1 && SPEC_PI="$(cygpath -m "$SPEC")"
grep -qx -- "@$SPEC_PI" "$TMPD/trace/args"; verifie "spec passée en chemin absolu (@)" "$?" 0
grep -q "Tu es un exécutant" "$TMPD/trace/args"; verifie "consignes de executant.md en prompt système" "$?" 0
grep -q "maxTurns" "$TMPD/trace/args"; verifie "frontmatter exclu des consignes" "$?" 1
grep -q '"http://127.0.0.1:8000/v1"' "$TMPD/trace/models.json"; verifie "models.json : URL par défaut" "$?" 0
grep -q '"openai-completions"' "$TMPD/trace/models.json"; verifie "models.json : API openai-completions" "$?" 0
grep -q '"qwen3.6-colibri"' "$TMPD/trace/models.json"; verifie "models.json : modèle" "$?" 0
verifie "PI_OFFLINE=1" "$(cat "$TMPD/trace/offline")" 1
[ ! -e "$(cat "$TMPD/trace/confdir")" ]; verifie "configuration temporaire supprimée" "$?" 0

echo "Options"
UCODE_PI_URL="http://192.168.1.5:9000/v1" "$E" "$WT" "$SPEC" >/dev/null 2>&1
grep -q '"http://192.168.1.5:9000/v1"' "$TMPD/trace/models.json"; verifie "UCODE_PI_URL" "$?" 0
FAUX_PI_CODE=5 "$E" "$WT" "$SPEC" >/dev/null 2>&1; verifie "code de sortie de pi propagé" "$?" 5
if command -v timeout >/dev/null 2>&1; then
  SORTIE=$(FAUX_PI_DORT=5 "$E" "$WT" "$SPEC" 1 2>/dev/null); CODE=$?
  verifie "délai dépassé" "$CODE" 124
  printf '%s' "$SORTIE" | grep -q "STATUT_EXECUTANT: delai_depasse"; verifie "statut délai dépassé affiché" "$?" 0
fi

echo; echo "$OK réussis, $KO échoués"
[ "$KO" -eq 0 ]
