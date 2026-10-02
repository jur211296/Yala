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
#
# Variables (todas con default):
#   SIM_NAME        nombre del device              (iPhone 17 Pro)
#   SIM_TYPE        device type para crearlo       (…SimDeviceType.iPhone-17-Pro)
#   SIM_INTENTOS    vueltas antes de rendirse      (6)
#   SIM_ESPERA      segundos entre vueltas         (20)
#   XCRUN           binario de xcrun; el banco lo sustituye por uno falso
#   KILLALL         binario de killall; el banco lo sustituye para no tocar el
#                   CoreSimulator de la máquina donde corre
#   GITHUB_OUTPUT   donde escribir `udid=…`        (si falta, solo se imprime)
#
# Banco: qa/scripts/ci-simulador-test.sh
set -euo pipefail

SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"
SIM_TYPE="${SIM_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
SIM_INTENTOS="${SIM_INTENTOS:-6}"
SIM_ESPERA="${SIM_ESPERA:-20}"
XCRUN="${XCRUN:-xcrun}"
KILLALL="${KILLALL:-killall}"

SDK="$("$XCRUN" --sdk iphonesimulator --show-sdk-version 2>/dev/null || true)"
echo "SDK de simulador: ${SDK:-desconocido}"

# Lee `simctl list -j` y contesta una línea: `device <udid>`, `runtime <identifier>` o nada.
elegir() {
  SIM_NAME="$SIM_NAME" SDK="$SDK" python3 -c '
import json, os, sys
name, sdk = os.environ["SIM_NAME"], os.environ["SDK"]
try:
    data = json.loads(sys.stdin.read() or "{}")
except ValueError:
    sys.exit()
def clave(v):
    return [int(x) for x in v.split(".") if x.isdigit()]
rts = [r for r in data.get("runtimes", [])
       if r.get("platform") == "iOS" and r.get("isAvailable")]
casa = lambda r: bool(sdk) and (r["version"] == sdk or r["version"].startswith(sdk + "."))
rts.sort(key=lambda r: (casa(r), clave(r["version"])), reverse=True)
devs = data.get("devices", {})
for r in rts:
    for d in devs.get(r["identifier"], []):
        if d.get("name") == name and d.get("isAvailable", True):
            print("device", d["udid"]); sys.exit()
if rts:
    print("runtime", rts[0]["identifier"])
'
}

UDID=""
for intento in $(seq 1 "$SIM_INTENTOS"); do
  respuesta="$("$XCRUN" simctl list -j 2>/dev/null | elegir || true)"
  case "$respuesta" in
    device\ *)
      UDID="${respuesta#device }"
      echo "Encontrado $SIM_NAME: $UDID (intento $intento)"
      break ;;
    runtime\ *)
      RT="${respuesta#runtime }"
      if UDID="$("$XCRUN" simctl create "$SIM_NAME" "$SIM_TYPE" "$RT")" && [ -n "$UDID" ]; then
        echo "Creado $SIM_NAME en $RT: $UDID (intento $intento)"
        break
      fi
      UDID=""
      echo "::warning title=Simulador::intento $intento: no se pudo crear $SIM_NAME en $RT" ;;
    *)
      echo "::warning title=Simulador::intento $intento/$SIM_INTENTOS: CoreSimulator no devuelve devices ni runtimes iOS; se reinicia" ;;
  esac
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
