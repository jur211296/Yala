#!/usr/bin/env bash
# El cerebro de `.github/workflows/nocturna-vigilante.yml`: decide si a la suite completa de UI le
# falta su corrida de hoy y, si falta, la lanza y comprueba que nació.
#
#   bash qa/scripts/ci-vigilante-nocturna.sh decidir   # escribe decision, motivo, … en $SALIDA
#   bash qa/scripts/ci-vigilante-nocturna.sh lanzar    # escribe nacio, run_id, run_url en $SALIDA
#
# Su banco es `qa/scripts/ci-vigilante-nocturna-test.sh` (corre en el job `coverage-index`).
#
# ─── POR QUÉ ESTÁ ESCRITO ASÍ: lo que se midió el 2026-10-06 ────────────────────────────────────
#
# 1. LA API DE RUNS FILTRADA MIENTE POR OMISIÓN. `GET …/workflows/qa.yml/runs?event=X&branch=Y`
#    devuelve subconjuntos distintos llamada a llamada: dos vigilantes a un minuto de distancia
#    vieron 0 y 1 corridas de `schedule`; en local, la misma consulta dio 0 y, un minuto después,
#    29. El vigilante anterior hacía UNA lectura y, si salía 0, lanzaba: así nacieron sus 22
#    disparos entre el 8-sep y el 6-oct, y LOS 22 FUERON FALSOS — en todos había una corrida de UI
#    en las 26 h previas. Por eso aquí se lee de dos fuentes (con filtro y sin filtro) y en varias
#    rondas, y se hace la UNIÓN: lo observado es que la API omite corridas, nunca que las invente.
#
# 2. EL `schedule` DE GITHUB SÍ CORRE, PERO TARDE. La nocturna nació los 29 días medidos, entre
#    3,9 y 8,9 h después de su cron. Una ventana deslizante de 26 h no aguanta ese vaivén (tres
#    huecos entre nocturnas consecutivas pasaron de 26 h). Aquí se pregunta otra cosa: ¿ha nacido
#    la corrida de HOY? «Hoy» empieza a la hora del cron de `qa.yml`, que se LEE de `qa.yml` para
#    que mover el cron no deje al vigilante mirando la hora vieja. Y antes de `PLAZO_HORAS` desde
#    ese inicio, el vigilante no actúa nunca: la nocturna puede estar aún de camino.
#
# 3. NO PODER LEER NO ES «NO HAY». Si ninguna fuente responde, la decisión es `sin_lectura`, que
#    pasado el plazo también lanza — lanzar una nocturna de más cuesta runner; no lanzarla el día
#    que hacía falta cuesta la cobertura — y el aviso dice que no se pudo comprobar, que es otra
#    noticia (ticket `vigilante-calla-si-no-puede-comprobar-la-nocturna`).
#
# Entorno: REPO (obligatorio) · RAMA (vacía ⇒ la rama por defecto) · QA_YML · AHORA (ISO-8601 UTC;
# si viene, es un ENSAYO y nunca se lanza nada) · FORZAR (si|no) · PLAZO_HORAS · RONDAS · PAUSA ·
# PAUSA_VERIF · GH (el binario de gh; el banco pone uno falso) · SALIDA (por defecto $GITHUB_OUTPUT).
set -uo pipefail

MODO="${1:-}"
REPO="${REPO:?falta REPO}"
RAMA="${RAMA:-}"
QA_YML="${QA_YML:-.github/workflows/qa.yml}"
AHORA="${AHORA:-}"
FORZAR="${FORZAR:-no}"
# 12 h: el retraso máximo medido en 29 días fue 8,9 h. Tres horas de margen; y cada hora de más es
# una hora más que tarda en llegar el aviso el día que el fallo es real.
PLAZO_HORAS="${PLAZO_HORAS:-12}"
RONDAS="${RONDAS:-3}"
PAUSA="${PAUSA:-20}"
PAUSA_VERIF="${PAUSA_VERIF:-5}"
GH="${GH:-gh}"
SALIDA="${SALIDA:-${GITHUB_OUTPUT:-/dev/stdout}}"
WF="qa.yml"
VISTAS="$(mktemp)"
trap 'rm -f "$VISTAS"' EXIT

salida() { echo "$1=$2" >> "$SALIDA"; echo "  → $1=$2"; }
ep()  { jq -nr --arg t "$1" '$t | fromdateiso8601'; }
iso() { jq -nr --argjson s "$1" '$s | todateiso8601'; }
error() { echo "::error title=Vigilante de la nocturna::$1"; }

# Añade a $VISTAS «id evento created_at» de las corridas completas de UI de `qa.yml` sobre $RAMA nacidas
# en [$DESDE, $HASTA], y suma a VALIDAS cuántas fuentes respondieron con una lista legible.
# Escribe a fichero y no a stdout a propósito: llamada dentro de `$(…)`, VALIDAS se perdería.
# «Corrida completa de UI» = `schedule` o `workflow_dispatch`: los dos ponen UI_TOCABA en qa.yml.
# No se filtra por conclusión: una corrida en vuelo cuenta, o el siguiente push lanzaría otra encima.
FILTRO='.workflow_runs[]
  | select((.event == "schedule" or .event == "workflow_dispatch")
           and .head_branch == $rama and .created_at >= $desde and .created_at <= $hasta)
  | "\(.id) \(.event) \(.created_at)"'
