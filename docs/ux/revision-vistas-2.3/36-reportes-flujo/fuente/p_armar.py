"""Problema 3: el plan vive escondido y armarlo pide revisar 18 líneas en cinco pantallas de scroll."""
from ui import ic, cat, tabbar
from est import card
from flujo import rtop, screen, secthead


def _row(name, catname, sub, amt, on=True):
    chk = f'<span class="okc">{ic("check", 9, sw=3)}</span>' if on else '<span class="okc off"></span>'
    return (f'<div class="crow">{chk}{cat(catname, 22)}<div class="ct"><b>{name}</b><small>{sub}</small></div>'
            f'<div class="cr"><span class="ca"><small>S/</small>{amt}</span></div></div>')


def _start(cls=""):
    return (f'<div class="cfhero {cls}"><span class="ecap">¿Con cuánto empiezas?</span>'
            f'<div class="eamt"><small>S/</small>73,356<small>.70</small></div>'
            f'<div class="cfl">Lo que tienes hoy en tus 2 cuentas · <em>Cambiar el monto</em></div></div>')


def _summary(cls=""):
    return (f'<div class="ecard {cls}"><div class="rowkv"><span>Ingresos al mes</span><b>S/ 8,500.00</b></div>'
            f'<div class="rowkv"><span>Gastos al mes</span><b>S/ 7,912.82</b></div>'
            f'<div class="rowkv"><span><b>Te sobran al mes</b></span><b>S/ 587.18</b></div></div>')


def _btn(text="Crear mi plan", cls=""):
    return f'<div class="btn pri {cls}" style="margin:4px 0 8px">{ic("plus", 11, sw=2.6)}{text}</div>'


A = {
    "code": "A", "titulo": "Primero el resultado y «Crear mi plan»; las 18 líneas, plegadas",
    "que": ("La pantalla de armar abre con <b>lo que el plan te deja al mes</b> y el botón «Crear mi plan» a la vista. "
            "Las líneas sugeridas van plegadas en tres grupos con su total («Lo que entra · 1 de 2», «Gastos fijos · 13», "
            "«Gastos que cambian · 20»). Quien quiere revisar despliega; quien no, crea en un toque."),
    "screens": [
        screen(rtop(plan=False) + _start() + _summary(cls="chg") + _btn(cls="chg") +
               '<div class="ecard clist chg">' +
               '<div class="crow"><div class="ct"><b>Lo que entra · 1 de 2</b><small>Salario S/ 8,500 · Facturación (sin marcar)</small></div><span class="chv">' + ic("chev-r", 10) + '</span></div>'
               '<div class="crow"><div class="ct"><b>Gastos fijos · 13</b><small>Alquiler, Supermercados, Delivery…</small></div><span class="chv">' + ic("chev-r", 10) + '</span></div>'
               '<div class="crow"><div class="ct"><b>Gastos que cambian · 20</b><small>Restaurantes, Combustible… como promedio</small></div><span class="chv">' + ic("chev-r", 10) + '</span></div></div>',
               cap="Todo lo que decide, en una pantalla.", step=1),
        screen(rtop(small=True, plan=False) + secthead("Gastos fijos · 13", "6,280.00") +
               '<div class="ecard clist">' +
               _row("Alquiler o hipoteca", "Hogar", "Promedio de 6 meses", "2,200") +
               _row("Supermercados y bodegas", "Alimentación", "Promedio de 6 meses", "1,760") +
               _row("Delivery", "Alimentación", "Promedio de 6 meses", "339") +
               _row("Servicios del hogar", "Servicios", "Promedio de 5 meses", "234") + '</div>' +
               '<div class="note2">Toca una fila para cambiar cómo se calcula.</div>',
               cap="Desplegar un grupo, solo si quiere revisar.", step=2),
    ],
    "pros": ["Crear el plan pasa de cinco pantallas de scroll a un toque.",
             "El resumen (lo que te sobra) se ve antes de decidir, no al final.",
             "Los grupos ya existen en el código («Gastos que cambian»): se extiende a los fijos."],
    "contras": ["Quien quería revisar línea a línea da un toque más por grupo.",
                "Crear sin mirar puede dejar líneas que no esperaba (se corrigen después en el mes)."],
    "conteo": "1 toque para crear; +1 por grupo para revisar", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("M", "quiere ver todas las líneas"), "P2": ("B", "una cifra y un botón"), "P3": ("B", "un toque"),
             "P4": ("B", "despliega lo que le importa"), "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("B", "menos scroll")},
}

