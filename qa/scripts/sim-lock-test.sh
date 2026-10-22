#!/bin/bash
# Banco de pruebas de la cola del simulador — `sim-lock.sh` + `sim-libre.sh`.
#
#   bash qa/scripts/sim-lock-test.sh
#
# **Por qué existe.** El lock es un candado, y un candado sin banco se relaja sin que nadie
# lo note (mismo argumento que `commit-msg-test.sh`). Aquí el riesgo es peor que en un hook:
# un lock roto **no da error** — deja correr las dos sesiones a la vez y el daño aparece
# tres horas después, disfrazado de test en rojo. Medido: quitar una sola línea del script
# (`os.set_inheritable(fd, True)`) evapora el lock en el `exec` sin un solo síntoma visible.
#
# **Nada de esto toca el simulador ni compila nada**: los casos usan un `xcodebuild` de
# mentira —un enlace a `/bin/sh` con ese nombre, para que `pgrep -x xcodebuild` lo cace
# igual que al de verdad— y su propio lockfile en un directorio temporal. Corre en un
# minuto largo y es seguro con otras sesiones trabajando.
#
# **Cómo se escribe un caso aquí, que tiene dos trampas propias:**
#
#  · **Un caso de concurrencia cuyo tramo dure MENOS que el sondeo de `sim-lock.sh` no mide
#    el lock: mide la siesta.** Medido con el mutante que evapora el lock — dos tramos de
#    2 s salían «sin solape» igual, porque lo que los separaba era el reintento.
#  · **`ok` solo se pone cuando algo se ha comprobado de verdad.** Un comparador que
#    devuelva «no pude medir» no puede caer en la rama del ✓; si no hay datos, es `mal`.
#    El banco existe para desconfiar, y el primero del que hay que desconfiar es él.
#  · **Y una del shell, que mordió TRES veces el mismo día: `«$VAR»` no funciona.** Bash
#    lee el nombre de la variable hasta el primer carácter que no valga, y los bytes altos
#    de `»` sí le valen: intenta expandir `VAR»` y con `set -u` mata el script con «unbound
#    variable» y un exit 1 que se lee como un fallo del caso. En español, con comillas
#    angulares por todas partes, es fácil de repetir: escribe siempre `«${VAR}»`.
#
# Exit: 0 = todos los casos pasan · 1 = alguno falla
set -u

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK_SH="$RAIZ/qa/scripts/sim-lock.sh"
LIBRE_SH="$RAIZ/qa/scripts/sim-libre.sh"

# **El banco también hace cola, y no por simetría.** Sus casos levantan procesos que se
# llaman `xcodebuild` de verdad (por eso `pgrep -x` los caza, que es justo lo que se quiere
# probar) — y esos procesos los vería el centinela de CUALQUIER otra sesión que estuviera
# corriendo su gate en esta máquina, cantándole un intruso que no existe. Correr el banco
# no puede costarle a nadie una corrida de 40 min. Así que pide el turno real antes de
# empezar y lo suelta al terminar; en el CI el lock está siempre libre y no cuesta nada.
#
# La marca de «ya estoy en cola» viaja como ARGUMENTO, no por el entorno: una variable
# exportada en un shell —o heredada por accidente— haría que el banco se saltara su propia
# cola en silencio, y entonces sería él quien ensucia las corridas ajenas.
if [ "${1:-}" = "--ya-en-cola" ]; then
  shift
else
  exec bash "$LOCK_SH" --timeout 900 -- bash "$0" --ya-en-cola "$@"
fi
# Ya tenemos el turno (el fd vive en este proceso). La marca de reentrada, en cambio, hay
# que quitarla: si no, los `sim-lock.sh` de los casos se creerían dentro del turno y no
# pedirían nada — el banco entero mediría un lock que nadie tomó.
unset YALA_SIM_LOCK_HELD

