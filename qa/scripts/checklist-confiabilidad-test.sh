#!/usr/bin/env bash
# Banco de qa/checklist-confiabilidad.yaml (2026-11-17, P4 de la propuesta de verificación).
#
#   bash qa/scripts/checklist-confiabilidad-test.sh            # casos de mentira + el fichero real
#   bash qa/scripts/checklist-confiabilidad-test.sh --solo F   # valida solo el YAML F (sin casos)
#
# Qué comprueba del fichero real, además de la forma:
#   - entre 30 y 40 ítems, `id` en kebab-case y único;
#   - `area` de la lista cerrada; `titulo` y `comprobacion` con texto;
#   - `disparador` con al menos una de `rutas`, `simbolos` o `patrones`;
#     cada glob casa con algún fichero del repo, cada símbolo aparece en el código y cada patrón compila;
#   - `pruebas`: cada nombre es un tipo de prueba o un fichero de pruebas (sin `.swift`) que existe
#     en YalaTests/ o YalaUITests/;
#   - `origen`: al menos DOS entradas, con fecha `AAAA-MM-DD` entre comillas, `ref` distinto y `que`;
#     un `ref` que es ruta (`tickets/…`, `docs/…`) tiene que existir;
#   - `regla`: `fichero:inicio-fin`, fichero existente y líneas dentro del fichero;
#   - `ultimo_disparo`: vacío (`null`) o una fecha `AAAA-MM-DD`.
#
# Por qué valida contra el árbol y no solo la forma: en este repo la documentación envejece más
# rápido que el código. Un ítem cuyo glob, símbolo o prueba ya no existe no se dispararía nunca y
# nadie lo notaría: tiene que caer aquí.
#
# Por qué Ruby para leer el YAML: la Max no tiene PyYAML y la librería estándar de Ruby sí trae YAML.
# Si hay PyYAML se usa ese. Los dos rechazan una fecha sin comillas (Ruby en `safe_load`, Python
# porque el validador exige texto), así que el fichero tiene un solo formato.
#
# Exit: 0 = todo en verde · 1 = algún caso o el fichero real en rojo.
set -uo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
RAIZ="$(cd "$AQUI/../.." && pwd)"
REAL="$RAIZ/qa/checklist-confiabilidad.yaml"

# yaml_a_json <fichero> → JSON en stdout (exit ≠ 0 si el YAML no se puede leer).
yaml_a_json() {
  if python3 -c 'import yaml' 2>/dev/null; then
    python3 - "$1" <<'PY'
import json, sys, yaml
with open(sys.argv[1], encoding="utf-8") as f:
    print(json.dumps(yaml.safe_load(f)))
PY
  elif command -v ruby >/dev/null 2>&1; then
    ruby -ryaml -rjson -e 'puts JSON.generate(YAML.safe_load(File.read(ARGV[0], encoding: "UTF-8")))' "$1"
  else
    echo "ni PyYAML ni ruby: no puedo leer YAML" >&2
    return 2
  fi
}

