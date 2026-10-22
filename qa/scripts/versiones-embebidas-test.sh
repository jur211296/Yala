#!/bin/bash
# Banco de pruebas de `versiones-embebidas.py`.
#
#   bash qa/scripts/versiones-embebidas-test.sh
#
# **Por qué existe.** El script es una red, y una red que no falla con el bug que vino a cazar
# no es una red. Cada caso copia el proyecto y los Info.plist a un directorio temporal, mete
# UNA regresión y exige que el script salga con 1. El primer caso es el árbol real, que debe
# salir con 0; el segundo, el widget como estaba hasta el 2026-10-10 (`CFBundleVersion = 3`).
#
# No compila nada ni toca el simulador: corre en Linux, en el job `coverage-index`.

set -uo pipefail

RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$RAIZ/qa/scripts/versiones-embebidas.py"
TMP_BASE="$(mktemp -d "${TMPDIR:-/tmp}/versiones-embebidas.XXXXXX")"
trap 'rm -r "${TMP_BASE}"' EXIT

FALLOS=0
N=0

copia() {
  local dir="$TMP_BASE/caso-$N"
  mkdir -p "$dir/Yala.xcodeproj"
  cp "$RAIZ/Yala.xcodeproj/project.pbxproj" "$dir/Yala.xcodeproj/"
  # Solo los Info.plist que el proyecto declara: son los que el script lee.
  grep -oE '[[:space:]]INFOPLIST_FILE = [^;]+' "$RAIZ/Yala.xcodeproj/project.pbxproj" \
    | sed -E 's/[[:space:]]*INFOPLIST_FILE = "?([^"]+)"?/\1/' | sort -u | while read -r p; do
      mkdir -p "$dir/$(dirname "$p")"
      cp "$RAIZ/$p" "$dir/$p"
    done
  echo "$dir"
}

# Edición en sitio portable (BSD y GNU sed difieren en -i).
editar() {
  local fichero="$1" expr="$2"
  sed -E "$expr" "$fichero" > "$fichero.nuevo" && mv "$fichero.nuevo" "$fichero"
}

caso() {
  local nombre="$1" esperado="$2" dir="$3"
  N=$((N + 1))
  python3 "$SCRIPT" --raiz "$dir" > "$TMP_BASE/salida" 2>&1
  local rc=$?
  if [ "$rc" = "$esperado" ]; then
    echo "✓ ${nombre} (sale ${rc})"; [ "$rc" = 1 ] && sed "s/^/    /" "$TMP_BASE/salida"
  else
    echo "✗ ${nombre}: esperaba ${esperado}, sale ${rc}"
    sed 's/^/    /' "$TMP_BASE/salida"
    FALLOS=$((FALLOS + 1))
  fi
}

# 1. El árbol tal cual: verde.
caso "árbol real" 0 "$(copia)"

# 2. El widget con su build fijo, como estuvo desde mayo.
D="$(copia)"
editar "$D/YalaWidgets/Info.plist" 's|\$\(CURRENT_PROJECT_VERSION\)|3|'
caso "widget con CFBundleVersion = 3" 1 "$D"

# 3. El widget con la versión fija.
D="$(copia)"
editar "$D/YalaWidgets/Info.plist" 's|\$\(MARKETING_VERSION\)|2.1|'
caso "widget con CFBundleShortVersionString = 2.1" 1 "$D"

# 4. La share extension, que hoy no lleva la clave, la gana con un valor fijo.
D="$(copia)"
editar "$D/YalaShare/Info.plist" 's|<dict>|<dict><key>CFBundleVersion</key><string>7</string>|'
caso "share con CFBundleVersion = 7" 1 "$D"

# 5. La share deja de generar su Info.plist: sin la clave, se quedaría sin build.
D="$(copia)"
editar "$D/Yala.xcodeproj/project.pbxproj" '/INFOPLIST_FILE = YalaShare/s|$|\
				GENERATE_INFOPLIST_FILE = NO;|'
caso "share sin la clave y sin generar" 1 "$D"

# 6. Una sola configuración con otro build.
D="$(copia)"
editar "$D/Yala.xcodeproj/project.pbxproj" '0,/CURRENT_PROJECT_VERSION = [0-9]+;/s//CURRENT_PROJECT_VERSION = 3;/'
grep -q 'CURRENT_PROJECT_VERSION = 3;' "$D/Yala.xcodeproj/project.pbxproj" || {
  # BSD sed no entiende `0,/re/`: se hace con awk sobre la primera aparición.
  awk '!h && /CURRENT_PROJECT_VERSION = [0-9]+;/ {sub(/= [0-9]+;/, "= 3;"); h=1} {print}' \
    "$RAIZ/Yala.xcodeproj/project.pbxproj" > "$D/Yala.xcodeproj/project.pbxproj"
}
caso "una configuración con CURRENT_PROJECT_VERSION = 3" 1 "$D"

# 7. El build fijado por build setting en vez de en el plist.
D="$(copia)"
editar "$D/Yala.xcodeproj/project.pbxproj" '/INFOPLIST_FILE = YalaWidgets/s|$|\
				INFOPLIST_KEY_CFBundleVersion = 3;|'
caso "INFOPLIST_KEY_CFBundleVersion = 3" 1 "$D"

echo
if [ "$FALLOS" -eq 0 ]; then
  echo "✓ ${N} casos"
  exit 0
fi
echo "✗ ${FALLOS} de ${N} casos fallan"
exit 1