leer_ronda() {
  local ev j page viejo
  # Fuente A: el endpoint filtrado en el servidor, un evento cada vez.
  for ev in schedule workflow_dispatch; do
    if j=$("$GH" api "repos/$REPO/actions/workflows/$WF/runs?event=$ev&branch=$RAMA&per_page=100") \
       && jq -e '.workflow_runs | type == "array"' >/dev/null 2>&1 <<<"$j"; then
      VALIDAS=$((VALIDAS + 1))
      jq -r --arg rama "$RAMA" --arg desde "$DESDE" --arg hasta "$HASTA" "$FILTRO" <<<"$j" >> "$VISTAS"
    else
      echo "  (fuente event=$ev sin respuesta legible)" >&2
    fi
  done
  # Fuente B: el listado SIN filtro, filtrado aquí, hasta pasar de $DESDE. qa.yml corre en cada PR
  # y en cada push: una primera página vacía no es «no hay nada», es una lectura que no vale.
  for page in 1 2 3 4 5; do
    j=$("$GH" api "repos/$REPO/actions/workflows/$WF/runs?per_page=100&page=$page") || {
      echo "  (fuente sin filtro, página $page, sin respuesta)" >&2; break; }
    jq -e '.workflow_runs | type == "array" and length > 0' >/dev/null 2>&1 <<<"$j" || {
      echo "  (fuente sin filtro, página $page, vacía o ilegible)" >&2; break; }
    [ "$page" = 1 ] && VALIDAS=$((VALIDAS + 1))
    jq -r --arg rama "$RAMA" --arg desde "$DESDE" --arg hasta "$HASTA" "$FILTRO" <<<"$j" >> "$VISTAS"
    viejo=$(jq -r '.workflow_runs[-1].created_at' <<<"$j")
    [[ "$viejo" < "$DESDE" ]] && break
  done
}

rama_por_defecto() {
  # La rama se PREGUNTA: un `schedule` corre siempre sobre la rama por defecto y no se elige otra.
  # Fijar «2.1» aquí dejaría al vigilante mirando una rama vacía el día que eso cambie.
  [ -n "$RAMA" ] && return 0
  RAMA=$("$GH" api "repos/$REPO" | jq -r '.default_branch // empty' 2>/dev/null) || RAMA=""
  [ -n "$RAMA" ] || { error "No se pudo leer la rama por defecto de $REPO."; exit 1; }
}