TMP="$(mktemp -d "${TMPDIR:-/tmp}/sim-lock-test.XXXXXX")" || { echo "no se pudo crear el temporal" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT

export YALA_SIM_LOCK="$TMP/simulador.lock"
# Un `xcodebuild` de mentira, con dos trampas medidas el 2026-09-12:
#
#  · **Enlace simbólico, NUNCA una copia.** Copiar `/bin/sh` invalida su firma y macOS mata
#    el proceso al instante con SIGKILL (exit 137) — sin mensaje que mencione la firma. El
#    enlace conserva el binario firmado y aun así `ps -o comm=` devuelve el nombre del
#    enlace, así que `pgrep -x xcodebuild` lo caza igual que al de verdad.
#  · **El comando que se le pasa tiene que ser COMPUESTO** (`'sleep 3; :'`). Con uno simple
#    `sh` se auto-reemplaza por `sleep` para ahorrarse un proceso, y entonces el proceso ya
#    no se llama `xcodebuild`: el centinela deja de verlo y el caso mide otra cosa.
#
# Se invoca como `xcodebuild -c '…' test` para que su línea de comando termine en ` test`,
# que es la otra mitad del predicado de `sim-libre.sh`.
mkdir -p "$TMP/bin"
ln -s /bin/sh "$TMP/bin/xcodebuild"

PASA=0
FALLA=0

ok()   { PASA=$((PASA + 1)); printf '  ✓ %s\n' "$1"; }
mal()  { FALLA=$((FALLA + 1)); printf '  ✘ %s\n     %s\n' "$1" "${2:-}"; }
caso() { printf '\n▸ %s\n' "$1"; }

# Marca el instante en un fichero de trazas, para comprobar SOLAPAMIENTO después. El
# testigo es aritmético a propósito: «no se pisaron» se demuestra comparando intervalos, no
# mirando si los dos salieron en verde (dos corridas pisadas también pueden salir verdes).
tramo() {
  local etiqueta="$1" segs="$2" traza="$3"
  echo "$etiqueta inicio $(python3 -c 'import time; print(time.time())')" >> "$traza"
  sleep "$segs"
  echo "$etiqueta fin    $(python3 -c 'import time; print(time.time())')" >> "$traza"
}
export -f tramo

# ¿Se solapan los dos tramos de una traza? 0 = se solapan · 1 = no · 2 = NO SE PUDO MEDIR.
# El 2 no se puede confundir con el 1: una traza vacía —porque `sim-lock.sh` murió antes de
# ejecutar nada— significaría «ningún solape» y pondría verde el caso estrella del banco.
hay_solape() {
  python3 - "$1" <<'PY'
import sys
ini, fin = {}, {}
for linea in open(sys.argv[1]):
    etiqueta, clase, t = linea.split()
    (ini if clase == "inicio" else fin)[etiqueta] = float(t)
if len(ini) < 2 or len(fin) < 2:
    sys.exit(2)
a, b = sorted(ini, key=lambda k: ini[k])
sys.exit(0 if ini[b] < fin[a] else 1)
PY
}

# Envuelve `hay_solape` para que los tres códigos vayan a la rama correcta.
espera_sin_solape() {
  local traza="$1" etiqueta="$2"
  hay_solape "$traza"
  case $? in
    0) mal "$etiqueta: los tramos se solaparon CON el lock puesto" "$(cat "$traza")" ;;
    1) ok  "$etiqueta" ;;
    *) mal "$etiqueta: no hubo tramos que medir" "la traza está vacía o incompleta: los comandos no llegaron a correr, así que este caso no probó NADA" ;;
  esac
}

echo "════════════════════════════════════════════════════════════"
echo " Banco de la cola del simulador — sim-lock.sh + sim-libre.sh"
echo "════════════════════════════════════════════════════════════"

# ─────────────────────────────────────────────────────────────────
caso "CONTROL NEGATIVO · sin lock, los dos tramos SÍ se solapan"
# Va primero y no es ceremonia: si el escenario no supiera producir un solape, el caso
# positivo de abajo saldría verde sin medir nada — se sostendría por lo corto que es el
# tramo, no por el lock.
TRAZA="$TMP/traza-sin-lock.txt"
: > "$TRAZA"
bash -c "tramo A 3 '$TRAZA'" &
bash -c "tramo B 3 '$TRAZA'" &
wait
hay_solape "$TRAZA"
case $? in
  0) ok  "sin lock se pisan (el escenario sabe reproducir la colisión)" ;;
  1) mal "sin lock NO se pisaron" "el escenario no reproduce nada; el caso positivo no probaría el lock" ;;
  *) mal "sin lock no hubo tramos que medir" "el escenario está roto" ;;
