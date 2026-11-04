#!/usr/bin/env bash
#
# sentry-subir-dsym.sh — Sube a Sentry los dSYM de un archivado de Yala.
#
# Sin dSYM, Sentry no pone nombre a los frames de Yala y un cuelgue se diagnostica a ciegas
# (YALA-IOS-2, build 2.2 (5)). Recompilar el mismo commit NO sirve: sale otro UUID. Por eso los
# dSYM se suben del MISMO archivado que va a TestFlight.
#
# Dos formas de llamarlo:
#   1. Solo: lo corre el post-action «Archive» del scheme `Yala` (Yala.xcscheme) con las
#      variables que pone Xcode (ARCHIVE_DSYMS_PATH, ARCHIVE_PATH). Si algo falta, avisa y sale
#      con 0: el archivado no se rompe por esto. El registro queda junto al archivado, en
#      `<archivo>-sentry-dsym.log`, porque la salida de un post-action no llega a la consola.
#   2. A mano, sobre un archivado o una carpeta / zip de dSYM:
#        scripts/sentry-subir-dsym.sh ruta/Yala.xcarchive
#        scripts/sentry-subir-dsym.sh ruta/Yala-2.2-7-dSYMs.zip
#      Aquí un fallo sale con 1, para que se vea.
#
# Token: con escritura (project:write), org yala-is. Se lee de SENTRY_AUTH_TOKEN o, si no está,
# del Llavero (servicio `sentry-yala`, cuenta `jur`). NUNCA se escribe en el repo ni se pasa por
# argumento (se vería en `ps`): viaja por el entorno de sentry-cli.
#
# Requiere sentry-cli (`brew install getsentry/tools/sentry-cli`).
#
# Códigos de salida: 0 = subido (o saltado en modo post-action) · 1 = falló a mano · 2 = uso.

set -uo pipefail

SENTRY_ORG_SLUG="${SENTRY_ORG:-yala-is}"
SENTRY_PROJECT_SLUG="${SENTRY_PROJECT:-yala-ios}"

if [[ $# -ge 1 ]]; then
  modo="manual"
  objetivo="$1"
  if [[ -d "$objetivo/dSYMs" ]]; then
    objetivo="$objetivo/dSYMs"
  fi
  if [[ ! -e "$objetivo" ]]; then
    echo "❌ No existe: $objetivo" >&2
    exit 2
  fi
else
  modo="post-action"
  objetivo="${ARCHIVE_DSYMS_PATH:-}"
  if [[ -z "$objetivo" && -n "${ARCHIVE_PATH:-}" ]]; then
    objetivo="$ARCHIVE_PATH/dSYMs"
  fi
  if [[ -n "${ARCHIVE_PATH:-}" ]]; then
    registro="${ARCHIVE_PATH%.xcarchive}-sentry-dsym.log"
    exec >"$registro" 2>&1
  fi
fi

# En modo post-action un fallo avisa y no rompe el archivado; a mano, sale con 1.
fallar() {
  echo "⚠️  dSYM NO subidos a Sentry: $1" >&2
  if [[ "$modo" == "manual" ]]; then
    exit 1
  fi
  exit 0
}

[[ -n "$objetivo" && -e "$objetivo" ]] || fallar "no encuentro la carpeta de dSYM del archivado (ARCHIVE_DSYMS_PATH='${ARCHIVE_DSYMS_PATH:-}')."

# Xcode lanza los post-action con un PATH mínimo: Homebrew no está.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
command -v sentry-cli >/dev/null 2>&1 || fallar "falta sentry-cli (brew install getsentry/tools/sentry-cli)."

if [[ -z "${SENTRY_AUTH_TOKEN:-}" ]]; then
  if token="$(security find-generic-password -s sentry-yala -a jur -w 2>/dev/null)" && [[ -n "$token" ]]; then
    SENTRY_AUTH_TOKEN="$token"
  else
    fallar "no hay token con escritura: ni SENTRY_AUTH_TOKEN ni el Llavero (servicio sentry-yala, cuenta jur). Guárdalo con: security add-generic-password -s sentry-yala -a jur -w"
  fi
fi
export SENTRY_AUTH_TOKEN

echo "🔍 Subiendo dSYM de $objetivo a Sentry ($SENTRY_ORG_SLUG/$SENTRY_PROJECT_SLUG)"
if sentry-cli debug-files upload \
     --org "$SENTRY_ORG_SLUG" \
     --project "$SENTRY_PROJECT_SLUG" \
     "$objetivo"; then
  echo "✅ dSYM subidos a Sentry."
else
  fallar "sentry-cli devolvió error (mira arriba)."
fi
