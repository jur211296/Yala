"""Partes 5 a 8: crear cuenta, presupuesto, pago planificado y dónde se encuentran las acciones."""
from partes_1 import A, L, C, SIM
from pantallas import *
from partes_2 import C2 as _C2

OBS = ("obs", "Simulador hoy")


# =============================================================== 5. CREAR CUENTA
def cuenta_sheet(tap=True, compact=False):
    tiles = [("card", "General"), ("cash", "Efectivo"), ("bank", "Cuenta corriente"), ("piggy", "Ahorros"), ("card", "Tarjeta de crédito")]
    t = "".join(f'<div class="tile{" on" if n == "Tarjeta de crédito" else ""}">{ic(i, 14)}<span>{n}</span></div>' for i, n in tiles)
    extra = "" if compact else (sh_sec("Moneda") + group(row("<i class=fpe></i> Moneda", "Sol peruano")))
    return (sheet_top("Nueva cuenta", right_on=True).replace('class="circ d on"', f'class="circ d on{" tap" if tap else ""}"')
            + sh_sec("General") + group(row("Tarjeta de crédito", "", icon="edit", color="#a5a6ff", chev=False))
            + sh_sec("Tipo") + f'<div class="tile3">{t}</div>' + extra
            + sh_sec("Saldo inicial") + seg(["A favor", "Por pagar"], 1)
            + '<div class="fld big" style="margin-top:6px;background:#1c1c22"><span class="funit">S/</span><span class="fv">420.00</span></div>')


def finanzas_dos(cls=""):
    return (sec("Tus finanzas", right="") + f'<div class="accrow two {cls}">' + acc_card() +
            acc_card("Tarjeta de crédito", "Tarjeta · PEN", "420", icon="card", color="#a855f7", label="Por pagar", neg=True) + '</div>')


E1 = A("E1", "Tarjeta «Agregar cuenta» siempre visible", "src",
       "Con «Tus finanzas» desplegada, una tarjeta para agregar aparece <b>junto a la primera cuenta</b> mientras haya menos de 3, sin tener que desplazar el carrusel.",
       [phone(panel([balance(), actions(), sec("Tus finanzas", right=""),
                     '<div class="accrow">' + acc_card() + f'<div class="accc add chg tap" style="flex:0 0 74px;padding:6px">{ic("plus", 18, sw=2.2)}<b style="font-size:10.5px">Agregar cuenta</b></div></div>']),
              "app", step=1, mark=MQ, cap="La tarjeta para agregar se ve sin desplazar"),
        phone(cuenta_sheet(), "sheet", step=2, mark=MQ, cap="Tarjeta de crédito, S/ 420 por pagar"),
        phone(panel([balance(note2="Tienes S/ 1,080.00 en tus cuentas"), actions(), finanzas_dos("chg")]), "app", step=3, mark=MQ,
              cap="Las dos cuentas en «Tus finanzas»")],
       ["Visible sin desplazar", "Barato"],
       ["Reabre en parte L3-9 (la variante con chips)", "Ocupa espacio del carrusel"],
       L(("M", "una a una"), ("B", "la ve sin buscar"), ("B", "—"), ("B", "—"), ("B", "—"), ("M", "una a una"), ("B", "tarjeta grande")),
       esf="S", riesgo="Bajo", reabre="L3-9 (en parte)", conteo="1 toque al formulario con «Tus finanzas» desplegada (hoy: desplazar + 1)")

E2 = A("E2", "Botón «+» con menú de crear", "src",
       "El «+» flotante del Panel abre un menú: Registro · Cuenta · Presupuesto · Pago planificado. <b>Un solo sitio para crear todo.</b>",
       [phone(panel([balance(), actions(), sec("Tus finanzas", right=""), acc_chips(add=None)], fab_btn=True).replace('class="fab "', 'class="fab tap chg"'),
              "app", step=1, mark=MQ, cap="Toca el «+» flotante"),
        phone(panel([balance(), actions(), sec("Tus finanzas", right=""), acc_chips(add=None)], fab_btn=True) + dim()
              + menu([("plus", "Registro"), ("card", "Cuenta"), ("calendar", "Presupuesto"), ("repeat", "Pago planificado")], cls="chg").replace('<div class="mi"><svg', '<div class="mi"><svg', 1),
              "app", step=2, mark=MQ, cap="Elige «Cuenta»"),
        phone(cuenta_sheet(), "sheet", step=3, mark=MQ, cap="Mismo formulario"),
        phone(panel([balance(note2="Tienes S/ 1,080.00 en tus cuentas"), actions(), finanzas_dos()]), "app", step=4, mark=MQ, cap="Resultado")],
       ["Un solo sitio para crear todo (F11, F19, F20)", "Sirve también para presupuesto y pago"],
       ["Un toque más para lo más común: registrar", "Hay que ver qué hace hoy el «+» y si la gente ya lo usa como atajo", "En iPad el «+» vive en otra parte"],
       L(("M", "—"), ("M", "tiene que abrir el menú"), ("M", "un toque más para registrar"), ("B", "todo en un sitio"), ("B", "—"), ("M", "—"),
         ("M", "menú pequeño")),
       esf="M", riesgo="Medio: cambia un gesto aprendido", conteo="2 toques del Panel al formulario")

