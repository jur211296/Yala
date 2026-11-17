#!/bin/bash
# Banco de pruebas de `interfaz-de-lo-tocado.py`.
#
#   bash qa/scripts/interfaz-de-lo-tocado-test.sh            # sintético + casos reales
#   bash qa/scripts/interfaz-de-lo-tocado-test.sh --sin-reales
#
# **Por qué existe.** El script decide qué pruebas de interfaz corren el gate y el CI del PR. Si se
# equivoca no da error: deja fuera la clase que el cambio rompe y todo sale en verde. Cada caso fija
# una capa o una regla del techo sobre un árbol de mentira (un repo git en un temporal, con commits
# para que haya líneas y textos en el diff), y los casos reales fijan lo que motivó el script.
#
# **Casos reales.** El PR de categorías a un toque (#920, merge 59eeb2d1f) rompió
# `SplitCalculatorUITests` y `AccountCardPickersUITests` (nocturna del 16-nov, 3 de 3). Con el techo
# por defecto del gate (30 min) `SplitCalculatorUITests` sale DENTRO y la otra, nombrada en la lista de
# fuera; con 40 min, las dos dentro. Las cuatro que el ticket pide como mínimo para un
# cambio de layout de «Nuevo registro» (`tickets/done/2026-11-16-ui-tests-rojos-tandas.md`) tienen
# que salir, dentro o en la lista de fuera. Se leen del árbol de ese commit (`--arbol-de`), así que
# necesitan historia: si el commit no está, el banco lo trae con `git fetch --depth=2`; si no puede,
# FALLA. Un caso real que se salta en silencio es el hueco que el script viene a cerrar.
#
# No compila nada ni toca el simulador: corre en Linux, en el job `coverage-index`.
#
# Exit: 0 = todos los casos pasan · 1 = alguno falla
set -u
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PY="$RAIZ/qa/scripts/interfaz-de-lo-tocado.py"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/interfaz-tocado-test.XXXXXX")" || { echo "no se pudo crear el temporal" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT
REALES=si
[ "${1:-}" = "--sin-reales" ] && REALES=no

fallos=0
n=0
ok()  { n=$((n + 1)); echo "  ✓ ${n}. $1"; }
mal() { n=$((n + 1)); echo "  ✗ ${n}. $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; fallos=$((fallos + 1)); }

# espera <nombre> <salida> <clases esperadas, en orden, separadas por espacio>
espera() {
  local nombre="$1" salida="$2" esperadas="$3"
  if [ "$(printf '%s' "$salida" | tr '\n' ' ' | sed 's/ $//')" = "$esperadas" ]; then ok "$nombre"; else mal "$nombre" "salida: $(printf '%s' "$salida" | tr '\n' ' ')
esperado: $esperadas"; fi
}

sel() { python3 -I "$PY" "$@" 2>"$TMP/stderr"; }

# ── Árbol de mentira ───────────────────────────────────────────────────────────────────────────
A="$TMP/arbol"
mkdir -p "$A/YalaUITests/Flows" "$A/YalaUITests/Support" "$A/Yala/App/Views/Forms" "$A/Yala/App/Logic" \
  "$A/Yala/App/ViewModels" "$A/Yala/Resources/es.lproj" "$A/qa"
cd "$A" || exit 1
git init -q -b base . && git config user.email banco@local && git config user.name banco && git config commit.gpgsign false

cat > Yala/App/Views/Forms/FormView.swift <<'EOF'
struct FormView: View {
    var body: some View {
        VStack {
            Text("Monto").accessibilityIdentifier("form_amount")
            filaDeAbajo
        }
    }

    private var filaDeAbajo: some View {
        Button("Cuenta") {}.accessibilityIdentifier("form_account_chip")
    }

    private var otraCosa: some View {
        // "form_comentado" no cuenta: está en un comentario.
        ForEach(items) { i in Text(i.name).accessibilityIdentifier("form_row_\(i.id)") }
    }
}
EOF
cat > Yala/App/Views/Forms/Chip.swift <<'EOF'
struct Chip: View {
    var body: some View { Text("chip") }
}
EOF
cat > Yala/App/Views/HostView.swift <<'EOF'
struct HostView: View {
    var body: some View { Chip().accessibilityIdentifier("host_screen_title") }
}
EOF
cat > Yala/App/Logic/MathLogic.swift <<'EOF'
enum MathLogic { static func suma() -> Int { 1 } }
EOF
cat > Yala/App/ViewModels/MathViewModel.swift <<'EOF'
final class MathViewModel { let n = MathLogic.suma() }
EOF
cat > Yala/App/Views/MathView.swift <<'EOF'
struct MathView: View {
    let vm = MathViewModel()
    var body: some View { Text("x").accessibilityIdentifier("math_result_label") }
}
EOF
cat > Yala/App/Logic/Huerfano.swift <<'EOF'
enum Huerfano { static let x = 1 }
EOF
cat > Yala/App/Logic/Indexado.swift <<'EOF'
enum Indexado { static let x = 1 }
EOF
cat > Yala/Resources/es.lproj/Localizable.strings <<'EOF'
"settings.favorites" = "Favoritos";
"settings.tags" = "Etiquetas";
EOF
cat > YalaUITests/Support/XCUIApplication+Yala.swift <<'EOF'
extension XCUIApplication {
    func abrirFormulario() {
        let campo = buttons["form_amount"]
        campo.tap()
    }

    var tituloHost: XCUIElement { staticTexts["host_screen_title"] }

    func nadaQueVer() {
        _ = 1
    }
}
EOF
cat > YalaUITests/Flows/MontoUITests.swift <<'EOF'
final class MontoUITests: XCTestCase {
    func test_monto() { app.buttons["form_amount"].tap() }
}
EOF
cat > YalaUITests/Flows/CuentaUITests.swift <<'EOF'
final class CuentaUITests: XCTestCase {
    func test_cuenta() { app.buttons["form_account_chip"].tap() }
}
EOF
cat > YalaUITests/Flows/FilaUITests.swift <<'EOF'
final class FilaUITests: XCTestCase {
    func test_fila() { app.buttons["form_row_42"].tap() }
}
EOF
cat > YalaUITests/Flows/AyudanteUITests.swift <<'EOF'
final class AyudanteUITests: XCTestCase {
    func test_a() { app.abrirFormulario() }
}
EOF
cat > YalaUITests/Flows/HostUITests.swift <<'EOF'
final class HostUITests: XCTestCase {
    func test_host() { XCTAssert(app.tituloHost.exists) }
}
EOF
cat > YalaUITests/Flows/MathUITests.swift <<'EOF'
final class MathUITests: XCTestCase {
    func test_math() { XCTAssert(app.staticTexts["math_result_label"].exists) }
}
EOF
cat > YalaUITests/Flows/AjustesUITests.swift <<'EOF'
final class AjustesUITests: XCTestCase {
    func test_fila() { XCTAssert(app.staticTexts["Favoritos"].exists) }
}
EOF
cat > YalaUITests/Flows/IndiceUITests.swift <<'EOF'
final class IndiceUITests: XCTestCase {
    func test_a() {}
}
EOF
cat > YalaUITests/Flows/AnchoUITests.swift <<'EOF'
final class AnchoUITests: XCTestCase {
    func test_a() {}
}
EOF
cat > YalaUITests/Flows/CaraUITests.swift <<'EOF'
final class CaraUITests: XCTestCase {
    func test_a() { app.buttons["form_amount"].tap(); app.buttons["form_account_chip"].tap() }
}
EOF
cat > YalaUITests/Flows/LocaleUITests.swift <<'EOF'
final class LocaleUITests: XCTestCase {
    func test_a() { app.launchArguments += ["-AppleLocale", "en_US", "yyyy-MM-dd"] }
}
EOF
cat > qa/coverage-index.json <<'EOF'
{"areas": [
  {"area": "estrecha", "codeGlobs": ["Yala/App/Logic/Indexado.swift"], "coverage": "xcuitest:YalaUITests/IndiceUITests | 2026-11-17"},
  {"area": "ancha", "codeGlobs": ["Yala/App/Views/**"], "coverage": "xcuitest:YalaUITests/Flows/AnchoUITests"},
  {"area": "fantasma", "codeGlobs": ["Yala/App/Logic/Indexado.swift"], "coverage": "xcuitest:YalaUITests/NoExisteUITests"}
]}
EOF
cat > qa/ci-ui-tiempos.json <<'EOF'
{"suites": {"MontoUITests": 60, "CuentaUITests": 120, "FilaUITests": 60, "AyudanteUITests": 60, "HostUITests": 60,
            "MathUITests": 60, "AjustesUITests": 60, "IndiceUITests": 60, "AnchoUITests": 60, "CaraUITests": 3000}}
EOF
git add -A && git commit -qm base

# Cada caso parte de `base` en su propia rama.
rama() { git checkout -q base && git checkout -q -B "$1"; }
cometer() { git add -A && git commit -qm "$1"; }

echo "── interfaz-de-lo-tocado · sintético"

# 1 · prueba tocada: la clase del fichero, aunque ningún identificador cambie.
rama c1; echo "// toque" >> YalaUITests/Flows/MathUITests.swift; cometer c1
espera "prueba tocada → su clase" "$(sel --base base --cabeza HEAD)" "MathUITests"

# 2 · ayudante por miembro: tocar `abrirFormulario` trae a quien lo llama, no a quien llama a `tituloHost`.
rama c2; sed -i.bak 's/campo.tap()/campo.tap(); campo.tap()/' YalaUITests/Support/XCUIApplication+Yala.swift && rm -f YalaUITests/Support/*.bak; cometer c2
espera "ayudante → solo los llamadores del miembro tocado" "$(sel --base base --cabeza HEAD)" "AyudanteUITests"

# 3 · una variable local de un cuerpo no es un miembro: tocar `campo` sigue siendo tocar `abrirFormulario`.
rama c3; sed -i.bak 's/let campo = buttons/let campo = self.buttons/' YalaUITests/Support/XCUIApplication+Yala.swift && rm -f YalaUITests/Support/*.bak; cometer c3
espera "variable local → su miembro" "$(sel --base base --cabeza HEAD)" "AyudanteUITests"

# 4 · índice: la clase del área estrecha; la clase que el índice nombra y no existe, no.
rama c4; echo "// toque" >> Yala/App/Logic/Indexado.swift; cometer c4
espera "índice estrecho; clase inexistente fuera" "$(sel --base base --cabeza HEAD)" "IndiceUITests"

# 4b · un glob que cubre medio árbol (`Yala/App/Views/**`) casa con todo: su clase va al final.
rama c4b; echo "// toque" >> Yala/App/Views/HostView.swift; cometer c4b
espera "glob ancho detrás" "$(sel --base base --cabeza HEAD)" "HostUITests AnchoUITests"

# 5 · lo que queda DEBAJO del cambio puntúa más que lo de encima: insertar antes de `filaDeAbajo`
#     empuja `form_account_chip`; `form_amount` está encima. A igual coste, la cuenta va primero.
rama c5; sed -i.bak 's/            filaDeAbajo/            Spacer()\
            filaDeAbajo/' Yala/App/Views/Forms/FormView.swift && rm -f Yala/App/Views/Forms/*.bak; cometer c5
salida="$(sel --base base --cabeza HEAD --techo-min 1000)"
primera="$(printf '%s\n' "$salida" | head -1)"
if [ "$primera" = "CuentaUITests" ] && printf '%s\n' "$salida" | grep -qx MontoUITests; then ok "debajo del cambio va delante de lo de encima"; else mal "debajo del cambio va delante de lo de encima" "$salida"; fi

# 6 · prefijo interpolado: `form_row_\(id)` casa con `form_row_42`; un comentario no declara nada.
if printf '%s\n' "$salida" | grep -qx FilaUITests; then ok "prefijo interpolado casa"; else mal "prefijo interpolado casa" "$salida"; fi

# 7 · un ayudante que usa el identificador cuenta como si la prueba lo usara.
if printf '%s\n' "$salida" | grep -qx AyudanteUITests; then ok "identificador vía ayudante"; else mal "identificador vía ayudante" "$salida"; fi

# 8 · un locale o un formato de fecha no son identificadores.
if printf '%s\n' "$salida" | grep -qx LocaleUITests; then mal "locale y fecha no son identificadores" "$salida"; else ok "locale y fecha no son identificadores"; fi

# 9 · anfitrión: tocar un componente trae a quien usa los identificadores de la vista que lo pinta (vía ayudante).
rama c9; echo "// toque" >> Yala/App/Views/Forms/Chip.swift; cometer c9
espera "componente → vista anfitriona" "$(sel --base base --cabeza HEAD)" "HostUITests AnchoUITests"

# 10 · dos saltos: lógica → view model → vista.
rama c10; echo "// toque" >> Yala/App/Logic/MathLogic.swift; cometer c10
espera "lógica → view model → vista" "$(sel --base base --cabeza HEAD)" "MathUITests"

# 11 · texto quitado de es.lproj que una prueba busca tal cual.
rama c11; sed -i.bak 's/"Favoritos"/"Registros favoritos"/' Yala/Resources/es.lproj/Localizable.strings && rm -f Yala/Resources/es.lproj/*.bak; cometer c11
espera "texto que cambia → la prueba que lo busca" "$(sel --base base --cabeza HEAD)" "AjustesUITests"

# 12 · sin clase: un fichero de la app por el que no pasa nada se dice, no se calla.
rama c12; echo "// toque" >> Yala/App/Logic/Huerfano.swift; cometer c12
salida="$(sel --base base --cabeza HEAD)"
if [ -z "$salida" ] && grep -q "Ninguna clase" "$TMP/stderr" && grep -q "Yala/App/Logic/Huerfano.swift" "$TMP/stderr"; then ok "sin clase: plan vacío y el fichero se nombra"; else mal "sin clase: plan vacío y el fichero se nombra" "$salida $(cat "$TMP/stderr")"; fi

# 13 · techo: lo que no cabe sale en FUERA con su motivo; la primera entra aunque sola lo pase.
rama c13; sed -i.bak 's/            filaDeAbajo/            Spacer()\
            filaDeAbajo/' Yala/App/Views/Forms/FormView.swift && rm -f Yala/App/Views/Forms/*.bak; cometer c13
salida="$(sel --base base --cabeza HEAD --techo-min 2)"
if [ "$salida" = "CuentaUITests" ] && grep -q "FUERA por el techo" "$TMP/stderr" && grep -q "MontoUITests" "$TMP/stderr"; then ok "techo de minutos: fuera, con nombre"; else mal "techo de minutos: fuera, con nombre" "$salida / $(cat "$TMP/stderr")"; fi
salida="$(sel --base base --cabeza HEAD --techo-min 0.5)"
if [ "$salida" = "CuentaUITests" ]; then ok "la primera entra aunque pase el techo"; else mal "la primera entra aunque pase el techo" "$salida"; fi
salida="$(sel --base base --cabeza HEAD --techo-min 1000 --techo-clases 2 | wc -l | tr -d ' ')"
if [ "$salida" = "2" ] && grep -q "FUERA" "$TMP/stderr"; then ok "techo de clases"; else mal "techo de clases" "$salida"; fi

# 14 · una clase cara pesa por minuto: `CaraUITests` usa lo mismo que `CuentaUITests` y cuesta 25 veces más.
salida="$(sel --base base --cabeza HEAD --techo-min 1000)"
pos_cara=$(printf '%s\n' "$salida" | grep -nx CaraUITests | cut -d: -f1)
pos_cuenta=$(printf '%s\n' "$salida" | grep -nx CuentaUITests | cut -d: -f1)
if [ -n "$pos_cara" ] && [ -n "$pos_cuenta" ] && [ "$pos_cara" -gt "$pos_cuenta" ]; then ok "la cara va detrás de la barata con la misma señal"; else mal "la cara va detrás de la barata con la misma señal" "$salida"; fi

# 15 · el árbol de trabajo cuenta, también lo no versionado (el gate corre antes del commit).
rama c15; printf 'final class NuevaUITests: XCTestCase {\n    func test_a() {}\n}\n' > YalaUITests/Flows/NuevaUITests.swift
espera "árbol de trabajo + no versionado" "$(sel --base base)" "NuevaUITests"
rm -f YalaUITests/Flows/NuevaUITests.swift

# 16 · formatos y JSON.
rama c16; echo "// toque" >> YalaUITests/Flows/MathUITests.swift; cometer c16
espera "--formato only-testing" "$(sel --base base --cabeza HEAD --formato only-testing)" "-only-testing:YalaUITests/MathUITests"
sel --base base --cabeza HEAD --json-a "$TMP/plan.json" >/dev/null
if python3 -c "import json,sys; p=json.load(open('$TMP/plan.json')); sys.exit(0 if p['clases'][0]['clase']=='MathUITests' and p['clases'][0]['capa']=='prueba' and 'minutos_estimados' in p else 1)"; then ok "--json-a con capa y minutos"; else mal "--json-a con capa y minutos" "$(cat "$TMP/plan.json")"; fi

# 17 · errores: base inexistente y techo inválido salen con 2.
python3 -I "$PY" --base no-existe --cabeza HEAD >/dev/null 2>&1; rc1=$?
python3 -I "$PY" --base base --cabeza HEAD --techo-min 0 >/dev/null 2>&1; rc2=$?
if [ "$rc1" = 2 ] && [ "$rc2" = 2 ]; then ok "errores de uso → exit 2"; else mal "errores de uso → exit 2" "rc base=$rc1 techo=$rc2"; fi

# 18 · --arbol-de lee el árbol de un commit sin extraerlo: en c1 la prueba existe aunque estemos en base.
git checkout -q base
espera "--arbol-de lee del commit" "$(sel --base base --cabeza c1 --arbol-de c1)" "MathUITests"

cd "$RAIZ" || exit 1

# ── Casos reales ───────────────────────────────────────────────────────────────────────────────
if [ "$REALES" = si ]; then
  echo "── interfaz-de-lo-tocado · casos reales"
  M920=59eeb2d1fac037638c84869c95432b823ad7d55e
  if ! git cat-file -e "$M920^{commit}" 2>/dev/null || ! git cat-file -e "$M920^1^{commit}" 2>/dev/null; then
    git fetch -q --depth=2 origin "$M920" 2>/dev/null
  fi
  if ! git cat-file -e "$M920^1^{commit}" 2>/dev/null; then
    mal "#920 · no está el commit de merge ni se pudo traer (git fetch --depth=2 origin $M920)"
  else
    # techo, clases que tienen que salir DENTRO
    for caso in "30 SplitCalculatorUITests" "40 SplitCalculatorUITests AccountCardPickersUITests"; do
      techo=${caso%% *}; dentro_esperadas=${caso#* }
      python3 -I "$PY" --base "$M920^1" --cabeza "$M920" --arbol-de "$M920" --techo-min "$techo" --json-a "$TMP/p920.json" >/dev/null 2>"$TMP/stderr"
      resultado=$(python3 - "$TMP/p920.json" $dentro_esperadas <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
dentro = [x['clase'] for x in p['clases']]
todas = dentro + [x['clase'] for x in p['fuera']]
minimo = ['SplitCalculatorUITests', 'AccountCardPickersUITests', 'TransactionFormDecided02UITests', 'EdgeCasesUITests']
f1 = [c for c in sys.argv[2:] if c not in dentro]
f2 = [c for c in minimo if c not in todas]
print('ok' if not f1 and not f2 else f'faltan dentro: {f1}; faltan en el informe: {f2}; dentro: {dentro}')
PY
)
      nombre="#920 · techo $techo: dentro ${dentro_esperadas// /, }; las cuatro del mínimo, en el informe"
      if [ "$resultado" = ok ]; then ok "$nombre"; else mal "$nombre" "$resultado"; fi
    done
  fi
fi

echo
if [ "$fallos" -eq 0 ]; then echo "interfaz-de-lo-tocado: $n casos, todos pasan"; exit 0; fi
echo "interfaz-de-lo-tocado: $fallos de $n casos fallan"; exit 1
