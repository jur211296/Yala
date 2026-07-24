#!/usr/bin/env bash
#
# asc-preflight.sh — Validación previa al upload a App Store Connect.
#
# Bloquea la subida de un build que:
#   1. Tenga OPENAI_API_KEY / EXCHANGE_RATE_API_KEY embebidas en el Info.plist →
#      secretos extraíbles del IPA. Desde el épico del gateway viven SOLO en el
#      Cloudflare Worker; no deben volver al binario (regresión de builds ≤18).
#
# Nota: el chequeo de TELEMETRY_DECK_APP_ID se retiró el 2026-07-24 — TelemetryDeck
# fue eliminado por completo el 2026-07-17 (branch 2.0.5, commits `67508ee5`/
# `13791215`/`d460480b`). La telemetría propia (MetricsService → POST /metrics del
# gateway → Analytics Engine) no usa una key embebida en el binario, así que no
# aplica un chequeo equivalente en este nivel.
#
# Uso — entre `xcodebuild -exportArchive` y `asc builds upload`:
#   scripts/asc-preflight.sh .asc/artifacts/Yala-buildNN.xcarchive
#
# Códigos de salida: 0 = OK para subir · 1 = validación falló · 2 = error de uso.

set -euo pipefail

ARCHIVE="${1:-}"
if [[ -z "$ARCHIVE" ]]; then
  echo "❌ Uso: $0 <ruta-al-.xcarchive>" >&2
  exit 2
fi

PLIST="$ARCHIVE/Products/Applications/Yala.app/Info.plist"
if [[ ! -f "$PLIST" ]]; then
  echo "❌ No se encontró el Info.plist del build en: $PLIST" >&2
  exit 2
fi

echo "🔍 Pre-flight sobre $PLIST"
fail=0

# 1) Las API keys NO deben viajar en el binario (viven solo en el gateway).
for key in OPENAI_API_KEY EXCHANGE_RATE_API_KEY; do
  if plutil -extract "$key" raw "$PLIST" >/dev/null 2>&1; then
    echo "❌ $key embebida en el Info.plist → secreto filtrado en el IPA." >&2
    fail=1
  else
    echo "✅ $key ausente del binario."
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo "" >&2
  echo "🚫 Pre-flight FALLÓ — NO subas este build a App Store Connect." >&2
  exit 1
fi

echo ""
echo "✅ Pre-flight OK — el build es seguro para subir."
