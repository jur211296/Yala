# comun.sh — lo que comparten los scripts del molde. Uso: source "<molde>/comun.sh" <idioma>
# Deja: MOLDE, IDIOMA, APPLE_LANGUAGES, APPLE_LOCALE, MONEDA, LPROJ, MONEDA_EXTRANJERA, RELOJ, SALIDA (la carpeta del
# idioma) y las funciones udid, texto_app y cuentas.
MOLDE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IDIOMA="${1:?Falta el idioma (es, en, pt-BR…: las claves de idiomas.json)}"
_campo() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); v=d
for k in sys.argv[2:]: v=v[k]
print(v)' "$MOLDE/idiomas.json" "$@"; }
APPLE_LANGUAGES="$(_campo idiomas "$IDIOMA" appleLanguages)" || { echo "✗ «${IDIOMA}» no está en idiomas.json" >&2; exit 1; }
APPLE_LOCALE="$(_campo idiomas "$IDIOMA" appleLocale)"
MONEDA="$(_campo idiomas "$IDIOMA" moneda)"
LPROJ="$(_campo idiomas "$IDIOMA" lproj)"
MONEDA_EXTRANJERA="$(_campo idiomas "$IDIOMA" monedaExtranjera)"
RELOJ="$(_campo reloj)"
SALIDA="${YALA_FICHA_SALIDA:-$HOME/Claude/propuestas/ficha-app-store-2.1}/$IDIOMA"
BUNDLE="${YALA_FICHA_BUNDLE:-com.jurgenschmidt.yala}"
# udid <iphone|ipad>: el simulador de idiomas.json (o YALA_FICHA_IPHONE / YALA_FICHA_IPAD).
udid() {
  local var="YALA_FICHA_$(echo "$1" | tr '[:lower:]' '[:upper:]')"
  if [ -n "${!var:-}" ]; then echo "${!var}"; return; fi
  local nombre; nombre="$(_campo simuladores "$1")"
  xcrun simctl list devices available -j | python3 -c 'import json,sys
n=sys.argv[1]
for rt, ds in json.load(sys.stdin)["devices"].items():
    for d in ds:
        if d["name"] == n: print(d["udid"]); sys.exit(0)
sys.exit("no hay simulador «%s»" % n)' "$nombre"
}
# barra <udid>: la hora del reloj del molde (9:41) en la barra de estado, al lanzar y antes de cada captura. Solo la hora:
# el iPad pone al lado la fecha REAL en el idioma del sistema. Medido el 16-oct-2026 (iPad Pro 13, iOS 27.0): una fecha
# ISO en --time fija también la fecha, pero la escribe siempre en inglés («Tue 13 Oct» con el sistema en pt-BR) y, tras
# relanzar la app, con el día de la semana de hoy («Fri Oct 13»), aunque se vuelva a aplicar. Mejor la fecha real bien
# escrita que la del reloj mal escrita.
barra() {
  xcrun simctl status_bar "$1" clear
  xcrun simctl status_bar "$1" override --time "$(date -j -f "%Y-%m-%d %H:%M:%S" "$RELOJ" +%H:%M)" \
    --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
}

# preparar <udid>: cada corrida parte de un simulador BORRADO, con el idioma del sistema de la ficha y la app recién instalada. Medido el
# 16-oct-2026: el simulador guarda preferencias de la app fuera de su contenedor, donde -uitest-reset no llega, y una
# corrida anterior cambiaba el Panel de la siguiente (todas las secciones en vez del Panel de usuario nuevo). Y la barra
# de estado del iPad escribe la fecha en el idioma del SISTEMA, no en el de la app.
# La app sale de la que ya está instalada, o de YALA_FICHA_APP (ruta a Yala.app, la del DerivedData).
preparar() {   # preparar <udid>
  local U="$1"
  local estado app copia
  estado=$(xcrun simctl list devices -j | python3 -c 'import json,sys; u=sys.argv[1]
print(next((d["state"] for ds in json.load(sys.stdin)["devices"].values() for d in ds if d["udid"]==u), ""))' "$U")
  [ "$estado" = Booted ] || { xcrun simctl boot "$U"; xcrun simctl bootstatus "$U" -b >/dev/null 2>&1; }
  copia="$(mktemp -d)/Yala.app"
  if [ -n "${YALA_FICHA_APP:-}" ]; then ditto "$YALA_FICHA_APP" "$copia"
  elif app=$(xcrun simctl get_app_container "$U" "$BUNDLE" 2>/dev/null); then ditto "$app" "$copia"
  else echo "✗ la app no está instalada en el simulador: pasa YALA_FICHA_APP=<ruta a Yala.app>" >&2; exit 1; fi
  xcrun simctl shutdown "$U"; xcrun simctl erase "$U"
  xcrun simctl boot "$U"; xcrun simctl bootstatus "$U" -b >/dev/null 2>&1
  xcrun simctl spawn "$U" defaults write -g AppleLanguages -array "${APPLE_LANGUAGES//[()]/}"
  xcrun simctl spawn "$U" defaults write -g AppleLocale "$APPLE_LOCALE"
  xcrun simctl shutdown "$U"; xcrun simctl boot "$U"; xcrun simctl bootstatus "$U" -b >/dev/null 2>&1
  xcrun simctl install "$U" "$copia"
  echo "✓ simulador limpio en ${APPLE_LANGUAGES//[()]/}"
}

# texto_app <clave> [%@]: una cadena de la app en el idioma de la ficha (su Localizable.strings), con %@ sustituido.
texto_app() {
  python3 -c 'import re,sys
t=open(sys.argv[1],encoding="utf-8").read()
m=re.search(r"^\"%s\" = \"(.*)\";" % re.escape(sys.argv[2]), t, re.M)
if not m: sys.exit("no está la clave %s" % sys.argv[2])
print(m.group(1).replace("%@", sys.argv[3] if len(sys.argv) > 3 else "%@"))' \
    "$MOLDE/../Yala/Resources/$LPROJ.lproj/Localizable.strings" "$@"
}
# Las cuentas de la semilla `ficha` como las nombra la app en ese idioma (DevSeedFicha): efectivo, tarjeta, principal y
# la de la divisa extranjera (la de la 09).
CUENTA_EFECTIVO="$(texto_app account.type.cash)"
CUENTA_TARJETA="$(texto_app account.type.creditCard)"
CUENTA_PRINCIPAL="$(texto_app devseed.accountMain)"
CUENTA_EXTRANJERA="$(texto_app devseed.ficha.accountForeign "$MONEDA_EXTRANJERA")"
