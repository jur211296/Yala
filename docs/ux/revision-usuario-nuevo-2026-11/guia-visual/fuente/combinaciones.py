"""Páginas transversales: las cuatro combinaciones como recorridos completos, los siete perfiles y el índice."""
import re
from partes_1 import L, C, SIM, B4, B5, B1, moneda
from partes_2 import steps_d1, d1_card, tend_text
from partes_3 import presupuesto_corto, selector_corto
from pantallas import *
from build import PERFILES, NIVEL, tag, legend

OBS = ("obs", "Captura real")


def exitc(text="Sale de Yala y la vuelve a abrir"):
    return f'<figure class="ph cardx"><div class="plabel"><span></span></div><div class="fr xc exit"><b>{ic("power", 22)}</b><span>{text}</span></div></figure>'


def skipc(text):
    return f'<figure class="ph cardx"><div class="plabel"><span></span></div><div class="fr xc skip"><b>{ic("dots", 22)}</b><span>{text}</span></div></figure>'


def goal(screen):
    return screen.replace('<div class="plabel"><span></span>', '<div class="plabel"><span class="goal">PRIMERA UTILIDAD</span>', 1)


def cap_shot(name, cap):
    return shot(C + name + "#w=280", cap=cap, mark=None)


def panel_tras_gasto(extra_parts=()):
    return panel([balance_after(), actions()] + list(extra_parts) + [sec("Últimos registros", right=""), rec("Almuerzo", "Alimentación", "18.50")])


START = [cap_shot("01-arranque.jpg", "Presentación"), cap_shot("02-selector.jpg", "Selector"), cap_shot("03-primera-vez.jpg", "Sin iCloud: «Seguir así»")]

CSS_EXTRA = """
.cardx .fr.xc{display:flex;flex-direction:column;align-items:center;justify-content:center;gap:10px;text-align:center;padding:20px;font-size:15px;line-height:1.3;color:var(--ink2)}
.cardx .fr.exit{background:#fff1f1;box-shadow:inset 0 0 0 2px #d6455d;color:#a3263d}
.cardx .fr.skip{background:#f1efe9;box-shadow:inset 0 0 0 2px #d8d4ca}
.mini-strip .cardx .fr{zoom:1;width:174px;height:375px;border-radius:28px}
.goal{background:#0f7a4b;color:#fff;padding:2px 7px;border-radius:99px;font-size:9.5px;letter-spacing:.05em}
.combo{background:#fff;border:1px solid var(--line);border-radius:20px;padding:18px 16px;margin:18px 0}
.combo h3{margin:0;font-size:22px}
.combo .num{font:800 13px/1 ui-monospace,Menlo,monospace;background:var(--ink);color:#fff;padding:6px 8px;border-radius:8px}
.combo .ah a{text-decoration:none}
.cnt{display:flex;flex-wrap:wrap;gap:8px;margin:10px 0 4px}
.cnt div{background:#f6f4ef;border-radius:12px;padding:8px 12px;min-width:120px}
.cnt b{display:block;font-size:22px;letter-spacing:-.02em}.cnt small{color:var(--ink2);font-size:12px}
.pf{background:#fff;border:1px solid var(--line);border-radius:18px;padding:16px;margin:16px 0}
.pf h3{margin:0 0 2px;font-size:20px}.pf .code{font-size:13px}
.pf .two{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin:10px 0}
.pf .two div{background:#f6f4ef;border-radius:12px;padding:10px 12px;font-size:14px}
.pf .two b{display:block;font-size:11.5px;letter-spacing:.06em;text-transform:uppercase;color:var(--ink3)}
.wide-shot{max-width:100%;border-radius:14px;border:1px solid var(--line);display:block}
.ipadrow{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:14px;margin:10px 0}
.ipadrow figure{margin:0}.ipadrow img{max-width:100%;border-radius:14px;border:1px solid var(--line);display:block}.ipadrow figcaption{font-size:13px;color:var(--ink2);margin-top:6px}
.find{background:#fff;border:1px solid var(--line);border-radius:16px;padding:14px 16px;margin:12px 0}
.find h4{margin:0 0 6px;font-size:17px}.find ul{margin:4px 0 0;padding-left:18px}.find li{margin:3px 0}
@media (max-width:700px){.pf .two{grid-template-columns:1fr}}
"""


