"""Interruptores TEMPORALES para atribuir las pasadas fuera de pantalla del Panel (lote 7). Solo en la copia de medición,
nunca en el PR. Uso: interruptores_render.py <carpeta de la copia>
  -perfTempSinBarras YES   el Panel oculta la barra de pestañas y la de navegación
  -perfTempSinGraficas YES las gráficas (Swift Charts) del Panel con opacidad 0
"""
import os, re, sys
C = sys.argv[1]
P = os.path.join(C, "Yala/App/Views/Panel")
open(os.path.join(P, "PerfTempRender.swift"), "w").write('''import Foundation
enum PerfTempRender {
    static let sinBarras = UserDefaults.standard.bool(forKey: "perfTempSinBarras")
    static let sinGraficas = UserDefaults.standard.bool(forKey: "perfTempSinGraficas")
}
''')
pv = os.path.join(P, "PanelView.swift"); s = open(pv).read()
a = "        NavigationStack {\n            mainContent\n"
assert s.count(a) == 1
s = s.replace(a, a + "                .toolbar(PerfTempRender.sinBarras ? .hidden : .automatic, for: .tabBar, .navigationBar)\n")
open(pv, "w").write(s)

def cierre(s, i, abre, cierra):
    n = 0
    while i < len(s):
        if s[i] == abre: n += 1
        elif s[i] == cierra:
            n -= 1
            if n == 0: return i
        i += 1
    raise ValueError
hechos = 0
for f in os.listdir(P):
    if not f.endswith(".swift") or f == "PerfTempRender.swift": continue
    p = os.path.join(P, f); s = open(p).read()
    out, pos = [], 0
    for m in re.finditer(r"(?<![\w.])Chart\s*(\{|\()", s):
        if m.start() < pos: continue
        inicio_linea = s.rfind("\n", 0, m.start()) + 1
        if "//" in s[inicio_linea:m.start()]: continue  # dentro de un comentario
        i = m.end() - 1
        if s[i] == "(":
            j = cierre(s, i, "(", ")")
            k = j + 1
            while k < len(s) and s[k] in " \t": k += 1
            if k < len(s) and s[k] == "{": j = cierre(s, k, "{", "}")
        else:
            j = cierre(s, i, "{", "}")
        out.append(s[pos:j + 1]); out.append("\n        .opacity(PerfTempRender.sinGraficas ? 0 : 1)")
        pos = j + 1; hechos += 1
    out.append(s[pos:])
    open(p, "w").write("".join(out))
print("gráficas con interruptor:", hechos)