E3 = A("E3", "Crear la cuenta desde el registro", "src",
       "Al elegir la cuenta de un registro aparece <b>«Nueva cuenta»</b>: la cuenta se crea justo cuando hace falta.",
       [phone(registro_sheet("Supermercado", "84.20", "Alimentación", tap_save=False).replace(
           '<div class="lrow ">' + tint("card", "#5b5cf0", 24), '<div class="lrow tap">' + tint("card", "#5b5cf0", 24)),
              "sheet", step=1, mark=MQ, cap="Paga con la tarjeta: toca «Cuenta»"),
        phone(sheet_top("Cuenta", right=None) + group(row("Mi dinero Soles", "S/ 1,500", icon="card", color="#5b5cf0", chev=False),
                                                     f'<div class="lrow chg tap">{tint("plus", "#a5a6ff", 24)}<div class="lt"><span>Nueva cuenta</span></div></div>'),
              "sheet", step=2, mark=MQ, cap="«Nueva cuenta» al final de la lista"),
        phone(cuenta_sheet(compact=True), "sheet", step=3, mark=MQ, cap="Formulario corto, encima del registro"),
        phone(registro_sheet("Supermercado", "84.20", "Alimentación", account="Tarjeta de crédito"), "sheet", step=4, mark=MQ,
              cap="Vuelve al registro con la tarjeta elegida")],
       ["Aparece justo cuando hace falta (P6 al pagar en dólares o con tarjeta)"],
       ["Interrumpe el registro con otro formulario", "No ayuda a quien quiere ordenar sus cuentas antes de registrar"],
       L(("M", "una a una"), ("B", "aparece cuando la necesita"), ("B", "—"), ("B", "—"), ("B", "—"), ("B", "justo al pagar en dólares"),
         ("M", "formulario dentro de otro")),
       esf="S-M", riesgo="Bajo-medio", conteo="2 toques desde el registro")

E4 = A("E4", "Importar crea las cuentas", "src",
       "Desde la bienvenida o el Panel vacío, importar un estado de cuenta o un Excel <b>crea la cuenta con sus movimientos</b>.",
       [phone(panel([balance(), actions(), sec("Tus finanzas", right=""), acc_chips(),
                     f'<div class="lrow chg tap" style="background:rgba(255,255,255,.07);border-radius:12px;margin-top:8px">{tint("import", "#22b35e", 26)}<div class="lt"><span>¿Tienes un Excel o un estado de cuenta?</span><small>Importa y creamos la cuenta por ti</small></div></div>']),
              "app", step=1, mark=MQ, cap="La puerta a importar, en el Panel vacío"),
        phone(sheet_top("Importar", right=None) + '<div class="mini center" style="margin:6px 0 10px">estado-tarjeta-octubre.pdf</div>'
              + group(row("Cuenta nueva", "Tarjeta de crédito", icon="card", color="#a855f7", chev=False),
                      row("Saldo por pagar", "S/ 420.00", icon="cash", color="#ef4444", chev=False),
                      row("Movimientos encontrados", "12", icon="list", color="#64748b"))
              + sh_sec("Vista previa") + rec("Supermercado", "Alimentación", "84.20", "28 oct") + rec("Farmacia", "Personal", "36.50", "25 oct")
              + bottom(btn("Crear cuenta e importar", cls="tap")), "sheet", step=2, mark=MQ, cap="Revisa lo que se va a crear"),
        phone(panel([balance(note2="Tienes S/ 1,080.00 en tus cuentas"), actions(), finanzas_dos()]), "app", step=3, mark=MQ,
              cap="La tarjeta llega con sus movimientos")],
       ["Responde a P1", "El import ya existe; lo nuevo es la puerta"],
       ["Revisar un import lleva tiempo y mete trabajo el día 1", "Formatos distintos por país y banco"],
       L(("B", "trae lo que ya tiene"), ("M", "revisar un import cuesta"), ("A", "trabajo el día 1"), ("B", "—"), ("N", "—"), ("M", "formatos por banco"),
         ("A", "revisión larga")),
       esf="M-L", riesgo="Medio", conteo="2 toques + revisar",
       estado=[("nov", "El estado de cuenta y sus 12 movimientos son ficticios")])

