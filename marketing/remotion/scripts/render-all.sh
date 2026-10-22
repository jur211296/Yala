#!/usr/bin/env bash
# Renderiza los dos lienzos de una pieza, o el pack entero.
#
#   scripts/render-all.sh [slug] [locale]   → 9:16 + 16:9 de esa pieza
#   scripts/render-all.sh --pack [locale]   → todas las piezas CON toma
#
# Al final dice qué salió y qué NO. Un pack a medias se ve igual que uno
# completo hasta que alguien lo abre: por eso el parte es parte del script.
set -euo pipefail

cd "$(dirname "$0")/.."

MODE="${1:-ia-gasto-pizza}"
LOCALE="${2:-es}"

SLUGS=""
if [ "$MODE" = "--pack" ]; then
  # Los slugs salen de copy.ts, que es la SSOT. Nada de listas a mano aquí:
  # una lista paralela se desincroniza y el pack sale incompleto en silencio.
  #
  # Se LEE EL CÓDIGO, no se le hace grep: los slugs reservados se escriben con
  # el helper `reserved(...)` y un grep de `slug: "..."` no los ve. Hoy da el
  # mismo resultado por casualidad —ninguno tiene toma— y mañana no.
  if ! command -v bun >/dev/null 2>&1; then
    echo "✗ --pack necesita bun para leer src/brand/copy.ts." >&2
    echo "  Sin bun: pasa el slug a mano, o 'npx remotion compositions' para ver qué hay." >&2
    exit 1
  fi
  SLUGS=$(bun -e 'import {PIECES} from "./src/brand/copy"; console.log(PIECES.filter(p=>p.footage).map(p=>p.slug).join(" "))')
else
  SLUGS="$MODE"
fi

if [ -z "$(echo "$SLUGS" | tr -d ' ')" ]; then
  echo "✗ No hay ninguna pieza con toma. Nada que renderizar." >&2
  exit 1
fi

OK_LINES=""
FAIL_LINES=""
OK_N=0
FAIL_N=0

for slug in $SLUGS; do
  for aspect in 9x16 16x9; do
    if bash scripts/render-reels.sh "$slug" "$LOCALE" --aspect "$aspect"; then
      OK_LINES="${OK_LINES}✓ ${slug} ${aspect}\n"
      OK_N=$((OK_N + 1))
    else
      FAIL_LINES="${FAIL_LINES}✗ ${slug} ${aspect}\n"
      FAIL_N=$((FAIL_N + 1))
    fi
  done
done

echo
echo "─────────── parte del render ───────────"
printf "%b" "$OK_LINES"
if [ "$FAIL_N" -gt 0 ]; then
  printf "%b" "$FAIL_LINES"
  echo "⇒ ${FAIL_N} pieza(s) SIN vídeo. No se publica el pack." >&2
  exit 1
fi
echo "⇒ ${OK_N} vídeo(s) en out/"
