#!/usr/bin/env bash
# Compila reloj.c para el simulador (arm64) y deja el dylib en la caché del molde. Uso: reloj/compilar.sh → imprime la ruta.
set -euo pipefail
D="$(cd "$(dirname "$0")" && pwd)"
OUT="${YALA_FICHA_CACHE:-$HOME/Library/Caches/Yala/ficha}/reloj.dylib"
mkdir -p "$(dirname "$OUT")"
if [ ! -f "$OUT" ] || [ "$D/reloj.c" -nt "$OUT" ]; then
  xcrun --sdk iphonesimulator clang -target arm64-apple-ios26.0-simulator -dynamiclib -O2 \
    -framework CoreFoundation -o "$OUT" "$D/reloj.c"
  codesign -s - -f "$OUT" >/dev/null 2>&1
fi
echo "$OUT"
