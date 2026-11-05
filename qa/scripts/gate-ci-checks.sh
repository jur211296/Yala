#!/bin/bash
# gate-ci-checks.sh — corre en local TODO lo que corre el job `coverage-index` del CI.
#
#   bash qa/scripts/gate-ci-checks.sh                       # lee .github/workflows/qa.yml
#   bash qa/scripts/gate-ci-checks.sh --workflow F --job J  # el banco pasa otro YAML
#   bash qa/scripts/gate-ci-checks.sh --listar              # solo enseña los pasos, no corre nada
#
# **Por qué existe.** El paso 5 del `/gate` corría `validate-coverage.sh` y nada más, pero el job
# `coverage-index` —un check que el ruleset exige para mergear— ya tenía doce pasos. El
# 2026-09-08 una suite con `makeTestContext()` sin `.serialized` pasó el gate entero y el CI la
# tumbó a los 17 segundos (`qa/check-test-isolation.sh`, que el gate no corría). Con el commit
# directo desde el árbol principal no hay CI antes de aterrizar: el gate es la única red.
#
# **Por qué lee el YAML y no repite la lista.** Una lista copiada a mano ya divergió una vez (de
# 2 pasos a 12 sin que el gate se enterara). Aquí la lista es la del CI, sin copia.
#
# **Fail-closed.** Este script solo sabe correr pasos `run:` de una línea. Si el job trae algo
# que no sabe replicar —un `run:` multilínea, un `if:`, un `env:` o un `working-directory:` en un
# paso— o si no encuentra el job o ningún paso, sale con 2 y lo dice. Un paso saltado en silencio
# sería justo el fallo que vino a quitar. Los `uses:` (el checkout) no hacen falta en local.
#
# Exit: 0 = todos los pasos en verde · 1 = alguno en rojo · 2 = el job no se puede replicar
# Banco: `qa/scripts/gate-ci-checks-test.sh`.
set -u
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW="$RAIZ/.github/workflows/qa.yml"
JOB="coverage-index"
LISTAR=0

while [ $# -gt 0 ]; do
  case "$1" in
    --workflow) WORKFLOW="${2:?--workflow necesita un fichero}"; shift 2 ;;
    --job)      JOB="${2:?--job necesita un nombre}"; shift 2 ;;
    --listar)   LISTAR=1; shift ;;
    *) echo "gate-ci-checks: argumento desconocido: $1" >&2; exit 2 ;;
  esac
done

# Saca los comandos del job, uno por línea, o un «!ERROR …» si hay algo que no sabe replicar.
pasos="$(python3 -I - "$WORKFLOW" "$JOB" <<'PY'
import re, sys

ruta, job = sys.argv[1], sys.argv[2]
try:
    lineas = open(ruta, encoding='utf-8').read().split('\n')
except OSError as e:
    print(f'!ERROR no puedo leer {ruta}: {e}'); sys.exit()

# El bloque del job: desde «  <job>:» hasta la siguiente clave de su mismo nivel.
inicio = next((i for i, l in enumerate(lineas) if l.rstrip() == f'  {job}:'), None)
if inicio is None:
    print(f'!ERROR no encuentro el job «{job}» en {ruta}'); sys.exit()
bloque = []
for l in lineas[inicio + 1:]:
    if re.match(r'^ {0,2}\S', l):
        break
    bloque.append(l)

en_steps, n = False, 0
for l in bloque:
    if re.match(r'^    steps:\s*$', l):
        en_steps = True; continue
    if not en_steps:
        if re.match(r'^    (if|env|defaults):', l):
            print(f'!ERROR el job «{job}» lleva «{l.strip()}», que este script no replica'); sys.exit()
        continue
    s = l.strip()
    if not s or s.startswith('#'):
        continue
    m = re.match(r'^(?:- )?(\w[\w-]*):\s*(.*)$', s)
    if not m:
        continue
    clave, valor = m.group(1), m.group(2)
    if clave in ('if', 'env', 'working-directory', 'shell', 'continue-on-error'):
        print(f'!ERROR un paso del job «{job}» lleva «{s}», que este script no replica'); sys.exit()
    if clave == 'run':
        if valor in ('', '|', '>', '|-', '>-') or valor.startswith(('|', '>')):
            print(f'!ERROR un paso del job «{job}» tiene un run: multilínea, que este script no replica'); sys.exit()
        print(valor); n += 1
if n == 0:
    print(f'!ERROR el job «{job}» no tiene ningún paso run:')
PY
)"

if [ -z "$pasos" ] || printf '%s\n' "$pasos" | grep -q '^!ERROR'; then
  printf '%s\n' "${pasos:-!ERROR el lector del YAML no devolvió nada}" | grep '^!ERROR' | sed 's/^!ERROR /❌ gate-ci-checks: /' >&2
  exit 2
fi

total="$(printf '%s\n' "$pasos" | wc -l | tr -d ' ')"
if [ "$LISTAR" = 1 ]; then
  printf '%s\n' "$pasos"
  exit 0
fi

cd "$RAIZ" || exit 2
rojos=()
i=0
while IFS= read -r cmd; do
  i=$((i + 1))
  inicio_s=$(date +%s)
  salida="$(bash -c "$cmd" 2>&1 </dev/null)"; rc=$?
  dur=$(( $(date +%s) - inicio_s ))
  if [ "$rc" = 0 ]; then
    echo "  ✓ ${i}/${total} ${cmd} (${dur} s)"
  else
    echo "  ✗ ${i}/${total} ${cmd} — exit ${rc} (${dur} s). Últimas líneas:"
    printf '%s\n' "$salida" | tail -15 | sed 's/^/        /'
    rojos+=("$cmd")
  fi
done <<< "$pasos"

if [ ${#rojos[@]} -ne 0 ]; then
  echo "❌ gate-ci-checks: ${#rojos[@]} de ${total} pasos del job «${JOB}» en rojo. El CI los bloquearía igual."
  exit 1
fi
echo "✅ gate-ci-checks: los ${total} pasos del job «${JOB}» en verde."
