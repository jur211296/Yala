#!/bin/bash
# Matriz de estados: una hoja por widget y tamaño, una fila por estado y una columna por modo (claro, oscuro).
#
#   matriz.sh <carpeta con una subcarpeta por estado> <carpeta de salida> [modos…]
#
# Las subcarpetas son las salidas de `render.sh run` con cada foto de `estados.py` (completo, vacio, pocos…). Con dos
# carpetas de capturas (antes y después) se pinta una matriz de cada una y se comparan lado a lado. Usa ImageMagick
# (`magick montage`), no PIL: no todas las máquinas lo tienen.
set -euo pipefail
IN="${1:?carpeta de estados}"; OUT="${2:?carpeta de salida}"; shift 2
MODES=("${@:-claro oscuro}")
[ $# -eq 0 ] && MODES=(claro oscuro)
STATES=(completo pocos sin-ingresos sin-presupuestos sin-gastos vacio)
mkdir -p "$OUT"
# Los widgets y tamaños salen de la carpeta del estado completo: <widget>-<tamaño>-claro.png.
for f in "$IN/completo/"*-claro.png; do
  base="$(basename "$f" -claro.png)"
  args=()
  for st in "${STATES[@]}"; do
    for m in "${MODES[@]}"; do
      p="$IN/$st/$base-$m.png"
      if [ -f "$p" ]; then args+=(-label "$st · $m" "$p"); fi
    done
  done
  [ ${#args[@]} -eq 0 ] && continue
  magick montage "${args[@]}" -tile "${#MODES[@]}x" -geometry '+12+12' -font /System/Library/Fonts/Supplemental/Arial.ttf -pointsize 22 \
    -background '#F2F2F7' "$OUT/$base.png"
done
ls "$OUT" | wc -l | xargs echo "matriz: hojas en $OUT:"
