#!/bin/bash
# El simulador es UNO y las sesiones son catorce: aquí se hace cola.
#
# Envuelve un comando que use el simulador para tests (`xcodebuild … test`) en un lock
# EXCLUSIVO compartido por toda la máquina. La segunda sesión **espera**; no falla, no
# instala su `.app` encima de la que está corriendo, y no mata el runner ajeno.
#
#   bash qa/scripts/sim-lock.sh -- xcodebuild -scheme "Yala Dev" … test …
#   bash qa/scripts/sim-lock.sh --estado
#
# ## Por qué existe, y por qué no basta con detectar
#
# `sim-libre.sh` DETECTA la colisión —antes (foto) y durante (`--vigilar`)— pero cuando
# canta, la corrida ya se perdió. Y perderla no es barato: el 2026-09-11 un rojo de una
# corrida pisada, **con su línea de fallo y su mensaje de aserto**, se archivó como ticket
# `high` y costó una sesión entera refutarlo. Decisión de Jürgen (2026-09-11): opción (2)
# del ticket `diez-worktrees-comparten-un-simulador` — lock de fichero. NO un simulador
# por worktree (la Mini no aguanta varios booteados: con 4 el load llegó a 944 y el tiempo
# por corrida se duplicó), y NO dejarlo solo en la guardia.
#
# ## Por qué python3 y no `flock`
#
# **macOS no trae `flock(1)`** — es de util-linux (medido: `command -v flock` → vacío).
# `shlock(1)` sí está, pero es PID-based: deja el lock puesto si el dueño muere de golpe y
# hay que detectar el cadáver por polling, con los PIDs reciclándose por debajo. El lock
# del kernel (`fcntl.flock`) no tiene ese problema: **lo suelta el kernel cuando el proceso
# muere, incluso con `kill -9`**, así que no hay huérfanos que limpiar en `/cerrar`.
#
# Tres propiedades medidas el 2026-09-12 en esta máquina, y las tres son load-bearing:
#
#  1. **El lock sobrevive al `exec`**, porque va atado al *open file description*, no al
#     proceso. Por eso este script puede encadenar `exec python3` → `execvp(xcodebuild)`.
#     Comprobado **con un `xcodebuild` de verdad dentro**, no solo con shells: en la
#     medición de dos corridas reales, la segunda esperó 54 s con la primera compilando y
#     corriendo. Si `xcodebuild` cerrara los fds heredados, habría entrado al instante.
#  2. **`os.set_inheritable(fd, True)` hace falta.** Python pone `O_CLOEXEC` por defecto
#     desde 3.4: sin esa línea el fd se cierra en el `exec` y el lock **se evapora** — dos
#     corridas a la vez, en silencio, que es el modo de fallo peligroso. Control negativo
#     corrido: sin la línea, el segundo proceso consigue el lock. Lo fija el caso
#     `serializa` de `qa/scripts/sim-lock-test.sh`.
#  3. **El PID se preserva** por la cadena de `exec`, así que `sim-lock.sh … & echo $!` da
#     el PID del `xcodebuild` de verdad — que es justo lo que `sim-libre.sh --vigilar`
#     exige, y no admite el PID de un shell envoltorio.
#
# ## La marca de reentrada NO es un PID, y eso importa
#
# Un `sim-lock.sh` dentro de otro se abrazaría a sí mismo (`flock` sobre otro fd del mismo
# fichero bloquea aunque sea el mismo proceso), así que hace falta reconocer «este turno ya
# es mío». La primera versión usaba el PID del dueño y **tenía dos llaves maestras**, las
# dos reproducidas el 2026-09-12: con `YALA_SIM_LOCK_HELD=0`, `os.kill(0, 0)` señala al
# propio grupo de procesos y nunca falla ⇒ **cualquiera con esa variable corría sin lock, en
# silencio**; y con el PID de un proceso de otro usuario, el `PermissionError` se leía como
# «vivo, es mi ancestro» ⇒ lo mismo. Más el reciclado de PIDs, que es justo el motivo por el
# que aquí se descartó `shlock`. Ahora la marca es un **token aleatorio** que el dueño
# escribe DENTRO del lockfile: solo es reentrante quien lleva el token que el lock tiene
# puesto ahora mismo. Un valor inventado no coincide con nada y cae a la cola — falla
# CERRADO. Lo que la reentrada sí concede, y es correcto, es que **todo lo que cuelgue de un
# turno comparte ese turno**: si un script lanza dos `xcodebuild` en paralelo dentro del
# suyo, se pisan entre ellos. El turno es de quien lo pidió, y repartirlo es cosa suya.
#
# ## Qué NO cubre
#
# - **Al `/qa` de producto no se le pone lock**: ese es device-QA a mano, con un humano
#   mirando, y encolarlo detrás de un gate de 40 min no ayuda a nadie. Ojo con la otra
#   cara: un `simctl install` suelto pisa un bundle id sin que ninguna de las dos firmas
#   que vigila `sim-libre.sh` lo vea (ticket `qa-de-producto-toca-el-simulador-sin-cola`).
# - **Un worktree cuya rama no traiga este script no hace cola** (el fichero vive en el
#   árbol de trabajo, como `.githooks/`). Por eso `sim-libre.sh --vigilar` SIGUE siendo la
#   red: caza al que corre sin lock. Si el centinela canta con el lock puesto, el intruso
#   es una rama vieja o un `xcodebuild` lanzado a mano.
# - **El turno cubre TODO el `xcodebuild … test`, compilación incluida**, así que el
#   simulador está parado durante el build. Se aceptó para no complicar el gate; si la cola
#   se hace larga, el arreglo es sacar el `build-for-testing` fuera del turno (ticket
#   `el-turno-del-simulador-cubre-tambien-la-compilacion`).
# - **No hay orden de llegada**: en cada liberación compiten todos los que esperan. Con dos
#   o tres sesiones da igual; si alguna se queda fuera de forma sistemática, hay ticket.
# - **El CI no lo necesita**: corre en `macos-26` de GitHub, una máquina por run.
#
# Exit: el del comando · 2 = error de uso o de entorno · 75 = se agotó `--timeout`
set -u

