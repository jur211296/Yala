#!/usr/bin/env bash
# Corre una suite de tests UNA vez y, si hay rojos, repite SOLO esos tests (2026-10-06).
#
#   bash qa/scripts/ci-reintentar-rojos.sh [--vueltas N] [--max-rojos M] [--dir DIR] \
#     -- <argumentos comunes de xcodebuild, verbo incluido> \
#     --- <selección de la primera vuelta: -only-testing / -skip-testing>
#
# POR QUÉ NO `-retry-tests-on-failure`. Con Swift Testing, `xcodebuild` no repite el test que
# falló: repite la SUITE ENTERA hasta 3 veces. Medido en el paso pure-logic de `qa.yml`: un solo
# rojo lo llevaba de ~13 a 27-30 min (26 889 tests = 3 × 8 963) y el tope de 45 min del job lo
# cancelaba — y `continue-on-error` no rescata una cancelación, así que un rojo advisory dejaba
# `tests` en rojo y el auto-merge bloqueado. Con XCTest no pasa: en las nocturnas de UI cada caso
# rojo sale 3 veces y ningún verde se repite. Ticket:
# `ci-one-red-in-pure-logic-triples-the-step-and-the-job-ceiling-cancels-it`.
#
# CÓMO. Primera vuelta con la selección completa y sin reintento. Si sale en rojo, se leen del
# `.xcresult` los casos con `result: Failed` (`xcresulttool get test-results tests`) y se repiten
# solos con `-only-testing:<bundle>/<id>`. Cada vuelta repite solo lo que sigue en rojo, hasta
# `--vueltas` en total (3, como el reintento de Xcode).
#
# QUÉ CUENTA COMO RESCATADO. Que el test APAREZCA como `Passed` en el `.xcresult` de la
# repetición — no el exit 0 de `xcodebuild`. Medido: un `-only-testing` que no casa con ningún
# test sale exit 0 con CERO tests ejecutados. Fiarse del exit daría por rescatado un rojo que no
# se volvió a correr.
#
# CAÍDA SEGURA. Si el `.xcresult` de la primera vuelta falta, no se puede leer, tiene un formato
# inesperado o no nombra ningún caso rojo, o hay más de `--max-rojos` (eso ya no es un flaky), NO
# se repite nada: sale con el código de la primera vuelta.
#
# ARRANQUE FALLIDO: LA ÚNICA VEZ QUE SE REPITE LA SELECCIÓN ENTERA (2026-10-26). Medido en el run
# 38969099625 (16-oct): el simulador no lanzó el runner («Host is down», «The system shell
# probably crashed»), no corrió ningún test y el `.xcresult` traía un caso `Failed` cuyo
# identificador era el TEXTO del error, «Yala encountered an error». El script lo repitió como si
# fuera un test: dos vueltas de `-only-testing:YalaTests/Yala encountered an error`, 0 tests
# ejecutados y el paso en rojo. Ahora:
#   - un identificador con espacios NO es un test (Swift Testing y XCTest no los admiten; el repo
#     no usa identificadores crudos con backticks) y no se repite jamás. Si la vuelta sí corrió
#     tests reales, ese pseudo-caso cuenta como rojo hasta el final: nada lo puede rescatar;
#   - una vuelta con exit ≠ 0 que no corrió NINGÚN test real es un arranque fallido: se relanza la
#     selección entera, dentro del mismo tope de `--vueltas`. No cuesta la suite dos veces: la
#     vuelta fallida no corrió nada. Si se agotan las vueltas sin arrancar, sale en rojo con un
#     «fallo de infraestructura» explícito;
#   - una repetición de rojos que corre 0 tests se anota como fallo de infraestructura: no rescata
#     nada, y lo pendiente sigue pendiente para la vuelta siguiente.
#
# Formato medido con un paquete sonda (Xcode 27): `nodeIdentifier` vale `Suite/test()` —también
# para un `@Test("nombre visible")`: el identificador es la función, no el nombre—,
# `Suite/Anidada/test()`, `test()` para una función libre, y `Suite/param(n:)` UNA vez aunque
# fallen varios argumentos. Todos sirven tal cual en `-only-testing` con el bundle delante.
#
# UN CRASH NO DEJA TESTS SIN CORRER. Medido con la sonda: si el proceso de test muere,
# `xcodebuild` lo relanza («Restarting after unexpected exit, crash, or test timeout») y sigue con
# los casos de detrás; el `.xcresult` marca `Failed` solo el que estaba corriendo. Por eso basta
# con repetir los rojos: no hay casos «sin ejecutar» que la primera vuelta se haya saltado.
#
# PÁSALE `-collect-test-diagnostics never` entre los comunes. Medido en la Mini (Xcode 27): cada
# corrida con un rojo lanza un `simctl diagnose --timeout=600` y gasta 10 min en él, también una
# repetición de 4 tests que corren en 0,03 s. Sin el flag, «repetir solo los rojos» cuesta lo mismo
# que repetir la suite.
#
# CUARENTENA (2026-11-17, propuesta P1 de verificación). Un rescate solo vale si la prueba está en
# la cuarentena (`qa/cuarentena.json`), que el CI lee de `origin/2.3` y nunca del PR. Con
# `--cuarentena FICHERO`, cada rescatado se busca en la lista (el caso exacto, o su suite
# `Bundle/Suite`):
#   - en la lista: aviso «Rescatado en cuarentena» con dueño, ticket y días que lleva;
#   - fuera de la lista y `_meta.modo` = `observar`: aviso «Rescate fuera de cuarentena» en el PR
#     y en el resumen del job; el paso sigue verde;
#   - fuera de la lista y `_meta.modo` = `bloquear`: error, el caso pasa a `rojos` y el paso sale 1.
# Un fichero ausente o ilegible cuenta como lista vacía en modo observar, con su aviso: en el CI del
# PR que creó la cuarentena el fichero aún no estaba en 2.3. Los arranques fallidos del simulador
# no pasan por la cuarentena: son infraestructura, no una prueba.
#   --informe-cuarentena F  solo escribe el estado y las vencidas (≥ `caducidadDias`) en el resumen
#                           del job y como avisos; sale 0 siempre. No corre ningún test.
#   --validar-cuarentena F  comprueba el formato (lo corre `cuarentena-test.sh`); sale 0 o 1.
#   --juzgar-cuarentena F -- ID…  dice de cada ID si está en la lista: líneas `DENTRO id dueño
#                           ticket días` o `FUERA id`, tras las de ESTADO/MODO/N/MALA. Lo usa el
#                           veredicto de las tandas de UI (`ci-ui-veredicto.py`, 2026-11-25).
# `HOY=AAAA-MM-DD` fija la fecha (el banco); por defecto, la de hoy en UTC.
#
# Salida en `$GITHUB_OUTPUT` (si existe): `rojos` (los que siguen en rojo, separados por «; »),
# `rescatados`, `vueltas` (las que corrieron), `tests_primera` (casos de la primera vuelta) y, con
# `--cuarentena`, `fuera_cuarentena` (los rescatados que no estaban en la lista).
# Exit: 0 si todo verde o todo rescatado; 1 si queda algún rojo tras repetirlo; el código de la
# primera vuelta en la caída segura; 2 si se llama mal.
#
# Banco: `qa/scripts/ci-reintentar-rojos-test.sh` (corre en el job `coverage-index`).
set -uo pipefail

