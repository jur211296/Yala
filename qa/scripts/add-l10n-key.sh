#!/usr/bin/env bash
#
# add-l10n-key.sh — Propaga una key nueva a los 9 locales base de Yala marcando
# las traducciones pendientes con [NEEDS_TRANSLATION].
#
# Uso:
#   ./add-l10n-key.sh "panel.newKey" "Texto en es-419 neutro" "Comment for translators"
#
# La key se añade en es-419 con el valor real (es el reference locale para los
# tests de paridad) y se propaga como [NEEDS_TRANSLATION] al resto. El dev luego
# traduce manualmente cada locale antes del commit.
#
# Variantes regionales (es-ES, es-AR, pt-PT, en-GB) TAMBIÉN se materializan: iOS NO
# hace fallback per-key cuando la variante es el idioma de SISTEMA (resuelve el .lproj
# de la variante y devuelve la key cruda si falta). es-ES/es-AR copian el valor real de
# es-419; en-GB/pt-PT reciben [NEEDS_TRANSLATION] (igual que en/pt-BR). Si la key requiere
# override regional (peninsular/voseo/británico), edítalo manualmente después. Detalle en
# planning/L10N.md.
#
# Tests CI fallarán si quedan strings con [NEEDS_TRANSLATION] o si una variante queda
# incompleta respecto a su padre:
#   - LocalizationParityTests.noNeedsTranslationMarker_anywhere
#   - LocalizationParityTests.variants_haveAllKeys_fromParent
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <key> <es-419-value> [comment]" >&2
  echo "Example: $0 'panel.newKey' 'Hola %@' 'Greeting on panel'" >&2
  exit 1
fi

KEY="$1"
VALUE_ES_419="$2"
COMMENT="${3:-}"

# Locales BASE — variantes regionales (es-ES, es-AR, pt-PT, en-GB) se omiten
# porque heredan del padre vía fallback chain en ls().
BASE_LOCALES=(
  "es"           # alias catch-all (copia de es-419)
  "es-419"       # reference
  "en"
  "de"
  "fr"
  "it"
  "pt"           # alias catch-all (copia de pt-BR)
  "pt-BR"        # reference lusofona
  "nl"
  "pl"
  "ja"
  "zh-Hans"
)

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOURCES="$REPO_ROOT/Yala/Resources"

PLACEHOLDER="[NEEDS_TRANSLATION]"

added=0
skipped=0

for locale in "${BASE_LOCALES[@]}"; do
  file="$RESOURCES/$locale.lproj/Localizable.strings"
  if [ ! -f "$file" ]; then
    echo "  ⚠️  $locale: $file no existe — saltando"
    continue
  fi

  # Skip si la key ya existe (idempotente)
  if grep -qE "^\"${KEY//./\\.}\" = " "$file"; then
    echo "  ✓  $locale: key '$KEY' ya existe — saltando"
    skipped=$((skipped + 1))
    continue
  fi

  # es-419 + es (alias) reciben el valor real; el resto reciben el placeholder
  if [ "$locale" = "es-419" ] || [ "$locale" = "es" ]; then
    value="$VALUE_ES_419"
  else
    value="$PLACEHOLDER $VALUE_ES_419"
  fi

  # Apéndice al final del archivo. El comment va como bloque /* ... */ en línea anterior.
  if [ -n "$COMMENT" ]; then
    {
      echo ""
      echo "/* $COMMENT */"
      echo "\"$KEY\" = \"$value\";"
    } >> "$file"
  else
    {
      echo "\"$KEY\" = \"$value\";"
    } >> "$file"
  fi

  echo "  +  $locale: añadida con valor: $value"
  added=$((added + 1))
done

# Variantes regionales — DEBEN materializar la key (sin esto, un usuario con la
# variante como idioma de sistema vería la key cruda: iOS no hace fallback per-key).
# es-ES/es-AR heredan el valor real de es-419; en-GB/pt-PT reciben el placeholder
# (igual que en/pt-BR) para forzar su traducción. Override regional → editar a mano.
for variant in "es-ES" "es-AR" "en-GB" "pt-PT"; do
  file="$RESOURCES/$variant.lproj/Localizable.strings"
  if [ ! -f "$file" ]; then
    echo "  ⚠️  $variant: $file no existe — saltando"
    continue
  fi

  if grep -qE "^\"${KEY//./\\.}\" = " "$file"; then
    echo "  ✓  $variant: key '$KEY' ya existe — saltando"
    skipped=$((skipped + 1))
    continue
  fi

  case "$variant" in
    es-ES|es-AR) value="$VALUE_ES_419" ;;               # padre es-419 → valor real
    *)           value="$PLACEHOLDER $VALUE_ES_419" ;;  # en-GB←en, pt-PT←pt-BR → pendiente
  esac

  if [ -n "$COMMENT" ]; then
    {
      echo ""
      echo "/* $COMMENT */"
      echo "\"$KEY\" = \"$value\";"
    } >> "$file"
  else
    echo "\"$KEY\" = \"$value\";" >> "$file"
  fi

  echo "  +  $variant: añadida con valor: $value"
  added=$((added + 1))
done

echo ""
echo "✓ Resumen: $added añadidas, $skipped existentes."
echo ""
echo "Siguiente paso: traducir las keys [NEEDS_TRANSLATION] antes de commit."
echo "Tests CI fallarán mientras existan placeholders sin traducir:"
echo "  xcodebuild test -scheme Yala -only-testing:YalaTests/LocalizationParityTests"
echo ""
echo "Las variantes (es-ES/es-AR/en-GB/pt-PT) ya se materializaron. Si la key requiere"
echo "un override regional (peninsular/voseo/británico), edítalo manualmente en su .lproj."