def mini(screens):
    return f'<div class="strip mini-strip">{"".join(screens)}</div><p class="swipe noprint">Desliza: {len(screens)} pantallas →</p>'


# ------------------------------------------------------------------ recorridos
def hoy_journey():
    s = START + [cap_shot("04-reabre-yala.jpg", "«Reabre Yala»"), exitc(), cap_shot("05-onb-paso1-nombre.jpg", "Paso 1 de 7"), skipc("Pasos 2 a 6: uso, dónde, cuenta, saldo, categorías"),
                 cap_shot("11-onb-paso7-resumen.jpg", "Paso 7 de 7"), cap_shot("12-primer-panel.jpg", "Panel: aviso 1 de 3"),
                 phone(registro_sheet(), "sheet", cap="Nuevo registro", mark=MQ),
                 goal(phone(panel_tras_gasto([notice("Primeros pasos", "1 de 7 completados", tag=None, foot=None)]), "app", cap="Primer gasto guardado", mark=MQ))]
    return s


def combo1():
    return START + [cap_shot("04-reabre-yala.jpg", "«Reabre Yala»"), exitc(), cap_shot("05-onb-paso1-nombre.jpg", "Paso 1 de 7"), skipc("Pasos 2 a 6 iguales a hoy"),
                    cap_shot("11-onb-paso7-resumen.jpg", "Paso 7 de 7"),
                    phone(panel([balance(), actions(tap_new=True), d1_card("0 de 4", [("now", "Registra tu primer gasto"), ("todo", "Ponle un límite al mes"),
                                                                                        ("todo", "Agrega un pago que se repite"), ("todo", "Agrega otra cuenta")])]),
                          "app", cap="C4 + D1: la guía de 4 primero, sin Pro", mark=MQ),
                    phone(registro_sheet(), "sheet", cap="Nuevo registro", mark=MQ),
                    goal(phone(panel_tras_gasto([d1_card("1 de 4", [("done", "Registra tu primer gasto"), ("now", "Ponle un límite al mes")], nxt="Ponle un límite al mes")]),
                               "app", cap="Primer gasto; la guía sigue con el presupuesto", mark=MQ)),
                    phone(ptop("Panel de Ana") + sec("Planificación", right="") + '<div class="wrow">'
                          + widget("Pagos planificados", empty("calendar", "¿Pagas algo cada mes?", action="Agregar"))
                          + widget("Presupuestos", empty("calendar", "Ponle un límite", action="Crear"), cls="chg") + '</div>' + tabbar(shrink=True),
                          "app", cap="Después: C2, vacíos con botón", mark=MQ),
                    phone(selector_corto(tap=False), "sheet", cap="H2: selector corto", mark=MQ)]