B = {
    "code": "B", "titulo": "Armar en tres pasos cortos: con cuánto empiezas, lo que entra, lo que sale",
    "que": ("Un asistente de tres pantallas con «Paso 1 de 3». Cada paso tiene pocas filas y su botón «Siguiente». "
            "El último enseña el resumen y «Crear mi plan»."),
    "screens": [
        screen(rtop(small=True, plan=False) + '<div class="pill2 chg">Paso 1 de 3</div>' + _start() +
               '<div class="note2">Usamos el saldo de tus cuentas de hoy. Puedes cambiarlo.</div>' + _btn("Siguiente", cls="chg"),
               cap="Paso 1: con cuánto empiezas.", step=1),
        screen(rtop(small=True, plan=False) + '<div class="pill2 chg">Paso 2 de 3</div>' + secthead("Lo que entra", "8,500.00") +
               '<div class="ecard clist">' + _row("Salario", "Ingresos", "Promedio de 6 meses", "8,500") +
               _row("Facturación y freelance", "Ingresos", "Solo 3 meses de actividad", "2,264", on=False) + '</div>' +
               _btn("Siguiente", cls="chg"),
               cap="Paso 2: lo que entra.", step=2),
        screen(rtop(small=True, plan=False) + '<div class="pill2 chg">Paso 3 de 3</div>' + secthead("Lo que sale", "7,912.82") +
               '<div class="ecard clist">' + _row("Alquiler o hipoteca", "Hogar", "Pago planificado", "2,200") +
               _row("Supermercados y bodegas", "Alimentación", "Promedio de 6 meses", "1,760") +
               '<div class="crow"><div class="ct"><b>+ 11 fijos y 20 que cambian</b><small>Ver todos</small></div></div></div>' +
               _summary() + _btn(cls="chg"),
               cap="Paso 3: lo que sale y el resumen.", step=3),
    ],
    "pros": ["Cada pantalla tiene una sola pregunta: menos carga para quien no sabe qué es un flujo de caja.",
             "El progreso «Paso N de 3» dice cuánto falta.",
             "Separa el saldo inicial, que hoy pasa desapercibido arriba."],
    "contras": ["Tres pantallas y tres toques para lo que hoy es una (larga).",
                "Más código: un flujo nuevo con su vuelta atrás."],
    "conteo": "3 toques", "esf": "medio-alto", "riesgo": "medio",
    "lens": {"P1": ("M", "más pasos"), "P2": ("B", "una pregunta por pantalla"), "P3": ("M", "tres toques"),
             "P4": ("A", "asistente que no puede saltarse"), "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("B", "pantallas cortas")},
}

C = {
    "code": "C", "titulo": "«Flujo de caja» pasa a Planificación, junto a Presupuestos y Pagos",
    "que": ("El plan se encuentra donde vive lo demás que se planifica: un tercer chip «Flujo de caja» en Planificación "
            "(hoy: Presupuestos · Pagos planificados). Reportes se queda con la Comparativa. El enlace de «Ver proyectado» "
            "lleva al mismo sitio."),
    "screens": [
        screen(f'<div class="etop"><span class="sp"></span><span class="avatar">{ic("user", 13)}</span></div>'
               f'<h1 class="etitle">Planificación</h1>'
               f'<div class="rchips chg"><span class="rchip">Presupuestos</span><span class="rchip">Pagos</span>'
               f'<span class="rchip on">{ic("swap", 11)}Flujo de caja</span></div>' + _start() + _summary() + _btn(),
               cap="En Planificación, a la vista en la barra.", step=1, tabactive="Planificación"),
    ],
    "pros": ["Pasa de «Más › Reportes › chip» (oculto por defecto) a una pestaña que la barra ya tiene.",
             "Agrupa las tres herramientas de mirar hacia adelante.",
             "Reportes queda con una sola cosa y se puede renombrar a «Comparativa»."],
    "contras": ["Mueve una pantalla de sitio: quien ya la usaba en Reportes la busca.",
                "Planificación tiene lista y detalle en iPad (<code>ListDetailSplit</code>): el flujo de caja tendría que encajar en ese molde."],
    "conteo": "1 toque a la pestaña + 1 al chip", "esf": "medio", "riesgo": "medio", "reabre": "Dónde vive Reportes",
    "lens": {"P1": ("B", "—"), "P2": ("B", "lo encuentra sin «Más»"), "P3": ("B", "—"), "P4": ("B", "donde lo espera"),
             "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("B", "—")},
}

D = {
    "code": "D", "titulo": "Los chips de Reportes dejan de flotar sobre el contenido",
    "que": ("Al desplazar, los chips «Comparativa · Flujo de caja» se quedan arriba con fondo propio (o suben con la "
            "página) y el contenido ya no pasa por debajo. Hoy se leen trozos («nar todo», el rótulo «Este mes te "
            "sobran») detrás de los chips. Cambio de pulido, independiente de las demás."),
    "screens": [
        screen(rtop(small=True, plan=True).replace('<div class="rchips">', '<div class="rchips chg" style="background:#17153a;padding:5px 0;margin:0">') +
               '<div class="cfhero"><span class="ecap">Este mes te sobran</span><div class="eamt"><small>S/</small>396<small>.18</small></div></div>' +
               secthead("Ingresos", "8,500.00"),
               cap="Los chips con fondo: nada se lee por detrás.", step=1),
    ],
    "pros": ["Quita un defecto visible en todas las pantallas de la zona.", "Esfuerzo bajo.", "No cambia ningún flujo."],
    "contras": ["No ayuda a encontrar el plan ni a armarlo: es pulido.", "Un fondo sólido rompe el cristal de iOS 26 en ese borde."],
    "conteo": "—", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("B", "—"), "P3": ("B", "—"), "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("B", "—"),
             "P7": ("B", "texto grande: menos solape")},
}

ARMAR = {
    "slug": "13-encontrar-y-armar", "corto": "3 · Encontrar y armar el plan", "num": 3, "sev": "Media-alta",
    "titulo": "El plan vive escondido y armarlo pide revisar 18 líneas en cinco pantallas de scroll",
    "problema": ("Con la barra por defecto (Panel · Estadísticas · Planificación), Flujo de caja está en <b>Más › "
                 "Reportes</b>, bajo el título «Reportes financieros», o tras el enlace bajo «Ver proyectado». La pantalla "
                 "de armar el plan enseña 18 líneas pre-marcadas, cada una con «Basado en 6 meses de actividad», y el "
                 "resumen y «Crear mi plan» quedan <b>cinco desplazamientos</b> más abajo. Mientras se desplaza, el "
                 "contenido pasa por debajo de los chips «Comparativa · Flujo de caja» y se leen trozos («nar todo», "
                 "«Streaming y…»). El ticket del flujo proyectado lo dice: «casi nadie lo usa y es difícil de configurar»."),
    "hoy": [("capturas/c02-setup-arriba.jpg", "Armar el plan: arriba."),
            ("capturas/c03-setup-scroll1.jpg", "Primer desplazamiento: «nar todo» bajo los chips."),
            ("capturas/c05-setup-scroll3.jpg", "Tercer desplazamiento: aún líneas."),
            ("capturas/c07-setup-fin.jpg", "Al fondo: el resumen y «Crear mi plan»."),
            ("capturas/c11-mes-arriba.jpg", "Ya creado: el rótulo del mes, tapado por los chips.")],
    "hoy_conteo": "Más → Flujo de caja (2 toques) + 5 desplazamientos + «Crear mi plan»",
    "evid": [("obs", "Capturas del 7-nov, semilla «realista», iPhone 17 Pro."),
             ("cod", "<code>TabBarConfiguration</code>: barra por defecto <code>[.panel, .statistics, .planning]</code>; "
                     "Reportes vive en «Más» (<code>MoreView</code>, sección «Reportes»)."),
             ("cod", "<code>FinancialReportView</code>: los chips van en un <code>safeAreaInset</code> sobre el scroll."),
             ("cod", "Ticket <code>flujo-proyectado-en-tendencias-y-panel</code>, «Siguiente paso, aparte»: la nota de "
                     "Jürgen del 6-nov sobre lo difícil que es configurarlo."),
             ("hip", "Cuánta gente llega a armar el plan no se sabe: no hay medición de uso.")],
    "alts": [A, B, C, D],
    "reco": ("A + D",
             "A ataca lo que más cuesta (llegar al botón) sin quitar la posibilidad de revisar; D quita un defecto visible "
             "en toda la zona con poco esfuerzo. C es la mejor respuesta a «dónde está», pero mueve una pantalla de sitio y "
             "choca con el molde de lista y detalle del iPad: conviene decidirla aparte. B alarga el camino para P3 y P4."),
    "hoy_lens": {"P1": ("M", "revisa todo, pero largo"), "P2": ("A", "no sabe qué revisar"), "P3": ("A", "no llega al botón"),
                 "P4": ("M", "lo busca en Planificación"), "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("A", "más scroll aún")},
    "decide": ["¿«Crear mi plan» y el resumen arriba, con las líneas plegadas por grupos (A)?",
               "¿Flujo de caja se muda a Planificación (C)? Reabre dónde vive Reportes.",
               "¿Los chips de Reportes con fondo propio para que nada pase por debajo (D)?"],
}
