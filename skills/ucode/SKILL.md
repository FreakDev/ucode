---
name: ucode
description: Découper le travail d'implémentation et le déléguer à un sous-agent sur un petit modèle, dans des worktrees git, avec contrôles déterministes. À utiliser dès qu'une tâche d'implémentation dépasse quelques lignes.
---

# Délégation native à un petit modèle

Tu es l'architecte. Tu conçois, découpes, spécifies et vérifies. Le sous-agent exécutant (petit modèle) implémente.
Par défaut, tu délègues. Tu ne gardes pour toi que ce qui ne peut pas être découpé : architecture, interfaces entre modules, points vraiment délicats (sécurité, concurrence, migrations de données, logique métier subtile).

Écueil à éviter : faire le travail toi-même parce que c'est plus rapide sur le moment. La question n'est pas « est-ce que je délègue ? » mais « comment je découpe pour rendre ça déléguable ? ».

Dans ce document, DOSSIER_SKILL désigne le dossier qui contient ce fichier SKILL.md (son chemin absolu t'est indiqué au chargement du skill). Il contient aussi `executant.md`, `executant-pi.sh` et `verifier.sh`.

## 0. Amorçage (une fois par session, avant la première délégation)

1. **Exécutant pi (prioritaire).** Lance `bash "DOSSIER_SKILL/executant-pi.sh" --sonder`. S'il affiche `OK`, l'exécutant est pi coding agent sur le modèle local servi par colibri : tu le lanceras avec `executant-pi.sh` (section 3). Passe à l'étape 4. Sinon (code 3 : pi absent ; code 4 : colibri injoignable ou modèle absent), dis-le à l'utilisateur en une phrase et continue avec un exécutant Claude (étapes 2 et 3).
2. **Trouver l'exécutant Claude.** Si un sous-agent nommé `ucode:executant` (installation en plugin) ou `executant` figure parmi tes sous-agents disponibles, c'est lui que tu lanceras. Passe à l'étape 4.
3. **Sinon, le créer (installation en skill seul).**
   - Si `.claude/agents/executant.md` n'existe pas à la racine du dépôt, dis à l'utilisateur en une phrase que tu crées le sous-agent du skill, puis copie `DOSSIER_SKILL/executant.md` vers `.claude/agents/executant.md` (crée le dossier si besoin).
   - Un sous-agent créé en cours de session n'est chargé qu'à la session suivante. D'ici là, utilise le **mode de repli** : lance un sous-agent généraliste en forçant le modèle `haiku`, et place en tête de son prompt les consignes de `DOSSIER_SKILL/executant.md` (le texte situé après le frontmatter), suivies de la spec.
4. **Journal.** Si `.ucode/` n'est pas dans le `.gitignore` du dépôt, ajoute-le.

## 1. Méthode

1. Comprends la demande et conçois l'architecture.
2. Fixe les interfaces : signatures, types, structures de données. Écris-les toi-même dans le code (stubs).
3. Découpe en tâches de la taille d'une fonction ou d'un petit module, chacune indépendante et testable.
4. Pour chaque tâche, écris d'abord les tests. Ils sont le critère d'acceptation.
5. Délègue chaque tâche selon la routine ci-dessous.
6. Vérifie de façon déterministe, relis, puis fusionne ou abandonne.

Ne découpe pas trop finement : si écrire la spec coûte plus cher que coder, fais-le toi-même.

## 2. Routine git par tâche

Avant de déléguer (stubs et tests compris dans le commit) :

    git add -A && git commit -m "Stubs et tests pour <tache>"
    BASE=$(git rev-parse HEAD)
    RACINE=$(git rev-parse --show-toplevel)
    git worktree add -b deleg/<tache> "$RACINE/../.deleg-$(basename "$RACINE")-<tache>" HEAD

Utilise toujours le chemin absolu du worktree. Note la valeur de BASE : la vérification en a besoin.

Après une vérification réussie et ta relecture :

    git -C <worktree> add -- <fichiers autorisés> && git -C <worktree> commit -m "<tache> (déléguée)"
    git merge --no-ff deleg/<tache>

N'utilise pas `git add -A` dans le worktree : seuls les fichiers autorisés doivent entrer dans le commit, jamais les caches ou artefacts produits par les tests.

Dans tous les cas, ensuite :

    git worktree remove --force <worktree> && git branch -D deleg/<tache>

## 3. Lancer l'exécutant

Lance l'exécutant (étape 0) avec cette spec. Il est petit : il ne doit jamais avoir à deviner ni à explorer.

    WORKTREE : chemin absolu du worktree (jamais le dépôt principal)
    OBJECTIF : une ou deux phrases concrètes, un seul objectif
    FICHIERS AUTORISÉS : liste exhaustive, chemins relatifs au worktree
    FICHIERS DE CONTEXTE : chemins absolus à lire (interfaces, types, exemples voisins). Donne des références, ne recopie pas le contenu.
    CONTRAT : signatures exactes, entrées, sorties, erreurs attendues
    COMMANDE DE TESTS : la commande qui doit passer, lancée depuis la racine du worktree
    CONTRAINTES : style, bibliothèques autorisées ou interdites

### Avec pi (exécutant prioritaire)

Écris la spec dans `.ucode/specs/<tache>.md` à la racine du dépôt principal (ignoré par git), puis lance, de préférence en arrière-plan car un modèle local est lent :

    bash "DOSSIER_SKILL/executant-pi.sh" <worktree> <chemin absolu de la spec> [délai_secondes, défaut 1800]

Le script lance pi en mode non interactif dans le worktree, avec les consignes de `executant.md` en prompt système et une configuration temporaire (`UCODE_PI_URL`, `UCODE_PI_MODELE`). Sa sortie est le compte rendu de pi ; `STATUT_EXECUTANT: delai_depasse` et le code 124 signalent un délai dépassé. Comme pour tout exécutant, seule la vérification (section 4) fait foi.

Colibri sert généralement une requête à la fois : lance les tâches pi l'une après l'autre, sauf si tu sais que le serveur en traite plusieurs en parallèle.

### Avec un sous-agent Claude

Lance le sous-agent trouvé à l'étape 0 avec la même spec dans son prompt.

Des tâches indépendantes, dans des worktrees séparés et avec des interfaces déjà fixées, peuvent être lancées en parallèle.

## 4. Vérification déterministe

Ne te fie jamais au compte rendu de l'exécutant. Lance toujours :

    bash "DOSSIER_SKILL/verifier.sh" <worktree> <BASE> "<fichier1,fichier2>" "<commande de tests>"

Les caches courants générés par les tests (`__pycache__`, `.pytest_cache`, `node_modules`…) sont ignorés, en plus du `.gitignore` du projet. Si les tests du projet produisent d'autres fichiers, ajoute-les au `.gitignore` avant de déléguer, ou passe-les via la variable `VERIFIER_IGNORER="motif1 motif2"`.

Le script donne le statut (succes, tests_en_echec, perimetre_viole, delai_depasse ou refus), les fichiers réellement modifiés (via git), les fichiers hors périmètre et la fin de la sortie des tests.

Seulement si le statut est `succes`, relis le code avec `git -C <worktree> diff <BASE>` et vérifie :
- le code respecte le contrat et reste cohérent avec l'architecture ;
- pas de raccourci suspect (cas codé en dur, exception avalée, test contourné).

## 5. Escalade (3 tentatives maximum par tâche)

- Erreur ponctuelle (cas limite, nom, détail) : relance un exécutant dans le même worktree, avec la spec et un retour ciblé (ligne concernée, sortie des tests, comportement attendu).
- Périmètre violé : abandonne le worktree, recrée-le, relance en rappelant explicitement la liste des fichiers autorisés.
- Délai dépassé : la tâche est probablement trop grosse ; redécoupe-la.
- Erreur de compréhension (mauvaise direction) : la spec est ambiguë. Abandonne le worktree, réécris la spec, relance une tâche neuve.
- Tâche trop grosse (réussite partielle) : garde ce qui marche, redécoupe le reste en tâches plus petites.
- Tâche trop subtile : fais-la toi-même, en dernier recours seulement.

## 6. Journal

Après chaque tâche terminée, ajoute une ligne JSON à `.ucode/journal.jsonl` à la racine du dépôt principal :

    {"date": "...", "tache": "...", "executant": "<pi|plugin|agent-projet|repli>-<modèle>", "nb_fichiers_autorises": 0, "tentatives": 0, "statut_final": "succes|abandon", "type_echec": "aucun|ponctuel|perimetre|delai|comprehension|trop_gros|trop_subtil", "reprise_par_orchestrateur": false}

## 7. Hygiène git

Avant de terminer ta session, lance `git worktree list` et supprime tout worktree et toute branche `deleg/` restants.