esac

# ─────────────────────────────────────────────────────────────────
caso "serializa · con lock, la segunda ESPERA y los tramos no se solapan"
# **El tramo tiene que durar MÁS que el sondeo de `sim-lock.sh`, o este caso no mide nada.**
# Medido el 2026-09-12 con el mutante que le quita el `os.set_inheritable` al lock: con
# tramos de 2 s y un sondeo de 5 s el caso salía VERDE con el lock roto — el segundo proceso
# no se pisaba con el primero porque estaba dormido esperando su reintento, no porque
# hubiera una cerradura. Los separaba la siesta. Con el sondeo en 1 s y tramos de 3 s, el
# lock roto produce solape de verdad y el caso cae, que es lo que tiene que pasar.
TRAZA="$TMP/traza-con-lock.txt"
: > "$TRAZA"
bash "$LOCK_SH" --quiet -- bash -c "tramo A 3 '$TRAZA'" &
bash "$LOCK_SH" --quiet -- bash -c "tramo B 3 '$TRAZA'" &
wait
espera_sin_solape "$TRAZA" "la segunda esperó su turno (cero solape)"

# ─────────────────────────────────────────────────────────────────
caso "reparto · con cinco a la vez, ninguna pareja se solapa"
# Dos procesos pueden no solaparse por casualidad de scheduling. Cinco, no. Los tramos
# siguen por encima del sondeo, por lo mismo que el caso de arriba.
TRAZA="$TMP/traza-cinco.txt"
: > "$TRAZA"
for n in 1 2 3 4 5; do
  bash "$LOCK_SH" --quiet -- bash -c "tramo P$n 2 '$TRAZA'" &
done
wait
SOLAPES=$(python3 - "$TRAZA" <<'PY'
import sys
ini, fin = {}, {}
for linea in open(sys.argv[1]):
    e, c, t = linea.split()
    (ini if c == "inicio" else fin)[e] = float(t)
if len(ini) < 5 or len(fin) < 5:
    print("incompleta:%d" % len(fin))
    sys.exit(0)
tramos = sorted(((ini[k], fin[k]) for k in ini))
print(sum(1 for (a1, a2), (b1, _) in zip(tramos, tramos[1:]) if b1 < a2))
PY
)
case "$SOLAPES" in
  0)           ok "5 corridas, 0 solapes" ;;
  incompleta:*) mal "solo llegaron a correr ${SOLAPES#incompleta:} de 5 tramos" "este caso no probó nada" ;;
  *)           mal "$SOLAPES solapes entre 5 corridas" "$(cat "$TRAZA")" ;;
esac

# ─────────────────────────────────────────────────────────────────
caso "exit code · el del comando viaja intacto"
bash "$LOCK_SH" --quiet -- sh -c 'exit 0'  ; [ $? -eq 0 ]  && ok "0 → 0"   || mal "0 no viajó"
bash "$LOCK_SH" --quiet -- sh -c 'exit 65' ; [ $? -eq 65 ] && ok "65 → 65" || mal "65 no viajó" "el 65 de xcodebuild es «fallo de test»: perderlo sería un gate ciego"
bash "$LOCK_SH" --quiet -- sh -c 'exit 70' ; [ $? -eq 70 ] && ok "70 → 70" || mal "70 no viajó" "el 70 es «fallo de infraestructura»"
# 75 y 2 son los dos códigos que el propio wrapper usa. Si el comando los devuelve, tienen
# que llegar igual: si no, un `--timeout` agotado y un comando que sale 75 serían el mismo
# byte y nadie podría distinguirlos.
bash "$LOCK_SH" --quiet -- sh -c 'exit 75' ; [ $? -eq 75 ] && ok "75 → 75 (el del comando, no el de la cola)" || mal "75 del comando no viajó"
bash "$LOCK_SH" --quiet -- sh -c 'exit 2'  ; [ $? -eq 2 ]  && ok "2 → 2"   || mal "2 del comando no viajó"

