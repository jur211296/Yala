#!/usr/bin/env bash
# Regenera `qa/ci-ui-tiempos.json`, la tabla de segundos por suite con que `ci-ui-tandas.sh` reparte
# la UI de la nocturna en tandas, a partir de los logs de uno o varios runs de `qa.yml`.
#
#   bash qa/scripts/ci-ui-tiempos.sh <run-id> [<run-id> …]           # escribe qa/ci-ui-tiempos.json
#   bash qa/scripts/ci-ui-tiempos.sh <run-id> --log-dir D            # un run, logs ya bajados en D (*.log)
#   bash qa/scripts/ci-ui-tiempos.sh <run-id> <run-id> --log-dir D   # varios: D/<run-id>/*.log
#
# POR QUÉ (2026-11-05). El reparto contaba casos y el coste por caso va de 10 s a más de 4 min: con
# ocho tandas iguales en casos, los pasos fueron de 54 a 92 min. Ver la cabecera de `ci-ui-tandas.sh`.
#
# VARIOS RUNS Y MEDIANA (2026-11-19). Con un solo run la tabla hereda sus accidentes: en el dispatch
# 44074738336 dos casos de `IAGuiadosUITests` tardaron 29 y 19 min con el runner congelado (los dos
# «passed»), y la suite pesó 73 min cuando en las otras dos noches pesó 24. Con varios runs cada suite
# pesa la MEDIANA de lo que sumó en los runs donde corrió, y cada caso cuenta como mucho `TOPE_CASO`
# s, el mismo tope por caso que el paso de UI aplica desde ese día
# (`-default-test-execution-time-allowance` en `qa.yml`): por encima, XCTest lo corta y no lo gasta.
# Una suite que solo corrió en uno de los runs (la tanda que la llevaba agotó su tope en los otros)
# pesa lo que sumó en ese.
#
# CUÁNDO. Cuando una tanda se descompense (una pasa de ~80 min de paso y otra va holgada) o tras
# cambiar mucho la suite. Mejor tres runs seguidos que uno: una tanda cortada por su tope deja sus
# suites con menos tiempo del real, y la mediana lo amortigua. El script se niega si alguna tanda de
# algún run no llegó a correr tests. Lo que tarda una suite es la suma de sus casos, reintentos
# incluidos: es lo que gasta el paso.
#
# Necesita `gh` con acceso al repo. No toca el simulador.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SALIDA="${UI_TIEMPOS_SALIDA:-$AQUI/../ci-ui-tiempos.json}"
USO="uso: ci-ui-tiempos.sh <run-id> [<run-id> …] [--log-dir D]"
RUNS=()
LOGS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --log-dir) LOGS="${2:?falta el directorio}"; shift 2 ;;
    ''|*[!0-9]*) echo "$USO" >&2; exit 2 ;;
    *) RUNS+=("$1"); shift ;;
  esac
done
[ "${#RUNS[@]}" -gt 0 ] || { echo "$USO" >&2; exit 2; }

# Un directorio de logs por run. Con un solo run y `--log-dir`, D puede ser ese directorio (como antes).
if [ -n "$LOGS" ]; then
  if [ "${#RUNS[@]}" -eq 1 ] && [ ! -d "$LOGS/${RUNS[0]}" ]; then
    RAIZ="$(mktemp -d)"
    trap 'rm -rf "$RAIZ"' EXIT
    ln -s "$(cd "$LOGS" && pwd)" "$RAIZ/${RUNS[0]}"
    LOGS="$RAIZ"
  fi
else
  LOGS="$(mktemp -d)"
  trap 'rm -rf "$LOGS"' EXIT
  for run in "${RUNS[@]}"; do
    mkdir -p "$LOGS/$run"
    jobs=$(gh api "repos/{owner}/{repo}/actions/runs/$run/jobs" --paginate \
      --jq '.jobs[] | select(.name | startswith("UI tests (tanda")) | .id')
    [ -n "$jobs" ] || { echo "ci-ui-tiempos: el run $run no tiene tandas de UI" >&2; exit 2; }
    # En serie: varias descargas a la vez de `gh run view --log` comparten caché y devuelven
    # «zip: not a valid zip file» (medido el 2026-11-19).
    for j in $jobs; do
      gh run view "$run" --job "$j" --log > "$LOGS/$run/$j.log"
    done
  done
fi

python3 -I - "$LOGS" "$SALIDA" "${RUNS[@]}" <<'PY'
import datetime, glob, json, os, re, statistics, sys

logs, salida, runs = sys.argv[1], sys.argv[2], sys.argv[3:]
# El tope por caso del paso de UI (`qa.yml`, `-default-test-execution-time-allowance`).
TOPE_CASO = 600
# `skipped` también: una suite que se salta entera (vídeos de tutorial, medidas de carga) cuesta casi nada, y sin su
# fila pesaría 46 s por caso y descompensaría su tanda (33 casos de `TutorialVideoRecordingUITests` = 25 min fantasma).
caso = re.compile(r"Test Case '-\[YalaUITests\.(\w+) \w+\]' (?:passed|failed|skipped) \(([\d.]+) seconds\)")
por_run, vacias = [], []
for run in runs:
    ficheros = sorted(glob.glob(os.path.join(logs, run, "*.log")))
    if not ficheros:
        print(f"ci-ui-tiempos: no hay logs del run {run} en {logs}", file=sys.stderr); sys.exit(2)
    suites = {}
    for f in ficheros:
        n = 0
        for linea in open(f, encoding="utf-8", errors="replace"):
            m = caso.search(linea)
            if m:
                suites[m.group(1)] = suites.get(m.group(1), 0) + min(float(m.group(2)), TOPE_CASO); n += 1
        if n == 0:
            vacias.append(f"{run}/{os.path.basename(f)}")
    por_run.append(suites)
if vacias:
    print(f"ci-ui-tiempos: tandas sin un solo caso ({', '.join(vacias)}): ese run no sirve, elige otro completo",
          file=sys.stderr)
    sys.exit(2)
todas = sorted(set().union(*por_run))
tabla = {
    "_meta": {
        "runs": [int(r) for r in runs],
        "generado": datetime.date.today().isoformat(),
        "como": "bash qa/scripts/ci-ui-tiempos.sh <run-id> [<run-id> …]; segundos por suite, reintentos incluidos, "
                f"mediana entre runs y cada caso con tope de {TOPE_CASO} s",
    },
    "suites": {s: round(statistics.median([d[s] for d in por_run if s in d])) for s in todas},
}
with open(salida, "w", encoding="utf-8") as fh:
    json.dump(tabla, fh, indent=2, ensure_ascii=False); fh.write("\n")
print(f"ci-ui-tiempos: {len(todas)} suites de {len(runs)} run(s), {round(sum(tabla['suites'].values()) / 60)} min → {salida}",
      file=sys.stderr)
PY