def combo2(sin_reinicio=False):
    pre = START + ([] if sin_reinicio else [cap_shot("04-reabre-yala.jpg", "«Reabre Yala»"), exitc()])
    banner = [note('<b style="color:#fff">Tus datos están en este iPhone.</b> La próxima vez que abras Yala se conectan con tu iCloud.', cls="chg")] if sin_reinicio else []
    return pre + [phone(paso_nombre(1, 4), "onb", cap="B1: paso 1 de 4", mark=MQ),
                  phone(B5["screens"][0].split('<div class="bd">', 1)[1].rsplit('</div><div class="hi">', 1)[0], "onb", cap="B5: «Controlar mi sueldo»", mark=MQ),
                  phone(moneda(3, 4), "onb", cap="B1: moneda", mark=MQ),
                  phone(paso_saldo(4, 4, zero_chip=True), "onb", cap="B1: saldo", mark=MQ),
                  phone(panel(banner + [balance(), actions(tap_new=True), d1_card("0 de 4", [("now", "Registra tu primer gasto"), ("todo", "Ponle un límite al mes"),
                                                                                             ("todo", "Agrega un pago que se repite"), ("todo", "Agrega otra cuenta")]),
                                        sec("Tus finanzas", right=""), acc_chips()]),
                        "app", cap="C1 + D2: Panel reducido" + (" + A2: sin reinicio" if sin_reinicio else ""), mark=MQ),
                  phone(registro_sheet(), "sheet", cap="Nuevo registro", mark=MQ),
                  goal(phone(panel([balance_after(), actions(), sec('Últimos registros<span class="badge">NUEVO</span>', right="", cls="chg"),
                                    rec("Almuerzo", "Alimentación", "18.50"), d1_card("1 de 4", [("done", "Registra tu primer gasto"), ("now", "Ponle un límite al mes")], nxt="Ponle un límite al mes")]),
                             "app", cap="Primer gasto: aparece «Últimos registros»", mark=MQ))] + (
        [phone(panel([balance_after(), actions(), sec("Últimos registros", right=""), rec("Almuerzo", "Alimentación", "18.50")]) + toast("Listo: Yala ya guarda en tu iCloud privado", cls="chg"),
               "app", cap="Al día siguiente se conecta sola", mark=MQ)] if sin_reinicio else [])


def combo3():
    chats = [phone(s.split('<div class="bd">', 1)[1].rsplit('</div><div class="hi">', 1)[0], "chat", cap=c, mark=MQ)
             for s, c in zip(B4["screens"], ["B4: nombre y uso", "«¿Qué es esto?»", "Saldo", "Resumen"])]
    return START + [cap_shot("04-reabre-yala.jpg", "«Reabre Yala»"), exitc()] + chats + [
        phone(panel([balance(), actions(tap_new=True), steps_d1(), sec("Tus finanzas", right=""), acc_chips()]), "app", cap="Panel con C4 + C2 de la combinación 1", mark=MQ),
        phone(registro_sheet(), "sheet", cap="Nuevo registro", mark=MQ),
        goal(phone(panel_tras_gasto(), "app", cap="Primer gasto guardado", mark=MQ))]


COMBOS = [
    dict(n="Hoy", titulo="El recorrido de hoy (línea de base)", comp=[], screens=hoy_journey,
         ataca="—", esf="—", riesgo="—", reabre="—", para="—",
         cnt=[("11", "pantallas antes del Panel"), ("1", "salida de la app"), ("7 + 7", "preguntas del alta + pasos de la guía"), ("3", "avisos el día 1, uno es Pro")]),
    dict(n="1", titulo="«Menos capas»: lo mínimo que ataca el reporte", comp=["C2", "C4", "D1", "H2"], screens=combo1,
         ataca="F9, F10, F11, F13, F24. Deja F1, F2 y F4 como están.", esf="Bajo-medio", riesgo="Bajo: todo determinista, sin tocar sync", reabre="L5-1 en parte (D1)",
         para="P2, P3, P4. Poco para P1 y P6.",
         cnt=[("11", "pantallas antes del Panel"), ("1", "salida de la app"), ("7 + 4", "preguntas + pasos de la guía"), ("1", "aviso a la vez, sin Pro")]),
    dict(n="2", titulo="«Alta corta + Panel que crece»", comp=["C2", "C4", "D1", "H2", "B1", "B5", "C1", "D2"], screens=combo2,
         ataca="Además F2, F5, F6, F8, F12.", esf="Medio", riesgo="Medio: Panel por defecto y modos de uso; tocar PanelDefaults afecta a la nube",
         reabre="L1-7 si el saldo pasa a «0 por ahora»", para="P2, P3, P7. P1 si se suma importar (E4).",
         cnt=[("8", "pantallas antes del Panel"), ("1", "salida de la app"), ("4 + 4", "preguntas + pasos de la guía"), ("4", "bloques en el Panel del día 1")]),
    dict(n="3", titulo="«Conversación guionizada»", comp=["C2", "C4", "D1", "H2", "B4"], screens=combo3,
         ataca="F4, F5 y el miedo del principiante; no acorta.", esf="Medio-alto: vista nueva, 16 idiomas, VoiceOver de un chat", riesgo="Medio",
         reabre="—", para="P2 sobre todo; neutral o peor para P3 y P4.",
         cnt=[("4 + 1", "pantallas + 1 conversación"), ("1", "salida de la app"), ("6 + 7", "preguntas + pasos de la guía"), ("1", "aviso a la vez, sin Pro")]),
    dict(n="4", titulo="«Sin reinicio» (aquí, sobre la 2)", comp=["A2", "B1", "B5", "C1", "D2"], screens=lambda: combo2(True),
         ataca="F1, el único punto donde la persona sale de la app.", esf="Alto", riesgo="Alto: arranque de SwiftData con CloudKit; review adversarial y encargo propio",
         reabre="L1-4", para="Todos, si el reinicio es donde más se pierde gente (aún sin medir).",
         cnt=[("7", "pantallas antes del Panel"), ("0", "salidas de la app"), ("4 + 4", "preguntas + pasos de la guía"), ("4", "bloques en el Panel del día 1")]),
]