CUENTA = dict(
    slug="05-crear-cuenta", num=5, titulo="Crear una cuenta", corto="Crear cuenta",
    problema="La revisión decía que para agregar una cuenta hay que llegar al final del carrusel de «Tus finanzas». <b>En la build de 2.3 es así solo con la sección desplegada.</b>",
    fricciones="F19 crear cuenta (era «por confirmar en pantalla»)",
    caso="Ana quiere agregar su <b>tarjeta de crédito</b>, con <b>S/ 420</b> por pagar.",
    hoy=[(SIM + "sim-01-panel-dia1-finanzas-plegada.jpg", "Plegada: chip «+ Agregar» a la vista", OBS),
         (SIM + "sim-02-agregar-abre-nueva-cuenta.jpg", "1 toque: se abre «Nueva cuenta»", OBS),
         (SIM + "sim-03-nueva-cuenta-completa.jpg", "El formulario completo", OBS),
         (SIM + "sim-04-finanzas-desplegada.jpg", "Desplegada: la tarjeta de agregar queda fuera", OBS),
         (SIM + "sim-05-carrusel-agregar-cuenta.jpg", "Hay que desplazar el carrusel", OBS)],
    hoy_nota="Medido esta noche en el simulador (build de 2.3, instalación nueva, iPhone 17 Pro). Con «Tus finanzas» <b>plegada</b> —así salió al terminar el alta— el chip «+ Agregar» abre «Nueva cuenta» en 1 toque. <b>Desplegada</b>, «Agregar cuenta» es la última tarjeta del carrusel y solo asoma el borde: hay que desplazar. Las capturas del 6-nov mostraban la sección desplegada.",
    hoy_lens=L(("A", "tiene varias cuentas que traer"), ("M", "—"), ("B", "—"), ("M", "—"), ("B", "—"), ("A", "necesita 2-3 cuentas"), ("M", "—")),
    alts=[E1, E2, E3, E4],
    decide=dict(pregunta="Con el chip «+ Agregar» que 2.3 ya enseña plegado, ¿hace falta más? Si sí: ¿un sitio único para crear (E2), la cuenta en el momento de usarla (E3) o traerla importada (E4)?",
                ejes=["<b>Primero, una decisión pequeña</b>: con qué estado arranca «Tus finanzas» en una instalación nueva. Plegada, crear cuenta ya está a 1 toque.",
                      "<b>E2 resuelve también presupuesto y pago</b> (parte 8): decide las dos cosas a la vez.",
                      "<b>E3 y E4 se suman</b> a cualquiera; no compiten."]),
)

# =============================================================== 6. PRESUPUESTO
def selector_corto(tap=True):
    rows = [row(n, "", icon=CAT[n][0], color=CAT[n][1], cls=("tap" if (tap and n == "Alimentación") else "")) for n in
            ["Alimentación", "Transporte", "Compras", "Hogar", "Entretenimiento", "Personal"]]
    return (sheet_top("Elegir categorías", left="chev-l", right=None) + sh_sec("Las de todos los días") + group(*rows, cls="chg")
            + group(row("Ver todas", "10", icon="list", color="#64748b")) + '<div class="mini" style="margin-top:8px">«Ingresos» no aparece: un límite de gasto no cuenta ingresos.</div>')


def presupuesto_corto(tap=True, name="Comida", cats=("Alimentación",), more=True, widget_on=True):
    c = chips(["Todos mis gastos", "Elegir categorías"], selected=("Elegir categorías",)) + (
        f'<div class="achips" style="margin-top:6px">' + "".join(f'<span class="achip">{cat(x, 16)}<b>{x}</b></span>' for x in cats) + '</div>')
    m = f'<div class="lrow chg" style="background:#1c1c22;border-radius:12px;margin-top:10px">{ic("chev-d", 12)}<div class="lt"><span>Más opciones</span><small>Período, alertas y filtros</small></div></div>' if more else ""
    return (sheet_top("Nuevo presupuesto", right_on=True).replace('class="circ d on"', f'class="circ d on{" tap" if tap else ""}"')
            + group(row(name, "", icon="edit", color="#a5a6ff", chev=False))
            + '<div class="fld big" style="margin-top:8px;background:#1c1c22"><span class="funit">S/ al mes</span><span class="fv">600</span></div>'
            + sh_sec("¿Qué gastos cuenta?") + c
            + group(toggle_row("Mostrar en el Panel", widget_on, "Activado para tu primer presupuesto"), cls="chg").replace('class="grp chg"', 'class="grp chg" style="margin-top:10px;padding:0 10px"')
            + m)


def widget_comida(name="Comida", spent="18.50", total="600", pct=3, cls="chg", extra=""):
    return widget("Presupuestos", f'<div style="font-size:11px"><b>{name}</b><div class="pbar"><i style="width:{pct}%"></i></div><small style="color:rgba(255,255,255,.6)">S/ {spent} de S/ {total} · quedan {30 - 6} días</small>{extra}</div>', cls=cls)


H1 = A("H1", "Presupuesto rápido", "src",
       "Una sola pregunta: «¿Cuánto quieres gastar este mes?». Crea un presupuesto mensual de <b>todos</b> los gastos, visible en el Panel.",
       [phone(sheet_top("Tu límite del mes", right=None) + '<div style="height:60px"></div>'
              + head("calendar", "¿Cuánto quieres gastar este mes?", "Cuenta todos tus gastos. Puedes afinarlo después.").replace('class="hd"', 'class="hd chg"')
              + '<div class="fld big" style="background:#1c1c22"><span class="funit">S/</span><span class="fv">600</span></div>'
              + note("Para limitar solo la comida, edítalo después y elige la categoría.")
              + bottom(btn("Crear límite", cls="tap")), "sheet", step=1, mark=MQ, cap="Un campo y listo"),
        phone(panel([balance_after(), actions(), sec("Planificación", right=""),
                     widget_comida("Todos mis gastos", extra='<div class="mini" style="margin-top:3px">Incluye todo, no solo comida</div>')]),
              "app", step=2, mark=MQ, cap="En el Panel: S/ 18.50 de S/ 600")],
       ["El primer presupuesto en segundos", "«Todos mis gastos» ya existe (L9-2)"],
       ["Uno solo y sin categorías: <b>no cumple el caso de Ana</b> (solo comida) sin editarlo", "Lo demás queda para después"],
       L(("M", "lo quiere por categoría"), ("B", "un solo número"), ("B", "—"), ("M", "le falta la categoría"), ("B", "—"), ("M", "¿en qué moneda?"),
         ("B", "una pregunta")),
       esf="S", riesgo="Bajo", conteo="1 campo (hoy: formulario de 8 bloques)")

