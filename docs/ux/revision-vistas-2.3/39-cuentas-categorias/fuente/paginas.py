"""Páginas de contexto de la zona 39: índice, estado actual vista a vista, y revisión (perfiles, eficiencia, secundarios)."""
import os
import re
from ui import shot
from cta import CASO

NIV = {"A": "riesgo alto", "M": "riesgo medio", "B": "riesgo bajo", "N": "no aplica"}
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FECHA = "9-nov-2026"


def _tag(kind, text):
    return f'<span class="tag {kind}">{text}</span>'


def _strip(screens, cls=""):
    return f'<div class="strip {cls}">{"".join(screens)}</div>' + (f'<p class="swipe noprint">Desliza para ver las {len(screens)} pantallas →</p>' if len(screens) > 1 else '')


def _ipad(src, cap, m):
    return (f'<figure class="ph ipadf"><div class="plabel"><span></span><span class="pmark obs">{m}</span></div>'
            f'<img src="{src}" alt="{re.sub("<[^>]+>", "", cap)}" loading="lazy"><div class="cap"><span>{cap}</span></div></figure>')


def _shots(items, prefix="capturas/"):
    out = []
    for f, c, m in items:
        if not os.path.exists(os.path.join(HERE, "capturas", f)):
            raise SystemExit(f"falta la captura {f}")
        out.append(_ipad(prefix + f, c, m) if f.startswith("ipad-") else shot(prefix + f, cap=c, mark=("obs", m)))
    return out


# (vista, qué es, estados con captura, problemas)
VISTAS = [
    ("AccountsSettingsListView", "Ajustes › Cuentas: activas (con sus líneas en otra divisa), Sistema y Archivadas; ↑↓ para reordenar y «+».",
     "con 4 cuentas, reordenar, sin Pro, tras archivar, con número de cuenta, AX3, iPad", "1, 5"),
    ("AccountFormView", "Crear y editar una cuenta: nombre, tipo, número, moneda, otras divisas, tarjeta (corte, pago, aviso), saldo y acciones.",
     "nueva, tarjeta, ahorros, saldo escrito, «¿Cómo lo corregimos?», archivar, oferta de línea, AX3", "1, 4, 5"),
    ("AdjustmentModeSelectorView", "La pantalla «Ajuste» con «Ajustar por registro» y «Cambiar saldo inicial». Solo se usa en el modo «Solo anotar mis gastos».",
     "leída en el código (no capturada: en el modo normal el saldo se edita en «Tu saldo»)", "4"),
    ("CategoriesSettingsListView", "Ajustes › Categorías: activas (A-Z), ocultas y Sistema; «Editar» para borrar; «+».",
     "con 11, editar, tras renombrar, vacía, con 210 registros (no se puede eliminar), AX3, iPad", "2, 3"),
    ("CategoryDetailView", "Una categoría: icono, nombre, «Usar al registrar», subcategorías y eliminar.",
     "Alimentación, nueva, sin subcategoría (alerta), renombrar, AX3", "2, 3, 7"),
    ("SubcategoryDetailView", "Una subcategoría: nombre, necesidad, «Usar al registrar» y eliminar.", "Restaurantes, nueva", "3, 7"),
    ("SubcategoryNeedSelectorView", "«Gastos por necesidad»: Esencial, Prioritaria, Opcional o Sin clasificación, con su explicación.", "Opcional elegida", "3"),
    ("TagsSettingsListView", "Ajustes › Etiquetas: activas e inactivas, ↑↓ y «+».", "con 5, reordenar, vacía, AX3", "7"),
    ("TagFormView", "Crear y editar una etiqueta: nombre (20), icono, color, estado y eliminar.", "editar, eliminar, nueva, nombre largo, AX3", "7"),
    ("CurrencySettingsView", "Moneda y tipo de cambio: principal, secundarias, tipos de cambio y «Ver todas».",
     "con USD y EUR, elegir principal, confirmar cambio, cambiando, secundarias, añadir una (tapada), ver todas, AX3", "6"),
]


