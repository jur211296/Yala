#!/usr/bin/env bash
# Deja listo el simulador del job `tests` de `.github/workflows/qa.yml` y escribe su UDID
# en $GITHUB_OUTPUT (`udid=…`). Lo llama el paso «Simulador del runner».
#
# Por qué existe: en el runner hospedado de GitHub, CoreSimulator a veces aún no ha
# cargado los devices cuando `xcodebuild` pregunta, y la corrida muere con exit 70 y
# cero simuladores listados (8 veces entre el 2026-08-18 y el 2026-10-02). Aquí se
# pregunta antes, con reintentos:
#
#   1. Busca un device disponible llamado $SIM_NAME. Prefiere el runtime cuya versión
#      casa con el SDK de simulador del Xcode activo; si no, el runtime más nuevo.
#   2. Si no hay device pero sí runtime iOS disponible, lo crea por tipo + runtime.
#   3. Si CoreSimulator no devuelve ni device ni runtime, lo reinicia y vuelve a mirar.
#   4. Si tras $SIM_DESCARGA_TRAS vueltas sigue sin runtime iOS, descarga la plataforma
#      (`xcodebuild -downloadPlatform iOS`) UNA vez. Los logs de las caídas no distinguen
#      «CoreSimulator tarda» de «la imagen vino sin runtime», así que se cubren los dos.
#
# SOLO RUNTIMES QUE ADMITEN EL MODELO (2026-10-23). La imagen `xcode-27-arm64` 20261022.0305
# trajo un runtime iOS 27.1 (24A94425) con un único simulador, el iPhone Duo. Casaba con el SDK
# 27.1, el paso 1 lo prefería, y `simctl create` contestaba 8 veces `SimError 403 · Incompatible
# device`: todos los PR a 2.2 en rojo sin correr un test (run 39930117496). Dos defensas:
#   a. Se descartan los runtimes cuyo `supportedDeviceTypes` no trae $SIM_TYPE. Si la clave
#      falta (un simctl que no la da), el runtime se acepta, como antes.
#   b. Si aun así `create` contesta «Incompatible device», ese runtime se excluye y la vuelta
#      siguiente prueba el próximo. Otro fallo de `create` se reintenta en el mismo runtime.
# Si ningún runtime iOS admite el modelo, la vuelta cuenta como vacía (reinicio y descarga).
#
# NUNCA UN RUNTIME MÁS NUEVO QUE EL SDK, SI HAY OTRO (2026-11-07). La imagen `xcode-27-arm64`
# 20261104.0337.1 trajo Xcode 27.2 final y, con él, un runtime iOS 27.2 completo. El 27.1 seguía
# siendo solo del Duo, y la regla «si ninguno casa con el SDK, el más nuevo» elegía el 27.2 en vez
# del 27.0 de siempre. Con el Xcode 27.1 del CI, el paquete de UI no cargaba ahí:
# `AppIntentsTesting.framework` de Xcode 27.1 pide a `AppIntentsServices` del runtime un símbolo
# que el 27.2 ya no tiene («Failed to load the test bundle», `Symbol not found`). Las nueve tandas
# de la nocturna corrieron CERO tests del 5 al 7-nov (runs 42064641786, 42247422332, 42383702440)
# y el run salía verde. El orden es ahora, por niveles:
#   1. el runtime que casa con el SDK;
#   2. el más nuevo de los que NO pasan del SDK (hoy, el 27.0: el par Xcode 27.1 + iOS 27.0 corrió
#      la UI entera hasta el 4-nov);
#   3. solo si no hay otro, el MENOS nuevo de los que pasan del SDK, con un aviso.
# El device se busca solo en el mejor nivel: un iPhone 17 Pro ya creado en un runtime peor no le
# gana a crear uno en el bueno. Con SIM_HASTA_SDK=si (job `ui`) el nivel 3 se descarta entero:
# ahí un runtime más nuevo no es un mal menor, es una tanda que no ejecuta ningún test.
#
# EL DESTINO LO VALIDA XCODEBUILD, NO SIMCTL (2026-11-16). La imagen `xcode-27-arm64` 20261112.0361.1
# trae el mismo runtime iOS 27.0 (24A434) que la 20261104, y `simctl create` crea ahí el iPhone 17 Pro
# sin quejarse, pero el Xcode 27.1 del CI ya no lo ofrece como destino: «Build for testing» moría con
# exit 70 y `Unable to find a device matching…`, listando solo iPhones de iOS 27.1 y 27.2 (run
# 43807611829). Lo que `simctl` acepta no es lo que el esquema ve. Por eso, elegido o creado el
# device, se pregunta a `xcodebuild -showdestinations` del esquema:
#   - si lo lista, vale;
#   - si no, ese runtime se excluye y se busca otra vez con el orden de siempre (hoy: crear el
#     iPhone 17 Pro en el 27.2, que en el modo tolerante es un mal menor con aviso);
#   - si no queda ninguno, falla con la lista de destinos iOS que xcodebuild SÍ ve;
#   - si `-showdestinations` no contesta, se avisa y se sigue: el build es la prueba siguiente.
# No se filtra ANTES por lo que lista xcodebuild: solo lista devices que ya existen, y en la imagen
# buena el iPhone 17 Pro del 27.0 se crea aquí, así que ese filtro lo habría descartado también.
# `-derivedDataPath` es el mismo que el del build: la resolución de paquetes que pide el esquema se
# paga una vez y el build la reutiliza.
#
# Al acabar imprime el ENTORNO (preflight): imagen, Xcode, SDK y runtime elegido con su build, y lo
# deja en $GITHUB_OUTPUT (`runtime=…`) y en el resumen del paso.
#
# Variables (todas con default):
#   SIM_NAME        nombre del device              (iPhone 17 Pro)
#   SIM_TYPE        device type para crearlo       (…SimDeviceType.iPhone-17-Pro)
#   SIM_INTENTOS    vueltas antes de rendirse      (8)
#   SIM_DESCARGA_TRAS  vuelta vacía tras la que se descarga la plataforma (3)
#   SIM_ESPERA      segundos entre vueltas         (20)
#   SIM_HASTA_SDK   si = descartar runtimes más nuevos que el SDK  (no)
#   SIM_VALIDAR     no = no preguntar a xcodebuild por el destino  (si)
#   SIM_SCHEME      esquema con el que se valida   (Yala Dev)
#   SIM_PROJECT     proyecto con el que se valida  (Yala.xcodeproj; si no existe, no se valida)
#   SIM_DERIVED     -derivedDataPath de la validación (.ddp, el del build)
#   XCRUN           binario de xcrun; el banco lo sustituye por uno falso
#   XCODEBUILD      binario de xcodebuild; el banco lo sustituye
#   KILLALL         binario de killall; el banco lo sustituye para no tocar el
#                   CoreSimulator de la máquina donde corre
#   GITHUB_OUTPUT   donde escribir `udid=…`        (si falta, solo se imprime)
#
# Banco: qa/scripts/ci-simulador-test.sh
set -euo pipefail

SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"
SIM_TYPE="${SIM_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
SIM_INTENTOS="${SIM_INTENTOS:-8}"
SIM_DESCARGA_TRAS="${SIM_DESCARGA_TRAS:-3}"
SIM_ESPERA="${SIM_ESPERA:-20}"
SIM_HASTA_SDK="${SIM_HASTA_SDK:-no}"
XCRUN="${XCRUN:-xcrun}"
KILLALL="${KILLALL:-killall}"
XCODEBUILD="${XCODEBUILD:-xcodebuild}"
SIM_VALIDAR="${SIM_VALIDAR:-si}"
SIM_SCHEME="${SIM_SCHEME:-Yala Dev}"
SIM_PROJECT="${SIM_PROJECT:-Yala.xcodeproj}"
SIM_DERIVED="${SIM_DERIVED:-.ddp}"

SDK="$("$XCRUN" --sdk iphonesimulator --show-sdk-version 2>/dev/null || true)"
echo "SDK de simulador: ${SDK:-desconocido}"

# Lee `simctl list -j` y contesta una línea: `device <udid> <runtime> <versión> <build>`,
# `runtime <identifier> <versión> <build>`, `incompatible <identifiers>` (hay runtimes iOS pero
# ninguno sirve) o nada.
EXCLUIDOS=""
elegir() {
  SIM_NAME="$SIM_NAME" SIM_TYPE="$SIM_TYPE" SDK="$SDK" EXCLUIDOS="$EXCLUIDOS" SIM_HASTA_SDK="$SIM_HASTA_SDK" python3 -c '
import json, os, sys
name, tipo, sdk = os.environ["SIM_NAME"], os.environ["SIM_TYPE"], os.environ["SDK"]
excluidos = set(os.environ["EXCLUIDOS"].split())
hasta_sdk = os.environ.get("SIM_HASTA_SDK") == "si"
try:
    data = json.loads(sys.stdin.read() or "{}")
except ValueError:
    sys.exit()
def clave(v):
    return [int(x) for x in v.split(".") if x.isdigit()]
def admite(r):
    tipos = r.get("supportedDeviceTypes")
    return tipos is None or any(t.get("identifier") == tipo for t in tipos)
# Nivel de un runtime frente al SDK del Xcode activo: 2 casa, 1 no pasa de él, 0 es más nuevo.
# Sin SDK conocido todos valen 1 y gana el más nuevo, como antes.
def nivel(r):
    v = r.get("version", "")
    if not sdk:
        return 1
    if v == sdk or v.startswith(sdk + "."):
        return 2
    return 0 if clave(v) > clave(sdk) else 1
ios = [r for r in data.get("runtimes", [])
       if r.get("platform") == "iOS" and r.get("isAvailable")]
def motivo(r):
    if r["identifier"] in excluidos:
        return "excluido tras un create incompatible"
    if not admite(r):
        return "no admite " + tipo
    if hasta_sdk and nivel(r) == 0:
        return ("más nuevo que el SDK " + sdk + " de este Xcode: su paquete de tests no carga ahí")
    return None
rts = [r for r in ios if motivo(r) is None]
for r in ios:
    m = motivo(r)
    if m:
        print("descartado", r["identifier"], "(" + r.get("version", "?") + "):", m, file=sys.stderr)
# Dentro de los niveles 2 y 1, el más nuevo; dentro del 0, el MENOS nuevo (el más cercano al SDK).
rts.sort(key=lambda r: (nivel(r), [x if nivel(r) else -x for x in clave(r.get("version", ""))]),
         reverse=True)
def señas(r):
    return " ".join([r["identifier"], r.get("version") or "?", r.get("buildversion") or "?"])
devs = data.get("devices", {})
mejores = [r for r in rts if nivel(r) == nivel(rts[0])] if rts else []
for r in mejores:
    for d in devs.get(r["identifier"], []):
        if d.get("name") == name and d.get("isAvailable", True):
            print("device", d["udid"], señas(r)); sys.exit()
if rts:
    print("runtime", señas(rts[0]))
elif ios:
    print("incompatible", " ".join(r["identifier"] for r in ios))
'
}

