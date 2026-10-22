#!/bin/bash
# Informe de espacio en disco y de lo recuperable en un entorno de desarrollo iOS.
# Solo LEE. No borra nada. Lo consumen: el hook SessionStart (modo --guard) y /cerrar.
#
# Uso:
#   bash qa/scripts/disk-report.sh            # informe completo
#   bash qa/scripts/disk-report.sh --guard    # una línea, solo si hay poco espacio (para hooks)
#
# Por qué existe: con el disco casi lleno, CoreSimulator no consigue lanzar apps en los
# clones que crea xcodebuild y los XCUITest fallan con errores que NO mencionan el disco
# (`RequestDenied (SBMainWorkspace)`). Ese diagnóstico costó 11 días una vez. Ver la
# entrada cerrada del 2026-07-24 en TESTING-STRATEGY.md.

set -uo pipefail

UMBRAL_GB=${YALA_DISK_UMBRAL_GB:-25}

libre_gb() {
    df -g /System/Volumes/Data 2>/dev/null | awk 'NR==2 {print $4}'
}

tam() { # tamaño legible de una ruta, "-" si no existe
    [ -e "$1" ] || { echo "-"; return; }
    du -sh "$1" 2>/dev/null | cut -f1
}

LIBRE=$(libre_gb)
LIBRE=${LIBRE:-0}

if [ "${1:-}" = "--guard" ]; then
    if [ "$LIBRE" -lt "$UMBRAL_GB" ]; then
        echo "⚠️  Disco: quedan ${LIBRE} GB libres (umbral ${UMBRAL_GB} GB)."
        echo "   Con poco espacio los simuladores fallan al lanzar apps y los XCUITest"
        echo "   caen con errores que no mencionan el disco. Corre /cerrar para limpiar."
    fi
    exit 0
fi

echo "## Disco"
echo
df -h /System/Volumes/Data | awk 'NR==2 {printf "Libre: %s de %s (%s usado)\n", $4, $2, $5}'
if [ "$LIBRE" -lt "$UMBRAL_GB" ]; then
    echo "Estado: ⚠️  POR DEBAJO del umbral de ${UMBRAL_GB} GB — el simulador puede fallar."
else
    echo "Estado: ✓ por encima del umbral de ${UMBRAL_GB} GB."
fi

echo
echo "### Recuperable"
printf "%-46s %s\n" "Scratchpads de sesiones Claude" "$(tam /private/tmp/claude-501)"
printf "%-46s %s\n" "DerivedData (Xcode)" "$(tam "$HOME/Library/Developer/Xcode/DerivedData")"
printf "%-46s %s\n" "DerivedData (XcodeBuildMCP)" "$(tam "$HOME/Library/Developer/XcodeBuildMCP")"
printf "%-46s %s\n" "Simuladores (CoreSimulator/Devices)" "$(tam "$HOME/Library/Developer/CoreSimulator/Devices")"
printf "%-46s %s\n" "Archives de Xcode" "$(tam "$HOME/Library/Developer/Xcode/Archives")"
printf "%-46s %s\n" "Worktrees del repo (.claude/worktrees)" "$(tam .claude/worktrees)"

echo
echo "### Señales"
# `grep -c` sale con 1 cuando no hay coincidencias; sin el `|| true` el `|| echo 0`
# añadía una segunda línea a la salida ya correcta ("0").
CLONES=$(xcrun simctl list devices 2>/dev/null | grep -c "Clone " || true)
echo "Clones de simulador huérfanos: ${CLONES:-0}   (los deja atrás una corrida de tests interrumpida)"

BOOTED=$(xcrun simctl list devices booted 2>/dev/null | grep -c "Booted" || true)
echo "Simuladores arrancados: ${BOOTED:-0}"

WT=$(git worktree list 2>/dev/null | grep -c "detached HEAD" || true)
echo "Worktrees en detached HEAD: ${WT:-0}   (los limpia /cerrar)"

# Los snapshots locales de Time Machine retienen los bloques de lo que borras: puedes
# eliminar 30 GB y ver el espacio libre casi igual. Es LA razón por la que una limpieza
# parece no servir de nada. macOS los purga solo bajo presión, pero puedes forzarlo:
#   tmutil thinlocalsnapshots / <bytes> 4
SNAP=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c "com.apple.TimeMachine" || true)
echo "Snapshots locales de Time Machine: ${SNAP:-0}"
if [ "${SNAP:-0}" -gt 0 ]; then
    echo "   ↳ retienen el espacio de lo ya borrado. Si acabas de limpiar y el disco"
    echo "     no bajó, es esto: 'tmutil thinlocalsnapshots / 40000000000 4'"
fi

echo
echo "### Simuladores más pesados"
for d in "$HOME"/Library/Developer/CoreSimulator/Devices/*/; do
    [ -d "$d" ] || continue
    mb=$(du -sm "$d" 2>/dev/null | cut -f1)
    [ "${mb:-0}" -lt 500 ] && continue
    nombre=$(plutil -extract name raw "$d/device.plist" 2>/dev/null || echo "?")
    printf "%6s MB  %s  %s\n" "$mb" "$(basename "$d" | cut -c1-8)" "$nombre"
done | sort -rn