XCODEBUILD="${XCODEBUILD:-xcodebuild}"
XCRUN="${XCRUN:-xcrun}"
VUELTAS=3
MAX_ROJOS=100
DIR="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/reintentar-rojos"
CUARENTENA=""
HOY="${HOY:-$(date -u +%F)}"

uso() { echo "uso: $0 [--vueltas N] [--max-rojos M] [--dir DIR] [--cuarentena F] -- <comunes> --- <selección>" >&2
       echo "     $0 --informe-cuarentena F | --validar-cuarentena F" >&2; exit 2; }
MODO_SOLO=""

while [ $# -gt 0 ]; do
  case "$1" in
    --vueltas) VUELTAS="${2:-}"; shift 2 ;;
    --max-rojos) MAX_ROJOS="${2:-}"; shift 2 ;;
    --dir) DIR="${2:-}"; shift 2 ;;
    --cuarentena) CUARENTENA="${2:-}"; [ -n "$CUARENTENA" ] || uso; shift 2 ;;
    --informe-cuarentena) MODO_SOLO="informe"; CUARENTENA="${2:-}"; [ -n "$CUARENTENA" ] || uso; shift 2 ;;
    --validar-cuarentena) MODO_SOLO="validar"; CUARENTENA="${2:-}"; [ -n "$CUARENTENA" ] || uso; shift 2 ;;
    --juzgar-cuarentena) MODO_SOLO="juzgar"; CUARENTENA="${2:-}"; [ -n "$CUARENTENA" ] || uso; shift 2 ;;
    --) shift; break ;;
    *) uso ;;
  esac