COMBO_LENS = {
    "Hoy": L(("M", "teclea todo; reinicio"), ("A", "se agota antes del Panel"), ("A", "11 pantallas para anotar"), ("M", "candados y Pro"), ("B", "no pasa por aquí"),
             ("A", "una moneda principal"), ("A", "reinicio y pantallas largas")),
    "1": L(("M", "sigue tecleando todo"), ("M", "alta igual; Panel más claro"), ("M", "el alta sigue larga"), ("B", "sin ruido el día 1"), ("B", "—"),
           ("A", "el alta no cambia para varias monedas"), ("M", "el reinicio sigue")),
    "2": L(("M", "B si se suma importar (E4)"), ("B", "pocas preguntas, Panel que crece"), ("B", "corto"), ("B", "—"), ("B", "—"), ("M", "una moneda al inicio"),
           ("M", "el reinicio sigue")),
    "3": L(("M", "—"), ("B", "le explican cada término"), ("A", "conversación lenta"), ("M", "lento"), ("B", "—"), ("M", "puede preguntar por la tarjeta"),
           ("M", "VoiceOver por diseñar; reinicio")),
    "4": L(("B", "—"), ("B", "sin salir de la app"), ("B", "corto y sin salida"), ("B", "—"), ("B", "—"), ("M", "una moneda al inicio"), ("B", "nada fuera de la app")),
}

PART_OF = {}