# ─────────────────────────────────────────────────────────────────
caso "pid · el wrapper NO añade un proceso: \$! es el del comando"
# Esto es lo que hace compatible el lock con `sim-libre.sh --vigilar`, que EXIGE el pid del
# xcodebuild y rechaza el de un shell envoltorio.
bash "$LOCK_SH" --quiet -- "$TMP/bin/xcodebuild" -c 'sleep 3; :' test &
PID=$!
sleep 1
# `comm` y no `command`: la línea de comando del python3 envoltorio CONTIENE la palabra
# xcodebuild (va en sus argumentos), así que mirarla daría ✓ justo en el fallo que este
# caso vigila. El nombre del ejecutable no miente.
COMM="$(ps -o comm= -p "$PID" 2>/dev/null)"
case "$COMM" in
  *xcodebuild) ok "el pid devuelto ES el del comando ($COMM)" ;;
  *)           mal "el pid devuelto no es el del comando" "ps -o comm= dice: ${COMM:-<muerto>}" ;;
esac
if pgrep -x xcodebuild 2>/dev/null | grep -qxF "$PID"; then
  ok "pgrep -x xcodebuild lo ve (el centinela podrá vigilarlo)"
else
  mal "pgrep -x no lo ve" "el centinela no sabría que la corrida arrancó"
fi
wait $PID 2>/dev/null

# ─────────────────────────────────────────────────────────────────
caso "kill -9 · el lock se suelta aunque el dueño muera de golpe"
# Es la razón de usar el lock del kernel y no un lockfile con PID dentro: no hay huérfanos
# que limpiar a mano ni en `/cerrar`.
bash "$LOCK_SH" --quiet -- sleep 30 &
VICTIMA=$!
sleep 1
kill -9 "$VICTIMA" 2>/dev/null
wait "$VICTIMA" 2>/dev/null
sleep 1
if bash "$LOCK_SH" --quiet --timeout 5 -- true; then
  ok "tras un kill -9 el siguiente entra sin esperar"
else
  mal "el lock quedó huérfano tras kill -9" "haría falta limpiarlo a mano"
fi

# ─────────────────────────────────────────────────────────────────
caso "timeout · se agota, sale 75 y NO ejecuta el comando"
TESTIGO="$TMP/no-deberia-existir"
bash "$LOCK_SH" --quiet -- sleep 6 &
BLOQ=$!
sleep 1
bash "$LOCK_SH" --quiet --timeout 2 -- touch "$TESTIGO"
CODIGO=$?
[ "$CODIGO" -eq 75 ] && ok "sale 75 (cola agotada, no fallo de test)" || mal "salió $CODIGO, esperaba 75"
[ -f "$TESTIGO" ] && mal "ejecutó el comando pese al timeout" "eso es correr sin lock" || ok "no ejecutó el comando"
wait $BLOQ 2>/dev/null

# ─────────────────────────────────────────────────────────────────
caso "estado · distingue libre de tomado"
bash "$LOCK_SH" --estado >/dev/null 2>&1 && ok "libre → 0" || mal "dijo tomado estando libre"
bash "$LOCK_SH" --quiet -- sleep 3 &
DUENIO=$!
sleep 1
SALIDA="$(bash "$LOCK_SH" --estado 2>&1)"; CODIGO=$?
[ "$CODIGO" -eq 1 ] && ok "tomado → 1" || mal "tomado devolvió $CODIGO, esperaba 1"
case "$SALIDA" in
  *"$DUENIO"*) ok "dice QUIÉN lo tiene (pid $DUENIO)" ;;
  *)           mal "no dice quién lo tiene" "$SALIDA" ;;
esac
wait $DUENIO 2>/dev/null

# ─────────────────────────────────────────────────────────────────
caso "entorno · una ruta de lockfile RELATIVA se rechaza"
# Con una relativa, cada worktree cerraría sobre su propio fichero: catorce locks y ninguna
# cola, sin un solo mensaje. Falla cerrado o no vale de nada.
TESTIGO="$TMP/relativa"
( cd "$TMP" && YALA_SIM_LOCK="rel.lock" bash "$LOCK_SH" --quiet -- touch "$TESTIGO" ) >/dev/null 2>&1
CODIGO=$?
[ "$CODIGO" -eq 2 ] && ok "sale 2" || mal "salió $CODIGO, esperaba 2"
[ -f "$TESTIGO" ] && mal "ejecutó el comando con un lockfile relativo" "cada worktree habría cerrado sobre el suyo" || ok "no ejecutó nada"

