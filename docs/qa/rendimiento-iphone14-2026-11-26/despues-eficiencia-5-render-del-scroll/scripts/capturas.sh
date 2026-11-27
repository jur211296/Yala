#!/bin/bash
# Capturas del iPhone 14 para comparar antes y después: el Panel arriba (píldoras de acción rápida) y Registros arriba y
# bajado (filas y botones flotantes), en el tema por defecto (Liquid Glass, 8), claro (1) y oscuro (2). Registros se abre
# con el enlace de pruebas (`-uitest-deeplink records`) y se baja por distancia exacta, sin inercia, para que las dos
# tandas paren en el mismo sitio. Uso: capturas.sh <etiqueta> <dir salida>
U=00008110-001A35A6267A401E; E=$1; OUT=$2; mkdir -p $OUT
CLI="/Applications/Device MCP.app/Contents/MacOS/device-mcp-cli"
shot(){ rm -f "$OUT/$1"; "$CLI" screenshot -o "$OUT/$1" --device $U --no-launch >/dev/null 2>&1; }
abrir(){ xcrun devicectl device process launch --device $U --terminate-existing com.jurgenschmidt.yala.dev -- \
  -uitest -uitest-skip-onboarding "$@" >/dev/null 2>&1; sleep 30; }
for par in glass:8 claro:1 oscuro:2; do
  tema=${par%:*}; n=${par#*:}
  abrir -userTheme $n
  shot $E-$tema-panel-arriba.png
  abrir -userTheme $n -uitest-deeplink records
  shot $E-$tema-registros.png
  "$CLI" scroll down --distance 300 --device $U --no-launch >/dev/null 2>&1; sleep 3
  shot $E-$tema-registros-bajado.png
done
ls $OUT | grep "^$E-"
