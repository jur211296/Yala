#!/usr/bin/env bash
# Banco de scripts/indexar_doc.py: dónde cae el índice y que una segunda pasada no cambie nada.
#
# Por qué: el índice caía ENCIMA del frontmatter YAML y el frontmatter dejaba de serlo
# (ticket generated-index-lands-above-yaml-frontmatter). Trabaja sobre ficheros temporales;
# no toca el árbol.
#
# Uso: bash scripts/indexar_doc_test.sh
set -u
cd "$(dirname "$0")/.."
SCRIPT="$PWD/scripts/indexar_doc.py"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fallos=0; casos=0

FM=$'---\nid: prueba\nstatus: backlog\n---\n'
TIT=$'# Título del documento\n\n> Una cita bajo el título.\n'
SECC=""; for i in 1 2 3 4 5 6 7 8 9; do SECC+=$'\n## Sección '"$i"$' sobre swiftdata\n\nTexto.\n'; done
VIN=$'\n'; for i in 1 2 3 4 5 6 7 8 9; do VIN+="- **Regla $i:** texto de la regla."$'\n'; done

# caso <nombre> <contenido> <primera línea esperada> <línea que debe ir justo encima del índice o "">
caso() {
  local nom="$1" cont="$2" l1="$3" antes="$4" f="$TMP/$1.md"
  casos=$((casos+1))
  printf '%s' "$cont" > "$f"
  python3 "$SCRIPT" "$f" --apply >/dev/null || { echo "FALLO $nom: el script salió con error"; fallos=$((fallos+1)); return; }
  local p1; p1=$(cat "$f")
  local got; got=$(head -1 "$f")
  local err=""
  [ "$got" = "$l1" ] || err+=" línea1=[$got] esperaba [$l1];"
  local n; n=$(grep -n '<!-- INDICE:inicio' "$f" | head -1 | cut -d: -f1)
  [ -n "$n" ] || err+=" sin índice;"
  if [ -n "$n" ]; then
    # lo último no vacío antes del índice
    local prev=""; [ "$n" -gt 1 ] && prev=$(head -n $((n-1)) "$f" | grep -v '^$' | tail -1)
    [ "$prev" = "$antes" ] || err+=" encima del índice=[$prev] esperaba [$antes];"
    # el frontmatter, si lo hay, cierra antes del índice
    if [ "$l1" = "---" ]; then
      local cierre; cierre=$(grep -n '^---$' "$f" | sed -n 2p | cut -d: -f1)
      [ -n "$cierre" ] && [ "$cierre" -lt "$n" ] || err+=" frontmatter no cierra antes del índice;"
    fi
  fi
  python3 "$SCRIPT" "$f" --apply >/dev/null
  [ "$(cat "$f")" = "$p1" ] || err+=" la segunda pasada cambió el fichero;"
  if [ -n "$err" ]; then echo "FALLO $nom:$err"; fallos=$((fallos+1)); else echo "ok    $nom"; fi
}

# Camino de encabezados
caso fm-y-titulo        "$FM"$'\n'"$TIT$SECC"   '---'                     '> Una cita bajo el título.'
caso fm-sin-titulo      "$FM$SECC"              '---'                     '---'
caso titulo-sin-fm      "$TIT$SECC"             '# Título del documento'   '> Una cita bajo el título.'
caso sin-nada           "${SECC#$'\n'}"         '<!-- INDICE:inicio — generado por scripts/indexar_doc.py, no editar a mano -->' ''
# La forma del bug: índice viejo ENCIMA del frontmatter. Una pasada lo repara.
caso indice-encima-fm   $'<!-- INDICE:inicio — viejo -->\n\n## Índice\n\n<!-- INDICE:fin -->\n\n'"$FM"$'\n'"$TIT$SECC" '---' '> Una cita bajo el título.'
# Camino de viñetas
caso vin-fm-y-titulo    "$FM"$'\n'"$TIT$VIN"    '---'                     '> Una cita bajo el título.'
caso vin-fm-sin-titulo  "$FM$VIN"               '---'                     '---'
caso vin-titulo-sin-fm  "$TIT$VIN"              '# Título del documento'   '> Una cita bajo el título.'

# En viñetas el índice cita líneas: tienen que apuntar a la viñeta de verdad.
casos=$((casos+1))
f="$TMP/vin-fm-y-titulo.md"
mal=$(python3 - "$f" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding='utf-8').read().split('\n')
for m in re.finditer(r'\| `L(\d+)` \| ([^|]+) \|', '\n'.join(lines)):
    n, tit = int(m.group(1)), m.group(2).strip()
    if not lines[n - 1].startswith('- **' + tit):
        print('L%d -> %r' % (n, lines[n - 1][:40]))
PY
)
if [ -z "$mal" ]; then echo "ok    vin-lineas-apuntan-bien"; else echo "FALLO vin-lineas-apuntan-bien: $mal"; fallos=$((fallos+1)); fi

echo "$((casos-fallos))/$casos casos en verde"
[ "$fallos" -eq 0 ]