decidir() {
  local cron lineas MIN HORA DOM MES DSEM ahora_s slot_s limite_s ronda encontradas ENSAYO=no
  rama_por_defecto

  # El cron de la nocturna, de su propio fichero.
  lineas=$(grep -E "^[[:space:]]*-[[:space:]]*cron:" "$QA_YML" 2>/dev/null || true)
  if [ "$(printf '%s\n' "$lineas" | grep -c cron)" != 1 ]; then
    error "$QA_YML debe tener exactamente un cron y tiene otra cosa: «${lineas}». Sin él no sé cuándo empieza el día de la nocturna."
    exit 1
  fi
  cron=$(sed -E "s/.*cron:[[:space:]]*['\"]([^'\"]+)['\"].*/\1/" <<<"$lineas")
  read -r MIN HORA DOM MES DSEM <<<"$cron"
  if ! [[ "$MIN" =~ ^[0-9]+$ && "$HORA" =~ ^[0-9]+$ && "$DOM $MES $DSEM" = "* * *" ]]; then
    error "El cron de $QA_YML («${cron}») no es diario a hora fija; este vigilante solo sabe vigilar ese caso."
    exit 1
  fi

  if [ -n "$AHORA" ]; then
    ENSAYO=si
    ahora_s=$(ep "$AHORA" 2>/dev/null) || { error "AHORA=«${AHORA}» no es una fecha ISO-8601 UTC (AAAA-MM-DDTHH:MM:SSZ)."; exit 1; }
  else
    ahora_s=$(jq -n 'now | floor')
  fi
  slot_s=$(( ahora_s / 86400 * 86400 + 10#$HORA * 3600 + 10#$MIN * 60 ))
  [ "$slot_s" -gt "$ahora_s" ] && slot_s=$(( slot_s - 86400 ))
  limite_s=$(( slot_s + PLAZO_HORAS * 3600 ))
  DESDE=$(iso "$slot_s"); HASTA=$(iso "$ahora_s")
  echo "Rama $RAMA · cron de la nocturna «${cron}» · el día de hoy empezó $DESDE · plazo hasta $(iso "$limite_s") · ahora $HASTA$( [ "$ENSAYO" = si ] && echo ' (ENSAYO)')"

  # Antes del plazo basta una ronda: no se va a actuar diga lo que diga.
  local rondas="$RONDAS"; [ "$ahora_s" -lt "$limite_s" ] && rondas=1
  VALIDAS=0; encontradas=""
  for ronda in $(seq 1 "$rondas"); do
    leer_ronda
    encontradas=$(grep . "$VISTAS" | sort -u)
    echo "  ronda $ronda: $(grep -c . <<<"$encontradas") corrida(s) de UI vistas, $VALIDAS fuente(s) legibles"
    [ -n "$encontradas" ] && break
    [ "$ronda" -lt "$rondas" ] && sleep "$PAUSA"
  done
  [ -n "$encontradas" ] && sed 's/^/    /' <<<"$encontradas"

  local decision motivo
  if [ "$FORZAR" = si ]; then decision=lanzar; motivo=forzada
  elif [ -n "$encontradas" ]; then decision=cubierta; motivo=ya_corrio
  elif [ "$ahora_s" -lt "$limite_s" ]; then
    decision=esperando; [ "$VALIDAS" -eq 0 ] && motivo=sin_lectura || motivo=aun_no_nacio
  elif [ "$VALIDAS" -eq 0 ]; then decision=lanzar; motivo=sin_lectura
  else decision=lanzar; motivo=falta
  fi

  salida decision "$decision"; salida motivo "$motivo"; salida ensayo "$ENSAYO"; salida rama "$RAMA"
  salida desde "$DESDE"; salida limite "$(iso "$limite_s")"; salida corridas "$(grep -c . <<<"$encontradas")"
  case "$decision/$motivo" in
    cubierta/*)  echo "::notice title=La UI tiene su corrida de hoy::Nacida desde $DESDE." ;;
    esperando/sin_lectura) echo "::warning title=No he podido leer los runs::Aún dentro del plazo; no hago nada." ;;
    esperando/*) echo "::notice title=Esperando a la nocturna::Aún no ha nacido; el plazo acaba $(iso "$limite_s")." ;;
    lanzar/forzada) echo "::notice title=Lanzamiento forzado::Se lanza para verificar el mecanismo." ;;
    lanzar/sin_lectura) echo "::warning title=No he podido comprobar la nocturna::Plazo vencido y ninguna fuente legible: se lanza por si acaso." ;;
    lanzar/*)    echo "::warning title=La nocturna de hoy no ha nacido::Plazo vencido ($(iso "$limite_s")): se lanza desde aquí." ;;
  esac
}

lanzar() {
  local antes resp run_id j
  rama_por_defecto
  # El instante ANTES de disparar es el ancla del respaldo: sin él, un dispatch ajeno reciente
  # pasaría por el nuestro.
  antes=$(iso "$(jq -n 'now | floor')")
  # `workflow_dispatch` es la excepción documentada a «el GITHUB_TOKEN no crea runs». Con
  # `return_run_details` la API contesta 200 con el id del run creado (sin él, 204 y nada: medido
  # en el runner el 2026-10-06), y con ese id se comprueba que nació sin depender de los listados
  # que mienten (punto 1 de arriba). Es lo mismo que manda `gh workflow run` desde la 2.8x.
  if ! resp=$("$GH" api -X POST "repos/$REPO/actions/workflows/$WF/dispatches" -f "ref=$RAMA" -F return_run_details=true); then
    error "El dispatch de $WF en $RAMA falló."
    salida nacio no; exit 1
  fi
  run_id=$(jq -r '.workflow_run_id // empty' 2>/dev/null <<<"$resp" || true)
  if [ -n "$run_id" ]; then
    for _ in $(seq 1 6); do
      if j=$("$GH" api "repos/$REPO/actions/runs/$run_id") \
         && jq -e --arg rama "$RAMA" '.event == "workflow_dispatch" and .head_branch == $rama
              and (.path | startswith(".github/workflows/qa.yml"))' >/dev/null 2>&1 <<<"$j"; then
        salida nacio si; salida run_id "$run_id"; salida run_url "$(jq -r '.html_url' <<<"$j")"
        echo "::notice title=Nocturna lanzada::Run $run_id creado; la suite de UI corre ahora."
        return 0
      fi
      sleep "$PAUSA_VERIF"
    done
    error "La API devolvió el run $run_id pero no se puede leer como un dispatch de $WF en $RAMA."
    salida nacio no; exit 1
  fi
  # Respaldo, por si la API vuelve a contestar 204 sin cuerpo: buscar el run en los listados.
  echo "La API no devolvió el id del run; se busca en los listados (nacido desde $antes)."
  DESDE="$antes"
  for _ in $(seq 1 12); do
    sleep "$PAUSA_VERIF"
    HASTA=$(iso "$(( $(jq -n 'now | floor') + 60 ))"); VALIDAS=0
    : > "$VISTAS"; leer_ronda
    if grep -q " workflow_dispatch " "$VISTAS"; then
      salida nacio si
      echo "::notice title=Nocturna lanzada::El run existe. La suite de UI corre ahora."
      return 0
    fi
  done
  error "gh salió en verde pero no aparece ningún run nuevo de $WF tras $((12 * PAUSA_VERIF)) s."
  salida nacio no; exit 1
}

case "$MODO" in
  decidir) decidir ;;
  lanzar)  lanzar ;;
  *) echo "uso: $0 decidir|lanzar" >&2; exit 2 ;;
esac