# validar <yaml> <raiz> → imprime los errores, exit 0 si no hay ninguno.
validar() {
  local json
  if ! json="$(yaml_a_json "$1" 2>&1)"; then
    echo "YAML ilegible: $json" | head -5
    return 1
  fi
  # El JSON va por variable de entorno: el stdin de `python3 -` ya es el heredoc con el script.
  CHECKLIST_JSON="$json" python3 - "$2" <<'PY'
import fnmatch, json, os, re, subprocess, sys

raiz = sys.argv[1]
AREAS = {"nube", "migracion", "dinero", "fechas", "formulario", "pruebas"}
FECHA = re.compile(r"^\d{4}-\d{2}-\d{2}$")
KEBAB = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
REGLA = re.compile(r"^(?P<f>[^:]+):(?P<a>\d+)-(?P<b>\d+)$")
errores = []

def err(donde, msg):
    errores.append(f"{donde}: {msg}")

try:
    doc = json.loads(os.environ["CHECKLIST_JSON"])
except Exception as e:
    print(f"no es JSON tras leer el YAML: {e}")
    sys.exit(1)

def ficheros_del_repo():
    try:
        out = subprocess.run(["git", "-C", raiz, "ls-files"], capture_output=True, text=True, check=True).stdout
        return out.splitlines()
    except Exception:
        lista = []
        for d, _, fs in os.walk(raiz):
            if "/.git" in d:
                continue
            lista += [os.path.relpath(os.path.join(d, f), raiz) for f in fs]
        return lista

FICHEROS = ficheros_del_repo()
CODIGO = [f for f in FICHEROS if f.endswith(".swift")]
PRUEBAS = [f for f in CODIGO if f.startswith(("YalaTests/", "YalaUITests/"))]
_cache = {}

def leer(f):
    if f not in _cache:
        try:
            with open(os.path.join(raiz, f), encoding="utf-8", errors="replace") as h:
                _cache[f] = h.read()
        except OSError:
            _cache[f] = ""
    return _cache[f]

def aparece(simbolo, universo):
    pat = re.compile(r"(?<![A-Za-z0-9_])" + re.escape(simbolo) + r"(?![A-Za-z0-9_])")
    return any(pat.search(leer(f)) for f in universo)

def prueba_existe(nombre):
    # Un tipo de prueba (lo que `-only-testing` filtra) o un fichero de pruebas por su nombre sin
    # `.swift`: muchos ficheros declaran suites que no se llaman como ellos, y el gate ya traduce
    # fichero → suites con `qa/scripts/suites-de-fichero.py`.
    if any(os.path.basename(f) == nombre + ".swift" for f in PRUEBAS):
        return True
    pat = re.compile(r"\b(class|struct|enum|actor|extension)\s+" + re.escape(nombre) + r"\b")
    return any(pat.search(leer(f)) for f in PRUEBAS)

def lista_de_textos(v):
    return isinstance(v, list) and all(isinstance(x, str) and x.strip() for x in v)

if not isinstance(doc, dict):
    print("la raíz tiene que ser un mapa con `version` e `items`")
    sys.exit(1)
if doc.get("version") != 1:
    err("raíz", "`version` tiene que ser 1")
items = doc.get("items")
if not isinstance(items, list):
    print("`items` tiene que ser una lista")
    sys.exit(1)
if not 30 <= len(items) <= 40:
    err("raíz", f"{len(items)} ítems; tienen que ser entre 30 y 40")

vistos = set()
for n, it in enumerate(items, 1):
    if not isinstance(it, dict):
        err(f"ítem {n}", "no es un mapa")
        continue
    iid = it.get("id")
    d = f"ítem {n} ({iid})"
    if not isinstance(iid, str) or not KEBAB.match(iid):
        err(d, "`id` tiene que ser kebab-case")
    elif iid in vistos:
        err(d, "`id` repetido")
    else:
        vistos.add(iid)
    conocidos = {"id", "area", "titulo", "disparador", "comprobacion", "pruebas", "origen", "regla", "ultimo_disparo"}
    for k in it:
        if k not in conocidos:
            err(d, f"clave desconocida `{k}`")
    if it.get("area") not in AREAS:
        err(d, f"`area` tiene que ser una de {sorted(AREAS)}")
    for k in ("titulo", "comprobacion"):
        if not isinstance(it.get(k), str) or not it[k].strip():
            err(d, f"`{k}` vacío")

    disp = it.get("disparador")
    if not isinstance(disp, dict):
        err(d, "`disparador` tiene que ser un mapa")
        disp = {}
    for k in disp:
        if k not in ("rutas", "simbolos", "patrones"):
            err(d, f"`disparador.{k}` desconocido")
    rutas, simbolos, patrones = (disp.get(k, []) or [] for k in ("rutas", "simbolos", "patrones"))
    for k, v in (("rutas", rutas), ("simbolos", simbolos), ("patrones", patrones)):
        if v and not lista_de_textos(v):
            err(d, f"`disparador.{k}` tiene que ser una lista de textos")
    if not (rutas or simbolos or patrones):
        err(d, "`disparador` sin rutas, símbolos ni patrones: no se vería en ningún diff")
    for g in rutas if lista_de_textos(rutas) else []:
        if not any(fnmatch.fnmatchcase(f, g) for f in FICHEROS):
            err(d, f"la ruta `{g}` no casa con ningún fichero del repo")
    for s in simbolos if lista_de_textos(simbolos) else []:
        if not aparece(s, CODIGO):
            err(d, f"el símbolo `{s}` no aparece en ningún .swift")
    for p in patrones if lista_de_textos(patrones) else []:
        try:
            re.compile(p)
        except re.error as e:
            err(d, f"el patrón `{p}` no compila: {e}")

    pr = it.get("pruebas", []) or []
    if pr and not lista_de_textos(pr):
        err(d, "`pruebas` tiene que ser una lista de nombres")
    for p in pr if lista_de_textos(pr) else []:
        if not prueba_existe(p):
            err(d, f"la prueba `{p}` no existe en YalaTests/ ni YalaUITests/")

    org = it.get("origen")
    if not isinstance(org, list) or len(org) < 2:
        err(d, "`origen` necesita al menos dos incidentes o PRs")
        org = org if isinstance(org, list) else []
    refs = set()
    for m, o in enumerate(org, 1):
        if not isinstance(o, dict):
            err(d, f"origen {m} no es un mapa")
            continue
        if not isinstance(o.get("fecha"), str) or not FECHA.match(o["fecha"]):
            err(d, f"origen {m}: `fecha` tiene que ser \"AAAA-MM-DD\" entre comillas")
        ref = o.get("ref")
        if not isinstance(ref, str) or not ref.strip():
            err(d, f"origen {m}: `ref` vacío")
        else:
            if ref in refs:
                err(d, f"origen {m}: `ref` repetido (dos orígenes tienen que ser dos incidentes)")
            refs.add(ref)
            if re.match(r"^(tickets|docs|qa)/", ref) and not os.path.exists(os.path.join(raiz, ref)):
                err(d, f"origen {m}: la ruta `{ref}` no existe")
        if not isinstance(o.get("que"), str) or not o["que"].strip():
            err(d, f"origen {m}: `que` vacío")

    reglas = it.get("regla")
    if not lista_de_textos(reglas) or not reglas:
        err(d, "`regla` tiene que ser una lista de `fichero:inicio-fin`")
        reglas = []
    for r in reglas:
        m = REGLA.match(r)
        if not m:
            err(d, f"`regla` `{r}` no tiene la forma `fichero:inicio-fin`")
            continue
        f, a, b = m["f"], int(m["a"]), int(m["b"])
        ruta = os.path.join(raiz, f)
        if not os.path.isfile(ruta):
            err(d, f"`regla` apunta a `{f}`, que no existe")
            continue
        total = leer(f).count("\n") + 1
        if not 1 <= a <= b <= total:
            err(d, f"`regla` `{r}` fuera del fichero ({total} líneas)")

    u = it.get("ultimo_disparo")
    if u is not None and not (isinstance(u, str) and FECHA.match(u)):
        err(d, "`ultimo_disparo` tiene que ser null o \"AAAA-MM-DD\"")

for e in errores:
    print(e)
sys.exit(1 if errores else 0)
PY
}