H2 = A("H2", "Selector corto de categorías", "src",
       "Al elegir categorías: <b>sin «Ingresos»</b>, primero las de uso diario (las padres, sin desplegar) y «Ver todas».",
       [phone(presupuesto_hoy().replace("Elegir categorías</span>", "Elegir categorías</span>").replace('<span class="chip">Elegir categorías', '<span class="chip tap">Elegir categorías'),
              "sheet", step=1, mark=MQ, cap="Toca «Elegir categorías»"),
        phone(selector_corto(), "sheet", step=2, mark=MQ, cap="6 opciones, «Ingresos» fuera"),
        phone(presupuesto_corto(more=False, widget_on=False).replace('class="grp chg"', 'class="grp"'), "sheet", step=3, mark=MQ,
              cap="«Comida» · S/ 600 · Alimentación")],
       ["Ataca F24 sin tocar datos", "Quitar «Ingresos» de un límite de gasto corrige un sinsentido"],
       ["Con cero registros no hay «más usadas»: el día 1 enseña las padres"],
       L(("B", "encuentra la suya"), ("B", "6 opciones"), ("B", "—"), ("B", "rápido"), ("B", "—"), ("M", "—"), ("B", "lista corta")),
       esf="S", riesgo="Bajo", conteo="6 opciones a la vista (hoy: 11 grupos y 62 subcategorías)")

H3 = A("H3", "Sugerir presupuestos con datos", "src",
       "Tras 2-4 semanas de registros, Yala propone un límite con lo que la persona <b>ya gasta</b>.",
       [phone(panel([balance(amount="−412", cents="80", note1="Gastaste S/ 412.80 este mes", note2="21 registros", out="412.80"), actions(),
                     notice("¿Le pones un límite a la comida?", "Gastas unos <b>S/ 540</b> al mes en Alimentación. Te avisamos antes de pasarte.",
                            tag="SUGERENCIA", cls="chg", btn_text="Poner S/ 600")]),
              "app", step=1, mark=MQ, label="3 semanas después", cap="La cifra sale de sus registros (aquí, ficticia)"),
        phone(presupuesto_corto(more=True), "sheet", step=2, mark=MQ, cap="El formulario llega relleno"),
        phone(panel([balance(amount="−412", cents="80", note1="Gastaste S/ 412.80 este mes", note2="21 registros", out="412.80"), actions(),
                     sec("Planificación", right=""), widget_comida(spent="402.30", pct=67)]), "app", step=3, mark=MQ, cap="En el Panel")],
       ["Usa datos reales; nada que configurar"],
       ["No ayuda el día 1", "El cálculo debe aguantar fechas y monedas: es cálculo financiero"],
       L(("B", "con sus datos"), ("M", "no ayuda el día 1"), ("B", "—"), ("M", "espera semanas"), ("B", "—"), ("M", "cálculo con monedas"), ("B", "1 toque")),
       esf="M", riesgo="Medio-alto: cálculo financiero", conteo="1 toque, después de 2-4 semanas",
       estado=[("nov", "S/ 540 es un ejemplo ficticio; el cálculo necesita review adversarial")])

H4 = A("H4", "Opciones avanzadas plegadas", "src",
       "A la vista: nombre, importe y «¿Qué gastos cuenta?». Período, alertas y filtros, en <b>«Más opciones»</b>. «Mostrar en el Panel» viene encendido para el primer presupuesto (F17).",
       [phone(presupuesto_corto(), "sheet", step=1, mark=MQ, cap="Formulario corto"),
        phone(sheet_top("Nuevo presupuesto", right_on=True) + group(row("Comida", "", icon="edit", color="#a5a6ff", chev=False))
              + f'<div class="lrow" style="background:#1c1c22;border-radius:12px;margin-top:8px">{ic("chev-u", 12)}<div class="lt"><span>Más opciones</span></div></div>'
              + sh_sec("Período") + seg(["Semanal", "Mensual", "Anual", "Único"], 1) + toggle_row("Activo", True)
              + sh_sec("Alertas") + toggle_row("Avisarme al llegar al 80 %", False)
              + sh_sec("Filtros") + group(row("Cuentas", "Todas"), row("Etiquetas", "Ninguna"), row("Necesidad del gasto", "Todas")),
              "sheet", step=2, mark=MQ, cap="Lo avanzado sigue ahí, plegado")],
       ["Formulario corto para el primero", "No quita nada"],
       ["Quien usa filtros los encuentra un toque más abajo"],
       L(("B", "—"), ("B", "formulario corto"), ("B", "—"), ("B", "lo avanzado sigue ahí"), ("B", "—"), ("M", "—"), ("B", "menos campos")),
       esf="S", riesgo="Bajo", conteo="4 bloques a la vista (hoy, 8)")