LOCK_DEFECTO="$HOME/Library/Caches/Yala/simulador.lock"
TIMEOUT=0          # 0 = esperar lo que haga falta
QUIET=0
MODO="ejecutar"

uso() {
  cat >&2 <<'TXT'
uso: bash qa/scripts/sim-lock.sh [--timeout SEGS] [--quiet] -- <comando…>
     bash qa/scripts/sim-lock.sh --estado

  --timeout SEGS  deja de esperar y sale 75 SIN ejecutar el comando.
                  Por defecto espera indefinidamente: una corrida de XCUITest dura
                  entre 3 y 40 min y un timeout corto solo convierte la cola en el
                  rojo que veníamos a evitar.
  --quiet         sin mensajes de espera (el exit code no cambia).
  --estado        dice si el simulador está tomado y por quién. No espera.
                  Toma el lock un instante para comprobarlo y lo suelta, así que su
                  respuesta caduca al salir: NO sirve de puerta (`--estado && xcodebuild`
                  es una carrera). Para correr, haz cola.

El lockfile vive FUERA del repo (todos los worktrees comparten uno):
  $YALA_SIM_LOCK  o, por defecto,  ~/Library/Caches/Yala/simulador.lock
TXT
}

while [ $# -gt 0 ]; do
  case "$1" in
    --timeout)
      [ $# -ge 2 ] || { echo "⛔ --timeout necesita un número de segundos" >&2; uso; exit 2; }
      TIMEOUT="$2"; shift 2 ;;
    --quiet)   QUIET=1; shift ;;
    --estado)  MODO="estado"; shift ;;
    --help|-h) uso; exit 0 ;;
    --)        shift; break ;;
    *)         echo "⛔ opción desconocida: $1" >&2; uso; exit 2 ;;
  esac
done

case "$TIMEOUT" in
  ''|*[!0-9]*) echo "⛔ --timeout espera un número de segundos, no «${TIMEOUT}»" >&2; exit 2 ;;
esac

