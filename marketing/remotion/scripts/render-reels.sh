#!/usr/bin/env bash
# Renderiza UNA pieza en UN lienzo.
#
#   scripts/render-reels.sh [slug] [locale] [--aspect 9x16|16x9]
#   scripts/render-reels.sh <slug-de-presentación> [locale] --presentation
#
# Sin argumentos saca el piloto en español y 9:16.
# Comprueba el fichero DESPUÉS de renderizar: «renderizado» no es «hay vídeo».
#
# Escrito para bash 3.2, que es el que trae macOS. Sin mapfile y sin arrays
# vacíos expandidos bajo `set -u`: los dos revientan aquí.
set -euo pipefail

cd "$(dirname "$0")/.."

SLUG="ia-gasto-pizza"
LOCALE="es"
ASPECT="9x16"
PRESENTATION=0
POS_COUNT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --aspect) ASPECT="$2"; shift 2 ;;
    --locale) LOCALE="$2"; shift 2 ;;
    --presentation) PRESENTATION=1; ASPECT="16x9"; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *)
      POS_COUNT=$((POS_COUNT + 1))
      if [ "$POS_COUNT" -eq 1 ]; then SLUG="$1"; fi
      if [ "$POS_COUNT" -eq 2 ]; then LOCALE="$1"; fi
      shift
      ;;
  esac
done

case "$ASPECT" in
  9x16) COMP="FeatureDemo-9x16" ;;
  16x9) COMP="FeatureDemo-16x9" ;;
  *) echo "✗ aspect desconocido: $ASPECT (usa 9x16 o 16x9)" >&2; exit 2 ;;
esac
if [ "$PRESENTATION" -eq 1 ]; then COMP="Presentation-16x9"; fi

# bun si está, npx si no: la Mini puede no tener bun.
if command -v bunx >/dev/null 2>&1; then
  RUNNER="bunx"
else
  RUNNER="npx"
fi

OUT="out/${SLUG}-${LOCALE}-${ASPECT}.mp4"
if [ "$PRESENTATION" -eq 1 ]; then
  PROPS=$(printf '{"slug":"%s","locale":"%s"}' "$SLUG" "$LOCALE")
else
  PROPS=$(printf '{"slug":"%s","locale":"%s","aspect":"%s","showSafeAreas":false}' "$SLUG" "$LOCALE" "$ASPECT")
fi

mkdir -p out
echo "→ ${COMP}  ·  ${SLUG}  ·  ${LOCALE}  →  ${OUT}"
if [ "$RUNNER" = "bunx" ]; then
  bunx remotion render "$COMP" "$OUT" --props="$PROPS"
else
  npx --yes remotion render "$COMP" "$OUT" --props="$PROPS"
fi

# --- Comprobación. Sin esto, un render vacío pasa por bueno. ---
if [ ! -s "$OUT" ]; then
  echo "✗ NO SE PUBLICA: $OUT no existe o está vacío" >&2
  exit 1
fi
BYTES=$(wc -c < "$OUT" | tr -d ' ')
if [ "$BYTES" -lt 100000 ]; then
  echo "✗ NO SE PUBLICA: $OUT pesa ${BYTES} bytes; eso no es un vídeo" >&2
  exit 1
fi
if command -v ffprobe >/dev/null 2>&1; then
  DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT")
  echo "✓ $OUT  ·  ${BYTES} bytes  ·  ${DUR}s"
else
  echo "✓ $OUT  ·  ${BYTES} bytes  (sin ffprobe: duración sin comprobar)"
fi