H5 = A("H5", "Presupuesto por tipo de gasto", "src",
       "En vez de categorías: <b>Esencial · Prioritario · Opcional</b>. Las subcategorías ya traen ese dato sembrado.",
       [phone(sheet_top("Nuevo presupuesto", right=None) + head("target", "¿Qué tipo de gasto quieres limitar?", "")
              + '<div class="chg">' + group(opt("home", "Esencial", "Comida, alquiler, servicios, transporte", checked=True, color="#22b35e", cls="tap"),
                                           opt("star", "Prioritario", "Salud, educación, deudas", color="#3b82f6"),
                                           opt("sparkle", "Opcional", "Salidas, compras, suscripciones", color="#ec4899")) + '</div>',
              "sheet", step=1, mark=MQ, cap="Tres opciones en vez de 62"),
        phone(sheet_top("Esenciales", right_on=True) + '<div class="fld big" style="margin-top:10px;background:#1c1c22"><span class="funit">S/ al mes</span><span class="fv">600</span></div>'
              + note('<b style="color:#fff">Ojo:</b> «Esencial» incluye el alquiler (S/ 900). Con S/ 600 te pasarías el día 5.', cls="chg"),
              "sheet", step=2, mark=MQ, cap="El caso de Ana no encaja: la comida va junto al alquiler")],
       ["Tres opciones en vez de 62", "Enseña a pensar el gasto"],
       ["Concepto nuevo para P2", "Hay que explicar qué cae en cada una", "<b>No sirve para «solo comida»</b>"],
       L(("M", "no es como su hoja"), ("M", "concepto nuevo"), ("B", "—"), ("M", "—"), ("B", "—"), ("M", "—"), ("B", "3 opciones")),
       esf="M", riesgo="Medio", conteo="3 opciones")

PRESUPUESTO = dict(
    slug="06-crear-presupuesto", num=6, titulo="Crear un presupuesto", corto="Presupuesto",
    problema="Al elegir categorías salen <b>11 grupos y 62 subcategorías</b>, «Ingresos» incluido, y el formulario enseña todo a la vez.",
    fricciones="F24 62 subcategorías · F16 formulario completo · F17 widget apagado",
    caso="Ana quiere gastar como mucho <b>S/ 600 al mes en comida</b>.",
    hoy=[(C + "21-planificacion.jpg", "Pestaña Planificación"), (C + "22-nuevo-presupuesto.jpg", "Todo el formulario a la vez"),
         (C + "23-presupuesto-elegir.jpg", "11 grupos, «Ingresos» incluido"), (C + "24-presupuesto-subcats.jpg", "Cada grupo despliega sus subcategorías")],
    hoy_nota="Capturas del 6-nov (no se repitieron esta noche: el código del editor no cambió en 2.3 desde entonces).",
    hoy_lens=L(("M", "ya tiene su lista"), ("A", "62 opciones"), ("B", "no presupuesta"), ("M", "quiere elegir rápido"), ("B", "—"), ("M", "—"),
               ("A", "lista larga con texto grande")),
    alts=[H1, H2, H3, H4, H5],
    decide=dict(pregunta="¿El primer presupuesto se crea con una sola cifra (H1) o con categoría pero con menos ruido (H2 + H4)?",
                ejes=["<b>H2 y H4 se suman</b> y no cambian datos: son el arreglo directo de F24, F16 y F17.",
                      "<b>H1 es el más rápido</b> pero no cumple «solo comida» sin editar.",
                      "<b>H3 y H5 son para después</b>: H3 necesita semanas de datos y un cálculo revisado; H5 es un concepto nuevo."]),
)

# =============================================================== 7. PAGO PLANIFICADO
def pagos_lista(cls="chg"):
    return (nav_title("Planificación") + chips(["Presupuestos", "Pagos planificados"], selected=("Pagos planificados",))
            + '<div class="mini" style="margin:10px 2px 4px">Te falta pagar este mes</div><div class="bamt" style="font-size:24px"><small>S/</small>900<small>.00</small></div>'
            + f'<div class="{cls}" style="margin-top:8px">' + group(f'<div class="lrow">{cat("Hogar", 26)}<div class="lt"><span>Alquiler</span><small>Cada mes · día 5 · te avisamos un día antes</small></div><span class="lr">S/ 900</span></div>') + '</div>'
            + tabbar("Planificación"))