done
case "$VUELTAS" in ''|*[!0-9]*) uso ;; esac
case "$MAX_ROJOS" in ''|*[!0-9]*) uso ;; esac
[ "$VUELTAS" -ge 1 ] || uso

# ── Cuarentena ─────────────────────────────────────────────────────────────────────────────
# python3 -I -c "$PYC" <validar|informe|juzgar> <fichero> <hoy> [ids…]. Una línea por dato,
# separada por tabuladores:
#   ESTADO ok|ausente|ilegible <detalle> · MODO observar|bloquear · DESDE <fecha> · CADUCA <días>
#   N <entradas> · VENCIDA <prueba> <dueño> <ticket> <entrada> <días> · MALA <motivo>
#   DENTRO <id> <dueño> <ticket> <días> · FUERA <id>
# `validar` es estricto (exit 1 con una MALA por fallo). `informe` y `juzgar` toleran: una entrada
# mala se salta (y se dice) y un fichero que no se entiende es «ilegible» = lista vacía, observar.
PYC='
import json, re, sys, datetime
accion, ruta, hoy = sys.argv[1], sys.argv[2], sys.argv[3]
ids = sys.argv[4:]
def out(*c): print("\t".join(str(x).replace("\t", " ").replace("\n", " ") for x in c))
def fecha(v):
    if not isinstance(v, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", v): return None
    try: return datetime.date.fromisoformat(v)
    except ValueError: return None
hoy_d = fecha(hoy)
if hoy_d is None:
    out("ESTADO", "ilegible", "HOY no es una fecha: " + hoy); sys.exit(2)
try:
    texto = open(ruta, encoding="utf-8").read()
except FileNotFoundError:
    out("ESTADO", "ausente", ruta); out("MODO", "observar"); out("N", 0)
    for i in ids: out("FUERA", i)
    sys.exit(1 if accion == "validar" else 0)
except OSError as e:
    texto = None; err = str(e)
malas = []
d = None
if texto is not None:
    try: d = json.loads(texto)
    except ValueError as e: err = "JSON: " + str(e)
meta = d.get("_meta") if isinstance(d, dict) else None
pruebas = d.get("pruebas") if isinstance(d, dict) else None
if not isinstance(meta, dict) or not isinstance(pruebas, list):
    out("ESTADO", "ilegible", err if d is None else "sin _meta o sin la lista pruebas")
    out("MODO", "observar"); out("N", 0)
    for i in ids: out("FUERA", i)
    sys.exit(1 if accion == "validar" else 0)
modo = meta.get("modo")
if modo not in ("observar", "bloquear"):
    malas.append("_meta.modo tiene que ser observar o bloquear, no " + repr(modo)); modo = "observar"
cad = meta.get("caducidadDias")
if not isinstance(cad, int) or isinstance(cad, bool) or cad < 1:
    malas.append("_meta.caducidadDias tiene que ser un entero ≥ 1"); cad = 14
desde = meta.get("bloquearDesde")
if fecha(desde) is None:
    malas.append("_meta.bloquearDesde tiene que ser AAAA-MM-DD"); desde = "?"
validas, vistas = [], set()
for i, e in enumerate(pruebas):
    if not isinstance(e, dict):
        malas.append(f"pruebas[{i}] no es un objeto"); continue
    p = e.get("prueba")
    falta = [k for k in ("prueba", "dueno", "ticket", "entrada", "motivo") if not isinstance(e.get(k), str) or not e.get(k).strip()]
    if falta:
        malas.append(f"pruebas[{i}] ({p}): falta " + ", ".join(falta)); continue
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*/\S+", p):
        malas.append(f"pruebas[{i}]: «{p}» no es Bundle/Suite[/caso()] (sin espacios)"); continue
    en = e["entrada"]; ent = fecha(en)
    if ent is None:
        malas.append(f"pruebas[{i}] ({p}): entrada «{en}» no es AAAA-MM-DD"); continue
    if ent > hoy_d:
        malas.append(f"pruebas[{i}] ({p}): entrada {en} es posterior a hoy ({hoy})"); continue
    if p in vistas:
        malas.append(f"pruebas[{i}]: «{p}» repetida"); continue
    vistas.add(p)
    validas.append((p, e["dueno"], e["ticket"], e["entrada"], (hoy_d - ent).days))
out("ESTADO", "ok", ruta); out("MODO", modo); out("DESDE", desde); out("CADUCA", cad); out("N", len(validas))
for m in malas: out("MALA", m)
if accion == "validar":
    sys.exit(1 if malas else 0)
if accion == "informe":
    for p, du, t, en, dias in validas:
        if dias >= cad: out("VENCIDA", p, du, t, en, dias)
    sys.exit(0)
for i in ids:
    hit = next((v for v in validas if i == v[0] or i.startswith(v[0] + "/")), None)
    if hit: out("DENTRO", i, hit[1], hit[2], hit[4])
    else: out("FUERA", i)
'

# Los comandos de flujo de GitHub cortan en `%`, CR y LF.
anota() { local s="${2//'%'/%25}"; s="${s//$'\r'/%0D}"; s="${s//$'\n'/%0A}"; echo "::$1 title=$3::$s"; }

lee_cuarentena() { python3 -I -c "$PYC" "$@"; }
campo() { printf '%s\n' "$1" | awk -F'\t' -v k="$2" '$1 == k { print $'"${3:-2}"'; exit }'; }
resumen() { [ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '%s\n' "$@" >> "$GITHUB_STEP_SUMMARY"; return 0; }

# Avisos comunes: fichero ausente o ilegible, y entradas malas.
avisa_estado_cuarentena() { # $1 = salida del lector
  local estado det
  estado="$(campo "$1" ESTADO)"; det="$(campo "$1" ESTADO 3)"
  case "$estado" in
    ausente) anota warning "No hay cuarentena en 2.3 ($det): cuenta como lista vacía, en modo observar." "Cuarentena ausente" ;;
    ok) ;;
    *) anota error "No pude leer la cuarentena de 2.3 (${det:-el lector no devolvió nada}): cuenta como lista vacía, en modo observar. Arréglala en 2.3." "Cuarentena ilegible" ;;
  esac
  printf '%s\n' "$1" | awk -F'\t' '$1 == "MALA" { print $2 }' | while IFS= read -r m; do
    anota warning "Entrada de la cuarentena que no cuenta: $m" "Cuarentena: entrada mala"
  done
}

