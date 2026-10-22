#!/bin/bash
# ¿Está el simulador libre para correr XCUITest?
#
# Dos corridas de XCUITest sobre el MISMO simulador se derriban entre sí: comparten
# bundle id, así que el runner de la segunda mata al de la primera a media ejecución.
# El síntoma NO se parece a un fallo de test — es «Restarting after unexpected exit»,
# exit 65 y casos en «Failing tests» que nunca imprimieron una línea de fallo.
# Medido el 2026-09-07; detalle en `.claude/rules/testing.md`.
#
# **Preguntar UNA vez no basta, y eso costó un ticket `high` falso (2026-09-11).** Esta
# comprobación caduca en el instante siguiente: una corrida de XCUITest dura entre 3 y 40
# minutos, en esta máquina conviven ~14 worktrees y todos apuntan al mismo simulador, así
# que la ventana para que otra sesión entre a mitad es la corrida entera. Cuando eso pasa,
# el veredicto de la primera NO vale — y no siempre se nota: además del «Restarting after
# unexpected exit» de arriba, la otra corrida INSTALA su .app sobre el mismo bundle id, y
# a partir de ahí la primera tapea un binario que no es el suyo. Eso da rojos con su línea
# de fallo y su mensaje de aserto, indistinguibles de un rojo de test.
#
# **Desde el 2026-09-12 esto es la RED, no la puerta.** La puerta es `sim-lock.sh`, que
# pone en cola a la segunda sesión en vez de dejarla correr encima (decisión de Jürgen,
# opción 2 del ticket `diez-worktrees-comparten-un-simulador`). Este script sigue haciendo
# falta porque el lock vive en el árbol de trabajo: un worktree con una rama anterior a esa
# fecha, o un `xcodebuild` lanzado a mano, no hacen cola. Si el centinela canta estando el
# lock puesto, el intruso es uno de esos dos — no un fallo del lock.
#
# Uso:  bash qa/scripts/sim-libre.sh              → informa y sale 1 si está ocupado
#       bash qa/scripts/sim-libre.sh --quiet      → solo el exit code
#       bash qa/scripts/sim-libre.sh --vigilar PID → centinela: vigila mientras viva PID
#                                                    (el xcodebuild de la corrida) y dice
#                                                    al final si estuviste solo
#       las banderas se combinan en cualquier orden
#
# Exit: 0 = libre / estuviste solo · 1 = hay (o hubo) otra corrida de test
#       2 = no se pudo vigilar (PID inexistente o que no es un `xcodebuild`, o murió sin
#           ejecutar un solo test): NO es un ✓, es «no medí nada»

# **Las banderas se parsean en cualquier orden, y eso arregla un fallo ABIERTO.** Antes se
# miraba solo `$1`: `--quiet --vigilar 12345` no entraba en el centinela, caía a la foto
# instantánea y —con el simulador libre— salía **0 sin haber vigilado un segundo**, callado
# por el propio `--quiet`. O sea que la única forma de pedir un centinela silencioso era
# justamente la que lo desactivaba. Medido el 2026-09-12.
QUIET=0
MODO="foto"
VIGILADO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --quiet)   QUIET=1; shift ;;
    --vigilar) MODO="vigilar"; VIGILADO="${2:-}"; shift 2 2>/dev/null || shift ;;
    *)
      echo "uso: bash qa/scripts/sim-libre.sh [--quiet] [--vigilar <pid del xcodebuild>]" >&2
      exit 2 ;;
  esac
done
say() { [ "$QUIET" -eq 1 ] || echo "$@"; }

# `pgrep -f` empareja también los argumentos de los OTROS `pgrep -f` que corran a la vez,
# así que buscar el patrón literal se cuenta a sí mismo. **Medido el 2026-09-12 con cero
# runners vivos: `pgrep -f 'UITests-Runner'` devuelve 1, y dos fotos simultáneas se
# declaraban «ocupado» mutuamente 6 de 6 veces con el simulador en reposo** — un gate
# bloqueado por nada. Los corchetes rompen la coincidencia consigo mismo: el argv lleva
# `[U]ITests-Runner`, que como regex no casa con su propio texto. Con el arreglo: 0 y 0.
runners_vivos() {
  pgrep -f '[U]ITests-Runner' 2>/dev/null | wc -l | tr -d ' '
}