G1 = A("G1", "Plantillas de pagos comunes", "src",
       "Alquiler, Luz, Agua, Celular, Internet, Streaming: cada una trae categoría e ícono; <b>solo pide importe y día</b>.",
       [phone(sheet_top("Nuevo pago planificado", right=None) + head(None, "¿Qué pagas cada mes?", "Elige uno o crea el tuyo.")
              + '<div class="tile3 chg">' + "".join(
                  f'<div class="tile{" tap" if n == "Alquiler" else ""}">{tint(i, c, 28)}<span>{n}</span></div>' for n, i, c in
                  [("Alquiler", "home", "#64748b"), ("Luz", "bolt", "#eab308"), ("Agua", "drop", "#0ea5e9"), ("Celular", "phone", "#a855f7"),
                   ("Internet", "wifi", "#3b82f6"), ("Streaming", "play", "#ec4899")]) + '</div>'
              + group(row("Otro pago", "", icon="plus", color="#a5a6ff"), cls="").replace('class="grp "', 'class="grp" style="margin-top:10px"'),
              "sheet", step=1, mark=MQ, cap="Toca «Alquiler»"),
        phone(sheet_top("Alquiler", right_on=True).replace('class="circ d on"', 'class="circ d on tap"')
              + '<div class="center" style="margin:6px 0">' + cat("Hogar", 40) + '</div>'
              + '<div class="fld big" style="background:#1c1c22"><span class="funit">S/</span><span class="fv">900</span></div>'
              + group(row("Día del mes", "5", icon="calendar", color="#64748b"), row("Avisarme", "1 día antes", icon="bell", color="#f59e0b")),
              "sheet", step=2, mark=MQ, cap="Solo importe y día"),
        phone(pagos_lista(), "app", step=3, mark=MQ, cap="Agendado")],
       ["Responde «¿qué es un pago planificado?» con ejemplos", "2 campos"],
       ["Plantillas por país e idioma"],
       L(("B", "—"), ("B", "ejemplos que reconoce"), ("B", "—"), ("B", "—"), ("B", "—"), ("M", "¿y en dólares?"), ("B", "botones grandes")),
       esf="S-M", riesgo="Bajo", conteo="2 campos (hoy, 8)")

G2 = A("G2", "Formulario mínimo", "src",
       "Nombre, importe y día del mes. Tipo, cuenta, frecuencia y fecha de inicio en <b>«Más opciones»</b>, con valores por defecto.",
       [phone(sheet_top("Nuevo pago planificado", right_on=True).replace('class="circ d on"', 'class="circ d on tap"')
              + group(row("Alquiler", "", icon="edit", color="#a5a6ff", chev=False))
              + '<div class="fld big" style="margin-top:8px;background:#1c1c22"><span class="funit">S/</span><span class="fv">900</span></div>'
              + group(row("Día del mes", "5", icon="calendar", color="#64748b")).replace('class="grp "', 'class="grp" style="margin-top:8px"')
              + f'<div class="lrow chg" style="background:#1c1c22;border-radius:12px;margin-top:8px">{ic("chev-d", 12)}<div class="lt"><span>Más opciones</span><small>Gasto · Mi dinero Soles · cada mes · desde hoy</small></div></div>',
              "sheet", step=1, mark=MQ, cap="Tres campos; lo demás, con valores por defecto"),
        phone(pagos_lista(), "app", step=2, mark=MQ, cap="Agendado")],
       ["Una sola pantalla", "L10-4 ya reordenó el formulario"],
       ["Quien paga cada 2 meses lo busca más abajo", "Sin ejemplos, «pago planificado» sigue sin explicarse"],
       L(("B", "—"), ("M", "¿qué es un pago planificado?"), ("B", "—"), ("B", "—"), ("B", "—"), ("M", "la moneda queda plegada"), ("B", "menos campos")),
       esf="S", riesgo="Bajo", conteo="3 campos (hoy, 8)")

G3 = A("G3", "Detectar los gastos que se repiten", "src",
       "Tras dos meses con el mismo gasto, Yala pregunta si se repite y ofrece avisar antes.",
       [phone(panel([balance(), actions(),
                     notice("¿El alquiler se repite cada mes?", "Pagaste «Alquiler» S/ 900 el 5 de octubre y el 5 de noviembre. ¿Te avisamos antes del próximo?",
                            tag="SUGERENCIA", cls="chg", btn_text="Sí, avísame"),
                     sec("Últimos registros", right=""), rec("Alquiler", "Hogar", "900.00", "5 nov")]),
              "app", step=1, mark=MQ, label="Dos meses después", cap="Yala lo detecta en sus registros"),
        phone(pagos_lista(), "app", step=2, mark=MQ, cap="Agendado con 1 toque")],
       ["Nada que configurar"],
       ["No ayuda el día 1", "Falsos positivos"],
       L(("M", "espera 2 meses"), ("B", "nada que hacer"), ("B", "—"), ("M", "lo quiere ya"), ("B", "—"), ("M", "—"), ("B", "1 toque")),
       esf="M", riesgo="Medio: heurística sobre registros", conteo="1 toque, después de 2 meses")

G4 = A("G4", "«¿Se repite?» al registrar", "src",
       "Hacer <b>visible</b> en el formulario de registro el paso a pago planificado que ya existe.",
       [phone(registro_sheet("Alquiler", "900.00", "Hogar",
                             extra=group(toggle_row("Se repite cada mes", True, "Día 5 · te avisamos un día antes")).replace('class="grp "', 'class="grp chg" style="margin-top:8px;padding:0 10px"')),
              "sheet", step=1, mark=MQ, cap="Al anotar el alquiler, lo marca como repetido"),
        phone(pagos_lista() + toast("Agendado: te avisamos el 4 de diciembre", cls="chg"), "app", step=2, mark=MQ, cap="Queda en Pagos planificados")],
       ["Aparece en el momento justo", "Ya existe en el código"],
       ["El formulario de registro ya es largo"],
       L(("M", "—"), ("B", "en el momento justo"), ("M", "formulario más largo"), ("B", "—"), ("B", "—"), ("M", "—"), ("M", "formulario largo")),
       esf="S", riesgo="Bajo", conteo="1 interruptor dentro del registro")