def combos_page(parts):
    for p in parts:
        for a in p["alts"]:
            PART_OF[a["code"]] = p["slug"]
    PART_OF.update({"A2": "01-bienvenida"})
    blocks = ""
    for c in COMBOS:
        comp = " ".join(f'<a class="tag src" href="{PART_OF.get(x, "")}.html#{x}">{x}</a>' for x in c["comp"])
        cnt = "".join(f"<div><b>{v}</b><small>{t}</small></div>" for v, t in c["cnt"])
        meta = "" if c["n"] == "Hoy" else (
            f'<div class="meta">{tag("lvl", "Ataca: " + c["ataca"])}{tag("lvl", "Esfuerzo " + c["esf"])}{tag("lvl", "Riesgo " + c["riesgo"])}'
            f'{tag("reo", "Reabre " + c["reabre"]) if c["reabre"] != "—" else ""}{tag("hip", "Para quién: " + c["para"])}</div>')
        blocks += f"""<section class="combo" id="c{c['n']}"><div class="ah"><span class="num">{'HOY' if c['n'] == 'Hoy' else 'COMBINACIÓN ' + c['n']}</span><h3>{c['titulo']}</h3></div>
<div class="flowsum">{comp}</div>{meta}<div class="cnt">{cnt}</div>{mini(c['screens']())}</section>"""
    # tabla
    rows = ""
    for c in COMBOS:
        vals = {t: v for v, t in c["cnt"]}
        rows += "<tr><td>" + ("Hoy" if c["n"] == "Hoy" else f"Combinación {c['n']}") + "</td>" + "".join(f"<td>{v}</td>" for v, t in c["cnt"]) + f"<td>{c['esf']}</td><td>{c['riesgo']}</td><td>{c['reabre']}</td></tr>"
    table = ('<div class="tbl"><table class="cmp"><tr><th>Recorrido</th><th>Pantallas antes del Panel</th><th>Salidas de la app</th><th>Preguntas + pasos</th><th>Día 1 en el Panel</th>'
             f'<th>Esfuerzo</th><th>Riesgo</th><th>Reabre</th></tr>{rows}</table></div>')
    head_cols = "<th>Perfil</th>" + "".join(f"<th>{'Hoy' if k == 'Hoy' else 'Comb. ' + k}</th>" for k in COMBO_LENS)
    lrows = ""
    for k, name, _ in PERFILES:
        cells = "".join(f'<td><div class="d"><i class="dot {COMBO_LENS[c][k][0]}"></i><span>{COMBO_LENS[c][k][1]}</span></div></td>' for c in COMBO_LENS)
        lrows += f"<tr><td>{k} · {name}</td>{cells}</tr>"
    lens = f'<div class="tbl"><table class="cmp lens"><tr>{head_cols}</tr>{lrows}</table></div>'
    body = f"""<style>{CSS_EXTRA}</style>
<header class="ph-h"><div class="kicker">Usuario nuevo · guía para decidir</div><h1 class="t">Las cuatro combinaciones, de principio a primera utilidad</h1>
<p class="lead">Cada fila es un recorrido completo, desde que Ana abre Yala por primera vez hasta que guarda su primer gasto (la «primera utilidad» de la revisión). Hoy va arriba como línea de base.</p>
<div class="case"><span class="ct">El caso</span><span>Ana, iPhone sin iCloud, S/ 1,500 en una cuenta. Primer gasto: «Almuerzo» S/ 18.50. <em style="color:var(--ink3)">Datos ficticios.</em></span></div>
{legend()}
<p class="sub" style="margin-top:12px">{tag('hip', 'Conteos sobre la maqueta')} Las cifras de cada recorrido se cuentan en las pantallas de esta guía, no en uso real. <b>Ninguna dice cuánta gente abandona</b>: esa medida todavía no existe (F21).</p></header>
<h2 class="s">Comparación rápida</h2>{table}
{blocks}
<h2 class="s">Cómo vive cada perfil cada combinación</h2>
<p class="sub">{tag('hip', 'Evaluación heurística, no entrevistas')} <i class="dot A"></i> riesgo alto de trabarse · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>{lens}
<div class="decide"><h3>Qué inclina la balanza (de la revisión)</h3><ul>
<li><b>Si el reinicio pierde mucha gente</b> (se sabrá con el evento propuesto en dos o tres semanas), la combinación 4 pasa delante.</li>
<li><b>Si el abandono está después del alta</b> (terminan y no registran), la 1 y la 2 dan más por menos.</li>
<li><b>La 3 compite con la 2, no la complementa</b>: las dos rehacen el onboarding. Hay que elegir una.</li>
<li><b>La 4 se puede montar sobre cualquiera</b>; aquí se muestra sobre la 2 para que se vea el recorrido más corto posible.</li></ul></div>
<p class="foot">Fuente: README §6 de la revisión. Maquetas en HTML, no la app.</p>"""
    return "Combinaciones · Usuario nuevo", body, "Las cuatro combinaciones del estudio como recorridos completos, comparables entre sí."