# La identidad de un proceso NO es su PID: los PIDs se reciclan (en macOS el techo es
# 99999, y catorce worktrees compilando lo dan la vuelta en horas). Si el vigilado muere y
# otro `xcodebuild … test` hereda su número, el centinela adoptaría la corrida ajena — y
# como `pids_ejecutando_tests` EXCLUYE al vigilado, esa corrida quedaría fuera de los
# intrusos y el veredicto sería «✓ estuviste solo» sobre una medición que no es tuya.
# Falla ABIERTO. El ancla barata es la hora de arranque del proceso, que un PID reciclado
# no puede reproducir.
sello_de_arranque() {
  ps -o lstart= -p "$1" 2>/dev/null | tr -s ' '
}

# ¿ESTE pid es un `xcodebuild` EJECUTANDO tests ahora mismo? Las dos mitades hacen falta:
# `pgrep -x` (nombre EXACTO del ejecutable) evita los ~91 falsos positivos de `pgrep -f
# xcodebuild` —cualquier shell que lo mencione—, y la subacción distingue una corrida de
# un `build-for-testing`, que compila pero no instala ni lanza. Y desde 2026-09-12 la
# primera mitad es además la que separa «corriendo» de «haciendo cola»: `sim-lock.sh` lleva
# el `xcodebuild … test …` entero en los argumentos de `python3` mientras espera su turno,
# así que mirar solo la línea de comando diría «sí» a un proceso que no ha tocado el
# simulador todavía.
ejecuta_tests() {
  local pid="$1"
  pgrep -x xcodebuild 2>/dev/null | grep -qxF "$pid" || return 1
  ps -o command= -p "$pid" 2>/dev/null | grep -qE '(^| )(test|test-without-building)( |$)'
}

pids_ejecutando_tests() {
  local excluir="${1:-}"
  local pid
  for pid in $(pgrep -x xcodebuild 2>/dev/null); do
    [ "$pid" = "$excluir" ] && continue
    if ejecuta_tests "$pid"; then
      echo "$pid"
    fi
  done
}

# MARK: - Centinela (--vigilar)

