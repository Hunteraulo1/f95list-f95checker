#!/usr/bin/env bash
# Equivalent Linux du launcher F95Checker-France.bat
# Usage: ./f95checker-france.sh [reconfigure|setup-only]
#
# Ce script lit F95Checker-France.bat (doit etre dans le meme dossier),
# en extrait les blocs Python embarques, puis installe/lance F95Checker
# avec le patch France, exactement comme le fait le .bat sous Windows.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BAT_FILE="$SCRIPT_DIR/F95Checker-France.bat"
RUNTIME="$SCRIPT_DIR/._f95_france_cache"
SRCDIR="$SCRIPT_DIR/F95Checker-src"
REPO="https://github.com/WillyJL/F95Checker.git"

EXTRA=""
DO_LAUNCH=1
case "${1:-}" in
    reconfigure|--reconfigure)
        EXTRA="--reconfigure"
        DO_LAUNCH=0
        ;;
    setup-only)
        EXTRA="--setup-only"
        DO_LAUNCH=0
        ;;
esac

if [[ ! -f "$BAT_FILE" ]]; then
    echo "Erreur : F95Checker-France.bat introuvable dans $SCRIPT_DIR" >&2
    exit 1
fi

# Choix de l'interpreteur Python systeme (3.11+ requis), uniquement pour creer le venv
SYSPY=""
for cand in python3.12 python3.11 python3; do
    if command -v "$cand" >/dev/null 2>&1; then
        SYSPY="$cand"
        break
    fi
done
if [[ -z "$SYSPY" ]]; then
    echo "Python 3.11+ requis. Installe-le via ton gestionnaire de paquets (ex: sudo pacman -S python)." >&2
    exit 1
fi

# venv dedie : sur Arch/CachyOS (et toute distro PEP 668), pip install refuse
# d'ecrire dans le python systeme ("externally-managed-environment"). On passe
# donc par un venv local pour que l'installation des dependances fonctionne.
VENV="$SCRIPT_DIR/.venv"
if [[ ! -x "$VENV/bin/python" ]]; then
    echo "Creation de l'environnement virtuel Python ($VENV)..."
    "$SYSPY" -m venv "$VENV"
fi
PY="$VENV/bin/python"
export PATH="$VENV/bin:$PATH"

mkdir -p "$RUNTIME"

# Extraction des blocs embarques @@BEGIN_xxx@@ ... @@END_xxx@@ depuis le .bat
extract_block() {
    local begin_marker="$1"
    local end_marker="$2"
    local out_file="$3"
    awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin { grabbing=1; next }
        $0 == end   { grabbing=0 }
        grabbing   { print }
    ' "$BAT_FILE" > "$out_file"
    if [[ ! -s "$out_file" ]]; then
        echo "Erreur : bloc $begin_marker introuvable ou vide dans le .bat" >&2
        exit 1
    fi
}

extract_block "@@BEGIN_SETUP_FRANCE@@" "@@END_SETUP_FRANCE@@" "$RUNTIME/setup_france.py"
extract_block "@@BEGIN_FRANCE_LABELS@@" "@@END_FRANCE_LABELS@@" "$RUNTIME/france_labels.py"
extract_block "@@BEGIN_FRANCE_ICON@@" "@@END_FRANCE_ICON@@" "$RUNTIME/france_icon.py"
extract_block "@@BEGIN_LC_GAMES@@" "@@END_LC_GAMES@@" "$RUNTIME/lc_games.py"
# Le lanceur silencieux (.vbs) est Windows-only, pas necessaire sous Linux.

echo
echo "=== F95Checker France (Linux) ==="
echo

"$PY" "$RUNTIME/setup_france.py" $EXTRA

if [[ "$DO_LAUNCH" == "0" ]]; then
    exit 0
fi

if [[ ! -f "$SRCDIR/main.py" ]]; then
    echo "F95Checker-src manquant. Relance ce script avec Internet/Git disponible." >&2
    exit 1
fi

if ! "$PY" -m py_compile "$SRCDIR/modules/gui.py" 2>/dev/null; then
    echo "gui.py invalide. Relance ce script pour reparer le patch." >&2
    exit 1
fi

echo
echo "Lancement de F95Checker..."
# Lancement detache, sans bloquer le terminal (equivalent du silent_launch.vbs)
setsid "$PY" "$SRCDIR/main.py" >/dev/null 2>&1 < /dev/null &
disown
echo "F95Checker demarre en arriere-plan."
