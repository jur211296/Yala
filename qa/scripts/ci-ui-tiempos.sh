#!/usr/bin/env bash
# Regenera `qa/ci-ui-tiempos.json`, la tabla de segundos por suite con que `ci-ui-tandas.sh` reparte
# la UI de la nocturna en tandas, a partir de los logs de un run de `qa.yml`.
#
#   bash qa/scripts/ci-ui-tiempos.sh <run-id>            # escribe qa/ci-ui-tiempos.json
#   bash qa/scripts/ci-ui-tiempos.sh <run-id> --log-dir D # lee los logs ya bajados en D (*.log)
#
# POR QUÉ (2026-11-05). El reparto contaba casos y el coste por caso va de 10 s a más de 4 min: con
# ocho tandas iguales en casos, los pasos fueron de 54 a 92 min. Ver la cabecera de `ci-ui-tandas.sh`.
#
# CUÁNDO. Cuando una tanda se descompense (una pasa de ~80 min de paso y otra va holgada) o tras
# cambiar mucho la suite. Usa un run en el que corrieran TODAS las tandas: una tanda cortada por su
# tope deja sus suites con menos tiempo del real. El script se niega si alguna tanda no llegó a correr
# tests. Lo que tarda una suite es la suma de sus casos, reintentos incluidos: es lo que gasta el paso.
#
# Necesita `gh` con acceso al repo. No toca el simulador.
set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SALIDA="${UI_TIEMPOS_SALIDA:-$AQUI/../ci-ui-tiempos.json}"
RUN="${1:-}"
case "$RUN" in ''|*[!0-9]*) echo "uso: ci-ui-tiempos.sh <run-id> [--log-dir D]" >&2; exit 2 ;; esac
shift
LOGS=""
if [ "${1:-}" = "--log-dir" ]; then LOGS="${2:?falta el directorio}"; fi

if [ -z "$LOGS" ]; then
  LOGS="$(mktemp -d)"
  trap 'rm -rf "$LOGS"' EXIT
  jobs=$(gh api "repos/{owner}/{repo}/actions/runs/$RUN/jobs" --paginate \
    --jq '.jobs[] | select(.name | startswith("UI tests (tanda")) | .id')
  [ -n "$jobs" ] || { echo "ci-ui-tiempos: el run $RUN no tiene tandas de UI" >&2; exit 2; }
  for j in $jobs; do
    gh run view "$RUN" --job "$j" --log > "$LOGS/$j.log"
  done
fi

python3 -I - "$LOGS" "$RUN" "$SALIDA" <<'PY'
import datetime, glob, json, os, re, sys

logs, run, salida = sys.argv[1], sys.argv[2], sys.argv[3]
# `skipped` también: una suite que se salta entera (vídeos de tutorial, medidas de carga) cuesta casi nada, y sin su
# fila pesaría 46 s por caso y descompensaría su tanda (33 casos de `TutorialVideoRecordingUITests` = 25 min fantasma).
caso = re.compile(r"Test Case '-\[YalaUITests\.(\w+) \w+\]' (?:passed|failed|skipped) \(([\d.]+) seconds\)")
suites, vacias = {}, []
ficheros = sorted(glob.glob(os.path.join(logs, "*.log")))
if not ficheros:
    print(f"ci-ui-tiempos: no hay logs en {logs}", file=sys.stderr); sys.exit(2)
for f in ficheros:
    n = 0
    for linea in open(f, encoding="utf-8", errors="replace"):
        m = caso.search(linea)
        if m:
            suites[m.group(1)] = suites.get(m.group(1), 0) + float(m.group(2)); n += 1
    if n == 0:
        vacias.append(os.path.basename(f))
if vacias:
    print(f"ci-ui-tiempos: tandas sin un solo caso ({', '.join(vacias)}): el run no sirve, elige uno completo",
          file=sys.stderr)
    sys.exit(2)
tabla = {
    "_meta": {
        "run": int(run),
        "generado": datetime.date.today().isoformat(),
        "como": "bash qa/scripts/ci-ui-tiempos.sh <run-id>; segundos por suite, reintentos incluidos",
    },
    "suites": {k: round(v) for k, v in sorted(suites.items())},
}
with open(salida, "w", encoding="utf-8") as fh:
    json.dump(tabla, fh, indent=2, ensure_ascii=False); fh.write("\n")
print(f"ci-ui-tiempos: {len(suites)} suites, {round(sum(suites.values()) / 60)} min → {salida}", file=sys.stderr)
PY