vacias=0
descargado=no
# Busca o crea el device en hasta $1 vueltas. Deja UDID, RT, RT_VERSION y RT_BUILD (UDID vacío si no).
buscar() {
local vueltas="$1" intento respuesta err
UDID=""
for intento in $(seq 1 "$vueltas"); do
  respuesta="$("$XCRUN" simctl list -j 2>/dev/null | elegir || true)"
  case "$respuesta" in
    device\ *)
      read -r _ UDID RT RT_VERSION RT_BUILD <<< "$respuesta"
      echo "Encontrado $SIM_NAME: $UDID en $RT (intento $intento)"
      break ;;
    runtime\ *)
      read -r _ RT RT_VERSION RT_BUILD <<< "$respuesta"
      err="$(mktemp)"
      if UDID="$("$XCRUN" simctl create "$SIM_NAME" "$SIM_TYPE" "$RT" 2>"$err")" && [ -n "$UDID" ]; then
        rm -f "$err"
        echo "Creado $SIM_NAME en $RT: $UDID (intento $intento)"
        break
      fi
      cat "$err" >&2
      UDID=""
      if grep -q "Incompatible device" "$err"; then
        EXCLUIDOS="$EXCLUIDOS $RT"
        echo "::warning title=Simulador::intento $intento: $RT no admite $SIM_TYPE; se prueba otro runtime"
        rm -f "$err"
        continue
      fi
      rm -f "$err"
      echo "::warning title=Simulador::intento $intento: no se pudo crear $SIM_NAME en $RT" ;;
    incompatible\ *)
      vacias=$((vacias+1))
      echo "::warning title=Simulador::intento $intento/$vueltas: ningún runtime iOS sirve para $SIM_TYPE con el SDK ${SDK:-desconocido} (${respuesta#incompatible }); se reinicia" ;;
    *)
      vacias=$((vacias+1))
      echo "::warning title=Simulador::intento $intento/$vueltas: CoreSimulator no devuelve devices ni runtimes iOS; se reinicia" ;;
  esac
  if [ "$vacias" -ge "$SIM_DESCARGA_TRAS" ] && [ "$descargado" = no ]; then
    descargado=si
    echo "::warning title=Simulador::$vacias vueltas sin runtime iOS: se descarga la plataforma"
    "$XCODEBUILD" -downloadPlatform iOS || echo "::warning title=Simulador::la descarga de la plataforma falló"
  fi
  [ "$intento" -lt "$vueltas" ] || break
  # Solo procesos del usuario del runner: en el hospedado es una VM de un solo uso.
  "$KILLALL" -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
  sleep "$SIM_ESPERA"
