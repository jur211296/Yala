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
# las reparte por lo que TARDAN (la más pesada primero, a la tanda más ligera). Así una suite nueva
# entra en una tanda sin que nadie toque el YAML.
#
# POR MINUTOS, NO POR CASOS (2026-11-05, dispatch 41931406144). Hasta ese día pesaba cada fichero por
# su número de `func test`. Con ocho tandas de ~90 casos cada una, los pasos de UI fueron de 54 a 92
# min: el coste por caso va de 10 s a más de 4 min y la tanda 3 se llevaba las lentas. Simulado con
# los tiempos de esa noche, 9 tandas por casos dejaban la más larga en ~77 min de paso y 10 en ~80;
# 9 por minutos, en ~68. El peso de un fichero sale ahora de `qa/ci-ui-tiempos.json` (segundos por
# suite, medidos en una nocturna; se regenera con `qa/scripts/ci-ui-tiempos.sh <run>`). Una suite
# que no esté en la tabla —nueva, o renombrada— pesa 46 s por caso, la media medida en el runner.
# Si la tabla envejece, las tandas se descompensan; ninguna suite se queda sin correr.
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
# `UI_TIEMPOS` cambia la tabla de tiempos; lo usa el banco. Si no existe, todo pesa 46 s por caso.
TIEMPOS="${UI_TIEMPOS:-$AQUI/../ci-ui-tiempos.json}"
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

python3 -I - "$DIR" "$TANDA" "$TOTAL" "$TIEMPOS" <<'PY'
import json, os, re, sys

raiz, tanda, total, ruta_tiempos = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
# Segundos por caso de una suite que la tabla no conoce: la media medida en el runner (qa.yml, «POR QUE OCHO»).
POR_CASO = 46
tiempos = {}
if os.path.isfile(ruta_tiempos):
    try:
        tiempos = json.load(open(ruta_tiempos, encoding="utf-8"))["suites"]
    except (ValueError, KeyError, TypeError) as e:
        # Una tabla rota no puede dejar el paso sin lista: se avisa y se reparte por casos.
        print(f"ci-ui-tandas: tabla de tiempos ilegible ({e}); reparto por casos", file=sys.stderr)
        tiempos = {}
clase = re.compile(r"^\s*(?:(?:final|public|internal|open|@MainActor)\s+)*class\s+(\w+)\s*:\s*XCTestCase\b", re.M)
test = re.compile(r"^\s*(?:@MainActor\s+)?func\s+test\w*\s*\(", re.M)

# Un grupo por fichero: sus clases van juntas y pesan lo que suman sus tiempos medidos. Si alguna
# clase del fichero no está en la tabla, el fichero entero pesa por sus casos (no se sabe cuántos
# son de la clase nueva), salvo que lo medido de las otras ya pese más.
def peso_de(casos, clases):
    medidos = [tiempos[c] for c in clases if isinstance(tiempos.get(c), (int, float))]
    if len(medidos) == len(clases):
        return max(1, round(sum(medidos)))
    return max(round(sum(medidos)), casos * POR_CASO)

grupos = []
for d, _, fs in os.walk(raiz):
    for f in sorted(fs):
        if not f.endswith(".swift"):
            continue
        texto = open(os.path.join(d, f), encoding="utf-8", errors="replace").read()
        clases = clase.findall(texto)
        if clases:
            casos = max(1, len(test.findall(texto)))
            grupos.append((peso_de(casos, clases), sorted(clases), casos))

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
ncasos = [0] * total
suites = [[] for _ in range(total)]
for w, cs, n in grupos:
    i = min(range(total), key=lambda k: (peso[k], k))
    peso[i] += w
    ncasos[i] += n
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
    print(f"ci-ui-tandas: tanda {tanda} de {total} — {len(suites[tanda - 1])} suites, {ncasos[tanda - 1]} casos, "
          f"{peso[tanda - 1]} s: "
          + " ".join(suites[tanda - 1]), file=sys.stderr)
else:
    print("-only-testing:YalaUITests")
    otras = sorted(s for k in range(total - 1) for s in suites[k])
    for s in otras:
        print(f"-skip-testing:YalaUITests/{s}")
    print(f"ci-ui-tandas: tanda {tanda} de {total} — el resto del target; descubiertas {len(suites[tanda - 1])} suites, "
          f"{ncasos[tanda - 1]} casos, {peso[tanda - 1]} s: " + " ".join(suites[tanda - 1]), file=sys.stderr)
PY
