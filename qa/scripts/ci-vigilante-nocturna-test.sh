#!/usr/bin/env bash
# Banco de qa/scripts/ci-vigilante-nocturna.sh. No llama a GitHub: sustituye `gh` por uno falso que
# contesta desde un directorio de escenario, llamada a llamada.
#
#   bash qa/scripts/ci-vigilante-nocturna-test.sh
#
# El falso reconoce cinco tipos de llamada y, para cada tipo T, contesta con el fichero `T.N` (la
# N-ésima llamada de ese tipo) o, si no existe, con `T`; si el fichero empieza por ERROR, falla;
# si existe `T.sh`, lo ejecuta. Tipos: sched y disp (endpoint filtrado por evento), unf1…unf5
# (listado sin filtro, por página), dispatch (POST de lanzamiento), run (GET de un run), repo.
#
# Los escenarios que importan son los de la API que OMITE corridas: es lo que se midió el
# 2026-10-06 y lo que convirtió 22 de 22 disparos del vigilante anterior en falsos.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$AQUI/ci-vigilante-nocturna.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

cat > "$T/gh" <<'FAKE'
#!/usr/bin/env bash
D="$ESCENARIO"
[ "$1" = api ] || { echo "gh falso: $*" >&2; exit 9; }
shift
url=""; for a in "$@"; do case "$a" in repos/*) url="$a" ;; esac; done
case "$url" in
  */dispatches)                          k=dispatch ;;
  */actions/runs/*)                      k=run ;;
  *event=schedule*)                      k=sched ;;
  *event=workflow_dispatch*)             k=disp ;;
  *runs\?per_page=100\&page=*)           k="unf${url##*page=}" ;;
  repos/*/*)                             k=repo ;;
  *) echo "gh falso: url desconocida $url" >&2; exit 9 ;;
esac
echo "$k $*" >> "$D/llamadas"
n=$(cat "$D/n.$k" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "$D/n.$k"
if [ -x "$D/$k.sh" ]; then exec "$D/$k.sh"; fi
f="$D/$k.$n"; [ -f "$f" ] || f="$D/$k"
if [ ! -f "$f" ]; then
  case "$k" in
    repo)     echo '{"default_branch":"2.1"}' ;;
    dispatch) echo '' ;;
    run)      echo 'ERROR' >&2; exit 1 ;;
    *)        echo '{"total_count":0,"workflow_runs":[]}' ;;
  esac
  exit 0
fi
if head -1 "$f" | grep -q '^ERROR'; then echo "gh falso: error HTTP 502" >&2; exit 1; fi
cat "$f"
FAKE
chmod +x "$T/gh"

# runs «id evento rama created_at» … → JSON de un listado de runs.
runs() {
  printf '%s\n' "$@" | grep . | jq -R 'split(" ") | {id: (.[0]|tonumber), event: .[1], head_branch: .[2], created_at: .[3]}' \
    | jq -s '{total_count: length, workflow_runs: .}'
}
# Un listado sin filtro realista: siempre hay runs de PR y de push, también antes del día.
RUIDO=("900 pull_request encargo/x 2026-10-06T14:00:00Z" "901 push 2.1 2026-10-06T13:00:00Z"
       "902 push 2.1 2026-10-05T07:00:00Z")

QA_FALSO="$T/qa.yml"
cat > "$QA_FALSO" <<'YML'
on:
  schedule:
    - cron: '17 8 * * *'
YML

fallos=0; n=0
nuevo() { E="$T/esc.$1"; rm -rf "$E"; mkdir -p "$E"; : > "$E/llamadas"; }
correr() {  # modo, y el resto son asignaciones de entorno
  local modo="$1"; shift
  : > "$E/salida"
  env ESCENARIO="$E" GH="$T/gh" REPO=dueño/repo QA_YML="$QA_FALSO" PAUSA=0 PAUSA_VERIF=0 \
      SALIDA="$E/salida" "$@" bash "$SCRIPT" "$modo" > "$E/log" 2>&1
  echo $? > "$E/exit"
}
valor() { grep "^$1=" "$E/salida" | tail -1 | cut -d= -f2-; }
espera() {  # descripción, clave, valor esperado
  n=$((n+1))
  local v; v=$(valor "$2")
  if [ "$v" = "$3" ]; then echo "  ok  $1"
  else echo "  MAL $1 — $2: esperaba «$3», salió «${v}»"; sed 's/^/        /' "$E/log"; fallos=$((fallos+1)); fi
}
espera_exit() {
  n=$((n+1))
  if [ "$(cat "$E/exit")" = "$2" ]; then echo "  ok  $1"
  else echo "  MAL $1 — exit $(cat "$E/exit"), esperaba $2"; sed 's/^/        /' "$E/log"; fallos=$((fallos+1)); fi
}
llamadas() { grep -c "^$1 " "$E/llamadas"; }

