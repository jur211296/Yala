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
# Variables (todas con default):
#   SIM_NAME        nombre del device              (iPhone 17 Pro)
#   SIM_TYPE        device type para crearlo       (…SimDeviceType.iPhone-17-Pro)
#   SIM_INTENTOS    vueltas antes de rendirse      (8)
#   SIM_DESCARGA_TRAS  vuelta vacía tras la que se descarga la plataforma (3)
#   SIM_ESPERA      segundos entre vueltas         (20)
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
XCRUN="${XCRUN:-xcrun}"
KILLALL="${KILLALL:-killall}"
XCODEBUILD="${XCODEBUILD:-xcodebuild}"

SDK="$("$XCRUN" --sdk iphonesimulator --show-sdk-version 2>/dev/null || true)"
echo "SDK de simulador: ${SDK:-desconocido}"

# Lee `simctl list -j` y contesta una línea: `device <udid>`, `runtime <identifier>`,
# `incompatible <identifiers>` (hay runtimes iOS pero ninguno admite $SIM_TYPE) o nada.
EXCLUIDOS=""
elegir() {
  SIM_NAME="$SIM_NAME" SIM_TYPE="$SIM_TYPE" SDK="$SDK" EXCLUIDOS="$EXCLUIDOS" python3 -c '
import json, os, sys
name, tipo, sdk = os.environ["SIM_NAME"], os.environ["SIM_TYPE"], os.environ["SDK"]
excluidos = set(os.environ["EXCLUIDOS"].split())
try:
    data = json.loads(sys.stdin.read() or "{}")
except ValueError:
    sys.exit()
def clave(v):
    return [int(x) for x in v.split(".") if x.isdigit()]
def admite(r):
    tipos = r.get("supportedDeviceTypes")
    return tipos is None or any(t.get("identifier") == tipo for t in tipos)
ios = [r for r in data.get("runtimes", [])
       if r.get("platform") == "iOS" and r.get("isAvailable")]
rts = [r for r in ios if admite(r) and r["identifier"] not in excluidos]
for r in ios:
    if r not in rts:
        print("descartado", r["identifier"], "(" + r.get("version", "?") + "):",
              "excluido tras un create incompatible" if r["identifier"] in excluidos
              else "no admite " + tipo, file=sys.stderr)
casa = lambda r: bool(sdk) and (r["version"] == sdk or r["version"].startswith(sdk + "."))
rts.sort(key=lambda r: (casa(r), clave(r["version"])), reverse=True)
devs = data.get("devices", {})
for r in rts:
    for d in devs.get(r["identifier"], []):
        if d.get("name") == name and d.get("isAvailable", True):
            print("device", d["udid"]); sys.exit()
if rts:
    print("runtime", rts[0]["identifier"])
elif ios:
    print("incompatible", " ".join(r["identifier"] for r in ios))
'
}

UDID=""
vacias=0
descargado=no
for intento in $(seq 1 "$SIM_INTENTOS"); do
  respuesta="$("$XCRUN" simctl list -j 2>/dev/null | elegir || true)"
  case "$respuesta" in
    device\ *)
      UDID="${respuesta#device }"
      echo "Encontrado $SIM_NAME: $UDID (intento $intento)"
      break ;;
    runtime\ *)
      RT="${respuesta#runtime }"
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
      echo "::warning title=Simulador::intento $intento/$SIM_INTENTOS: ningún runtime iOS admite $SIM_TYPE (${respuesta#incompatible }); se reinicia" ;;
    *)
      vacias=$((vacias+1))
      echo "::warning title=Simulador::intento $intento/$SIM_INTENTOS: CoreSimulator no devuelve devices ni runtimes iOS; se reinicia" ;;
  esac
  if [ "$vacias" -ge "$SIM_DESCARGA_TRAS" ] && [ "$descargado" = no ]; then
    descargado=si
    echo "::warning title=Simulador::$vacias vueltas sin runtime iOS: se descarga la plataforma"
    "$XCODEBUILD" -downloadPlatform iOS || echo "::warning title=Simulador::la descarga de la plataforma falló"
  fi
  [ "$intento" -lt "$SIM_INTENTOS" ] || break
  # Solo procesos del usuario del runner: en el hospedado es una VM de un solo uso.
  "$KILLALL" -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
  sleep "$SIM_ESPERA"
done

if [ -z "$UDID" ]; then
  echo "::error title=Simulador::sin $SIM_NAME tras $SIM_INTENTOS intentos. Runtimes que ve CoreSimulator:"
  "$XCRUN" simctl list runtimes 2>&1 || true
  exit 1
fi

[ -z "${GITHUB_OUTPUT:-}" ] || echo "udid=$UDID" >> "$GITHUB_OUTPUT"
"$XCRUN" simctl list devices 2>/dev/null | grep "$UDID" || true
