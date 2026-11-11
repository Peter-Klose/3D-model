#!/usr/bin/env bash
# Render all STLs and preview PNGs from the parametric sources, then verify
# that every STL is a valid, watertight solid.
#
#   scripts/export_all.sh            # all models
#   scripts/export_all.sh hexenkessel  # one model
#
# Needs: openscad (CLI), python3 with the packages in scripts/requirements.txt.
# PNG previews need an X display; xvfb-run is used automatically if present.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPENSCAD="${OPENSCAD:-openscad}"
IMGSIZE="${IMGSIZE:-1000,800}"
command -v "$OPENSCAD" >/dev/null || { echo "openscad not found" >&2; exit 1; }

XVFB=()
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then XVFB=(xvfb-run -a); fi

png() {  # png <out.png> <scad> [args] – failure only warns (no display etc.)
    local out="$1"; shift
    "${XVFB[@]}" "$OPENSCAD" -o "$out" --imgsize="$IMGSIZE" --colorscheme=Tomorrow "$@" >/dev/null 2>&1 \
        || echo "   WARNING: could not render $out" >&2
}

models=("$@")
if [ ${#models[@]} -eq 0 ]; then
    for d in "$ROOT"/models/*/; do models+=("$(basename "$d")"); done
fi

stls=()
for model in "${models[@]}"; do
    dir="$ROOT/models/$model"
    conf="$dir/export.conf"
    [ -f "$conf" ] || { echo "skip $model (no export.conf)"; continue; }
    mkdir -p "$dir/stl" "$dir/preview"
    echo "== $model"
    while read -r kind name scad args; do
        case "$kind" in ''|\#*) continue ;; esac
        eval "extra=($args)"
        case "$kind" in
        part)
            echo " - $name.stl"
            log="$("$OPENSCAD" -o "$dir/stl/$name.stl" --export-format binstl "${extra[@]}" "$dir/src/$scad" 2>&1)" \
                || { echo "$log" >&2; exit 1; }
            if grep -qE "WARNING|ERROR" <<<"$log"; then grep -E "WARNING|ERROR" <<<"$log" >&2; exit 1; fi
            stls+=("$dir/stl/$name.stl")
            tmp="$(mktemp --suffix=.scad)"
            echo "color(\"SlateGray\") import(\"$dir/stl/$name.stl\", convexity=10);" >"$tmp"
            png "$dir/preview/$name.png" "$tmp" --camera=0,0,0,62,0,25,0 --viewall --autocenter
            rm -f "$tmp"
            ;;
        view)
            echo " - $name.png"
            png "$dir/preview/$name.png" "${extra[@]}" "$dir/src/$scad"
            ;;
        shade)   # shade <name> <part> X0 X1 Z0 Z1 – raking-light front view of an STL
            echo " - $name.png"
            python3 "$ROOT/scripts/shade_stl.py" "$dir/stl/$scad.stl" "$dir/preview/$name.png" "${extra[@]}"
            ;;
        *) echo "unknown entry '$kind' in $conf" >&2; exit 1 ;;
        esac
    done <"$conf"
done

echo "== verifying STLs"
python3 "$ROOT/scripts/check_stl.py" "${stls[@]}"