def index_page(problemas, perfiles):
    filas = "".join(f'<tr><td><code>{v}</code></td><td>{q}</td><td>{e}</td><td>{p}</td></tr>' for v, q, e, p in VISTAS)
    cards = ""
    for p in problemas:
        code, _ = p["reco"]
        alt = next(a for a in p["alts"] if a["code"] == code)
        sev = "A" if p["sev"].startswith("Alta") else "M"
        cards += (f'<a class="idx-row vcard" href="{p["slug"]}.html" style="display:block;text-decoration:none;color:inherit">'
                  f'<div class="n">Problema {p["num"]} · <span class="sev {sev}">severidad {p["sev"].lower()}</span> · {len(p["alts"])} alternativas</div>'
                  f'<h4>{p["titulo"]}</h4><p>Recomendación: <b>{code} · {re.sub("<[^>]+>", "", alt["titulo"])}</b>.</p></a>')
    decs = "".join(f'<li><b>{p["corto"]}:</b> {p["decide"][0]}</li>' for p in problemas)
    body = f"""
<header class="ph-h"><div class="kicker">Revisión por vistas 2.3 · zona 39 · {FECHA}</div>
<h1 class="t">Cuentas, tarjetas, categorías, etiquetas y divisas</h1>
<p class="lead">Lo que se ordena en Ajustes: ajustar el saldo de una cuenta, archivar una tarjeta, reordenar y renombrar
categorías, crear una etiqueta y cambiar la moneda. También con texto grande y en el iPad. <b>No cambia la app y no elige:</b>
deja ocho problemas priorizados, de tres a cuatro alternativas maquetadas para cada uno y una recomendación. Decide Jürgen.</p>
<div class="case"><span class="ct">El caso</span><span>{CASO} <em style="color:var(--ink3)">Datos ficticios en las maquetas; en las capturas, las semillas de prueba de la app.</em></span></div>
</header>
<div class="kpis">
<div class="kpi"><b>4-5 pantallas</b><small>de desplazar hasta «Archivar» en una tarjeta; al archivarla, lo gastado con ella deja de sumar</small></div>
<div class="kpi"><b>0</b><small>formas de ordenar las categorías; Ajustes y el selector al registrar las ponen en órdenes distintos</small></div>
<div class="kpi"><b>12 toques</b><small>y una alerta para crear una categoría con tres subcategorías</small></div>
<div class="kpi"><b>AX3</b><small>con texto grande, Cuentas pierde los nombres y Etiquetas su última fila</small></div>
</div>
<h2 class="s">Los ocho problemas</h2>
<p class="sub">Numerados por el caso guía; cada uno dice su severidad (alta: 1, 2 y 8). Severidad = cuánto frena el caso × cuántos perfiles se traban × si cambia lo que suma. Cada página trae las capturas de hoy, las alternativas con maquetas, la comparación, la lente de perfiles, la recomendación y la decisión.</p>
<div class="idxgrid">{cards}</div>
<h2 class="s">Qué decide Jürgen (lo principal de cada uno)</h2><ul>{decs}</ul>
<p class="sub">Si hubiera que empezar por lo barato: la fila de cuentas con el nombre y «•••• 0019» (E1), la fila apilada con texto grande y el alto de las listas (H1 + H2), «registro de ajuste»
siempre preelegido y el teclado con «Listo» (D2), Guardar que dice lo que falta en una categoría nueva (C3), el nombre y el texto
de las monedas secundarias (F1 + F3) y los arreglos de Etiquetas (G3). Son cambios pequeños que no cierran la puerta a lo grande.</p>
<div class="callout"><b>Lo que ya decidiste y sigue sin hacer:</b> la opción A del 8-oct-2026 (archivar conserva el historial;
card «Archivar una cuenta…» en backlog 2.4), el rediseño de la lista de Cuentas del 3-oct (nombre siempre y número enmascarado;
card «Ajustes › Cuentas: lista clara…», backlog 2.4) y el rediseño del formulario de cuenta del 3-oct (ficha corta con «Más
opciones», archivar al fondo; solo está hecho «Editar el saldo»). Esta revisión se apoya en ellos: A1, E1 y E3 son esas decisiones
en pantalla. <b>Lo único que reabre algo:</b> A3 (acciones arriba, frente a «archivar al fondo») y G2 («Archivar» para todo, frente a
«Usar al registrar» de L7-11); por eso ninguna de las dos es la recomendada.</div>
<h2 class="s">Vistas cubiertas</h2>
<div class="tbl"><table class="cmp"><tr><th>Vista</th><th>Qué es</th><th>Estados con captura</th><th>Problemas</th></tr>{filas}</table></div>
<p class="sub" style="margin-top:10px"><b>Cargando:</b> todas leen en local y no tienen indicador; solo Moneda y tipo de cambio tapa la
pantalla mientras baja tipos de cambio (problema 6). <b>Error:</b> si una lectura falla, la lista queda vacía y el error va a un
registro de depuración (<code>CategoriesSettingsListViewModel.swift:86-93</code>, igual en cuentas y etiquetas); si no se puede contar lo
que tiene una categoría, no se borra nada y lo dice (<code>CategoryDetailView</code>, «countFailed»). <b>Sin conexión:</b> todo funciona
salvo los tipos de cambio: cambiar la moneda principal baja primero las tasas y, si falla, dice «No se pudo cambiar a USD · tus
registros siguen en PEN» (leído en <code>CurrencySettingsView.updatePreferredCurrency</code>; no medido en un iPhone en modo avión).
<b>Sin Pro:</b> el límite de cuentas del plan gratis lo enseña la lista con un aviso (<code>LimitReachedBanner</code>); con la semilla no se alcanzó.</p>
<h2 class="s">Cómo se hizo</h2>
<ul class="evl">
<li>{_tag("obs", "Captura")} Capturas del {FECHA} con la app de <code>origin/2.3</code> (Yala Dev, Debug), en un iPhone 17 Pro y un iPad Pro 13
simulados con iOS 27.2, creados para esta revisión y borrados al terminar. Las sacó un XCUITest temporal que no se publica
(<code>fuente/Revision39CapturasUITests.swift.txt</code>). Semillas de la app sin cambios: «tarjeta-dos-lineas» (Visa QA en soles con
línea en dólares, Ahorros QA, Dólares QA), «sin-registros», «realista» (dos años), «pesado» (diez años) y «sin-categorias».
Texto grande: AX3.</li>
<li>{_tag("obs", "Medido")} Tiempo de carga de Ajustes › Cuentas con la marca que la app ya trae (<code>PERF ajustes-cuentas</code>, solo en DEBUG), leída del registro del simulador con tres volúmenes de datos.</li>
<li>{_tag("src", "Código")} Lectura focalizada de las 10 vistas y de sus ViewModels, con fichero y línea.</li>
<li>{_tag("hip", "Perfiles")} Los siete perfiles de la revisión del usuario nuevo (PR 837), usados como lentes simuladas: no son entrevistas.
De esa revisión aplican aquí F6 (62 subcategorías sembradas sin preguntar) y F19 (crear una cuenta más); sus alternativas no se repiten.</li>
<li>{_tag("src", "Antes")} La auditoría UX 2.2 ya decidió en esta zona: «Editar el saldo» con «¿Cómo lo corregimos?» (L7-6), «Usar al registrar»
con su pie (L7-11), «No se puede eliminar · Ocultarla / Mover sus registros» (L7-10), «Eliminar» al fondo (L7-11), «Más opciones» al crear
una cuenta (L7-4), la confirmación del cambio de moneda con el antes y el después (L16-3) y la regla de archivar (3-oct). Y decidió sin hacer aún: archivar conserva el historial (8-oct, opción A), la lista de Cuentas con el nombre y el número enmascarado y la ficha corta del formulario (3-oct). Esta revisión parte de ahí.</li>
</ul>
<p class="foot">Fuente: <code>docs/ux/revision-vistas-2.3/39-cuentas-categorias/</code>. El generador está en <code>fuente/</code> (<code>python3 build.py</code>). PDF de respaldo: <code>revision-cuentas-categorias.pdf</code>.</p>
"""
    return "Cuentas y categorías · revisión por vistas", body, "Ocho problemas de cuentas, tarjetas, categorías, etiquetas y divisas, con alternativas maquetadas."


