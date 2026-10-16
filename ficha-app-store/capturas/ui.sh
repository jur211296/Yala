# ui.sh — conducir la app del simulador con axe (brew install axe). Uso: U=<udid>; source capturas/ui.sh
# Se toca por accessibilityIdentifier o por etiqueta, que son las de la app en ese idioma.
# El árbol de accesibilidad, aplanado a «tipo|etiqueta|id|valor @x,y ancho×alto».
arbol() {
  axe describe-ui --udid "$U" 2>/dev/null | python3 -c 'import json,sys
def w(n):
    f=n.get("frame") or {}
    print("%s|%s|%s|%s @%d,%d %dx%d" % (n.get("type",""), n.get("AXLabel") or "", n.get("AXUniqueId") or "", n.get("AXValue") or "",
          f.get("x",0), f.get("y",0), f.get("width",0), f.get("height",0)))
    for c in n.get("children") or []: w(c)
d=json.load(sys.stdin)
for n in (d if isinstance(d,list) else [d]): w(n)'
}
# esperar <texto> [segundos]: hasta que una línea del árbol lo contenga.
esperar() {
  local fin=$(( $(date +%s) + ${2:-20} ))
  while [ "$(date +%s)" -lt "$fin" ]; do arbol | grep -qF -- "$1" && return 0; sleep 0.7; done
  echo "✗ no apareció «$1»" >&2; return 1
}
id() { esperar "|$1|" "${2:-20}" && axe tap --udid "$U" --id "$1" >/dev/null; }
etiqueta() { esperar "|$1|" "${2:-20}" && axe tap --udid "$U" --label "$1" >/dev/null; }
# punto <etiqueta>: el centro del primer elemento con esa etiqueta (para los que no tienen id ni toque por etiqueta).
punto() { arbol | grep -F -- "|$1|" | head -1 | sed -E 's/.*@(-?[0-9]+),(-?[0-9]+) ([0-9]+)x([0-9]+)$/\1 \2 \3 \4/' | awk '{print $1+$3/2, $2+$4/2}'; }
tocar() { local xy; xy=$(punto "$1"); [ -n "$xy" ] || { echo "✗ no está «$1»" >&2; return 1; }; axe tap --udid "$U" -x "${xy% *}" -y "${xy#* }" >/dev/null; }
# tocar_linea <texto>: toca el centro de la parte VISIBLE del primer elemento cuya línea lo contenga (una tarjeta de un
# carrusel puede asomar a medias por el borde, y tocar su centro sería tocar fuera de la pantalla).
tocar_linea() {
  local a xy
  a=$(arbol)
  xy=$(printf '%s\n' "$a" | python3 -c 'import re,sys
lineas=sys.stdin.read().splitlines(); pat=sys.argv[1]
ancho=float(re.search(r"@\S+ (\d+)x", lineas[0]).group(1))
for l in lineas:
    if pat in l:
        x,y,w,h=map(float,re.search(r"@(-?\d+),(-?\d+) (\d+)x(\d+)$", l).groups())
        x0,x1=max(x,0),min(x+w,ancho); print(round((x0+x1)/2), round(y+h/2)); break' "$1")
  [ -n "$xy" ] || { echo "✗ no está «$1»" >&2; return 1; }
  axe tap --udid "$U" -x "${xy% *}" -y "${xy#* }" >/dev/null
}