PAGO = dict(
    slug="07-crear-pago", num=7, titulo="Crear un pago planificado", corto="Pago planificado",
    problema="Para «avísame del alquiler el 5», el formulario pide <b>ocho campos</b>, categoría con 62 opciones incluida.",
    fricciones="F18 formulario largo",
    caso="Ana paga <b>S/ 900 de alquiler el día 5</b> de cada mes.",
    hoy=[(C + "25-pagos-planificados.jpg", "Planificación › Pagos planificados"), (C + "26-nuevo-pago.jpg", "Tipo, nombre, importe, categoría, cuenta, frecuencia, día, fecha")],
    hoy_nota="Capturas del 6-nov.",
    hoy_lens=L(("M", "—"), ("M", "—"), ("B", "—"), ("B", "—"), ("B", "—"), ("M", "—"), ("M", "—")),
    alts=[G1, G2, G3, G4],
    decide=dict(pregunta="¿El primer pago se crea desde ejemplos (G1) o desde un formulario mínimo (G2)? ¿Se suma la detección (G3) o el interruptor en el registro (G4)?",
                ejes=["<b>G1 y G2 son compatibles</b>: la plantilla abre el formulario mínimo.",
                      "<b>G4 ya existe</b> en el código: es hacerlo visible.",
                      "<b>G3 no ayuda el día 1</b> y puede equivocarse: es un extra, no la puerta."]),
)

# =============================================================== 8. DÓNDE SE ENCUENTRAN LAS ACCIONES
def panel_scrolled(fab_btn=False, tap_fab=False):
    h = (ptop("Panel de Ana") + sec("Tendencias", right="") + widget("Saldo", chart(single=True, height=50))
         + sec("Planificación", right="") + '<div class="wrow">' + widget("Pagos planificados", empty("calendar", "Sin pagos próximos"))
         + widget("Presupuestos", empty("calendar", "Aún no tienes presupuestos")) + '</div>')
    h += tabbar(shrink=True)
    if fab_btn:
        h += fab("tap chg" if tap_fab else "")
    return h


X1 = A("X1", "Un «+» que crea cualquier cosa (E2)", "src",
       "El «+» flotante del Panel abre el menú de crear. Es E2 de la parte 5, mirado desde el presupuesto.",
       [phone(panel_scrolled(fab_btn=True, tap_fab=True), "app", step=1, mark=MQ, cap="Con la barra encogida, el «+» sigue ahí"),
        phone(panel_scrolled(fab_btn=True) + dim() + menu([("plus", "Registro"), ("card", "Cuenta"), ("calendar", "Presupuesto"), ("repeat", "Pago planificado")], cls="chg"),
              "app", step=2, mark=MQ, cap="Elige «Presupuesto»"),
        phone(presupuesto_corto(tap=False).replace('class="lrow chg"', 'class="lrow"').replace('class="grp chg"', 'class="grp"'), "sheet", step=3, mark=MQ, cap="Editor de presupuesto")],
       ["Un solo sitio para crear", "No depende del nombre de la pestaña"],
       ["Un toque más para registrar", "En iPad el «+» vive en otra parte"],
       L(("B", "—"), ("B", "un sitio para crear"), ("M", "un toque más para registrar"), ("B", "—"), ("M", "—"), ("B", "—"), ("M", "menú pequeño")),
       esf="M", riesgo="Medio", conteo="2 toques del Panel al editor")

X2 = A("X2", "El botón está en el vacío (C2)", "src",
       "Cada sección vacía del Panel trae su botón. Es C2 de la parte 3, mirado desde el presupuesto.",
       [phone(ptop("Panel de Ana") + sec("Planificación", right="")
              + '<div class="wrow">' + widget("Pagos planificados", empty("calendar", "¿Pagas algo cada mes?", action="Agregar"))
              + widget("Presupuestos", empty("calendar", "Ponle un límite a tus gastos", action="Crear").replace('class="btn pri sm"', 'class="btn pri sm tap"'), cls="chg") + '</div>'
              + tabbar(shrink=True), "app", step=1, mark=MQ, cap="Desplaza hasta Planificación y toca el botón"),
        phone(presupuesto_corto(tap=False).replace('class="lrow chg"', 'class="lrow"').replace('class="grp chg"', 'class="grp"'), "sheet", step=2, mark=MQ, cap="Editor de presupuesto")],
       ["El botón está donde se nota la falta"],
       ["Hay que desplazar hasta la sección", "Desaparece cuando ya hay uno: el segundo se crea en otra parte"],
       L(("B", "—"), ("B", "lo ve donde falta"), ("B", "—"), ("B", "—"), ("M", "—"), ("M", "—"), ("M", "desplazar con texto grande")),
       esf="S", riesgo="Bajo", conteo="1 toque (tras desplazar)")