if [ "$MODO_SOLO" = "validar" ]; then
  sal="$(lee_cuarentena validar "$CUARENTENA" "$HOY")"; ex=$?
  printf '%s\n' "$sal" | awk -F'\t' '$1 == "MALA" { print "MALA: " $2 } $1 == "ESTADO" && $2 != "ok" { print "ESTADO: " $2 " " $3 }'
  [ "$ex" -eq 0 ] && echo "── cuarentena válida: $(campo "$sal" N) entrada(s), modo $(campo "$sal" MODO)."
  exit "$ex"
fi

if [ "$MODO_SOLO" = "juzgar" ]; then
  lee_cuarentena juzgar "$CUARENTENA" "$HOY" "$@"
  exit 0
fi

if [ "$MODO_SOLO" = "informe" ]; then
  sal="$(lee_cuarentena informe "$CUARENTENA" "$HOY")"
  avisa_estado_cuarentena "$sal"
  modo="$(campo "$sal" MODO)"; n="$(campo "$sal" N)"; desde="$(campo "$sal" DESDE)"; cad="$(campo "$sal" CADUCA)"
  vencidas="$(printf '%s\n' "$sal" | awk -F'\t' '$1 == "VENCIDA"')"
  echo "── cuarentena ($(campo "$sal" ESTADO)): ${n:-0} prueba(s), modo ${modo:-observar}."
  resumen "### Cuarentena de pruebas inestables (leída de 2.3)" "" \
    "Modo **${modo:-observar}** · ${n:-0} prueba(s) en la lista · estado del fichero: $(campo "$sal" ESTADO)." ""
  [ "$modo" = "observar" ] && [ -n "$desde" ] && [ "$desde" != "?" ] && \
    resumen "Un rescate fuera de la lista se anota y no frena. Pasa a bloquear el $desde, en una sesión aparte." ""
  if [ -n "$vencidas" ]; then
    resumen "**Vencidas** (≥ ${cad:-14} días sin arreglo): se borran con su porqué, o salen de la lista si ya están arregladas." "" \
      "| Prueba | Dueño | Ticket | Entrada | Días |" "|---|---|---|---|---|"
    while IFS=$'\t' read -r _ p du t en dias; do
      resumen "| \`$p\` | $du | $t | $en | $dias |"
      anota warning "$p lleva $dias días en cuarentena (dueño $du, ticket $t): bórrala con su porqué o sácala si ya está arreglada." "Cuarentena vencida"
    done <<< "$vencidas"
  else
    resumen "Ninguna vencida."
  fi
  exit 0
