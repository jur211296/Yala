#!/bin/bash
# Banco de pruebas de `gate-ci-checks.sh`.
#
#   bash qa/scripts/gate-ci-checks-test.sh
#
# **Por qué existe.** `gate-ci-checks.sh` es lo que hace que el `/gate` corra lo mismo que el job
# `coverage-index`. Si deja de leer un paso, no da error: el gate vuelve a dar verde a lo que el
# CI bloquea, que es el fallo del 2026-09-08. Cada caso es un `qa.yml` de mentira bajo TMPDIR con
# pasos que solo hacen `true`/`false`/`echo`. El último caso lee el `qa.yml` real con `--listar`
# y exige que salga el check de aislamiento (el que el gate se saltaba).
#
# No compila nada ni toca el simulador: corre en Linux, en el job `coverage-index`.
#
# Exit: 0 = todos los casos pasan · 1 = alguno falla
set -u
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SH="$RAIZ/qa/scripts/gate-ci-checks.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/gate-ci-checks-test.XXXXXX")" || { echo "no se pudo crear el temporal" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT

fallos=0
n=0

# caso <nombre> <exit esperado> <texto que debe salir> — el YAML va por stdin, el job se llama `ci`.
caso() {
  local nombre="$1" exit_esperado="$2" debe="$3"
  n=$((n + 1))
  local y="$TMP/caso$n.yml"
  cat > "$y"
  local salida rc
  salida="$(bash "$SH" --workflow "$y" --job ci 2>&1)"; rc=$?
  if [ "$rc" = "$exit_esperado" ] && printf '%s\n' "$salida" | grep -qF -- "$debe"; then
    echo "  ✓ ${n}. ${nombre}"
  else
    echo "  ✗ ${n}. ${nombre} — exit ${rc} (esperado ${exit_esperado}), sin «${debe}» en:"
    printf '%s\n' "$salida" | sed 's/^/        /'
    fallos=$((fallos + 1))
  fi
}

echo "── gate-ci-checks"

caso "todos los pasos en verde, también el que va detrás de un comentario" 0 "los 3 pasos del job «ci» en verde" <<'YAML'
jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Uno
        run: true
      # Un comentario entre pasos, con run: dentro, no es un paso.
      - name: Dos
        run: echo dos
      - run: true
  otro:
    steps:
      - run: false
YAML

caso "un paso en rojo pone el script en rojo y lo nombra" 1 "✗ 2/3 false" <<'YAML'
jobs:
  ci:
    steps:
      - run: true
      - run: false
      - run: true
YAML

caso "un paso en rojo no impide correr los siguientes" 1 "✓ 3/3 echo tercero" <<'YAML'
jobs:
  ci:
    steps:
      - run: true
      - run: false
      - run: echo tercero
YAML

caso "el job de otro nombre no cuenta: solo lee el bloque pedido" 0 "los 1 pasos" <<'YAML'
jobs:
  antes:
    steps:
      - run: false
  ci:
    steps:
      - run: true
  despues:
    steps:
      - run: false
YAML

caso "un run: multilínea no se salta: exit 2" 2 "multilínea" <<'YAML'
jobs:
  ci:
    steps:
      - run: true
      - name: Varias líneas
        run: |
          echo uno
          false
YAML

caso "un if: en un paso no se salta: exit 2" 2 "no replica" <<'YAML'
jobs:
  ci:
    steps:
      - name: Condicional
        if: github.event_name == 'push'
        run: false
YAML

caso "un env: en el job no se salta: exit 2" 2 "no replica" <<'YAML'
jobs:
  ci:
    env:
      X: 1
    steps:
      - run: true
YAML

caso "sin el job: exit 2" 2 "no encuentro el job" <<'YAML'
jobs:
  otro:
    steps:
      - run: true
YAML

caso "un job sin pasos run: exit 2" 2 "ningún paso run:" <<'YAML'
jobs:
  ci:
    steps:
      - uses: actions/checkout@v4
YAML

# El qa.yml real: tiene que salir el check que el gate se saltaba, y el banco de este mismo
# script (si un día se borra del CI, se vuelve a correr solo a mano).
n=$((n + 1))
real="$(bash "$SH" --listar 2>&1)"; rc=$?
if [ "$rc" = 0 ] \
   && printf '%s\n' "$real" | grep -qx 'bash qa/check-test-isolation.sh' \
   && printf '%s\n' "$real" | grep -qx 'python3 qa/validate-coverage.py' \
   && printf '%s\n' "$real" | grep -qx 'bash qa/scripts/gate-ci-checks-test.sh'; then
  echo "  ✓ ${n}. qa.yml real: $(printf '%s\n' "$real" | wc -l | tr -d ' ') pasos, con el aislamiento, el índice y este banco"
else
  echo "  ✗ ${n}. qa.yml real (exit ${rc}):"; printf '%s\n' "$real" | sed 's/^/        /'
  fallos=$((fallos + 1))
fi

if [ "$fallos" -ne 0 ]; then
  echo "── gate-ci-checks: ${fallos} de ${n} casos en rojo."
  exit 1
fi
echo "── gate-ci-checks: ${n}/${n} casos en verde."