if [ "$MODO" = "ejecutar" ] && [ $# -eq 0 ]; then
  echo "⛔ falta el comando. ¿Olvidaste el «--»?" >&2
  uso; exit 2
fi

# **Si no hay python3, esto NO ejecuta el comando igual.** Un candado que se salta a sí
# mismo cuando le falta una pieza no es un candado: sería exactamente la corrida sin cola
# que este script viene a impedir, y encima invisible.
if ! command -v python3 >/dev/null 2>&1; then
  echo "⛔ sin python3 no hay lock, y sin lock no se corre: dos corridas sobre el mismo" >&2
  echo "   simulador se derriban y el rojo resultante parece tuyo." >&2
  exit 2
fi

RUTA_LOCK="${YALA_SIM_LOCK:-$LOCK_DEFECTO}"
# Una ruta relativa haría que cada worktree cerrase sobre SU propio fichero: catorce locks
# y ninguna cola, sin un solo mensaje que lo delate.
case "$RUTA_LOCK" in
  /*) ;;
  *)  echo "⛔ \$YALA_SIM_LOCK tiene que ser una ruta absoluta, y es «${RUTA_LOCK}»." >&2
      echo "   Con una relativa cada worktree cerraría sobre un fichero distinto." >&2
      exit 2 ;;
esac

export YALA_SIM_LOCK_PATH="$RUTA_LOCK"
export YALA_SIM_LOCK_DEFECTO="$LOCK_DEFECTO"
export YALA_SIM_LOCK_TIMEOUT="$TIMEOUT"
export YALA_SIM_LOCK_QUIET="$QUIET"

PY='
import errno, fcntl, os, re, signal, subprocess, sys, time, uuid

ruta    = os.environ["YALA_SIM_LOCK_PATH"]
defecto = os.environ["YALA_SIM_LOCK_DEFECTO"]
timeout = float(os.environ["YALA_SIM_LOCK_TIMEOUT"])
quiet   = os.environ["YALA_SIM_LOCK_QUIET"] == "1"
modo    = sys.argv[1]
cmd     = sys.argv[2:]
SONDEO  = 1.0

def di(*a):
    if not quiet:
        print(*a, file=sys.stderr)
        sys.stderr.flush()

def muere(msg):
    print("ERROR " + msg, file=sys.stderr)
    sys.exit(2)

def abrir():
    """Abre el lockfile. Un error aqui sale con 2 (el contrato de la cabecera), no con un
    traceback y un exit 1 que se confunde con «los tests fallaron»."""
    carpeta = os.path.dirname(ruta)
    try:
        if carpeta:
            os.makedirs(carpeta, exist_ok=True)
        fd = os.open(ruta, os.O_RDWR | os.O_CREAT, 0o644)
    except (OSError, IOError) as e:
        muere("no se pudo abrir el lockfile %s: %s" % (ruta, e))
    # Load-bearing: sin esto el fd lleva O_CLOEXEC y el lock se pierde en el execvp.
    os.set_inheritable(fd, True)
    return fd

fd = abrir()

def tomar():
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except (OSError, IOError) as e:
        if e.errno in (errno.EAGAIN, errno.EACCES, errno.EWOULDBLOCK):
            return False
        raise

def letrero():
    """Lo que el dueño dejo escrito. Se lee SIN el lock: vale para el mensaje y para
    comparar el token, nunca para conceder nada por su cuenta."""
    try:
        os.lseek(fd, 0, os.SEEK_SET)
        return os.read(fd, 4096).decode("utf-8", "replace").strip()
    except (OSError, IOError):
        return ""

def campos():
    partes = letrero().split("\t")
    return partes if len(partes) >= 5 else []

def quien():
    p = campos()
    if not p:
        crudo = letrero()
        return crudo[:200] if crudo else ""
    return "pid %s . desde %s . %s\n     |- %s" % (p[1], p[2], p[3], p[4][:120])

def mismo_fichero():
    """El fd puede quedar sobre un inodo DESENLAZADO: alguien borro o reemplazo el lockfile
    mientras lo teniamos abierto (`~/Library/Caches` es purgable). A partir de ahi cada
    proceso nuevo crea otro inodo y la exclusion mutua se acabo, en silencio."""
    try:
        return os.fstat(fd).st_ino == os.stat(ruta).st_ino
    except (OSError, IOError):
        return False

if modo == "estado":
    if tomar():
        fcntl.flock(fd, fcntl.LOCK_UN)
        print("OK Simulador libre - nadie tiene el lock.")
        if ruta != defecto:
            print("   (lockfile: %s)" % ruta)
        sys.exit(0)
    print("TOMADO El simulador esta ocupado.")
    q = quien()
    if q:
        print("   " + q)
    if ruta != defecto:
        print("   (lockfile: %s)" % ruta)
    print("")
    print("   Para hacer cola: bash qa/scripts/sim-lock.sh -- <tu xcodebuild ...>")
    sys.exit(1)

# ── Reentrada ────────────────────────────────────────────────────────────────────────
# La marca es un TOKEN, no un PID, y solo vale si coincide con el que el lock tiene escrito
# AHORA MISMO. Un valor inventado (0, 1, el pid de otro, uno reciclado) no coincide con nada
# y cae a la cola.
tenemos_turno = False
marca = os.environ.get("YALA_SIM_LOCK_HELD", "")
if marca:
    if tomar():
        # Estaba libre: la marca era de un dueño ya muerto. El turno es nuestro por la via
        # normal, sin atajo.
        tenemos_turno = True
    else:
        p = campos()
        if p and p[0] == marca:
            di("- El turno del simulador ya es tuyo (lo tiene un ancestro): no se pide otra vez.")
            try:
                os.execvp(cmd[0], cmd)
            except OSError as e:
                muere("no se pudo ejecutar %s: %s" % (cmd[0], e))

# ── La cola ──────────────────────────────────────────────────────────────────────────
t0 = time.time()
if not tenemos_turno and not tomar():
    di("[cola] El simulador esta ocupado: esta corrida ESPERA (no se corre encima).")
    q = quien()
    if q:
        di("   lo tiene: " + q)
    if ruta != defecto:
        di("   (lockfile: %s)" % ruta)
    ultimo_aviso = t0
    while not tomar():
        esperado = time.time() - t0
        if timeout and esperado >= timeout:
            di("[cola] Se agoto la espera (%d s) y el comando NO se ejecuto." % timeout)
            di("       Nadie corrio encima de nadie: esto es la cola, no un fallo de test.")
            sys.exit(75)
        if time.time() - ultimo_aviso >= 60:
            q = quien().split("\n")[0]
            di("   ... %d min esperando el simulador.%s" % (
               esperado // 60, ("  ahora lo tiene: " + q) if q else ""))
            ultimo_aviso = time.time()
        # El sondeo NO puede pasarse del timeout, o un `--timeout 2` dormiria la siesta
        # entera y el tope no cortaria nunca (medido). Quien pone un tope corto es porque
        # no quiere esperar.
        pausa = SONDEO
        if timeout:
            pausa = min(SONDEO, max(0.05, timeout - (time.time() - t0)))
        time.sleep(pausa)
    di("[cola] Turno tomado tras %d s de espera." % (time.time() - t0))

# El turno es nuestro. Antes de fiarnos: ¿seguimos cerrando sobre el fichero que esta en la
# ruta? Si alguien lo borro, tenemos un lock sobre un inodo que ya no protege nada.
intentos = 0
while not mismo_fichero():
    intentos += 1
    if intentos > 3:
        muere("el lockfile %s cambia de inodo mientras se toma: alguien lo esta borrando." % ruta)
    di("[cola] El lockfile fue reemplazado bajo nuestros pies; reabriendo.")
    try:
        fcntl.flock(fd, fcntl.LOCK_UN)
        os.close(fd)
    except (OSError, IOError):
        pass
    fd = abrir()
    while not tomar():
        time.sleep(SONDEO)

# ── El simulador tarda en quedarse quieto ────────────────────────────────────────────
# **Tener el turno no significa que el simulador este libre, y esto esta MEDIDO (2026-09-12).**
# El runner de XCUITest no es hijo de `xcodebuild`: cuelga de `launchd_sim`, dentro del
# simulador. Si una corrida muere de golpe —Ctrl-C, un `kill`, la sesion que se cierra— el
# kernel suelta el lock EN ESE INSTANTE y su runner sigue vivo: medido, 1 runner vivo a los
# 1, 3, 6 y 10 s de matar el `xcodebuild`, con el lock ya LIBRE. El siguiente de la cola
# entraria a instalar su `.app` sobre el mismo bundle id con el runner ajeno dentro, que es
# exactamente el modo de fallo que la cola viene a impedir.
#
# Asi que el turno se toma en dos tiempos: la cerradura, y luego esperar a que el simulador
# se quede quieto. Un runner cuyo `xcodebuild` ya no existe no es de nadie y se retira; si
# hay un `xcodebuild … test` vivo ahi fuera, el runner puede ser suyo (alguien corriendo sin
# cola) y entonces no se toca: se avisa, porque ese rojo no seria tuyo.
def runners_vivos():
    try:
        salida = subprocess.run(["pgrep", "-f", "[U]ITests-Runner"],
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        return [int(x) for x in salida.stdout.split()]
    except Exception:
        return []

def corridas_ajenas():
    """`xcodebuild` ejecutando tests que no seamos nosotros."""
    try:
        salida = subprocess.run(["pgrep", "-x", "xcodebuild"],
                                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        pids = [int(x) for x in salida.stdout.split() if int(x) != os.getpid()]
    except Exception:
        return []
    vivos = []
    for pid in pids:
        try:
            mando = subprocess.run(["ps", "-o", "command=", "-p", str(pid)],
                                   stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            texto = mando.stdout.decode("utf-8", "replace")
        except Exception:
            continue
        if re.search(r"(^| )(test|test-without-building)( |$)", texto):
            vivos.append(pid)
    return vivos

ESPERA_QUIETO = 60
t_quieto = time.time()
avisado = False
while runners_vivos():
    if not avisado:
        di("[cola] El turno es tuyo, pero el simulador aun tiene un runner dentro: esperando.")
        avisado = True
    if time.time() - t_quieto >= ESPERA_QUIETO:
        ajenas = corridas_ajenas()
        if ajenas:
            di("[cola] Sigue habiendo un runner y hay otro xcodebuild corriendo tests SIN cola")
            di("       (pids: %s). Tu corrida arranca igual, pero su veredicto puede no valer:"
               % " ".join(str(x) for x in ajenas))
            di("       vigilala con `bash qa/scripts/sim-libre.sh --vigilar $!`.")
        else:
            huerfanos = runners_vivos()
            di("[cola] Runner(s) huerfano(s) de una corrida que murio de golpe: %s. Se retiran."
               % " ".join(str(x) for x in huerfanos))
            for pid in huerfanos:
                try:
                    os.kill(pid, signal.SIGKILL)
                except OSError:
                    pass
            time.sleep(1)
        break
    time.sleep(1)
if avisado and not runners_vivos():
    di("[cola] Simulador quieto tras %d s." % (time.time() - t_quieto))

# El letrero. El token va primero, para que la reentrada lo reconozca; y se ESCRIBE antes de
# recortar el fichero, para que un lector no lo pille vacio a media escritura.
token = "%d-%s" % (os.getpid(), uuid.uuid4().hex[:12])
try:
    datos = "\t".join([
        token,
        str(os.getpid()),
        time.strftime("%Y-%m-%d %H:%M:%S"),
        os.getcwd(),
        " ".join(cmd),
    ]) + "\n"
    crudo = datos.encode("utf-8")
    os.pwrite(fd, crudo, 0)
    os.ftruncate(fd, len(crudo))
except (OSError, IOError):
    pass   # el lock ya esta tomado; el letrero es cortesia, no la cerradura

os.environ["YALA_SIM_LOCK_HELD"] = token
# execvp y no fork: conserva el PID (lo que --vigilar necesita) y el exit code del comando,
# y el kernel suelta el lock cuando ese proceso muera, pase lo que pase.
try:
    os.execvp(cmd[0], cmd)
except OSError as e:
    muere("no se pudo ejecutar %s: %s" % (cmd[0], e))
'

if [ "$MODO" = "estado" ]; then
  exec python3 -c "$PY" estado
fi

exec python3 -c "$PY" ejecutar "$@"
