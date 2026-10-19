#!/usr/bin/env bash
# Fija el Xcode de los jobs `tests` y `ui` de `.github/workflows/qa.yml` en la rama 2.2.
# Lo llama el paso «Seleccionar Xcode 27.1».
#
# Por qué existe: 2.2 usa APIs que solo trae el SDK de iOS 27, y la release se compila con
# Xcode 27.1 (build 27A9275) en la Mini. La imagen `xcode-27` de GitHub trae 27.0 por defecto,
# 27.1 y una beta de 27.2; aquí se elige 27.1 por ruta y se comprueba el build. Si la imagen
# cambia y el build ya no es el esperado, el paso falla con el motivo, en vez de compilar en
# silencio con otro Xcode.
#
# Variables (todas con default):
#   XCODE_APP     Xcode que se selecciona        (/Applications/Xcode_27.1.app)
#   XCODE_BUILD   build que tiene que dar        (27A9275)
set -euo pipefail

XCODE_APP="${XCODE_APP:-/Applications/Xcode_27.1.app}"
XCODE_BUILD="${XCODE_BUILD:-27A9275}"

if [ ! -d "$XCODE_APP" ]; then
  echo "::error title=Xcode::no existe $XCODE_APP en esta imagen. Los que hay:"
  ls -d /Applications/Xcode*.app 2>/dev/null || true
  exit 1
fi

sudo xcode-select -s "$XCODE_APP/Contents/Developer"
version="$(xcodebuild -version)"
echo "$version"

if ! printf '%s\n' "$version" | grep -qx "Build version $XCODE_BUILD"; then
  echo "::error title=Xcode::$XCODE_APP no es el build $XCODE_BUILD"
  exit 1
fi