done
}

# Destinos iOS Simulator que el esquema ofrece (solo los «Available»; los placeholders y los que
# traen `error:` no cuentan). Devuelve 1 si `xcodebuild -showdestinations` no contesta.
DESTINOS=""
destinos_ios() {
  local salida
  if ! salida="$("$XCODEBUILD" -showdestinations -scheme "$SIM_SCHEME" -project "$SIM_PROJECT" \
        -derivedDataPath "$SIM_DERIVED" 2>&1)"; then
    printf '%s\n' "$salida" | tail -5 >&2
    return 1
  fi
  DESTINOS="$(printf '%s\n' "$salida" | awk '/Ineligible destinations/ {exit}
    /platform:iOS Simulator/ && /id:/ && !/error:/ && !/placeholder/ {sub(/^[ \t]+/, ""); print}')"
}

buscar "$SIM_INTENTOS"

# ── Validación con xcodebuild (ver «EL DESTINO LO VALIDA XCODEBUILD» arriba) ─────────────────
no_ve=""
validar=no
if [ "$SIM_VALIDAR" = si ] && [ -e "$SIM_PROJECT" ]; then validar=si
elif [ "$SIM_VALIDAR" = si ]; then echo "Sin $SIM_PROJECT aquí: no se valida el destino con xcodebuild."
fi
while [ -n "$UDID" ] && [ "$validar" = si ]; do
  if ! destinos_ios; then
    echo "::warning title=Simulador::xcodebuild -showdestinations no contestó; se sigue con $UDID sin validar (el build lo dirá)"
    break
  fi
  if printf '%s\n' "$DESTINOS" | grep -qF "id:$UDID,"; then
    echo "xcodebuild ve $SIM_NAME $UDID como destino de «$SIM_SCHEME»."
    break
  fi
  echo "::warning title=Simulador::xcodebuild no ve $SIM_NAME $UDID (runtime $RT, iOS ${RT_VERSION:-?}) como destino de «$SIM_SCHEME»; se excluye ese runtime y se busca otro"
  no_ve="$no_ve $RT"
  EXCLUIDOS="$EXCLUIDOS $RT"
  # CoreSimulator ya contestó: lo que falla es la visibilidad en Xcode, y descargar la plataforma
  # no la arregla. Dos vueltas bastan para un `create` incompatible seguido de otro runtime.
  descargado=si
  buscar 2