X3 = A("X3", "Pestaña con nombre explícito y barra fija al principio", "new",
       "La pestaña «Planificación» pasa a llamarse <b>«Presupuestos»</b> y, los primeros días, la barra no se encoge al desplazar.",
       [phone(ptop() + balance() + actions() + sec("Tus finanzas", right="") + acc_chips()
              + tabbar("Panel", labels=("Panel", "Estadísticas", "Presupuestos", "Más", "Buscar"), cls="chg", tap="Presupuestos"),
              "app", step=1, mark=NEW, cap="La barra dice «Presupuestos» y no se esconde"),
        phone(nav_title("Presupuestos") + chips(["Presupuestos", "Pagos planificados"], selected=("Presupuestos",))
              + empty("calendar", "Aún no tienes presupuestos", "Un presupuesto es el máximo que quieres gastar en algo.", action="Nuevo presupuesto").replace('class="btn pri sm"', 'class="btn pri sm tap"')
              + tabbar("Presupuestos", labels=("Panel", "Estadísticas", "Presupuestos", "Más", "Buscar")), "app", step=2, mark=NEW, cap="Misma pantalla de hoy, con otro nombre"),
        phone(presupuesto_corto(tap=False).replace('class="lrow chg"', 'class="lrow"').replace('class="grp chg"', 'class="grp"'), "sheet", step=3, mark=NEW, cap="Editor de presupuesto")],
       ["La barra dice lo que hay dentro (F20)", "No añade botones"],
       ["Los pagos planificados quedan bajo «Presupuestos»", "Renombrar en 16 idiomas", "Que la barra se encoja al desplazar es el comportamiento de iOS 26: fijarla es ir contra el sistema"],
       L(("B", "—"), ("B", "dice lo que hay"), ("B", "—"), ("B", "—"), ("M", "—"), ("M", "—"), ("B", "barra siempre visible")),
       esf="S", riesgo="Bajo", conteo="2 toques del Panel al editor (como hoy)",
       estado=[("hip", "Que «Presupuestos» se entienda mejor que «Planificación» es hipótesis de esta guía")])

X4 = A("X4", "Buscar entiende acciones", "new",
       "Al escribir «presu» en Buscar, lo primero que sale es <b>«Crear presupuesto»</b>, antes que los registros.",
       [phone(panel_scrolled().replace('<div class="tabsearch">', '<div class="tabsearch tap">'), "app", step=1, mark=NEW, cap="Toca Buscar"),
        phone(f'<div class="srch">{ic("search", 13)}<span>presu</span></div>' + sh_sec("Acciones")
              + group(row("Crear presupuesto", "", icon="plus", color="#5b5cf0", cls="tap"), row("Ver presupuestos", "", icon="calendar", color="#64748b"), cls="chg")
              + sh_sec("Registros") + '<div class="mini">Sin resultados</div>'
              + '<div class="kbd"><span>q</span><span>w</span><span>e</span><span>a</span><span>s</span><span>d</span><span>z</span><span>x</span><span>c</span></div>',
              "app", step=2, mark=NEW, cap="«Crear presupuesto» sale primero"),
        phone(presupuesto_corto(tap=False).replace('class="lrow chg"', 'class="lrow"').replace('class="grp chg"', 'class="grp"'), "sheet", step=3, mark=NEW, cap="Editor de presupuesto")],
       ["Sirve para cualquier acción, también las avanzadas", "No cambia ninguna pantalla"],
       ["Hay que saber la palabra", "Escribir cuesta más que tocar"],
       L(("M", "—"), ("M", "tiene que saber la palabra"), ("B", "—"), ("B", "atajo"), ("M", "—"), ("M", "—"), ("M", "escribir")),
       esf="S-M", riesgo="Bajo", conteo="3 toques y escribir",
       estado=[("nov", "No se miró qué devuelve hoy Buscar al escribir «presupuesto»")])

DONDE = dict(
    slug="08-donde-crear", num=8, titulo="Dónde se encuentran las acciones", corto="Dónde crear",
    problema="Presupuestos y pagos viven en una pestaña llamada <b>«Planificación»</b> que desaparece al desplazar el Panel, y los widgets vacíos no tienen botón.",
    fricciones="F11 vacíos sin acción · F19 crear cuenta · F20 «Planificación» y barra encogida",
    caso="Desde el Panel, Ana busca <b>dónde crear su presupuesto</b> de comida.",
    hoy=[(C + "12-primer-panel.jpg", "Barra completa al entrar"), (C + "16-panel-primeros-pasos-y-cuentas.jpg", "Al desplazar, la barra queda en Panel y Buscar"),
         (C + "19-panel-widgets-vacios.jpg", "«Aún no tienes presupuestos», sin botón"), (C + "21-planificacion.jpg", "El botón está en otra pestaña")],
    hoy_nota="Capturas del 6-nov; la barra encogida y los vacíos sin botón se vieron igual esta noche en la build de 2.3.",
    hoy_lens=L(("M", "—"), ("A", "«Planificación» no dice «presupuestos»"), ("B", "—"), ("B", "—"), ("M", "—"), ("M", "—"), ("M", "barra que desaparece")),
    alts=[X1, X2, X3, X4],
    decide=dict(pregunta="¿Dónde se crea: en un sitio único (X1), donde se nota la falta (X2), con una pestaña que diga lo que es (X3) o buscando (X4)?",
                ejes=["<b>La revisión no traía alternativas propias</b> para esta parte: X1 y X2 vienen de E2 y C2; X3 y X4 son propuestas nuevas de esta guía.",
                      "<b>X2 + X3</b> no añaden gestos nuevos; <b>X1</b> sí, y decide a la vez cuenta, presupuesto y pago.",
                      "<b>X4</b> es complementaria: no sustituye a ninguna."]),
)
