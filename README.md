# delegation-native

Variante « skill seul » de l'agent de code délégué. Claude Code (gros modèle) conçoit, découpe, écrit les tests et vérifie. Un sous-agent `executant`, sur un petit modèle (Haiku par défaut), implémente chaque tâche dans un worktree git isolé. Un script vérifie le résultat de façon déterministe : fichiers réellement modifiés via git, périmètre, tests relancés.

Aucun serveur, aucune dépendance en dehors de git et bash.

## Structure

```
.claude-plugin/plugin.json          manifeste du plugin Claude Code
.claude-plugin/marketplace.json     marketplace (ce dépôt est sa propre marketplace)
agents/executant.md                 sous-agent fourni par le plugin
skills/delegation-native/
  SKILL.md                          méthode de l'orchestrateur
  executant.md                      modèle du sous-agent (amorçage hors plugin)
  verifier.sh                       vérification déterministe
install.sh / uninstall.sh           installation manuelle
tests/test.sh                       auto-test
```

`agents/executant.md` et `skills/delegation-native/executant.md` doivent rester identiques ; l'auto-test le vérifie.

## Installation

Trois façons, de la plus complète à la plus légère.

### 1. Plugin Claude Code (recommandé)

Depuis le dépôt publié sur GitHub :

```
/plugin marketplace add FreakDev/ucode
/plugin install delegation-native@delegation-native
```

Ou en ligne de commande, y compris depuis un clone local :

```bash
claude plugin marketplace add /chemin/vers/delegation-native
claude plugin install delegation-native@delegation-native              # pour l'utilisateur
claude plugin install delegation-native@delegation-native --scope project
```

Le plugin fournit le skill et le sous-agent `delegation-native:executant`, avec sa limite de tours.

### 2. npx skills

```bash
npx skills add FreakDev/ucode          # dans le projet
npx skills add FreakDev/ucode -g       # global
```

Seul le skill est installé. À la première utilisation, il crée `.claude/agents/executant.md` dans le projet (en le signalant). Pendant cette première session, il lance un sous-agent généraliste forcé sur Haiku avec les mêmes consignes ; l'agent dédié prend le relais à la session suivante.

### 3. Script d'installation

```bash
./install.sh /chemin/vers/mon-projet          # dans un projet
./install.sh --global                         # pour l'utilisateur (~/.claude)
./install.sh --modele sonnet <projet>         # autre modèle pour l'exécutant
./install.sh --sans-agent <projet>            # skill seul, agent créé au premier usage
./install.sh --force <projet>                 # remplacer une installation existante
./uninstall.sh <projet>    |    ./uninstall.sh --global
```

Redémarrez Claude Code après l'installation.

## Utilisation

Dans Claude Code, sur un dépôt git propre :

> Utilise le skill delegation-native pour implémenter <fonctionnalité>.

Claude fixe les interfaces, écrit les tests, crée un worktree par tâche, lance l'exécutant, vérifie avec `verifier.sh`, relit, puis fusionne ou abandonne. Chaque tâche est journalisée dans `.delegation/journal.jsonl`, que le skill ajoute au `.gitignore`.

### verifier.sh seul

```bash
skills/delegation-native/verifier.sh <worktree> <commit_base> "<fichier1,fichier2>" "<commande de tests>" [délai_secondes]
```

Sortie : `STATUT` (succes, tests_en_echec, perimetre_viole, delai_depasse, refus), fichiers réellement modifiés, fichiers hors périmètre, fin de la sortie des tests. Code de sortie 0 en cas de succès, 1 en cas d'échec, 2 en cas de refus.

Les caches de tests courants (`__pycache__`, `.pytest_cache`, `node_modules`…) sont ignorés ; d'autres motifs s'ajoutent avec `VERIFIER_IGNORER="*.log build"`.

## Prérequis

- Claude Code
- git 2.5 ou plus récent, bash
- Linux ou macOS (sous macOS, `brew install coreutils` active le délai maximal des tests via `gtimeout`)

## Tests

```bash
./tests/test.sh
```

Travaille dans un dossier temporaire. Lance aussi `claude plugin validate` si Claude Code est installé.

## Limites connues

- Le sous-agent partage la session : rien ne l'empêche techniquement de sortir du worktree ; seul le contrôle après coup le détecte.
- Les vérifications consomment du contexte de l'orchestrateur.
- Pas de métriques fines par tâche (tokens, durée) : seul le coût global de la session est disponible.
- En mode de repli (première session sans plugin), pas de limite de tours pour l'exécutant.
- Les noms de fichiers contenant des espaces ne sont pas gérés par `verifier.sh`.