fi

comunes=()
while [ $# -gt 0 ] && [ "$1" != "---" ]; do comunes+=("$1"); shift; done
[ "${1:-}" = "---" ] && shift
seleccion=("$@")
[ "${#comunes[@]}" -gt 0 ] || uso

mkdir -p "$DIR" || { echo "no puedo crear $DIR" >&2; exit 2; }

# Una línea por caso: «<resultado>\t<bundle>/<nodeIdentifier>\t<T|X>». Exit ≠ 0 si el JSON no tiene la
# forma esperada: mejor caer a la salida segura que repetir algo mal leído.
PY='
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(3)
nodos = d.get("testNodes") if isinstance(d, dict) else None
if not isinstance(nodos, list):
    sys.exit(3)
casos = []
def recorre(n, bundle):
    if not isinstance(n, dict):
        sys.exit(4)
    tipo = n.get("nodeType") or ""
    if tipo.endswith("test bundle"):
        bundle = n.get("name")
    if tipo == "Test Case":
        nid, res = n.get("nodeIdentifier"), n.get("result")
        if not bundle or not nid or not res:
            sys.exit(4)
        ident = bundle + "/" + nid
        if "\t" in ident or "\n" in ident:
            sys.exit(5)
        # T = test de verdad; X = pseudo-caso (el texto de un error, con espacios).
        tipo_caso = "X" if any(c.isspace() for c in nid) else "T"
        casos.append(res + "\t" + ident + "\t" + tipo_caso)
        return
    for c in n.get("children") or []:
        recorre(c, bundle)
for n in nodos:
    recorre(n, None)
print("\n".join(casos))
'

leer_casos() {
  local json
  json="$("$XCRUN" xcresulttool get test-results tests --path "$1" --compact 2>/dev/null)" || return 1
  printf '%s' "$json" | python3 -I -c "$PY"
}


rojos_txt="" rescatados_txt="" tests_primera="" vuelta=0 fuera_txt="" 
publica() {
  [ -n "${GITHUB_OUTPUT:-}" ] || return 0
  {
    echo "rojos=$rojos_txt"
    echo "rescatados=$rescatados_txt"
    echo "vueltas=$vuelta"
    echo "tests_primera=$tests_primera"
    [ -z "$CUARENTENA" ] || echo "fuera_cuarentena=$fuera_txt"
  } >> "$GITHUB_OUTPUT"
}
une() { local IFS=$'\n'; printf '%s\n' "$*" | awk 'NF' | paste -sd ';' - | sed 's/;/; /g'; }

corre() { # $1 = número de vuelta; resto = selección
  local k="$1"; shift
  local rb="$DIR/vuelta-$k.xcresult"
  rm -rf "$rb"   # xcodebuild se niega a escribir sobre un -resultBundlePath que ya existe
  local t0=$SECONDS
  "$XCODEBUILD" "${comunes[@]}" "$@" -resultBundlePath "$rb"
  local ex=$?
  echo "── vuelta $k/$VUELTAS: exit $ex en $(( (SECONDS - t0) / 60 )) min $(( (SECONDS - t0) % 60 )) s"
  return "$ex"
}

# Cuántos tests REALES corrieron (Passed, Failed, Expected Failure; no Skipped ni pseudo-casos).
corridos() { printf '%s\n' "$1" | awk -F'\t' '$3 == "T" && ($1 == "Passed" || $1 == "Failed" || $1 == "Expected Failure")' | wc -l | tr -d ' '; }

# ── Vuelta 1 (y sus relanzamientos si no arranca): la selección entera, sin reintento ───────
arranques_fallidos=0 pseudo_vistos=""
while :; do
  vuelta=$((vuelta + 1))
  corre "$vuelta" "${seleccion[@]+"${seleccion[@]}"}"
  ex1=$?
  casos="$(leer_casos "$DIR/vuelta-$vuelta.xcresult")"; leido=$?
  n_corridos=""
  [ "$leido" -eq 0 ] && n_corridos="$(corridos "$casos")"
  [ "$vuelta" -eq 1 ] && [ "$leido" -eq 0 ] && tests_primera="$n_corridos"

  if [ "$ex1" -eq 0 ] && { [ "$vuelta" -eq 1 ] || [ "${n_corridos:-1}" != "0" ]; }; then
    if [ "$vuelta" -eq 1 ]; then
      echo "── en verde a la primera (${tests_primera:-?} casos). Nada que repetir."
    else
      echo "── en verde en la vuelta $vuelta, tras $arranques_fallidos arranque(s) fallido(s) (${n_corridos:-?} casos)."
      anota warning "El simulador no arrancó los tests $arranques_fallidos vez/veces; la selección entera pasó al relanzarla. Infraestructura, no un test." "Arranque fallido rescatado"
      rescatados_txt="(arranque fallido x$arranques_fallidos)"
    fi
    publica; exit 0
  fi

  # Sin .xcresult legible no se sabe qué pasó: caída segura, sin repetir nada.
  [ "$leido" -eq 0 ] || break
  # Corrió algún test real: no es un arranque fallido.
  [ "$n_corridos" = "0" ] || break

  arranques_fallidos=$((arranques_fallidos + 1))
  pseudo_vistos="$(printf '%s\n' "$casos" | awk -F'\t' '$3 == "X" { print $2 }' | paste -sd ';' - | sed 's/;/; /g')"
  echo "── vuelta $vuelta/$VUELTAS: no corrió NINGÚN test (exit $ex1)${pseudo_vistos:+: $pseudo_vistos}. Arranque fallido."
  if [ "$vuelta" -ge "$VUELTAS" ]; then
    rojos_txt="(fallo de infraestructura: $arranques_fallidos vuelta(s) sin correr ningún test${pseudo_vistos:+ — $pseudo_vistos})"
    anota error "El simulador no llegó a correr ningún test en $arranques_fallidos vuelta(s)${pseudo_vistos:+ ($pseudo_vistos)}. Fallo de infraestructura, no un test en rojo." "Fallo de infraestructura"
    publica
    [ "$ex1" -ne 0 ] && exit "$ex1"
    exit 1
  fi
  echo "── relanzo la selección ENTERA: la vuelta fallida no corrió nada."
done

pendientes=() pseudo=()
if [ "$leido" -eq 0 ]; then
  while IFS=$'\t' read -r res id tipo_caso; do
    [ -n "$id" ] || continue
    if [ "$tipo_caso" = "X" ]; then
      case "$res" in Passed|Skipped|"Expected Failure") ;; *) pseudo+=("$id") ;; esac
    elif [ "$res" = "Failed" ]; then
      pendientes+=("$id")
    fi
  done <<< "$casos"