if [ "${1:-}" = "--solo" ]; then
  validar "${2:?falta el fichero}" "$RAIZ"
  exit $?
fi

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fallos=0

# Un repo de mentira con lo justo para que los ítems de los casos apunten a cosas que existen.
mkdir -p "$T/repo/Yala/Services" "$T/repo/YalaTests" "$T/repo/.claude/rules" "$T/repo/tickets/done"
printf 'final class Sincro {\n  func armar() {}\n}\n' > "$T/repo/Yala/Services/Sincro.swift"
printf 'import Testing\nstruct SincroTests {}\n' > "$T/repo/YalaTests/SincroTests.swift"
printf 'import Testing\nstruct SincroLogicaTests {}\nstruct SincroCableadoTests {}\n' > "$T/repo/YalaTests/SincroFicheroTests.swift"
printf 'uno\ndos\ntres\ncuatro\n' > "$T/repo/.claude/rules/nube.md"
printf -- '---\nid: x\n---\n' > "$T/repo/tickets/done/2026-11-14-x.md"
git -C "$T/repo" init -q && git -C "$T/repo" add -A >/dev/null 2>&1

# item <id> [clave=valor del disparador...] — un ítem válido; los casos lo estropean con sed.
item() {
  cat <<EOF
  - id: $1
    area: nube
    titulo: Algo que se rompió dos veces
    disparador:
      rutas: ["Yala/Services/*.swift"]
      simbolos: ["armar"]
      patrones: ['armar\\(']
    comprobacion: Correr SincroTests y mirar que arma una sola vez.
    pruebas: ["SincroTests"]
    origen:
      - {fecha: "2026-11-01", ref: "PR #100", que: primera vez}
      - {fecha: "2026-11-14", ref: "tickets/done/2026-11-14-x.md", que: segunda vez}
    regla: [".claude/rules/nube.md:1-3"]
    ultimo_disparo: null
EOF
}
base() {  # base <n> → YAML con n ítems válidos
  echo "version: 1"; echo "items:"
  for i in $(seq 1 "$1"); do item "item-$i"; done
}

# caso <nombre> <pasa|cae> <yaml> [texto que tiene que salir en el error]
# El texto no es adorno: en su primera versión el JSON no llegaba al validador y TODOS los casos
# «cae» caían por eso, en verde. Un caso que cae tiene que caer por su motivo.
caso() {
  local nombre="$1" esperado="$2" f="$T/$1.yaml" motivo="${4:-}" obtenido
  printf '%s\n' "$3" > "$f"
  if validar "$f" "$T/repo" > "$T/$1.log" 2>&1; then obtenido=pasa; else obtenido=cae; fi
  if [ "$obtenido" = "$esperado" ] && { [ -z "$motivo" ] || grep -qF -- "$motivo" "$T/$1.log"; }; then
    echo "ok   $nombre ($obtenido)"
  else
    echo "FALLO $nombre: $obtenido (esperado: $esperado${motivo:+, con «$motivo»})"
    sed 's/^/      | /' "$T/$1.log"
    fallos=$((fallos + 1))
  fi
}

