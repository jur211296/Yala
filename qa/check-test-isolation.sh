#!/usr/bin/env bash
#
# check-test-isolation.sh — anti-drift guard para el aislamiento de tests.
#
# `makeTestContext()` (YalaTests/TestHelpers.swift) REUSA un ModelContainer por archivo
# (`_testContainersByFile`). El reset entre tests (rollback + wipeAllModels) solo es seguro
# si la suite corre en SERIE. Una suite NO `.serialized` corre sus @Test en paralelo → se
# pisan el store compartido → falsos rojos order-dependent (p.ej. el incidente de
# CategoryDeduplicationServiceTests / LocaleResolutionTests, 2026-07-06).
#
# Este check FALLA si algún archivo que llama `makeTestContext(` no declara `.serialized`.
# Correr en CI junto a los tests.

set -euo pipefail
cd "$(dirname "$0")/.."

missing=()
while IFS= read -r file; do
    if ! grep -q '\.serialized' "$file"; then
        missing+=("$file")
    fi
done < <(grep -rl 'makeTestContext(' YalaTests/ --include='*.swift')

if [ ${#missing[@]} -ne 0 ]; then
    echo "❌ Aislamiento de tests roto: estos archivos llaman makeTestContext( pero NO son @Suite(.serialized):"
    for f in "${missing[@]}"; do echo "   - $f"; done
    echo ""
    echo "Fix: añade @Suite(.serialized) a la struct de la suite (ver YalaTests/TestHelpers.swift:makeTestContext)."
    exit 1
fi

count=$(grep -rl 'makeTestContext(' YalaTests/ --include='*.swift' | wc -l | tr -d ' ')
echo "✅ Aislamiento de tests OK: los $count archivos que usan makeTestContext( son .serialized"