fi

if [ "$leido" -ne 0 ] || [ "${#pendientes[@]}" -eq 0 ]; then
  rojos_txt="(sin identificar: xcodebuild salió con $ex1 y el .xcresult no nombra ningún caso rojo — mira el log)"
  [ "${#pseudo[@]}" -gt 0 ] && rojos_txt="$rojos_txt; $(une "${pseudo[@]}")"
  anota error "xcodebuild salió con $ex1 y no pude leer del .xcresult qué tests fallaron. No repito nada: un rojo es un rojo." "Rojo sin identificar"
  publica; exit "$ex1"
fi

if [ "${#pendientes[@]}" -gt "$MAX_ROJOS" ]; then
  rojos_txt="$(une "${pendientes[@]:0:20}") … (${#pendientes[@]} en total)"
  anota error "${#pendientes[@]} tests en rojo, más del tope de $MAX_ROJOS: eso no es un flaky. No repito nada." "Demasiados rojos para repetir"
  publica; exit "$ex1"
fi

# Los nombres salen ya, antes de repetir: si algo corta la repetición (el tope del paso, una
# cancelación), el aviso sabe al menos qué falló en la primera vuelta. `publica` vuelve a escribir
# las mismas claves al final, y en `$GITHUB_OUTPUT` gana la última.
rojos_txt="$(une "${pendientes[@]}" "${pseudo[@]+"${pseudo[@]}"}")"
publica