def perfiles_page(parts):
    cards = ""
    util = {"P1": ("Ver sus cuentas y saldos reales en la app", "Tener que teclear lo que ya tiene en la hoja"),
            "P2": ("Anotar un gasto y ver «te quedan X»", "Una pregunta que no entiende y no puede saltar"),
            "P3": ("Primer gasto guardado en menos de un minuto", "Cualquier pantalla entre abrir y anotar"),
            "P4": ("Un presupuesto por categoría funcionando", "Guías y ofertas que no puede quitar"),
            "P5": ("Ver el gasto del grupo", "Que le pidan su saldo personal para entrar a un grupo"),
            "P6": ("Ver soles y dólares por separado y la deuda de la tarjeta bien", "Un total mezclado o un saldo de tarjeta con el signo mal"),
            "P7": ("Anotar un gasto sin que nada se corte", "Botones tapados o instrucciones fuera de la app")}
    for k, name, why in PERFILES:
        rows = ""
        for p in parts:
            hl, ht = p["hoy_lens"].get(k, ("N", "—"))
            good = [a for a in p["alts"] if a["lens"].get(k, ("N",))[0] == "B"]
            bad = [a for a in p["alts"] if a["lens"].get(k, ("N",))[0] == "A"]
            fmt = lambda xs: " ".join(f'<a class="tag src" href="{p["slug"]}.html#{a["code"]}" title="{a["lens"][k][1]}">{a["code"]}</a> <small>{a["lens"][k][1]}</small><br>' for a in xs) or "—"
            rows += (f'<tr><td><a href="{p["slug"]}.html">{p["corto"]}</a></td><td><div class="d"><i class="dot {hl}"></i><span>{ht}</span></div></td>'
                     f'<td>{fmt(good)}</td><td>{fmt(bad)}</td></tr>')
        crow = "".join(f'<td><div class="d"><i class="dot {COMBO_LENS[c][k][0]}"></i><span>{COMBO_LENS[c][k][1]}</span></div></td>' for c in COMBO_LENS)
        u, ab = util[k]
        cards += f"""<section class="pf" id="{k}"><div class="ah"><span class="code">{k}</span><h3>{name}</h3></div><p class="sub" style="margin:4px 0">{why}</p>
<div class="two"><div><b>Primera utilidad</b>{u}</div><div><b>Qué lo haría abandonar</b>{ab}</div></div>
<div class="tbl"><table class="cmp lens"><tr><th>Parte</th><th>Hoy</th><th>Le van bien <i class="dot B"></i></th><th>Le van mal <i class="dot A"></i></th></tr>{rows}</table></div>
<div class="tbl" style="margin-top:8px"><table class="cmp lens"><tr><th>Recorrido</th>{''.join(f"<th>{'Hoy' if c == 'Hoy' else 'Comb. ' + c}</th>" for c in COMBO_LENS)}</tr><tr><td>Combinaciones</td>{crow}</tr></table></div></section>"""
    body = f"""<style>{CSS_EXTRA}</style>
<header class="ph-h"><div class="kicker">Usuario nuevo · guía para decidir</div><h1 class="t">Los siete perfiles, como lentes</h1>
<p class="lead">No son entrevistas: son siete maneras de mirar cada opción. Para cada perfil, qué opciones de cada parte le van bien y cuáles le van mal, y cómo vive cada combinación.</p>
<p class="sub" style="margin-top:12px">{tag('hip', 'Evaluación heurística')} La columna «Hoy» y «primera utilidad» vienen de la revisión (§4); el resto es estimación de esta guía. La forma de confirmarlo es la prueba de pasillo con 5-6 personas reales (revisión §7.2).</p>
<div class="flowsum">{''.join(f'<a class="tag src" href="#{k}">{k} · {n}</a>' for k, n, _ in PERFILES)}</div></header>
{cards}<p class="foot">Pasa el dedo o el ratón por un código para ver la frase completa; cada código lleva a su maqueta.</p>"""
    return "Perfiles · Usuario nuevo", body, "Los siete perfiles simulados como lentes sobre cada opción y cada combinación."


