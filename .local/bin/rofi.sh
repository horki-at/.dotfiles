#!/bin/sh
# launch — rofi picker: apps, manual PDFs, document PDFs
# usage: launch [apps|manuals|docs]
# deps: rofi zathura

THEME="$HOME/.config/rofi/theme.rasi"
MANUALS="$HOME/docs/manuals"
DOCS="$HOME/docs/burocracy"

pick() {
    rofi -dmenu -i -p "$1" -theme "$THEME"
}

pdf_menu() {
    dir=$2
    sel=$(cd "$dir" && find . -type f ! -name '.*' | sed 's|^\./||' | sort | pick "$1")
    [ -n "$sel" ] && exec zathura "$dir/$sel"
}

case "${1:-main}" in
    apps)    exec rofi -show drun -theme "$THEME" ;;
    manuals) pdf_menu manuals "$MANUALS" ;;
    docs)    pdf_menu docs "$DOCS" ;;
    main)
        sel=$(printf 'apps\nmanuals\ndocs' | pick launch)
        [ -n "$sel" ] && exec "$0" "$sel" ;;
    *) echo "usage: launch [apps|manuals|docs]" >&2; exit 1 ;;
esac