# ─────────────────────────────────────────────────────────────────
caso "reentrada · un sim-lock dentro de otro no se abraza a sí mismo"
# `flock` sobre otro fd del mismo fichero bloquea aunque sea el mismo proceso: sin la
# marca de reentrada, esto se colgaría para siempre.
SALIDA="$(bash "$LOCK_SH" --quiet --timeout 8 -- bash "$LOCK_SH" --quiet --timeout 8 -- echo anidado 2>&1)"
case "$SALIDA" in
  *anidado*) ok "el anidado corre (no hay abrazo mortal)" ;;
  *)         mal "el sim-lock anidado no llegó a ejecutar" "salida: ${SALIDA:-<vacía>}" ;;
esac

caso "reentrada · NINGUNA marca inventada abre la puerta"
# **Las tres eran llaves maestras y las tres están medidas (2026-09-12).** Con la marca
# basada en un PID: `0` hacía que `os.kill(0, 0)` señalara al propio grupo de procesos y
# nunca fallara ⇒ pase libre universal; el PID de un proceso de otro usuario daba
# `PermissionError`, que se leía como «vivo, es mi ancestro» ⇒ lo mismo; y un PID reciclado,
# igual. Ahora la marca es un token que tiene que coincidir con el que el lock lleva escrito,
# así que nada de esto vale. Si algún día vuelve a valer, el fallo es SILENCIOSO: dos
# corridas a la vez sin un solo mensaje.
# El dueño tiene que seguir vivo durante TODAS las iteraciones: cinco marcas x 2 s de
# timeout. Con un `sleep 8` las dos últimas encontraban el lock ya libre y entraban con
# razón — dos rojos que parecían del producto y eran del escenario. El caso estaba bien
# escrito (mide lo que dice); el que no llegaba era el decorado.
bash "$LOCK_SH" --quiet -- sleep 20 &
DUENIO=$!
sleep 1
for MARCA in 0 1 99999 "12345-deadbeefcafe" "$DUENIO"; do
  # Control de que el decorado sigue en pie: si el dueño se ha muerto, este caso no mide
  # nada y hay que decirlo, no apuntarse un ✓ ni un ✘.
  if ! kill -0 "$DUENIO" 2>/dev/null; then
    mal "el dueño del lock murió a mitad del caso" "las marcas restantes no se probaron"
    break
  fi
  TESTIGO="$TMP/cole-$MARCA"
  YALA_SIM_LOCK_HELD="$MARCA" bash "$LOCK_SH" --quiet --timeout 2 -- touch "$TESTIGO" >/dev/null 2>&1
  CODIGO=$?
  if [ "$CODIGO" -eq 75 ] && [ ! -f "$TESTIGO" ]; then
    ok "marca «${MARCA}» → hace cola (75), no ejecuta"
  else
    mal "marca «${MARCA}» abrió la puerta (exit ${CODIGO})" "corrió sin lock: es el fallo silencioso"
  fi
done
kill $DUENIO 2>/dev/null
wait $DUENIO 2>/dev/null

# ─────────────────────────────────────────────────────────────────
caso "centinela · las banderas se combinan en cualquier orden"
# **Medido el 2026-09-12: `--quiet --vigilar PID` caía a la foto instantánea y salía 0 sin
# vigilar un segundo**, callado por el propio `--quiet`. El llamante apuntaba ese 0 como
# «estuviste solo». La única forma de pedir un centinela silencioso era la que lo apagaba.
sleep 10 & AJENO=$!
bash "$LIBRE_SH" --quiet --vigilar "$AJENO" >/dev/null 2>&1
CODIGO=$?
kill $AJENO 2>/dev/null; wait $AJENO 2>/dev/null
[ "$CODIGO" -eq 2 ] && ok "«--quiet --vigilar <pid que no es xcodebuild>» → 2, no 0" \
                    || mal "salió $CODIGO: el centinela no vigiló y no lo dijo"