TARDE=2026-10-06T21:00:00Z     # pasado el plazo (08:17 + 12 h = 20:17)
PRONTO=2026-10-06T10:00:00Z    # dentro del plazo
SCHED_HOY="500 schedule 2.1 2026-10-06T15:11:20Z"

echo "decidir — la API que omite corridas"

nuevo filtrado-miente
runs > "$E/sched"; runs > "$E/disp"; runs "$SCHED_HOY" "${RUIDO[@]}" > "$E/unf1"
correr decidir AHORA=$TARDE
espera "el filtro por evento dice 0, el listado sin filtro la ve ⇒ cubierta (el bug del 6-oct)" decision cubierta

nuevo sin-filtro-miente
runs "$SCHED_HOY" > "$E/sched"; runs > "$E/disp"; runs > "$E/unf1"
correr decidir AHORA=$TARDE
espera "el listado sin filtro llega vacío, el filtro la ve ⇒ cubierta" decision cubierta

nuevo segunda-ronda
runs > "$E/sched"; runs > "$E/disp"; runs "${RUIDO[@]}" > "$E/unf1"
runs "$SCHED_HOY" > "$E/sched.2"
correr decidir AHORA=$TARDE RONDAS=3
espera "todas las fuentes la omiten en la 1.ª ronda y aparece en la 2.ª ⇒ cubierta" decision cubierta
n=$((n+1)); [ "$(llamadas sched)" = 2 ] && echo "  ok  y se para en la ronda que la ve (2 lecturas, no 3)" \
  || { echo "  MAL se esperaban 2 lecturas de sched, hubo $(llamadas sched)"; fallos=$((fallos+1)); }

nuevo dispatch-en-vuelo
runs > "$E/sched"; runs "501 workflow_dispatch 2.1 2026-10-06T20:59:00Z" > "$E/disp"; runs "${RUIDO[@]}" > "$E/unf1"
correr decidir AHORA=$TARDE
espera "un dispatch nacido hace un minuto (en vuelo) cuenta ⇒ cubierta" decision cubierta

echo "decidir — cuándo actúa"

nuevo pronto
runs > "$E/sched"; runs > "$E/disp"; runs "${RUIDO[@]}" > "$E/unf1"
correr decidir AHORA=$PRONTO RONDAS=3
espera "nada nacido y dentro del plazo ⇒ espera, no lanza" decision esperando
espera "… con el motivo de que aún no nació" motivo aun_no_nacio
n=$((n+1)); [ "$(llamadas sched)" = 1 ] && echo "  ok  dentro del plazo basta una ronda" \
  || { echo "  MAL dentro del plazo hubo $(llamadas sched) rondas"; fallos=$((fallos+1)); }

nuevo tarde
runs > "$E/sched"; runs > "$E/disp"; runs "${RUIDO[@]}" > "$E/unf1"
correr decidir AHORA=$TARDE RONDAS=3
espera "nada nacido y plazo vencido ⇒ lanza" decision lanzar
espera "… porque falta" motivo falta
n=$((n+1)); [ "$(llamadas sched)" = 3 ] && echo "  ok  antes de lanzar lee las 3 rondas" \
  || { echo "  MAL antes de lanzar hubo $(llamadas sched) rondas"; fallos=$((fallos+1)); }

nuevo plazo-justo
runs > "$E/sched"; runs > "$E/disp"; runs "${RUIDO[@]}" > "$E/unf1"
correr decidir AHORA=2026-10-06T20:16:59Z
espera "un segundo antes del plazo ⇒ espera" decision esperando
correr decidir AHORA=2026-10-06T20:17:00Z
espera "en el plazo exacto ⇒ lanza" decision lanzar

nuevo no-cuentan
runs "600 schedule 2.1 2026-10-06T08:16:59Z" "601 workflow_dispatch 1.0 2026-10-06T12:00:00Z" > "$E/sched"
runs "602 workflow_dispatch otra 2026-10-06T12:00:00Z" > "$E/disp"
runs "603 push 2.1 2026-10-06T12:00:00Z" "604 pull_request 2.1 2026-10-06T12:00:00Z" \
     "605 schedule 2.1 2026-10-06T21:30:00Z" "${RUIDO[@]}" > "$E/unf1"