ESTADO = [
    ("Ajustes › Cuentas (AccountsSettingsListView)", "Semilla «tarjeta-dos-lineas».", [
        ("c07-lista-cuentas-pro.jpg", "Activas: la Visa con su línea en USD.", "Captura"),
        ("c02-lista-reordenar.jpg", "↑↓: se arrastran.", "Captura"),
        ("c18-lista-tras-archivar.jpg", "Tras archivar la Visa.", "Captura"),
        ("c17-lista-con-numero.jpg", "Una cuenta con número: sale el número.", "Captura"),
        ("ipad-c-cuentas.jpg", "iPad: Ajustes al lado de Cuentas.", "Captura iPad"),
        ("ipad-c08-form-ahorros.jpg", "iPad: la ficha, en una hoja centrada pequeña.", "Captura iPad")]),
    ("Crear y editar una cuenta (AccountFormView)", "", [
        ("c13-nueva-cuenta.jpg", "Nueva cuenta.", "Captura"),
        ("c15-saldo-cero.jpg", "Al crear: «Balance inicial» y «¿No sabes tu saldo?».", "Captura"),
        ("c16-tras-guardar.jpg", "Oferta de línea en otra divisa.", "Captura"),
        ("c03-form-tarjeta.jpg", "Editar la tarjeta.", "Captura"),
        ("c03-form-tarjeta-abajo-1.jpg", "Corte, pago y aviso.", "Captura"),
        ("c06-archivar-aviso.jpg", "Archivar: el aviso.", "Captura"),
        ("c09-saldo-escrito.jpg", "«Tu saldo»: diferencia y opciones.", "Captura"),
        ("c11-como-corregimos-abajo.jpg", "Resultado y acciones.", "Captura")]),
    ("Ajustes › Categorías (CategoriesSettingsListView, CategoryDetailView, SubcategoryDetailView, SubcategoryNeedSelectorView)", "", [
        ("k01-categorias.jpg", "11 categorías, A-Z.", "Captura"),
        ("k02-categorias-editar.jpg", "Editar: solo borrar.", "Captura"),
        ("k09-no-se-puede-eliminar.jpg", "Con 210 registros: ocultar o mover.", "Captura"),
        ("k12-categorias-vacio.jpg", "Sin categorías.", "Captura"),
        ("k03-detalle-alimentacion.jpg", "Una categoría.", "Captura"),
        ("k04-subcategoria.jpg", "Una subcategoría.", "Captura"),
        ("k05-necesidad.jpg", "«Gastos por necesidad».", "Captura"),
        ("k06-nueva-categoria.jpg", "Nueva categoría.", "Captura"),
        ("k07-sin-subcategoria-alerta.jpg", "Sin subcategoría: alerta.", "Captura"),
        ("k14-selector-al-registrar-abajo.jpg", "El selector al registrar, en otro orden.", "Captura"),
        ("ipad-k-categorias.jpg", "iPad: una categoría al lado de Ajustes.", "Captura iPad"),
        ("ipad-e01-etiquetas.jpg", "iPad: Etiquetas, las cinco.", "Captura iPad")]),
    ("Ajustes › Etiquetas (TagsSettingsListView, TagFormView)", "Semilla «realista».", [
        ("e01-etiquetas.jpg", "5 etiquetas.", "Captura"),
        ("e02-etiquetas-reordenar.jpg", "↑↓.", "Captura"),
        ("e03-editar-etiqueta.jpg", "Editar una.", "Captura"),
        ("e05-eliminar-etiqueta.jpg", "Eliminar: «se quitará de 198 registros».", "Captura"),
        ("e06-nueva-etiqueta.jpg", "Nueva etiqueta.", "Captura"),
        ("e08-etiquetas-vacio.jpg", "Sin etiquetas.", "Captura")]),
    ("Moneda y tipo de cambio (CurrencySettingsView)", "Semilla «sin-registros», región Perú.", [
        ("d01-divisas.jpg", "Principal, secundarias y tipos.", "Captura"),
        ("d03-elegir-principal.jpg", "Elegir la principal.", "Captura"),
        ("d04-confirmar-cambio.jpg", "Confirmar: antes y después.", "Captura"),
        ("d07-tras-cambio.jpg", "Tras el cambio a USD.", "Captura"),
        ("d08-secundarias.jpg", "Secundarias.", "Captura"),
        ("d10b-cargando-secundaria.jpg", "Al añadir una: la pantalla tapada.", "Captura"),
        ("d12-ver-todas.jpg", "«Ver todas».", "Captura")]),
]


