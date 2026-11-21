#!/usr/bin/env bash
# Reparte los unit de `YalaTests` en N tandas para el job `unit` de `.github/workflows/qa.yml` e
# imprime los argumentos de `xcodebuild` de UNA tanda, uno por línea.
#
#   bash qa/scripts/ci-unit-tandas.sh <tanda> <total>   # pure-logic de esa tanda (1..total)
#   bash qa/scripts/ci-unit-tandas.sh contexto           # las clases context-based
#
# POR QUÉ (2026-11-21, auditoría de tiempos del CI). Pure-logic corría entero en un runner: ~23 min
# de paso (15 453 casos), detrás de un build de ~27. Partido en tres runners que corren a la vez,
# el paso baja a un tercio más el arranque de cada `xcodebuild test` (~3 min).
#
# CONTEXT-BASED VA EN LA TANDA 1. Sus 7 clases crean un ModelContext in-memory y corren en su propio
# `xcodebuild` (ver el job). Antes esperaban a que acabara todo pure-logic; ahora corren en la
# tanda 1, a la vez que las tandas 2 y 3, y el reparto le resta su peso a esa tanda
# (`_meta.contexto_s` de la tabla). La lista de esas clases vive SOLO aquí: el paso de context-based
# la pide con `contexto` y las tandas de pure-logic las excluyen.
#
# POR TIEMPOS. Cada suite pesa lo que mide `qa/ci-unit-tiempos.json` (segundos por suite, sacados
# del `.xcresult` de cada tanda con `ci-unit-tiempos.py`). Una suite que la tabla no conoce pesa
# `_meta.por_caso_s` por cada `@Test` de su código. Greedy determinista: la más pesada primero, a
# la tanda más ligera. Una tabla vieja descompensa; nunca deja una suite fuera.
#
# NINGUNA SUITE SE QUEDA FUERA, POR CONSTRUCCIÓN (como `ci-ui-tandas.sh`). Las tandas 1..N-1 llevan
# su lista explícita (`-only-testing:YalaTests/<Suite>`). La ÚLTIMA corre el target entero menos lo
# de las otras y menos context-based (`-only-testing:YalaTests` + `-skip-testing:…`): una suite que
# el descubrimiento no vea, o una función `@Test` suelta, la corre la última igual.
#
# Falla (exit 2) sin imprimir argumentos si la entrada no cuadra o si no descubre ninguna suite.
# `UNIT_TESTS_DIR` cambia la carpeta y `UNIT_TIEMPOS` la tabla; los usa el banco
# (`ci-unit-tandas-test.sh`). Sin tabla, todo pesa por casos.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"

exec python3 -I - "$@" "$AQUI/suites-de-fichero.py" \
  "${UNIT_TESTS_DIR:-$RAIZ/YalaTests}" "${UNIT_TIEMPOS:-$RAIZ/qa/ci-unit-tiempos.json}" <<'PY'
import importlib.util, json, os, re, sys

*args, ruta_sdf, raiz, ruta_tiempos = sys.argv[1:]

# Las 7 clases que crean un ModelContext: van en su propio `xcodebuild`, nunca con pure-logic.
CONTEXTO = [
    "BudgetFilterRegressionTests",
    "CategoryDeduplicationServiceTests",
    "ChatAssistantViewModelTests",
    "CurrencyConverterCacheTests",
    "ICloudAccountSummaryTests",
    "InitialBalanceServiceTests",
    "UserSegmentServiceTests",
]

def fallo(msg):
    print(f"ci-unit-tandas: {msg}", file=sys.stderr)
    sys.exit(2)

if args == ["contexto"]:
    for c in CONTEXTO:
        print(f"-only-testing:YalaTests/{c}")
    print(f"ci-unit-tandas: context-based — {len(CONTEXTO)} clases", file=sys.stderr)
    sys.exit(0)