# m <expr-perl> — aplica UNA sustitución (la primera coincidencia) a la base de 30 ítems.
# Perl y no sed: `0,/re/` y `\n` en el reemplazo son de GNU sed y no existen en el de macOS.
B30="$(base 30)"
m() { printf '%s' "$B30" | LC_ALL=C perl -0pe "$1"; }

caso valido_30 pasa "$B30"
caso valido_40 pasa "$(base 40)"
caso pocos_29 cae "$(base 29)" "29 ítems"
caso muchos_41 cae "$(base 41)" "41 ítems"
caso version_2 cae "$(m 's/^version: 1/version: 2/m')" "\`version\` tiene que ser 1"
caso id_repetido cae "$(m 's/id: item-2\n/id: item-1\n/')" "\`id\` repetido"
caso id_no_kebab cae "$(m 's/id: item-2\n/id: Item_2\n/')" "kebab-case"
caso area_desconocida cae "$(m 's/area: nube/area: estilo/')" "\`area\` tiene que ser"
caso clave_desconocida cae "$(m 's/    titulo:/    prioridad: alta\n    titulo:/')" "clave desconocida \`prioridad\`"
caso comprobacion_vacia cae "$(m 's/comprobacion: .*/comprobacion: ""/')" "\`comprobacion\` vacío"
caso disparador_vacio cae "$(m 's/rutas: .*\n(\s*)simbolos: .*\n(\s*)patrones: .*/rutas: []\n$1simbolos: []\n$2patrones: []/')" "sin rutas, símbolos ni patrones"
caso solo_patron pasa "$(m 's/rutas: .*\n(\s*)simbolos: .*/rutas: []\n$1simbolos: []/')"
caso ruta_que_no_casa cae "$(m 's/rutas: .*/rutas: ["Yala\/Views\/*.swift"]/')" "no casa con ningún fichero"
caso simbolo_renombrado cae "$(m 's/simbolos: .*/simbolos: ["armarDos"]/')" "\`armarDos\` no aparece"
caso simbolo_solo_prefijo cae "$(m 's/simbolos: .*/simbolos: ["arma"]/')" "\`arma\` no aparece"
caso patron_que_no_compila cae "$(m "s/patrones: .*/patrones: ['armar(']/")" "no compila"
caso prueba_por_fichero pasa "$(m 's/pruebas: .*/pruebas: ["SincroFicheroTests", "SincroCableadoTests"]/')"
caso prueba_inexistente cae "$(m 's/pruebas: .*/pruebas: ["SincroUITests"]/')" "\`SincroUITests\` no existe"
caso un_solo_origen cae "$(m 's/      - \{fecha: "2026-11-14".*\n//')" "al menos dos"
caso origen_repetido cae "$(m 's/ref: "tickets\/done\/2026-11-14-x.md"/ref: "PR #100"/')" "\`ref\` repetido"
caso fecha_sin_comillas cae "$(m 's/fecha: "2026-11-01"/fecha: 2026-11-01/')" "YAML ilegible"
caso fecha_mal cae "$(m 's/fecha: "2026-11-01"/fecha: "1-nov"/')" "entre comillas"
caso ticket_inexistente cae "$(m 's/2026-11-14-x.md/2026-11-14-y.md/')" "no existe"
caso regla_sin_lineas cae "$(m 's/nube.md:1-3/nube.md/')" "no tiene la forma"
caso regla_fuera_del_fichero cae "$(m 's/nube.md:1-3/nube.md:3-90/')" "fuera del fichero"
caso regla_fichero_inexistente cae "$(m 's/nube.md:1-3/pruebas.md:1-3/')" "que no existe"
caso ultimo_disparo_fecha pasa "$(m 's/ultimo_disparo: null/ultimo_disparo: "2026-12-01"/')"
caso ultimo_disparo_mal cae "$(m 's/ultimo_disparo: null/ultimo_disparo: ayer/')" "\`ultimo_disparo\`"
caso yaml_roto cae "version: 1
items: [ {id: x" "YAML ilegible"

echo "---- el fichero real: qa/checklist-confiabilidad.yaml"
if [ ! -f "$REAL" ]; then
  echo "FALLO no existe $REAL"
  fallos=$((fallos + 1))
elif validar "$REAL" "$RAIZ" > "$T/real.log" 2>&1; then
  echo "ok   checklist real ($(grep -c '^  - id:' "$REAL") ítems)"
else
  echo "FALLO checklist real:"
  sed 's/^/      | /' "$T/real.log"
  fallos=$((fallos + 1))
fi

if [ "$fallos" -gt 0 ]; then
  echo "$fallos fallo(s)"
  exit 1
fi
echo "todo en verde"
