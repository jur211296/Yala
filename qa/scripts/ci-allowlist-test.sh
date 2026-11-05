#!/bin/bash
# Prueba la decisión del job `changes` de `.github/workflows/qa.yml`: qué diffs encolan el
# runner de simulador (~100 min) y cuáles se saltan la suite.
#
# Por qué existe: esa lista es fácil de ampliar de más. Una ruta añadida sin medir deja de
# probar código de verdad, y el fallo es SILENCIOSO — sale verde igual, solo que sin haber
# probado nada. El caso `qa/scripts/` es el que más importa: está al lado de `qa/cloud/`
# pero decide CÓMO se verifica el proyecto, así que debe seguir disparando la suite.
#
# No copia el `case`: lo EXTRAE del workflow, para que el test no pueda divergir de él.
#
#   bash qa/scripts/ci-allowlist-test.sh
#
# Sale 0 si los 15 casos pasan. Al tocar la allowlist, volver a dejarlo en 15/15 y añadir
# el caso nuevo — con su gemelo negativo, la ruta vecina que NO debe saltarse.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)" || exit 1

WF=".github/workflows/qa.yml"
[ -f "$WF" ] || { echo "no encuentro $WF"; exit 1; }

CASE_BLOCK=$(awk '/case "\$file" in/,/^ *esac$/' "$WF")
[ -n "$CASE_BLOCK" ] || { echo "no pude extraer el case de $WF"; exit 1; }

# Replica el bucle del workflow: basta UN fichero fuera de la allowlist para correr.
decide() {
    local culprit=""
    for file in "$@"; do
        for _ in 1; do eval "$CASE_BLOCK"; done
        [ -n "$culprit" ] && break
    done
    [ -z "$culprit" ] && echo "SALTA" || echo "CORRE"
}

ok=0; ko=0
t() { # esperado  descripcion  ficheros...
    local esp="$1" desc="$2"; shift 2
    local got; got=$(decide "$@")
    if [ "$got" = "$esp" ]; then echo "  ✓ $desc → $got"; ok=$((ok+1))
    else echo "  ✘ $desc → $got (esperado $esp)"; ko=$((ko+1)); fi
}

echo "== Se salta la suite: nada de esto es input de xcodebuild"
t SALTA "solo el Worker"                     gateway/test/sync.goldens.test.ts gateway/src/index.ts
t SALTA "solo scripts de staging"            qa/cloud/cross-user-rls-test.sh qa/cloud/README.md
t SALTA "solo documentacion"                 docs/ESTADO.md tickets/x.md README.md
t SALTA "marketing y web"                    marketing/ficha.md Web/index.html
t SALTA "solo el encargo de la sesion"       encargos/lanzados/2026-11-04-lote-t6-ci.md
t SALTA "encargo + ticket + docs"            encargos/lanzados/x.md tickets/done/y.md docs/z.md

echo "== Sigue corriendo: esto SI decide como se construye o se verifica"
t CORRE "qa/scripts (el vecino de qa/cloud)" qa/scripts/worktree-stamp.sh
t CORRE "el validador del indice"            qa/validate-coverage.py
t CORRE "codigo de la app"                   Yala/App/Views/Panel/PanelView.swift
t CORRE "tests de la app"                    YalaTests/CloudSync/StagingTestCredentials.swift
t CORRE "el proyecto Xcode"                  Yala.xcodeproj/project.pbxproj
t CORRE "el propio workflow"                 "$WF"
t CORRE "un no-markdown en encargos/"        encargos/lanzados/x.sh

echo "== Deny-by-default: basta UNO fuera de la allowlist"
t CORRE "gateway + codigo de la app juntos"  gateway/src/index.ts Yala/App/YalaApp.swift
t CORRE "docs + un swift"                    docs/ESTADO.md Yala/Models/SplitGroup.swift

echo
echo "RESULTADO: $ok ok · $ko fallos"
[ "$ko" -eq 0 ]