def index_page(parts):
    rows = ""
    for p in parts:
        thumb = p["hoy"][0][0] + "#w=230"
        n = len(p["alts"])
        nnew = sum(1 for a in p["alts"] if a["origen"] == "new")
        extra = f" · {nnew} propuesta{'s' if nnew > 1 else ''} nueva{'s' if nnew > 1 else ''}" if nnew else ""
        rows += (f'<a class="idx-row" href="{p["slug"]}.html"><img src="{thumb}" alt="Hoy: {p["corto"]}" loading="lazy">'
                 f'<div><div class="n">PARTE {p["num"]} · {n} OPCIONES{extra.upper()}</div><h4>{p["titulo"]}</h4><p>{re.sub("<[^>]+>", "", p["problema"])}</p></div></a>')
    ip = lambda f, c: f'<figure><img src="{SIM}{f}" alt="{c}" loading="lazy"><figcaption>{c}</figcaption></figure>'
    body = f"""<style>{CSS_EXTRA}</style>
<header class="ph-h"><div class="kicker">Yala · usuario nuevo · noviembre 2026</div>
<h1 class="t">Las propuestas, en pantalla, para decidir</h1>
<p class="lead">Ocho partes del recorrido de una persona nueva. En cada una: lo que ve hoy, el problema en una línea y de 3 a 5 alternativas maquetadas como pantallas de Yala, con el mismo caso. Al final, las cuatro combinaciones como recorridos completos y los siete perfiles como lentes.</p>
<div class="case"><span class="ct">El caso, en toda la guía</span><span><b>Ana</b>, iPhone sin iCloud · cuenta <b>«Mi dinero Soles»</b> con <b>S/ 1,500</b> · primer gasto <b>«Almuerzo» S/ 18.50</b> · presupuesto <b>«Comida» S/ 600 al mes</b> · pago <b>«Alquiler» S/ 900 el día 5</b> · segunda cuenta <b>«Tarjeta de crédito», S/ 420 por pagar</b>. <em style="color:var(--ink3)">Datos ficticios.</em></span></div>
{legend()}</header>
<div class="kpis">
<div class="kpi"><b>11 + 1</b><small>pantallas y una salida de la app antes del Panel {tag('obs', 'Observado')}</small></div>
<div class="kpi"><b>7 + 7</b><small>preguntas del alta y pasos de la guía {tag('obs', 'Observado')}</small></div>
<div class="kpi"><b>62</b><small>subcategorías al elegir un presupuesto {tag('obs', 'Observado')}</small></div>
<div class="kpi"><b>0</b><small>medidas de dónde se abandona: aún no existen {tag('nov', 'Sin datos')}</small></div></div>
<h2 class="s">Las ocho partes</h2><div class="idxgrid">{rows}</div>
<h2 class="s">Recorridos completos y perfiles</h2>
<div class="grid2"><a class="pcard" href="09-combinaciones.html"><div class="n kicker">Cuatro recorridos + hoy</div><h4>Combinaciones</h4><p>Cada combinación del estudio de principio a primer gasto guardado, con sus conteos lado a lado.</p></a>
<a class="pcard" href="10-perfiles.html"><div class="n kicker">Siete lentes</div><h4>Perfiles</h4><p>Qué opción le va bien o mal a cada perfil, en cada parte y en cada combinación.</p></a></div>

<h2 class="s">Lo que faltaba validar, revisado en el simulador esta noche</h2>
<p class="sub">{tag('obs', 'Observado')} Build de <code>2.3</code> instalada desde cero, modo oscuro: iPhone 17 Pro (iOS 27.2) e iPad Pro 13 pulgadas creado para esta revisión. Las capturas están en <code>capturas-simulador/</code>.</p>
<div class="find"><h4>1. Crear una cuenta desde el carrusel (F19)</h4><ul>
<li>Al terminar el alta, <b>«Tus finanzas» salió plegada</b>, con un chip «+ Agregar» a la vista: <b>1 toque</b> abre «Nueva cuenta». Las capturas del 6-nov la mostraban desplegada.</li>
<li>Desplegada, «Agregar cuenta» es la última tarjeta del carrusel y solo asoma su borde: <b>hay que desplazar</b>.</li>
<li>No se midió qué decide si sale plegada o desplegada en otras instalaciones. <a href="05-crear-cuenta.html">Ver la parte 5 →</a></li></ul></div>
{mini([shot(SIM + f + "#w=280", cap=c, mark=None) for f, c in [("sim-01-panel-dia1-finanzas-plegada.jpg", "Plegada: «+ Agregar»"), ("sim-02-agregar-abre-nueva-cuenta.jpg", "1 toque"), ("sim-04-finanzas-desplegada.jpg", "Desplegada"), ("sim-05-carrusel-agregar-cuenta.jpg", "Al final del carrusel")]])}
<div class="find"><h4>2. Texto grande</h4><ul>
<li><b>Paso 1, tamaño AX3:</b> el botón «Siguiente» queda <b>encima</b> de la pregunta «¿Cómo quieres que te llamemos?» y el campo del nombre queda debajo de la vista.</li>
<li><b>Paso 3:</b> solo se ve la primera opción y el botón la tapa; para ver «Cuenta corriente» hay que desplazar.</li>
<li><b>Paso 5:</b> el campo del saldo queda fuera de la vista hasta desplazar; «¿No sabes tu saldo?» se ve después.</li>
<li><b>Panel, tamaño máximo (AX5):</b> «Nuevo registro» queda por debajo de la primera pantalla; el importe del balance no crece y los textos de alrededor sí.</li>
<li>No se probó VoiceOver.</li></ul></div>
{mini([shot(SIM + f + "#w=280", cap=c, mark=None) for f, c in [("sim-09-paso1-texto-grande.jpg", "Paso 1 · AX3"), ("sim-10-paso3-texto-grande.jpg", "Paso 3 · AX3"), ("sim-11-paso5-texto-grande.jpg", "Paso 5 · AX3"), ("sim-12-paso5-texto-grande-desplazado.jpg", "Paso 5, desplazado"), ("sim-06-panel-texto-grande-ax3.jpg", "Panel · AX3"), ("sim-07-panel-texto-maximo-ax5.jpg", "Panel · AX5")]])}
<div class="find"><h4>3. iPad (F23)</h4><ul>
<li><b>Confirmado en vertical:</b> el selector se limita al centro, pero los pasos del onboarding, sus campos y el botón «Siguiente» ocupan <b>todo el ancho</b> (unos 1000 puntos).</li>
<li>En el paso del saldo, el teclado numérico flotante tapa el lado de «Negativo».</li>
<li>El Panel del día 1 en dos columnas repite lo del iPhone: vacíos sin botón y la gráfica de un punto.</li>
<li><b>No se midió en horizontal</b>: esta Mac no tiene Simulator.app y girar exige un XCUITest, y el encargo no toca tests. En horizontal el ancho solo puede ser mayor.</li></ul></div>
<div class="ipadrow">{ip("sim-13-ipad-selector.jpg", "Selector: limitado al centro")}{ip("sim-14-ipad-paso1.jpg", "Paso 1: campo a todo el ancho")}{ip("sim-15-ipad-paso3.jpg", "Paso 3: lista a todo el ancho")}{ip("sim-16-ipad-paso5-teclado.jpg", "Paso 5: teclado flotante")}{ip("sim-17-ipad-panel-dia1.jpg", "Panel del día 1")}</div>

<h2 class="s">Qué es y qué no es esta guía</h2>
<div class="callout"><b>Es</b> una forma de ver las propuestas antes de elegir. Las maquetas están hechas en HTML con el estilo de Yala; <b>no son la app</b> y no se probó ningún flujo nuevo.<br>
<b>No elige ganador.</b> Cada parte termina con la decisión que toca y sus ejes. Las alternativas vienen de <code>alternativas.md</code>; las que no estaban llevan el rótulo <b>PROPUESTA NUEVA</b>.<br>
<b>No tiene métricas ni testimonios.</b> Los conteos de pantallas y toques se cuentan sobre las maquetas. Los perfiles son lentes heurísticas.<br>
<b>Si el navegador no ejecuta JavaScript</b>, todo se ve igual; solo se pierde el avance al tocar el anillo cian. El PDF tiene las mismas páginas.</div>
<p class="foot">Fuente: <code>docs/ux/revision-usuario-nuevo-2026-11/</code> (README.md, alternativas.md y capturas del 6-nov). Generado con <code>guia-visual/fuente/build.py</code>.</p>"""
    return "Usuario nuevo · guía visual", body, "Guía visual para decidir la experiencia del usuario nuevo de Yala: hoy, alternativas maquetadas, combinaciones y perfiles."