caso "centinela · un pid que no es un xcodebuild se rechaza EN EL ACTO"
# Antes giraba en silencio y para siempre, colgando el gate sin veredicto ni mensaje.
sleep 10 & AJENO=$!
INICIO=$(date +%s)
bash "$LIBRE_SH" --vigilar "$AJENO" >/dev/null 2>&1
CODIGO=$?
TARDO=$(( $(date +%s) - INICIO ))
kill $AJENO 2>/dev/null; wait $AJENO 2>/dev/null
[ "$CODIGO" -eq 2 ] && ok "sale 2" || mal "salió $CODIGO, esperaba 2"
[ "$TARDO" -le 3 ] && ok "y lo dice en ${TARDO}s, sin esperar a que muera" \
                   || mal "tardó ${TARDO}s en decirlo" "un centinela colgado es un gate colgado"

caso "centinela · --vigilar 0 se rechaza"
# `kill -0 0` señala al propio grupo de procesos y SIEMPRE tiene éxito: un cero colgaba la
# fase de cola para siempre.
bash "$LIBRE_SH" --vigilar 0 >/dev/null 2>&1
[ $? -eq 2 ] && ok "sale 2" || mal "un pid 0 no se rechazó"

caso "centinela · no cuenta como intruso a quien tiene el turno mientras haces cola"
# El caso que hace compatibles las dos piezas. Sin la fase de cola de `sim-libre.sh`, el
# centinela vería al dueño legítimo del lock y cantaría rojo en la situación NORMAL.
PATH="$TMP/bin:$PATH" bash "$LOCK_SH" --quiet -- "$TMP/bin/xcodebuild" -c 'sleep 6; :' test &
PRIMERO=$!
sleep 1
PATH="$TMP/bin:$PATH" bash "$LOCK_SH" --quiet -- "$TMP/bin/xcodebuild" -c 'sleep 3; :' test &
SEGUNDO=$!
SALIDA="$(bash "$LIBRE_SH" --vigilar "$SEGUNDO" 2>&1)"; CODIGO=$?
wait $PRIMERO 2>/dev/null; wait $SEGUNDO 2>/dev/null
if [ "$CODIGO" -eq 0 ]; then
  ok "el que hace cola sale limpio (esperó y luego corrió solo)"
else
  mal "el centinela cantó rojo con la cola funcionando" "$SALIDA"
fi
case "$SALIDA" in
  *esper*) ok "y deja dicho que hubo cola" ;;
  *)       mal "no informó de la espera" "$SALIDA" ;;
esac

caso "centinela · el PRIMERO no canta por el que espera detrás en la cola"
# **El caso que el lock hace posible, y que costó un falso positivo en la primera medición
# real (2026-09-12).** El centinela del que corre primero seguía muestreando hasta 5 s
# después de que su propio `xcodebuild` hubiera muerto, y en esos 5 s el siguiente de la
# cola ya tiene el turno: la corrida que se portó bien salía marcada como pisada. Con la
# cola funcionando eso pasaría SIEMPRE que haya alguien esperando, o sea, todos los días.
PATH="$TMP/bin:$PATH" bash "$LOCK_SH" --quiet -- "$TMP/bin/xcodebuild" -c 'sleep 4; :' test &
DELANTE=$!
sleep 1
PATH="$TMP/bin:$PATH" bash "$LOCK_SH" --quiet -- "$TMP/bin/xcodebuild" -c 'sleep 4; :' test &
DETRAS=$!
SALIDA="$(bash "$LIBRE_SH" --vigilar "$DELANTE" 2>&1)"; CODIGO=$?
wait $DELANTE 2>/dev/null; wait $DETRAS 2>/dev/null
if [ "$CODIGO" -eq 0 ]; then
  ok "el de delante sale limpio aunque otro espere su turno detrás"
else
  mal "el de delante cantó por el que hacía cola" "$SALIDA"
fi

caso "centinela · SIGUE cazando al que corre sin hacer cola"
# La red tiene que seguir viva: es lo único que protege de un worktree con una rama vieja,
# que no trae `sim-lock.sh` y por tanto no hace cola.
PATH="$TMP/bin:$PATH" "$TMP/bin/xcodebuild" -c 'sleep 5; :' test &
INTRUSO=$!
sleep 1
PATH="$TMP/bin:$PATH" "$TMP/bin/xcodebuild" -c 'sleep 3; :' test &
VICTIMA=$!
SALIDA="$(bash "$LIBRE_SH" --vigilar "$VICTIMA" 2>&1)"; CODIGO=$?
wait $INTRUSO 2>/dev/null; wait $VICTIMA 2>/dev/null
if [ "$CODIGO" -eq 1 ]; then
  ok "dos corridas sin lock → el centinela canta (exit 1)"