def estado_page(problemas, perfiles):
    html = ""
    for title, sub, items in ESTADO:
        items = [it for it in items if os.path.exists(os.path.join(HERE, "capturas", it[0]))]
        shots = _shots(items)
        s = f'<p class="sub">{sub}</p>' if sub else ""
        html += f'<h2 class="s">{title}</h2>{s}' + _strip(shots, "hoy" if len(shots) > 3 else "")
    body = f"""<header class="ph-h"><div class="kicker">Cuentas y categorías · lo que hay hoy</div><h1 class="t">Hoy, vista a vista</h1>
<p class="lead">Capturas del {FECHA}, app de <code>origin/2.3</code> en el simulador, con las semillas de prueba de la app. Ninguna está
editada. Las de texto grande (AX3) están en la página «Perfiles y eficiencia».</p></header>{html}
<p class="foot">Las capturas originales en PNG se quedaron fuera del repositorio; aquí van en JPEG reducido para que la página pese poco.
En las semillas las cuentas se llaman «Visa QA», «Ahorros QA» o «Cuenta Principal»; en las maquetas, las del caso de Lucía.</p>"""
    return "Hoy, vista a vista · Cuentas y categorías", body, "Capturas actuales de cada vista de la zona 39."


EFIC_MED = []   # se rellena desde medidas.py
EFIC_HIP = [
    ("Ajustes › Cuentas lee <b>todos</b> los registros al abrir y, en cada pintado, calcula el saldo de cada fila recorriéndolos "
     "enteros (filas × registros). El resultado no se guarda entre pintados.",
     "<code>AccountsSettingsListViewModel.loadData</code> (líneas 138-151, «Perf-note»), <code>formattedBalance</code> (166-182) llamado desde cada fila",
     "La marca de carga mide la lectura (tabla de arriba); el coste por pintado no lo mide. A medir con el instrumento SwiftUI al reordenar, que repinta en cada arrastre."),
    ("El formulario de cuenta lee todos los registros, pagos programados, favoritos y borradores al abrir; <code>showAdjustmentMode</code> "
     "recorre todos los registros cada vez que se pinta.",
     "<code>AccountFormViewModel.swift:493-541</code>, <code>:758-764</code>",
     "Con diez años de datos puede notarse al abrir y al escribir cada dígito del saldo. Medir con la semilla «pesado»."),
    ("Guardar una subcategoría lee <b>todas</b> las subcategorías de la app para reordenar las de una categoría.",
     "<code>SubcategoryDetailView.reorderSubcategoriesAlphabetically</code> (líneas 405-420)", "Bajo: ~62 filas. Solo importa con cientos."),
    ("Añadir una moneda secundaria baja un año de tipos de cambio con la pantalla tapada.",
     "<code>CurrencySettingsView.loadHistoricalRatesForCurrency</code>", "Con red lenta, la pantalla tapada dura lo que tarde; sin red, lo que tarde en fallar. No medido en un iPhone."),
    ("Eliminar una etiqueta cuenta sus registros recorriendo la relación (<code>tag.transactions?.count</code>), que carga cada registro.",
     "<code>TagFormView.deleteSection</code>", "Bajo con 200 registros; a medir con una etiqueta en miles."),
]
SECUNDARIOS = [
    ("La lista de cuentas dice los saldos con el código («PEN 2,000.00», «USD 255.00») y el formulario y el Panel con el símbolo («S/ 2,000.00»).",
     "Capturas c07 y c08; <code>AccountsSettingsListViewModel.formattedBalance</code> usa <code>info.code</code>", "M"),
    ("Moneda y tipo de cambio ya trae USD y EUR como secundarias sin que nadie las elija.", "Captura d01", "B"),
    ("Sin ninguna secundaria, «Tipo de cambio» enseña las dos primeras divisas de la lista, que no tienen por qué importar a nadie.",
     "<code>CurrencySettingsView.exchangeRatesSection</code> (<code>CurrencyCode.allCases.prefix(2)</code>)", "B"),
    ("«+» de Categorías crea e inserta una categoría vacía antes de escribir nada; si la app se cierra a mitad (tras guardar una subcategoría), puede quedar una categoría sin nombre.",
     "<code>CategoriesSettingsListViewModel.createAndOpenNewCategory</code>; <code>SubcategoryDetailView.saveSubcategory</code> guarda el contexto (línea 393). Hipótesis: no reproducida", "M"),
    ("La cabecera de una categoría nueva dice «Nueva categoría» con el icono por defecto hasta escribir el nombre; la de una subcategoría nueva, el nombre de la categoría madre.",
     "Capturas k06 y k08", "B"),
    ("El selector de necesidad se titula «Gastos por necesidad» y la fila que lo abre «Necesidad».", "Capturas k04 y k05", "B"),
    ("La X del formulario de etiqueta cierra sin preguntar aunque haya cambios (Cuentas y Categorías sí preguntan). Va en G3.", "<code>TagFormView</code>, toolbar", "M"),
    ("En la lista de etiquetas y en la de cuentas, el alto de la lista se calcula a mano (filas × alto fijo): con texto grande o nombres de dos líneas, la última fila puede quedar cortada.",
     "<code>TagsSettingsListView.swift:127</code>, <code>AccountsSettingsListView</code> (<code>.frame(height:)</code> con <code>@ScaledMetric</code>). Ver capturas AX3", "M"),
    ("El número de cuenta acepta el número completo de una tarjeta y lo guarda tal cual. Va en el problema 5.", "Captura c14", "A"),
    ("En el iPad, la ficha de una cuenta se abre en una hoja centrada de media pantalla: para llegar a «Acciones» hay que desplazar más que en el iPhone, con media pantalla libre a los lados.",
     "Captura ipad-c08", "M"),
    ("Al crear una tarjeta, Guardar ofrece «Tu cuenta puede tener más de una divisa» antes de volver: bien explicado, pero se ofrece a toda tarjeta nueva aunque no lo necesite.", "Captura c16", "B"),
]


