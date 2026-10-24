#!/usr/bin/env bash
# Auto-test du package : installation, puis verifier.sh sur les cas principaux.
# Usage : ./tests/test.sh   (ne touche à rien en dehors d'un dossier temporaire)
set -u
PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
OK=0; KO=0
verifie() { if [ "$2" = "$3" ]; then echo "  ok   $1"; OK=$((OK+1)); else echo "  ÉCHEC $1 (attendu : $3, obtenu : $2)"; KO=$((KO+1)); fi; }

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

echo "Structure du dépôt"
cmp -s "$PKG/agents/executant.md" "$PKG/skills/ucode/executant.md"; verifie "agent du plugin identique à celui du skill" "$?" 0
python3 -c "import json,sys; [json.load(open(f)) for f in sys.argv[1:]]" "$PKG/.claude-plugin/plugin.json" "$PKG/.claude-plugin/marketplace.json"; verifie "plugin.json et marketplace.json valides" "$?" 0
grep -q "DOSSIER_SKILL/verifier.sh" "$PKG/skills/ucode/SKILL.md"; verifie "skill autonome (chemin relatif à son dossier)" "$?" 0
if command -v claude >/dev/null 2>&1; then
  claude plugin validate "$PKG" >/dev/null 2>&1; verifie "claude plugin validate" "$?" 0
fi

echo "Installation dans un dépôt jouet"
REPO="$TMPD/jouet"; mkdir -p "$REPO"; cd "$REPO"
git init -q -b main
printf 'def add(a, b):\n    raise NotImplementedError\n' > calc.py
printf 'from calc import add\nassert add(2, 3) == 5\nprint("ok")\n' > test_calc.py
git add -A && git commit -qm init
"$PKG/install.sh" "$REPO" >/dev/null; verifie "install.sh projet" "$?" 0
[ -f .claude/agents/executant.md ] && [ -x .claude/skills/ucode/verifier.sh ] && [ -x .claude/skills/ucode/executant-pi.sh ]; verifie "fichiers installés" "$?" 0
[ -f .claude/skills/ucode/executant.md ]; verifie "modèle de l'agent embarqué dans le skill" "$?" 0
grep -qx '\.ucode/' .gitignore; verifie ".gitignore mis à jour" "$?" 0
"$PKG/install.sh" "$REPO" >/dev/null 2>&1; verifie "refus sans --force" "$?" 1
"$PKG/install.sh" --force --modele sonnet "$REPO" >/dev/null; grep -q '^model: sonnet$' .claude/agents/executant.md && grep -q '^model: sonnet$' .claude/skills/ucode/executant.md; verifie "option --modele" "$?" 0
REPO2="$TMPD/jouet2"; mkdir -p "$REPO2"; git -C "$REPO2" init -q
"$PKG/install.sh" --sans-agent "$REPO2" >/dev/null && [ ! -e "$REPO2/.claude/agents/executant.md" ] && [ -f "$REPO2/.claude/skills/ucode/executant.md" ]; verifie "option --sans-agent" "$?" 0
git add -A && git commit -qm "install"

V="$REPO/.claude/skills/ucode/verifier.sh"
BASE=$(git rev-parse HEAD)
WT="$TMPD/wt"; git worktree add -q -b deleg/add "$WT" HEAD
TESTS="python3 test_calc.py"

echo "Vérification"
"$V" "$REPO" "$BASE" calc.py "$TESTS" >/dev/null; verifie "refus du dépôt principal" "$?" 2
"$V" "$WT" "$BASE" calc.py "$TESTS" | grep -q "STATUT: tests_en_echec"; verifie "tests en échec détectés" "$?" 0
printf 'def add(a, b):\n    return a + b\n' > "$WT/calc.py"
"$V" "$WT" "$BASE" calc.py "$TESTS" >/dev/null; verifie "succès" "$?" 0
echo "x" > "$WT/autre.txt"
"$V" "$WT" "$BASE" "calc.py" "$TESTS" | grep -q "HORS_PERIMETRE: autre.txt"; verifie "fichier non suivi hors périmètre" "$?" 0
rm "$WT/autre.txt"
[ -d "$WT/__pycache__" ]; verifie "cache généré par les tests (présent)" "$?" 0
"$V" "$WT" "$BASE" calc.py "$TESTS" >/dev/null; verifie "cache ignoré" "$?" 0
echo "log" > "$WT/run.log"
VERIFIER_IGNORER="*.log" "$V" "$WT" "$BASE" calc.py "$TESTS" >/dev/null; verifie "VERIFIER_IGNORER" "$?" 0
rm "$WT/run.log"
printf 'print("ok")\n' > "$WT/test_calc.py"
"$V" "$WT" "$BASE" calc.py "$TESTS" | grep -q "STATUT: perimetre_viole"; verifie "test modifié détecté" "$?" 0
git -C "$WT" checkout -q test_calc.py
git -C "$WT" add -- calc.py && git -C "$WT" commit -qm "add"
"$V" "$WT" "$BASE" "calc.py, test_calc.py" "$TESTS" >/dev/null; verifie "changements commités + liste avec espaces" "$?" 0
"$V" "$WT" "$BASE" calc.py "sleep 5" 1 | grep -q "STATUT: delai_depasse"; verifie "délai dépassé" "$?" 0
git -C "$WT" add -f __pycache__ && git -C "$WT" commit -qm "cache commité par erreur"
"$V" "$WT" "$BASE" calc.py "$TESTS" >/dev/null; verifie "cache commité ignoré" "$?" 0
"$V" "$WT" "deadbeef" calc.py "$TESTS" >/dev/null; verifie "base introuvable" "$?" 2

echo "Installation globale (HOME temporaire)"
HOME="$TMPD/home" "$PKG/install.sh" --global >/dev/null; verifie "install.sh --global" "$?" 0
[ -f "$TMPD/home/.claude/skills/ucode/SKILL.md" ]; verifie "skill global présent" "$?" 0
HOME="$TMPD/home" "$PKG/uninstall.sh" --global >/dev/null
[ ! -e "$TMPD/home/.claude/skills/ucode" ]; verifie "désinstallation globale" "$?" 0

echo; echo "$OK réussis, $KO échoués"
[ "$KO" -eq 0 ]