else
  mal "el centinela NO cazó dos corridas simultáneas sin lock (exit $CODIGO)" "$SALIDA"
fi

caso "centinela · la foto no se cuenta a sí misma"
# **Medido el 2026-09-12: `pgrep -f 'UITests-Runner'` devolvía 1 con CERO runners vivos**,
# porque empareja los argumentos de los otros `pgrep` que corran a la vez — incluido el
# suyo. Dos fotos simultáneas se declaraban «ocupado» mutuamente 6 de 6 veces con el
# simulador en reposo, y eso bloquea un gate por nada.
CANTARON=0
for i in 1 2 3; do
  ( bash "$LIBRE_SH" --quiet; echo $? > "$TMP/foto-a" ) &
  ( bash "$LIBRE_SH" --quiet; echo $? > "$TMP/foto-b" ) &
  wait
  [ "$(cat "$TMP/foto-a")" = "0" ] || CANTARON=$((CANTARON + 1))
  [ "$(cat "$TMP/foto-b")" = "0" ] || CANTARON=$((CANTARON + 1))
done
[ "$CANTARON" -eq 0 ] && ok "6 fotos simultáneas, 0 falsos «ocupado»" \
                      || mal "$CANTARON de 6 fotos dijeron «ocupado» con el simulador en reposo" \
                             "se están contando entre ellas: el gate se bloquea solo"

# ─────────────────────────────────────────────────────────────────
caso "quiesce · el turno espera a que el simulador se quede quieto"
# **Tener el turno no es tener el simulador.** El runner de XCUITest no es hijo de
# `xcodebuild` —cuelga de `launchd_sim`— así que si una corrida muere de golpe, el kernel
# suelta el lock EN ESE INSTANTE y el runner sigue dentro. Medido el 2026-09-12 con una
# corrida real: 1 runner vivo a los 1, 3, 6 y 10 s de matar el `xcodebuild`, con el lock ya
# libre. Aquí se finge ese runner con un proceso cuyo argv lleva la cadena que `pgrep -f`
# busca, sin tocar ningún simulador.
sh -c 'sleep 4; :' YalaUITests-Runner &
FANTASMA=$!
sleep 1
INICIO=$(date +%s)
bash "$LOCK_SH" --quiet --timeout 30 -- true
CODIGO=$?
TARDO=$(( $(date +%s) - INICIO ))
wait $FANTASMA 2>/dev/null
[ "$CODIGO" -eq 0 ] && ok "el comando corre" || mal "salió $CODIGO"
if [ "$TARDO" -ge 2 ]; then
  ok "esperó ${TARDO}s a que el runner se fuera, en vez de instalar encima"
else
  mal "entró en ${TARDO}s con un runner todavía dentro" \
      "eso es instalar el .app sobre el bundle de otro: el modo de fallo que la cola evita"
fi

# ─────────────────────────────────────────────────────────────────
caso "entorno · sin python3 no se ejecuta el comando"
TESTIGO="$TMP/sin-python"
# `/bin/bash` por ruta absoluta: con el PATH vaciado, `bash` a secas tampoco se encuentra y
# el caso se rompía a sí mismo (127 en vez de medir nada).
PATH="/nonexistent" /bin/bash "$LOCK_SH" --quiet -- /usr/bin/touch "$TESTIGO" >/dev/null 2>&1
CODIGO=$?
[ "$CODIGO" -eq 2 ] && ok "sale 2" || mal "salió $CODIGO, esperaba 2"
[ -f "$TESTIGO" ] && mal "ejecutó el comando SIN lock" "falla abierto: es el modo peligroso" \
                  || ok "no ejecutó nada (falla cerrado)"

echo ""
echo "════════════════════════════════════════════════════════════"
printf ' %d pasan · %d fallan\n' "$PASA" "$FALLA"
echo "════════════════════════════════════════════════════════════"
[ "$FALLA" -eq 0 ] || exit 1