def revision_page(problemas, perfiles):
    head = "<th>Perfil</th>" + "".join(f"<th>{p['corto']}</th>" for p in problemas)
    rows_ = ""
    for k, name, why in perfiles:
        cells = ""
        for p in problemas:
            lvl, txt = p["hoy_lens"].get(k, ("N", "—"))
            cells += f'<td><div class="d"><i class="dot {lvl}" title="{NIV[lvl]}"></i><span>{txt}</span></div></td>'
        rows_ += f"<tr><td>{k} · {name}<br><small style='font-weight:400;color:var(--ink3)'>{why}</small></td>{cells}</tr>"
    med = "".join(f"<tr><td>{a}</td><td><b>{b}</b></td><td>{c}</td></tr>" for a, b, c in EFIC_MED)
    hip = "".join(f"<tr><td>{a}</td><td>{b}</td><td>{c}</td></tr>" for a, b, c in EFIC_HIP)
    sec = "".join(f'<tr><td><i class="dot {s}"></i></td><td>{a}</td><td>{b}</td></tr>' for a, b, s in SECUNDARIOS)
    ax = [f for f in sorted(os.listdir(os.path.join(HERE, "capturas"))) if f.startswith("ax-")]
    ax_html = _strip(_shots([(f, AX_CAP.get(f, "Texto grande (AX3)."), "Captura AX3") for f in ax]), "hoy") if ax else ""
    body = f"""<header class="ph-h"><div class="kicker">Cuentas y categorías · revisión adversarial</div><h1 class="t">Perfiles y eficiencia</h1>
<p class="lead">Los siete perfiles simulados como lentes sobre lo que hay hoy, el texto grande, lo medido y lo supuesto sobre
rendimiento, y los hallazgos que no llegan a problema prioritario.</p></header>
<h2 class="s">Lente de perfiles sobre lo de hoy</h2>
<p class="sub">{_tag("hip", "Perfiles simulados, no entrevistas")} Riesgo de que ese perfil se trabe en esa parte. <i class="dot A"></i> alto · <i class="dot M"></i> medio · <i class="dot B"></i> bajo.</p>
<div class="tbl"><table class="cmp lens">{'<tr>' + head + '</tr>'}{rows_}</table></div>
<div class="callout"><b>Lo que más se repite:</b> P6 (soles, dólares y tarjetas) es el más expuesto: archiva tarjetas, tiene números de
tarjeta y duda con las monedas secundarias. P2 (principiante) choca con las palabras: saldo de partida, subcategoría, necesidad,
secundaria. P7 (texto grande) sufre las fichas largas: archivar y el saldo están al fondo.</div>
<h2 class="s">Texto grande (AX3)</h2>
<p class="sub">Las mismas pantallas con el texto de accesibilidad «AX3». Lo que se ve aquí alimenta los problemas 1, 4 y 7.</p>
{AX_NOTE}
{ax_html}
<h2 class="s">Eficiencia: lo medido</h2>
<div class="tbl"><table class="cmp"><tr><th>Qué</th><th>Cifra</th><th>Cómo se midió</th></tr>{med}</table></div>
<p class="sub">Todo en Debug y en el simulador, que no es un iPhone en Release: sirve para comparar volúmenes, no como tiempo real.</p>
<h2 class="s">Eficiencia: hipótesis (sin medir)</h2>
<p class="sub">{_tag("hip", "Hipótesis")} Leído en el código. Ninguna es un refactor propuesto: son sitios a medir si se notan lentos con muchos datos.</p>
<div class="tbl"><table class="cmp"><tr><th>Qué pasa</th><th>Dónde</th><th>Qué se espera y qué medir</th></tr>{hip}</table></div>
<h2 class="s">Hallazgos secundarios</h2>
<p class="sub">No llegan a problema prioritario (o ya van dentro de uno). Severidad: <i class="dot A"></i> alta · <i class="dot M"></i> media · <i class="dot B"></i> baja.</p>
<div class="tbl"><table class="cmp"><tr><th></th><th>Hallazgo</th><th>Evidencia</th></tr>{sec}</table></div>
<h2 class="s">Lo que ya está bien</h2>
<ul class="evl"><li>«Editar el saldo» pregunta «¿Cuánto tienes de verdad hoy?», tacha lo que dice Yala, enseña la diferencia y escribe el resultado («Al guardar, queda en…»).</li>
<li>Una categoría con registros no se borra a ciegas: ofrece «Ocultarla» o «Mover sus registros…», con el número de registros.</li>
<li>Eliminar una etiqueta dice a cuántos registros se quita y que los registros no se borran.</li>
<li>Cambiar la moneda principal confirma con el saldo antes y después y dice que se puede volver.</li>
<li>Archivar una tarjeta con línea en otra divisa pregunta si se archivan también sus líneas.</li>
<li>«Gastos por necesidad» explica para qué sirve y cada opción trae ejemplos.</li>
<li>Al crear una cuenta, «¿No sabes tu saldo?» ofrece calcularlo, y «Más opciones» esconde lo avanzado.</li></ul>
<p class="foot">Fuentes: código de <code>origin/2.3</code> y capturas del {FECHA}.</p>"""
    return "Perfiles y eficiencia · Cuentas y categorías", body, "Perfiles, texto grande, rendimiento medido e hipótesis, y hallazgos secundarios de la zona 39."


AX_CAP = {}
AX_NOTE = ""
try:
    from medidas import EFIC_MED as _M, AX_CAP as _A, AX_NOTE as _N
    EFIC_MED[:] = _M
    AX_CAP.update(_A)
    AX_NOTE = _N
except ImportError:
    pass
