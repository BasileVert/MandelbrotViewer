#!/usr/bin/env bash

# ========= Paramètres de base =========
W=${1:-160}        # largeur en caractères
H=${2:-48}         # hauteur en lignes
MAX_ITER=${3:-800} # itérations Mandelbrot (monter pour plus de détails)
RENDER_BIN=${RENDER_BIN:-./mandelbrot_render}

# Centre initial (classique du Mandelbrot)
CENTER_X=-0.75
CENTER_Y=0.0

# Taille initiale de la fenêtre (demi-largeur en X)
ZOOM=1.5

# Facteurs de zoom (Espace / Backspace)
ZOOM_IN_FACTOR=0.8     # plus petit -> zoom plus fort
ZOOM_OUT_FACTOR=1.25   # plus grand -> dézoom plus fort

# Facteur de déplacement relatif à la taille actuelle
PAN_FACTOR=0.2         # plus grand = pan plus rapide

# ========= Fonctions =========

draw() {
    local cx="$CENTER_X"
    local cy="$CENTER_Y"
    local zoom="$ZOOM"
    local w="$W"
    local h="$H"
    local max_iter="$MAX_ITER"

    # Se repositionner en haut à gauche
    tput cup 0 0

    "$RENDER_BIN" "$w" "$h" "$max_iter" "$cx" "$cy" "$zoom"

    # ligne d’info en bas
    printf "cx=%.10f  cy=%.10f  zoom=%.10f  iter=%d  (flèches=pan, Espace=zoom, Backspace=dezoom, q=quit)\n" \
        "$cx" "$cy" "$zoom" "$max_iter"
}

cleanup() {
    tput cnorm
    stty echo
    clear
    exit 0
}

# ========= Initialisation terminal =========

clear
tput civis
# désactiver l’echo pour ne pas afficher les touches
stty -echo

if [[ ! -x "$RENDER_BIN" ]]; then
    tput cnorm
    stty echo
    echo "Renderer binaire introuvable: $RENDER_BIN"
    echo "Compilez-le avec: make"
    exit 1
fi

trap cleanup INT TERM

# Premier rendu
draw

# ========= Boucle d’événements clavier =========

while true; do
    # Lecture d’un caractère (ou début de séquence)
    IFS= read -rsn1 key || cleanup

    # Quitter avec "q"
    if [[ "$key" == "q" ]]; then
        cleanup
    fi

    case "$key" in
        " ")   # Espace -> zoom in
            ZOOM=$(awk -v z="$ZOOM" -v f="$ZOOM_IN_FACTOR" 'BEGIN { printf "%.15f", z*f }')
            ;;

        $'\177')  # Backspace -> zoom out
            ZOOM=$(awk -v z="$ZOOM" -v f="$ZOOM_OUT_FACTOR" 'BEGIN { printf "%.15f", z*f }')
            ;;

        $'\e')    # séquence d’échappement (flèches)
            IFS= read -rsn1 -t 0.0005 k1
            IFS= read -rsn1 -t 0.0005 k2
            seq="$k1$k2"
            # taille de pas selon zoom
            pan=$(awk -v z="$ZOOM" -v f="$PAN_FACTOR" 'BEGIN { printf "%.15f", z*f }')

            case "$seq" in
                "[A") # flèche haut -> monter (y augmente)
                    CENTER_Y=$(awk -v cy="$CENTER_Y" -v p="$pan" 'BEGIN { printf "%.15f", cy + p }')
                    ;;
                "[B") # flèche bas -> descendre (y diminue)
                    CENTER_Y=$(awk -v cy="$CENTER_Y" -v p="$pan" 'BEGIN { printf "%.15f", cy - p }')
                    ;;
                "[C") # flèche droite -> aller vers la droite (x augmente)
                    CENTER_X=$(awk -v cx="$CENTER_X" -v p="$pan" 'BEGIN { printf "%.15f", cx + p }')
                    ;;
                "[D") # flèche gauche -> aller vers la gauche (x diminue)
                    CENTER_X=$(awk -v cx="$CENTER_X" -v p="$pan" 'BEGIN { printf "%.15f", cx - p }')
                    ;;
            esac
            ;;

        *)  # autre touche : ignorée
            ;;
    esac

    # Redessiner après chaque action
    draw
done