done

if [ -z "$UDID" ] && [ -n "$no_ve" ]; then
  echo "::error title=Simulador::ningún runtime iOS deja un $SIM_NAME que xcodebuild vea como destino de «$SIM_SCHEME». Excluidos por no verse:$no_ve. Hace falta otro Xcode (qa/scripts/ci-xcode.sh) o una imagen cuyo Xcode vea un runtime con el modelo. Destinos iOS que xcodebuild SÍ ve:"
  printf '%s\n' "${DESTINOS:-(ninguno)}"
  "$XCRUN" simctl list runtimes 2>&1 || true
  exit 1
fi

if [ -z "$UDID" ]; then
  if [ "$SIM_HASTA_SDK" = si ]; then
    echo "::error title=Simulador::sin $SIM_NAME en un runtime iOS que no pase del SDK ${SDK:-desconocido} tras $SIM_INTENTOS intentos. Un runtime más nuevo no vale aquí: el paquete de UI no carga y la tanda ejecutaría cero tests. Hace falta una imagen con un runtime compatible, u otro Xcode (qa/scripts/ci-xcode.sh). Runtimes que ve CoreSimulator:"
  else
    echo "::error title=Simulador::sin $SIM_NAME tras $SIM_INTENTOS intentos. Runtimes que ve CoreSimulator:"
  fi
  "$XCRUN" simctl list runtimes 2>&1 || true
  exit 1
fi

# ── Preflight: el entorno con el que van a correr los tests, en una línea que se lee sola ──────
compat="casa con el SDK"
if [ -z "$SDK" ] || [ "${RT_VERSION:-?}" = "?" ]; then
  compat="compatibilidad desconocida (falta el SDK o la versión del runtime)"
elif [ "$RT_VERSION" != "$SDK" ] && [ "${RT_VERSION#"$SDK".}" = "${RT_VERSION:-}" ]; then
  mayor="$(printf '%s\n%s\n' "$SDK" "$RT_VERSION" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
  if [ "$mayor" = "$RT_VERSION" ]; then
    compat="MÁS NUEVO que el SDK $SDK"
    echo "::warning title=Simulador::el runtime iOS $RT_VERSION es más nuevo que el SDK $SDK del Xcode activo y no había otro. Los unit suelen correr; el paquete de UI no carga (2026-11-05)."
  else
    compat="anterior al SDK $SDK (compatible)"
  fi
fi
xcode="$("$XCODEBUILD" -version 2>/dev/null | paste -sd ' ' - || true)"
entorno="imagen ${ImageOS:-?} ${ImageVersion:-?} · ${xcode:-Xcode ?} · SDK simulador ${SDK:-?} · runtime iOS ${RT_VERSION:-?} (${RT_BUILD:-?}, $RT) · $compat · $SIM_NAME $UDID"
echo "Entorno: $entorno"
[ -z "${GITHUB_STEP_SUMMARY:-}" ] || echo "**Entorno de test:** $entorno" >> "$GITHUB_STEP_SUMMARY"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "udid=$UDID" >> "$GITHUB_OUTPUT"
  echo "runtime=iOS ${RT_VERSION:-?} (${RT_BUILD:-?})" >> "$GITHUB_OUTPUT"
fi
"$XCRUN" simctl list devices 2>/dev/null | grep "$UDID" || true
