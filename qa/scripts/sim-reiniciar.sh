#!/usr/bin/env bash
# Reinicia el simulador del gate entre la fase unitaria (paso 2) y la de interfaz (paso 3).
#
#   bash qa/scripts/sim-reiniciar.sh                    # «iPhone 17 Pro», el de `/gate`
#   bash qa/scripts/sim-reiniciar.sh "iPhone 17 Pro"
#
# Por qué existe (deuda de 2.3, 27-nov-2026): al menos siete cierres de noviembre cuentan lo mismo. La primera corrida
# de XCUITest tras `YalaTests` entero muere sin ejecutar ningún caso, con «AX loaded» en el log (la accesibilidad del
# simulador, no la app), y la misma corrida pasa tras apagar y arrancar el simulador. El gate lo hace ahora siempre,
# en vez de descubrirlo con una corrida perdida.
#
# Qué hace, en este orden:
#   1. Pide el turno del simulador (`sim-lock.sh`): apagar el simulador con la corrida de otra sesión dentro se la
#      tumbaría. Si ya corre dentro de un turno (`YALA_SIM_LOCK_HELD` válido), lo reutiliza.
#   2. Busca los simuladores ENCENDIDOS con ese nombre. Si no hay ninguno —`xcodebuild test` apaga al terminar el
#      simulador que arrancó él, así que tras la unitaria es lo normal—, toma el disponible con ese nombre en el
#      runtime más nuevo, que es el que elige `-destination name=…`.
#   3. Apaga los encendidos, los arranca y espera a que estén listos (`simctl bootstatus -b`), con techo de
#      $TECHO_SEGUNDOS. Así la interfaz no paga el arranque en frío dentro de su primera corrida. El simulador queda
#      encendido: lo apaga el cierre de la sesión (`/cerrar`, `/cerrar-total`).
#   4. Deja $ASENTAR_SEGUNDOS de reposo: la primera corrida tras arrancar es la más lenta del bloque
#      (`.claude/rules/testing.md`, regla de la primera corrida tras bootear).
#
# Salida: 0 = listo · 1 = no se pudo (el gate lo anota y corre la interfaz igual: sin
# reiniciar vuelve el riesgo de «AX loaded», no un rojo nuevo).
#
# Variables: TECHO_SEGUNDOS (180), ASENTAR_SEGUNDOS (15), XCRUN (xcrun; para sustituirlo en una prueba).
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
NOMBRE="iPhone 17 Pro"
DENTRO=0
for arg in "$@"; do
  case "$arg" in
    --dentro-del-turno) DENTRO=1 ;;
    *) NOMBRE="$arg" ;;
  esac
done
TECHO_SEGUNDOS="${TECHO_SEGUNDOS:-180}"
ASENTAR_SEGUNDOS="${ASENTAR_SEGUNDOS:-15}"
XCRUN="${XCRUN:-xcrun}"

# 1 · El turno. `sim-lock.sh` encadena `exec`, así que esto vuelve a entrar aquí ya con el lock puesto.
if [ "$DENTRO" -eq 0 ]; then
  exec bash "$DIR/sim-lock.sh" -- bash "$0" --dentro-del-turno "$NOMBRE"
fi

# 2 · Los encendidos con ese nombre; sin ninguno, el disponible del runtime más nuevo. Una línea por device:
#     «<udid> <estado>».
devices="$("$XCRUN" simctl list devices available -j 2>/dev/null | python3 -c '
import json, re, sys
nombre = sys.argv[1]
try:
    datos = json.load(sys.stdin)
except Exception:
    sys.exit(0)
def version(runtime):
    return [int(n) for n in re.findall(r"\d+", runtime.rsplit(".", 1)[-1])]
candidatos = [(version(rt), d) for rt, devs in datos.get("devices", {}).items() for d in devs
              if d.get("name") == nombre]
encendidos = [d for _, d in candidatos if d.get("state") == "Booted"]
if encendidos:
    for d in encendidos:
        print(d["udid"], "Booted")
elif candidatos:
    d = max(candidatos, key=lambda c: c[0])[1]
    print(d["udid"], d.get("state", "Shutdown"))
' "$NOMBRE")"

if [ -z "$devices" ]; then
  echo "[sim-reiniciar] no hay ningún «$NOMBRE» disponible" >&2
  exit 1
fi

fallo=0
while read -r udid estado; do
  [ -n "$udid" ] || continue
  inicio=$(date +%s)
  if [ "$estado" = "Booted" ]; then
    echo "[sim-reiniciar] apagando $NOMBRE ($udid)"
    if ! "$XCRUN" simctl shutdown "$udid"; then
      echo "[sim-reiniciar] no se pudo apagar $udid" >&2
      fallo=1
      continue
    fi
  else
    echo "[sim-reiniciar] $NOMBRE ($udid) estaba apagado"
  fi
  echo "[sim-reiniciar] arrancando $udid"
  # `bootstatus -b` arranca si hace falta y espera a que el simulador termine de arrancar.
  "$XCRUN" simctl bootstatus "$udid" -b > /dev/null 2>&1 &
  espera=$!
  vencido=0
  while kill -0 "$espera" 2>/dev/null; do
    if [ $(( $(date +%s) - inicio )) -ge "$TECHO_SEGUNDOS" ]; then
      kill "$espera" 2>/dev/null
      echo "[sim-reiniciar] $udid no quedó listo en ${TECHO_SEGUNDOS}s" >&2
      vencido=1
      break
    fi
    sleep 2
  done
  if wait "$espera" && [ "$vencido" -eq 0 ]; then
    echo "[sim-reiniciar] $udid listo en $(( $(date +%s) - inicio ))s"
  else
    fallo=1
  fi
done <<< "$devices"

if [ "$fallo" -eq 0 ] && [ "$ASENTAR_SEGUNDOS" -gt 0 ]; then
  echo "[sim-reiniciar] reposo de ${ASENTAR_SEGUNDOS}s antes de la interfaz"
  sleep "$ASENTAR_SEGUNDOS"
fi
exit "$fallo"