correr decidir AHORA=$TARDE
espera "ni la de ayer, ni otra rama, ni push/PR, ni una nacida tras AHORA cuentan ⇒ lanza" decision lanzar

nuevo madrugada
runs "700 schedule 2.1 2026-10-05T17:08:15Z" > "$E/sched"; runs > "$E/disp"; runs "${RUIDO[@]}" > "$E/unf1"
correr decidir AHORA=2026-10-06T03:24:51Z
espera "a las 03:24 UTC el día es el que empezó AYER a las 08:17 ⇒ cubierta" decision cubierta
espera "… y lo dice" desde 2026-10-05T08:17:00Z

nuevo paginas
runs > "$E/sched"; runs > "$E/disp"
runs "901 push 2.1 2026-10-06T19:00:00Z" > "$E/unf1"
runs "800 schedule 2.1 2026-10-06T14:00:00Z" "903 push 2.1 2026-10-06T07:00:00Z" > "$E/unf2"
correr decidir AHORA=$TARDE
espera "el listado sin filtro sigue a la página 2 si la 1 no llega al inicio del día" decision cubierta
n=$((n+1)); [ "$(llamadas unf3)" = 0 ] && echo "  ok  … y se para en cuanto pasa de él" \
  || { echo "  MAL pidió la página 3 sin necesidad"; fallos=$((fallos+1)); }

echo "decidir — no poder leer no es «no hay»"

nuevo sin-lectura-tarde
echo ERROR > "$E/sched"; echo ERROR > "$E/disp"; echo ERROR > "$E/unf1"
correr decidir AHORA=$TARDE
espera "todas las fuentes fallan y el plazo venció ⇒ lanza" decision lanzar
espera "… diciendo que no pudo leer" motivo sin_lectura
espera_exit "… y el paso no muere (el aviso depende de sus outputs)" 0

nuevo sin-lectura-pronto
echo ERROR > "$E/sched"; echo ERROR > "$E/disp"; echo 'no es json' > "$E/unf1"
correr decidir AHORA=$PRONTO
espera "todas fallan dentro del plazo ⇒ espera" decision esperando
espera "… y lo dice" motivo sin_lectura

nuevo pagina-vacia
echo ERROR > "$E/sched"; echo ERROR > "$E/disp"; runs > "$E/unf1"
correr decidir AHORA=$TARDE
espera "un listado sin filtro VACÍO no es una lectura válida (qa.yml siempre tiene runs) ⇒ sin_lectura" motivo sin_lectura

nuevo una-fuente-vale
echo ERROR > "$E/sched"; echo ERROR > "$E/disp"; runs "${RUIDO[@]}" > "$E/unf1"
correr decidir AHORA=$TARDE
espera "si una fuente responde y no la ve, es falta, no sin_lectura" motivo falta

echo "decidir — entradas"

nuevo forzar
runs "$SCHED_HOY" > "$E/sched"; runs > "$E/disp"; runs "${RUIDO[@]}" > "$E/unf1"
correr decidir AHORA=$TARDE FORZAR=si
espera "forzar lanza aunque esté cubierta" motivo forzada
espera "AHORA marca el ensayo" ensayo si

nuevo rama
runs "$SCHED_HOY" > "$E/sched"; runs > "$E/disp"; runs "${RUIDO[@]}" > "$E/unf1"
correr decidir AHORA=$TARDE
espera "sin RAMA, pregunta la rama por defecto" rama 2.1
n=$((n+1)); grep -q "branch=2.1&" "$E/llamadas" && echo "  ok  … y filtra por ella" \
  || { echo "  MAL no filtró por la rama preguntada"; fallos=$((fallos+1)); }

nuevo ahora-malo
correr decidir AHORA=ayer
espera_exit "un AHORA que no es fecha ⇒ error, no una decisión" 1

nuevo dos-crons
printf "on:\n  schedule:\n    - cron: '17 8 * * *'\n    - cron: '0 3 * * *'\n" > "$E/qa.yml"
correr decidir AHORA=$TARDE QA_YML="$E/qa.yml"
espera_exit "dos crons en qa.yml ⇒ error (no sabe qué día vigilar)" 1

nuevo cron-semanal
printf "on:\n  schedule:\n    - cron: \"17 8 * * 1\"\n" > "$E/qa.yml"
correr decidir AHORA=$TARDE QA_YML="$E/qa.yml"
espera_exit "un cron que no es diario ⇒ error" 1

