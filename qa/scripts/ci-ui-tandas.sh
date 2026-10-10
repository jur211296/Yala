#!/usr/bin/env bash
# Reparte la suite de UI (`YalaUITests`) en N tandas para el job `ui` de `.github/workflows/qa.yml`
# e imprime los argumentos de `xcodebuild` de UNA tanda, uno por línea.
#
#   bash qa/scripts/ci-ui-tandas.sh <tanda> <total>     # tanda: 1..total
#
# POR QUÉ EXISTE (2026-10-09, ticket nightly-ui-suite-hits-its-110-minute-cap-every-night). La suite
# entera, en serie y en un solo runner, ya no cabía: del 2 al 8 de octubre el paso de UI agotó sus
# 110 min todas las noches, y solo corrían 65 de las 85 suites — siempre las mismas, por orden
# alfabético. Partida en tandas que corren en paralelo, cada una en su runner, la suite entera corre
# cada noche.
#
# EL REPARTO SALE DEL ÁRBOL, NO DE UNA LISTA. Descubre las clases `XCTestCase` de `YalaUITests/` y
# las reparte por número de `func test` de su fichero (la más pesada primero, a la tanda más
# ligera). Así una suite nueva entra en una tanda sin que nadie toque el YAML.
#
# NINGUNA SUITE SE QUEDA FUERA, POR CONSTRUCCIÓN. Las tandas 1..N-1 llevan su lista explícita
# (`-only-testing:YalaUITests/<Suite>`). La ÚLTIMA no: corre el target entero menos lo de las otras
# (`-only-testing:YalaUITests` + `-skip-testing:...`). Si mañana una suite hereda de una clase base
# propia y el descubrimiento no la ve, la corre la última tanda igual. El peor caso es una tanda
# descompensada, nunca una suite sin correr.
#
# Falla (exit 2) sin imprimir argumentos si la entrada no cuadra o si no descubre ninguna suite:
# un paso de UI que arrancara con una lista vacía correría el target entero en cada tanda.
#
# `UI_TESTS_DIR` cambia la carpeta que se recorre; lo usa el banco (`ci-ui-tandas-test.sh`).
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
DIR="${UI_TESTS_DIR:-$AQUI/../../YalaUITests}"
TANDA="${1:-}"
TOTAL="${2:-}"

case "$TANDA$TOTAL" in
  ''|*[!0-9]*) echo "uso: ci-ui-tandas.sh <tanda> <total>" >&2; exit 2 ;;
esac
if [ "$TOTAL" -lt 1 ] || [ "$TANDA" -lt 1 ] || [ "$TANDA" -gt "$TOTAL" ]; then
  echo "ci-ui-tandas: tanda $TANDA de $TOTAL fuera de rango" >&2
  exit 2
fi
[ -d "$DIR" ] || { echo "ci-ui-tandas: no existe $DIR" >&2; exit 2; }

python3 -I - "$DIR" "$TANDA" "$TOTAL" <<'PY'
import os, re, sys

raiz, tanda, total = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
clase = re.compile(r"^\s*(?:(?:final|public|internal|open|@MainActor)\s+)*class\s+(\w+)\s*:\s*XCTestCase\b", re.M)
test = re.compile(r"^\s*(?:@MainActor\s+)?func\s+test\w*\s*\(", re.M)

# Un grupo por fichero: sus clases van juntas y pesan lo que suman sus `func test`.
grupos = []
for d, _, fs in os.walk(raiz):
    for f in sorted(fs):
        if not f.endswith(".swift"):
            continue
        texto = open(os.path.join(d, f), encoding="utf-8", errors="replace").read()
        clases = clase.findall(texto)
        if clases:
            grupos.append((max(1, len(test.findall(texto))), sorted(clases)))

if not grupos:
    print(f"ci-ui-tandas: ninguna clase XCTestCase en {raiz}", file=sys.stderr)
    sys.exit(2)

if total == 1:
    print("-only-testing:YalaUITests")
    print(f"ci-ui-tandas: tanda 1 de 1 — el target entero ({len(grupos)} ficheros)", file=sys.stderr)
    sys.exit(0)

# Greedy determinista: el grupo más pesado primero (empate: por nombre), a la tanda más ligera
# (empate: la de índice menor).
grupos.sort(key=lambda g: (-g[0], g[1][0]))
peso = [0] * total
suites = [[] for _ in range(total)]
for w, cs in grupos:
    i = min(range(total), key=lambda k: (peso[k], k))
    peso[i] += w
    suites[i].extend(cs)

vacias = [k + 1 for k in range(total) if not suites[k]]
if vacias:
    print(f"ci-ui-tandas: {total} tandas para {len(grupos)} ficheros deja vacías las tandas {vacias}", file=sys.stderr)
    sys.exit(2)

for k in range(total):
    suites[k].sort()

if tanda < total:
    for s in suites[tanda - 1]:
        print(f"-only-testing:YalaUITests/{s}")
    print(f"ci-ui-tandas: tanda {tanda} de {total} — {len(suites[tanda - 1])} suites, {peso[tanda - 1]} casos: "
          + " ".join(suites[tanda - 1]), file=sys.stderr)
else:
    print("-only-testing:YalaUITests")
    otras = sorted(s for k in range(total - 1) for s in suites[k])
    for s in otras:
        print(f"-skip-testing:YalaUITests/{s}")
    print(f"ci-ui-tandas: tanda {tanda} de {total} — el resto del target; descubiertas {len(suites[tanda - 1])} suites, "
          f"{peso[tanda - 1]} casos: " + " ".join(suites[tanda - 1]), file=sys.stderr)
PY
