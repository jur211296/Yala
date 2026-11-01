#!/bin/bash
# Copia las fuentes del widget (y los tres ficheros de `Yala/` que su target compila por membership) a `Generated/`,
# con cinco cambios para poder pintarlas fuera de WidgetKit (ver README):
#   1. sin el `@main` del bundle (el banco es una app);
#   2. el entorno de WidgetKit (familia, modo de pintado, fondo) pasa a claves propias que el banco fija;
#   3. el reloj (`Date()`, `Date.now`, `isDateInToday/Tomorrow/Yesterday`) pasa a `RenderClock`, fijado a la hora de la
#      foto: antes y después se pintan con el mismo «ahora» aunque se rendericen otro día;
#   4. `createEntry` deja de ser privado para que el catálogo use la misma construcción de la entrada que el proveedor;
#   5. `AccessoryWidgetBackground()` (no pinta nada fuera de la pantalla bloqueada) pasa a una imitación.
# Uso: prepare-sources.sh <raíz del repo>
set -euo pipefail
ROOT="${1:?raíz del repo}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/Generated"
rm -rf "$OUT"
mkdir -p "$OUT/Widget" "$OUT/Shared"

( cd "$ROOT/YalaWidgets" && find . -name '*.swift' ! -name 'YalaWidgetsBundle.swift' -print0 ) | while IFS= read -r -d '' f; do
  mkdir -p "$OUT/Widget/$(dirname "$f")"
  cp "$ROOT/YalaWidgets/$f" "$OUT/Widget/$f"
done
for f in Yala/App/Logic/Helpers/WidgetAmountSplitter.swift Yala/App/Logic/Helpers/WidgetInsightsLogic.swift Yala/App/Logic/Helpers/WidgetSelectionFallback.swift Yala/Shared/ControlCenterIntents.swift; do
  [ -f "$ROOT/$f" ] && cp "$ROOT/$f" "$OUT/Shared/"
done

find "$OUT" -name '*.swift' -print0 | while IFS= read -r -d '' f; do
  sed -i '' \
    -e 's/\\\.widgetFamily/\\.renderFamily/g' \
    -e 's/\\\.widgetRenderingMode/\\.renderRenderingMode/g' \
    -e 's/\\\.showsWidgetContainerBackground/\\.renderShowsContainerBackground/g' \
    -e 's/\([^A-Za-z0-9_.]\)Date()/\1RenderClock.now/g' \
    -e 's/\([^A-Za-z0-9_]\)Date\.now/\1RenderClock.now/g' \
    -e 's/\.isDateInToday(/.renderIsDateInToday(/g' \
    -e 's/\.isDateInTomorrow(/.renderIsDateInTomorrow(/g' \
    -e 's/\.isDateInYesterday(/.renderIsDateInYesterday(/g' \
    -e 's/private func createEntry(/func createEntry(/g' \
    -e 's/AccessoryWidgetBackground()/RenderAccessoryBackground()/g' \
    "$f"
done
echo "prepare-sources: $(find "$OUT" -name '*.swift' | wc -l | tr -d ' ') ficheros en $OUT"