nuevo otro-cron
printf "on:\n  schedule:\n    - cron: \"30 2 * * *\"\n" > "$E/qa.yml"
runs > "$E/sched"; runs > "$E/disp"; runs "${RUIDO[@]}" > "$E/unf1"
correr decidir AHORA=$TARDE QA_YML="$E/qa.yml"
espera "el día empieza a la hora del cron de qa.yml, no a una fija" desde 2026-10-06T02:30:00Z
espera "… y el plazo cuenta desde ahí" limite 2026-10-06T14:30:00Z

echo "lanzar"

nuevo lanzar-ok
echo '{"workflow_run_id": 4242, "run_url": "x", "html_url": "https://github.com/r/4242"}' > "$E/dispatch"
echo '{"id":4242,"event":"workflow_dispatch","head_branch":"2.1","path":".github/workflows/qa.yml","html_url":"https://github.com/r/4242"}' > "$E/run"
correr lanzar RAMA=2.1
espera "el dispatch devuelve el id y el run existe ⇒ nació" nacio si
espera "… con su id" run_id 4242
n=$((n+1)); grep -q "dispatches -f ref=2.1" "$E/llamadas" && echo "  ok  … lanzado sobre la rama" \
  || { echo "  MAL el dispatch no llevó ref=2.1"; fallos=$((fallos+1)); }
n=$((n+1)); grep -q "dispatches .*-F return_run_details=true" "$E/llamadas" && echo "  ok  … pidiendo el id del run (sin eso la API contesta 204 vacío)" \
  || { echo "  MAL el dispatch no pidió return_run_details"; fallos=$((fallos+1)); }

nuevo lanzar-run-tarda
echo '{"workflow_run_id": 4242}' > "$E/dispatch"
echo ERROR > "$E/run.1"
echo '{"id":4242,"event":"workflow_dispatch","head_branch":"2.1","path":".github/workflows/qa.yml","html_url":"u"}' > "$E/run"
correr lanzar RAMA=2.1
espera "el run aún no se lee a la primera ⇒ reintenta y nació" nacio si

nuevo lanzar-run-ajeno
echo '{"workflow_run_id": 4242}' > "$E/dispatch"
echo '{"id":4242,"event":"push","head_branch":"2.1","path":".github/workflows/otro.yml"}' > "$E/run"
correr lanzar RAMA=2.1
espera "el id devuelto no es un dispatch de qa.yml ⇒ no nació" nacio no
espera_exit "… y el paso falla" 1

nuevo lanzar-otro-workflow
echo '{"workflow_run_id": 4242}' > "$E/dispatch"
echo '{"id":4242,"event":"workflow_dispatch","head_branch":"2.1","path":".github/workflows/otro.yml"}' > "$E/run"
correr lanzar RAMA=2.1
espera "el id devuelto es un dispatch, pero de OTRO workflow ⇒ no nació" nacio no

nuevo lanzar-otra-rama
echo '{"workflow_run_id": 4242}' > "$E/dispatch"
echo '{"id":4242,"event":"workflow_dispatch","head_branch":"1.0","path":".github/workflows/qa.yml"}' > "$E/run"
correr lanzar RAMA=2.1
espera "el id devuelto es un dispatch de qa.yml en OTRA rama ⇒ no nació" nacio no

nuevo lanzar-falla
echo ERROR > "$E/dispatch"
correr lanzar RAMA=2.1
espera "el dispatch falla ⇒ no nació" nacio no
espera_exit "… y el paso falla" 1

nuevo lanzar-sin-id
# La API contesta 204 sin cuerpo: se busca el run en los listados, nacido después del disparo.
cat > "$E/disp.sh" <<'SH'
#!/usr/bin/env bash
jq -n --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{workflow_runs: [{id: 77, event: "workflow_dispatch", head_branch: "2.1", created_at: $t}]}'
SH
chmod +x "$E/disp.sh"
correr lanzar RAMA=2.1
espera "sin id en la respuesta, lo encuentra en los listados ⇒ nació" nacio si

nuevo lanzar-sin-id-viejo
runs "78 workflow_dispatch 2.1 2026-10-01T00:00:00Z" > "$E/disp"
correr lanzar RAMA=2.1
espera "sin id y solo un dispatch ANTERIOR al disparo ⇒ no nació" nacio no

echo
if [ "$fallos" -eq 0 ]; then echo "ci-vigilante-nocturna: $n comprobaciones en verde."; exit 0; fi
echo "ci-vigilante-nocturna: $fallos de $n comprobaciones en ROJO."; exit 1