# ── Vueltas siguientes: solo lo que sigue en rojo, y nunca un pseudo-caso ───────────────────
rescatados=()
while [ "${#pendientes[@]}" -gt 0 ] && [ "$vuelta" -lt "$VUELTAS" ]; do
  vuelta=$((vuelta + 1))
  echo "── vuelta $vuelta/$VUELTAS: repito SOLO ${#pendientes[@]} test(s): $(une "${pendientes[@]}")"
  args=(); for id in "${pendientes[@]}"; do args+=("-only-testing:$id"); done
  corre "$vuelta" "${args[@]}"
  if ! casos="$(leer_casos "$DIR/vuelta-$vuelta.xcresult")"; then
    anota warning "No pude leer el .xcresult de la vuelta $vuelta: lo que quedaba en rojo se queda en rojo." "Repetición ilegible"
    break
  fi
  if [ "$(corridos "$casos")" = "0" ]; then
    anota warning "La vuelta $vuelta no corrió ningún test: fallo de infraestructura, no rescata nada. Lo pendiente sigue en rojo." "Repetición sin tests"
  fi
  siguen=()
  for id in "${pendientes[@]}"; do
    res="$(printf '%s\n' "$casos" | awk -F'\t' -v id="$id" '$2 == id && $3 == "T" { print $1; exit }')"
    case "$res" in
      Passed|"Expected Failure") rescatados+=("$id") ;;
      *) siguen+=("$id") ;;   # Failed, Skipped o ausente: no se volvió a ver en verde
    esac
  done
  pendientes=("${siguen[@]+"${siguen[@]}"}")
