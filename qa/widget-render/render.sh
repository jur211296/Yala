#!/bin/bash
# Pinta todos los widgets con una foto del App Group y deja los PNG en <carpeta de salida>.
#
#   render.sh build <raíz del repo>                         compila el banco (sin simulador arrancado: -jobs 2)
#   render.sh run <foto.plist> <carpeta de salida> [slug]    lo instala y lo lanza en el simulador (arrancado)
#
# Variables: WIDGET_RENDER_UDID (por defecto, el iPhone 17 Pro de iOS 27.0), WIDGET_RENDER_DERIVED (DerivedData),
# WIDGET_RENDER_CLOCK (segundos desde 1970; por defecto, la hora de la foto).
# La foto se saca con export-snapshot.sh. Ver README.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
UDID="${WIDGET_RENDER_UDID:-CA0A0420-70CD-40FD-B44D-075CEC5F4F98}"
DERIVED="${WIDGET_RENDER_DERIVED:-/Volumes/ExtDev/DerivedData/WidgetRender}"
BUNDLE="com.jurgenschmidt.widgetrender"

case "${1:-}" in
  build)
    ROOT="${2:?raíz del repo}"
    "$HERE/prepare-sources.sh" "$ROOT"
    ( cd "$HERE" && xcodegen generate --quiet )
    xcodebuild -project "$HERE/WidgetRender.xcodeproj" -scheme WidgetRender \
      -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" -jobs 2 build -quiet
    echo "render: compilado en $DERIVED"
    ;;
  run)
    SNAP="${2:?foto.plist}"; OUT="${3:?carpeta de salida}"; ONLY="${4:-}"
    APP="$DERIVED/Build/Products/Debug-iphonesimulator/WidgetRender.app"
    [ -d "$APP" ] || { echo "render: falta compilar ($APP)"; exit 1; }
    mkdir -p "$OUT"
    xcrun simctl install "$UDID" "$APP"
    ARGS=(-snapshot "$SNAP" -AppleLanguages "(es-419)" -AppleLocale es_PE)
    [ -n "${WIDGET_RENDER_CLOCK:-}" ] && ARGS+=(-clock "$WIDGET_RENDER_CLOCK")
    [ -n "$ONLY" ] && ARGS+=(-only "$ONLY")
    DATA="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)"
    rm -f "$DATA/Documents/out/done.txt"
    xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" "${ARGS[@]}" >/dev/null
    for _ in $(seq 1 240); do
      [ -f "$DATA/Documents/out/done.txt" ] && break
      sleep 1
    done
    [ -f "$DATA/Documents/out/done.txt" ] || { echo "render: no terminó en 4 min"; exit 1; }
    cp "$DATA/Documents/out/"*.png "$OUT/"
    cat "$DATA/Documents/out/done.txt"; echo
    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
    ;;
  *)
    sed -n '2,10p' "$0"; exit 2 ;;
esac
