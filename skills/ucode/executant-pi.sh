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

echo "STATUT_EXECUTANT: non_implemente"
exit 99