if [ "$MODO" = "vigilar" ]; then
  case "$VIGILADO" in
    ''|*[!0-9]*)
      echo "uso: bash qa/scripts/sim-libre.sh --vigilar <pid del xcodebuild de tu corrida>" >&2
      exit 2 ;;
    0)
      # `kill -0 0` señala al propio grupo de procesos y SIEMPRE tiene éxito, así que un
      # cero colgaría la fase de cola para siempre y en silencio.
      echo "⛔ --vigilar 0 no es un pid: el centinela no vigilaría nada." >&2
      exit 2 ;;
  esac

  # **Si el PID no existe, esto NO dice «estuviste solo»: dice que no vigiló nada.** Un
  # centinela que deriva su veredicto de una AUSENCIA falla ABIERTO — un typo en el PID, o
  # pasarle el del wrapper en vez del de `xcodebuild`, daría un ✓ sin haber mirado una vez.
  if ! kill -0 "$VIGILADO" 2>/dev/null; then
    if ps -p "$VIGILADO" >/dev/null 2>&1; then
      echo "⛔ El PID $VIGILADO existe pero es de otro usuario: no se puede vigilar." >&2
    else
      echo "⛔ El PID $VIGILADO no existe: el centinela no vigiló NADA. Pasá el PID del \`xcodebuild\`" >&2
      echo "   de tu corrida (\`xcodebuild … test … & echo \$!\`), no el del shell que lo lanza." >&2
    fi
    exit 2
  fi

  # **Y si ese PID no es una corrida de tests ni va camino de serlo, se dice YA.** Antes, un
  # PID de un shell de larga vida —el error exacto que el mensaje de arriba anticipa— dejaba
  # al centinela girando en silencio y para siempre, colgando el gate sin un veredicto ni un
  # mensaje. Un `sim-lock.sh` esperando turno lleva el `xcodebuild` en su línea de comando,
  # así que la espera legítima sí pasa por aquí.
  MANDO_VIGILADO="$(ps -o command= -p "$VIGILADO" 2>/dev/null)"
  case "$MANDO_VIGILADO" in
    *xcodebuild*) ;;
    *)
      echo "⛔ El pid $VIGILADO no es un \`xcodebuild\` (ni uno esperando turno):" >&2
      echo "   $MANDO_VIGILADO" >&2
      echo "   El centinela no vigiló NADA. Pasá el pid del \`xcodebuild\`; con \`sim-lock.sh\`" >&2
      echo "   NO cambia, porque la cadena de exec lo conserva." >&2
      exit 2 ;;
  esac

  # La hora de arranque ancla la identidad: si el PID se recicla, deja de coincidir.
  SELLO="$(sello_de_arranque "$VIGILADO")"

  sigue_siendo_el_mismo() {
    [ -n "$SELLO" ] || return 0          # sin sello no se puede comparar: no se inventa
    [ "$(sello_de_arranque "$VIGILADO")" = "$SELLO" ]
  }

  # **Mientras el vigilado HACE COLA no se vigila nada, y es a propósito.** Desde que
  # existe `sim-lock.sh` (2026-09-12) el `xcodebuild` de tu corrida puede pasar minutos
  # esperando su turno: en ese rato el simulador es legítimamente de otro, y contar a ese
  # otro como intruso convertiría el caso NORMAL —la cola funcionando— en un rojo falso.
  # El reloj arranca cuando arrancas tú: cuando el vigilado aparece él mismo como
  # `xcodebuild` ejecutando tests.
  EN_COLA=0
  INICIO_COLA=$(date +%s)
  ULTIMO_AVISO=$INICIO_COLA
  while ! ejecuta_tests "$VIGILADO"; do
    if ! kill -0 "$VIGILADO" 2>/dev/null; then
      # Murió sin llegar a ejecutar un solo test. Eso NO es «estuviste solo»: es que no
      # hubo corrida. Un centinela que derive un ✓ de una ausencia falla ABIERTO.
      echo "⛔ El pid $VIGILADO murió sin llegar a ejecutar tests: el centinela no vigiló NADA." >&2
      [ "$EN_COLA" -eq 1 ] && echo "   Estuvo $(( $(date +%s) - INICIO_COLA ))s esperando el lock del simulador." >&2
      exit 2
    fi
    if ! sigue_siendo_el_mismo; then
      echo "⛔ El pid $VIGILADO ya no es el proceso que empezaste a vigilar (se recicló)." >&2
      echo "   El centinela no vigiló NADA: no se hereda la corrida de otro." >&2
      exit 2
    fi
    EN_COLA=1
    AHORA=$(date +%s)
    if [ $((AHORA - ULTIMO_AVISO)) -ge 60 ]; then
      say "· $(( (AHORA - INICIO_COLA) / 60 )) min esperando a que tu corrida tome el turno."
      ULTIMO_AVISO=$AHORA
    fi
    sleep 2
  done
  [ "$EN_COLA" -eq 1 ] && say "· Tu corrida esperó $(( $(date +%s) - INICIO_COLA ))s su turno en el lock; el centinela empieza ahora."

  INTRUSOS=""
  MAX_RUNNERS=0
  MUESTRAS=0
  # **Una muestra solo cuenta si el vigilado seguía vivo al tomarla, y esto costó un falso
  # positivo el 2026-09-12.** La versión anterior muestreaba PRIMERO y comprobaba después
  # si el vigilado seguía vivo, así que la última muestra se tomaba hasta 5 s DESPUÉS de
  # que hubiera muerto — y con la cola puesta, en esos 5 s ya está corriendo el siguiente
  # de la fila, legítimamente. Resultado medido en la primera corrida real con lock: la
  # sesión que terminó primero cantó «NO estuviste solo» señalando a la que esperaba
  # detrás. O sea, el lock funcionando hacía cantar al centinela **siempre**.
  # El orden correcto es: muestrear, y consolidar la muestra solo si el vigilado llegó vivo
  # al final de ella. La garantía de «al menos una muestra» ya no la da el do-while: la da
  # la fase de cola de arriba, que no sale hasta ver al vigilado ejecutando tests. Si aun
  # así se queda en cero, eso es un 2 («no medí nada»), nunca un ✓.
  while :; do
    PIDS_AHORA="$(pids_ejecutando_tests "$VIGILADO")"
    R=$(runners_vivos)
    kill -0 "$VIGILADO" 2>/dev/null || break
    # Un PID reciclado a mitad de corrida haría que el centinela siguiera midiendo la de
    # otro — y excluyéndola de los intrusos. Se corta en cuanto la identidad no cuadra.
    if ! sigue_siendo_el_mismo; then
      echo "⛔ El pid $VIGILADO se recicló durante la corrida: el veredicto NO vale." >&2
      exit 2
    fi
    MUESTRAS=$((MUESTRAS + 1))
    for pid in $PIDS_AHORA; do
      case " $INTRUSOS " in
        *" $pid "*) ;;
        *) INTRUSOS="$INTRUSOS $pid" ;;
      esac
    done
    [ "$R" -gt "$MAX_RUNNERS" ] && MAX_RUNNERS=$R
    sleep 5
  done

  if [ "$MUESTRAS" -eq 0 ]; then
    echo "⛔ El pid $VIGILADO murió antes de la primera muestra: el centinela no vigiló NADA." >&2
    exit 2
  fi

  # Con `parallelizable = "NO"` en las dos schemes (2026-07-24) una corrida sana tiene UN
  # runner vivo a la vez. Dos son dos corridas.
  if [ -n "$INTRUSOS" ] || [ "$MAX_RUNNERS" -gt 1 ]; then
    say "⛔ NO estuviste solo: el veredicto de esta corrida NO vale."
    [ -n "$INTRUSOS" ] && say "   otros xcodebuild ejecutando tests:$INTRUSOS"
    [ "$MAX_RUNNERS" -gt 1 ] && say "   runners de XCUITest simultáneos: $MAX_RUNNERS (lo sano es 1)"
    say ""
    say "   Repetí la corrida AISLADA antes de creerte ningún rojo — y antes de abrir un"
    say "   ticket por él. Los rojos de una corrida pisada pueden traer su línea de fallo."
    exit 1
  fi

  say "✓ Estuviste solo durante toda la corrida ($MUESTRAS muestreos, máx. $MAX_RUNNERS runner simultáneo)."
  exit 0
fi

# MARK: - Foto instantánea (modo por defecto)

OCUPADO=0
PIDS=""
for pid in $(pids_ejecutando_tests); do
  PIDS="$PIDS $pid"
  OCUPADO=1
done

# Runners de XCUITest vivos dentro del simulador
RUNNERS=$(runners_vivos)
[ "$RUNNERS" -gt 0 ] && OCUPADO=1

if [ "$OCUPADO" -eq 1 ]; then
  say "⛔ El simulador NO está libre."
  [ -n "$PIDS" ] && say "   xcodebuild ejecutando tests:$PIDS"
  for pid in $PIDS; do
    say "     └─ $(ps -o command= -p "$pid" 2>/dev/null | cut -c1-140)"
  done
  [ "$RUNNERS" -gt 0 ] && say "   runners de XCUITest vivos: $RUNNERS"
  say ""
  say "   Esperá a que termine. Correr ahora NO da un veredicto: las dos corridas"
  say "   se derriban y salen en rojo sin una sola línea de fallo real."
  exit 1
fi

say "✓ Simulador libre — ninguna otra corrida de test en curso."
exit 0
