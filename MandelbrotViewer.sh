#!/usr/bin/env bash

# ========= Paramètres de base =========
W=${1:-160}        # largeur en caractères
H=${2:-48}         # hauteur en lignes
MAX_ITER=${3:-800} # itérations Mandelbrot (monter pour plus de détails)

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

    awk -v W="$w" -v H="$h" -v max_iter="$max_iter" \
        -v cx="$cx" -v cy="$cy" -v zoom="$zoom" '
    BEGIN {
        # Définition de la fenêtre complexe pour ce zoom
        xmin = cx - zoom;
        xmax = cx + zoom;
        ymin = cy - zoom * H / W;
        ymax = cy + zoom * H / W;

        for (py = 0; py < H; py++) {
            for (px = 0; px < W; px++) {

                # Coordonnées complexes correspondant au point (px, py)
                x0 = xmin + (xmax - xmin) * px / W;
                y0 = ymin + (ymax - ymin) * py / H;

                x = 0; y = 0; iter = 0;
                while (x*x + y*y <= 4 && iter < max_iter) {
                    xt = x*x - y*y + x0;
                    y  = 2*x*y + y0;
                    x  = xt;
                    iter++;
                }

                if (iter == max_iter) {
                    color = 16;   # intérieur : noir
                } else {
                    # palette simple mais efficace
                    color = 17 + int((iter / max_iter) * 200);
                }

                # bloc plein en couleur de fond
                printf "\033[48;5;%dm \033[0m", color;
            }
            printf "\n";
        }

        # ligne d’info en bas
        printf "cx=%.10f  cy=%.10f  zoom=%.10f  iter=%d  (flèches=pan, Espace=zoom, Backspace=dezoom, q=quit)\n",
               cx, cy, zoom, max_iter;
    }'
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