if len(args) != 2 or not all(a.isdigit() for a in args):
    fallo("uso: ci-unit-tandas.sh <tanda> <total> | contexto")
tanda, total = int(args[0]), int(args[1])
if not (1 <= tanda <= total):
    fallo(f"tanda {tanda} fuera de 1..{total}")

spec = importlib.util.spec_from_file_location("sdf", ruta_sdf)
sdf = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sdf)

meta, tiempos = {}, {}
if os.path.isfile(ruta_tiempos):
    try:
        datos = json.load(open(ruta_tiempos, encoding="utf-8"))
        tiempos, meta = datos["suites"], datos.get("_meta", {})
    except (ValueError, KeyError, TypeError) as e:
        print(f"ci-unit-tandas: tabla de tiempos ilegible ({e}); reparto por casos", file=sys.stderr)
        tiempos, meta = {}, {}
POR_CASO = float(meta.get("por_caso_s", 0.08))
CONTEXTO_S = float(meta.get("contexto_s", 240))

# Casos por suite: los `@Test` del tramo de cada tipo de columna 0 (los anidados cuentan para el de
# fuera). Una suite repartida en varios ficheros (`extension`) suma los de todos.
TEST = re.compile(r'(?<![\w.])@Test\b')
casos = {}
for d, _, fs in os.walk(raiz):
    for f in sorted(fs):
        if not f.endswith(".swift"):
            continue
        codigo = sdf.sin_comentarios(open(os.path.join(d, f), encoding="utf-8", errors="replace").read())
        propias = set(sdf.suites(codigo))
        actual = None
        for linea in codigo.split("\n"):
            if linea[:1] not in ("", " ", "\t", "}", ")", "]"):
                m = sdf.DECL.match(linea)
                if m:
                    actual = m.group(2) if m.group(2) in propias else None
            if actual and TEST.search(linea):
                casos[actual] = casos.get(actual, 0) + 1
        for s in propias:
            casos.setdefault(s, 0)

suites = sorted(s for s in casos if s not in CONTEXTO)
if not suites:
    fallo(f"ninguna suite en {raiz}")

def peso(s):
    t = tiempos.get(s)
    if isinstance(t, (int, float)):
        return float(t)
    return max(1, casos[s]) * POR_CASO

if total == 1:
    print("-only-testing:YalaTests")
    for c in CONTEXTO:
        print(f"-skip-testing:YalaTests/{c}")
    print(f"ci-unit-tandas: tanda 1 de 1 — pure-logic entero ({len(suites)} suites)", file=sys.stderr)
    sys.exit(0)

carga = [0.0] * total
carga[0] = CONTEXTO_S  # la tanda 1 corre además context-based
grupos = [[] for _ in range(total)]
for s in sorted(suites, key=lambda s: (-peso(s), s)):
    i = min(range(total), key=lambda k: (carga[k], k))
    carga[i] += peso(s)
    grupos[i].append(s)

vacias = [k + 1 for k in range(total) if not grupos[k]]
if vacias:
    fallo(f"{total} tandas para {len(suites)} suites deja vacías las tandas {vacias}")

mias = sorted(grupos[tanda - 1])
resumen = (f"{len(mias)} suites, {sum(casos[s] for s in mias)} @Test, "
           f"{round(carga[tanda - 1])} s estimados" + (" (con context-based)" if tanda == 1 else ""))
if tanda < total:
    for s in mias:
        print(f"-only-testing:YalaTests/{s}")
    print(f"ci-unit-tandas: tanda {tanda} de {total} — {resumen}", file=sys.stderr)
else:
    print("-only-testing:YalaTests")
    for s in sorted(set(CONTEXTO) | {s for k in range(total - 1) for s in grupos[k]}):
        print(f"-skip-testing:YalaTests/{s}")
    print(f"ci-unit-tandas: tanda {tanda} de {total} — el resto del target; descubiertas {resumen}", file=sys.stderr)
PY