done

for id in "${rescatados[@]+"${rescatados[@]}"}"; do
  anota warning "$id falló y pasó al repetirlo solo: flaky, o depende del orden de la suite." "Rescatado al repetirlo"
done

# Un rescate solo vale si la prueba está en la cuarentena (ver la cabecera).
fuera=() fuera_bloquea=""
if [ -n "$CUARENTENA" ] && [ "${#rescatados[@]}" -gt 0 ]; then
  sal="$(lee_cuarentena juzgar "$CUARENTENA" "$HOY" "${rescatados[@]}")"
  avisa_estado_cuarentena "$sal"
  modo="$(campo "$sal" MODO)"; cad="$(campo "$sal" CADUCA)"
  while IFS=$'\t' read -r tipo id du t dias; do
    case "$tipo" in
      DENTRO) anota notice "$id está en cuarentena (dueño $du, ticket $t, día $dias de ${cad:-14}): el rescate vale." "Rescatado en cuarentena" ;;
      FUERA) fuera+=("$id") ;;
    esac
  done <<< "$sal"
  if [ "${#fuera[@]}" -gt 0 ]; then
    resumen "### Rescates fuera de la cuarentena" "" \
      "Estas pruebas fallaron y pasaron al repetirlas, y no están en \`qa/cuarentena.json\` de 2.3. Modo **$modo**." ""
    for id in "${fuera[@]}"; do
      resumen "- \`$id\`"
      if [ "$modo" = "bloquear" ]; then
        anota error "$id falló y pasó al repetirlo, y no está en la cuarentena de 2.3: un rescate fuera de la lista es un rojo. Arréglala, o apúntala con dueño y ticket en 2.3." "Rescate fuera de cuarentena"
      else
        anota warning "$id falló y pasó al repetirlo, y no está en la cuarentena de 2.3. Modo observar: no frena; desde que pase a bloquear, sí. Arréglala, o apúntala con dueño y ticket." "Rescate fuera de cuarentena (observar)"
      fi
    done
    resumen ""
    [ "$modo" = "bloquear" ] && fuera_bloquea="si"
  fi
fi
fuera_txt="$(une "${fuera[@]+"${fuera[@]}"}")"
for id in "${pendientes[@]+"${pendientes[@]}"}"; do
  anota error "$id sigue en rojo tras $vuelta vuelta(s)." "Test en rojo"
done
for id in "${pseudo[@]+"${pseudo[@]}"}"; do
  anota error "$id no es un test: es un error de xcodebuild en una vuelta que sí corrió tests. No se repite y sigue en rojo." "Error fuera de los tests"
done
rescatados_txt="$(une "${rescatados[@]+"${rescatados[@]}"}")"
rojos_bloq=()
[ -z "$fuera_bloquea" ] || for id in "${fuera[@]}"; do rojos_bloq+=("$id (rescatado fuera de la cuarentena)"); done
rojos_txt="$(une "${pendientes[@]+"${pendientes[@]}"}" "${pseudo[@]+"${pseudo[@]}"}" "${rojos_bloq[@]+"${rojos_bloq[@]}"}")"
publica

if [ -n "$fuera_bloquea" ]; then
  echo "── ${#fuera[@]} rescate(s) fuera de la cuarentena, en modo bloquear."
  exit 1
fi
if [ "${#pendientes[@]}" -eq 0 ] && [ "${#pseudo[@]}" -eq 0 ]; then
  echo "── todo rescatado en $vuelta vuelta(s)."
  exit 0
fi
echo "── quedan $(( ${#pendientes[@]} + ${#pseudo[@]} )) rojo(s) tras $vuelta vuelta(s)."
exit 1
