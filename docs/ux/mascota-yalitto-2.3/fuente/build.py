"""Genera la exploración de la mascota «Yalitto» en un solo HTML autocontenido.

    cd docs/ux/mascota-yalitto-2.3/fuente
    python3 build.py            → ../yalitto.html (capturas y SVG dentro: se abre como un solo archivo)

El PDF se imprime de ese mismo HTML (ver ../ficha.md). Sin dependencias: Python 3 de serie.
"""
import base64
import html
import pathlib

import yalittos as Y
from textos import (REFERENTES, FICHAS, SUPERFICIES, HACE, NO_HACE, PRESENCIA, TONO, TECNICA_FILAS,
                    TECNICA_NOTAS, COMPARA, DECISIONES, FUENTES, RESUMEN)

AQUI = pathlib.Path(__file__).resolve().parent
RAIZ = AQUI.parent
CAP = RAIZ / "capturas"
E = html.escape


def img64(nombre):
    data = (CAP / nombre).read_bytes()
    return "data:image/jpeg;base64," + base64.b64encode(data).decode()


def tag(kind, txt=None):
    nombres = {"fte": "Fuente externa", "cap": "Captura", "maq": "Maqueta", "hip": "Hipótesis", "pro": "Propio"}
    return f'<span class="tag {kind}">{txt or nombres[kind]}</span>'


def dirswap(state, size=None, **kw):
    """Las cinco direcciones apiladas; el selector de abajo elige cuál se ve."""
    return '<div class="dirswap">' + "".join(Y.demo(d, state, size=size, **kw.get(d, {})) for d, _, _ in Y.DIRECCIONES) + "</div>"


# ---------------------------------------------------------------- secciones

def sec_portada():
    fila = "".join(
        f'<figure class="hero-y">{Y.demo(d, "saludo" if i == 0 else "reposo")}<figcaption><b>{E(n)}</b><span>{E(t)}</span></figcaption></figure>'
        for i, (d, n, t) in enumerate(Y.DIRECCIONES))
    return f"""
<header class="cover" id="inicio">
  <div class="wrap">
    <p class="kicker">Yala 2.3 · Exploración de UX · 7 de noviembre de 2026</p>
    <h1>Yalitto: cinco mascotas posibles para Yala</h1>
    <p class="lead">Propuestas visuales, dónde viviría en la app, cómo se movería y qué haría. <b>No se implementa nada</b>:
    es material para que decidas si se hace y cuál. «Yalitto» es un nombre provisional.</p>
    <div class="hero-row">{fila}</div>
    <div class="callout"><span class="lbl">En una frase</span>{RESUMEN}</div>
    <p class="howto">Cómo leer este documento: {tag("fte")} viene de una fuente enlazada · {tag("cap")} es una pantalla real de Yala
    (simulador, datos ficticios) · {tag("maq")} es un dibujo nuestro · {tag("hip")} es una suposición que habría que validar.
    Todos los personajes son SVG propios: ninguno copia una marca.</p>
  </div>
</header>"""


def sec_referentes():
    filas = "".join(
        f"<tr><td><b>{E(r['nombre'])}</b><br><span class='muted'>{E(r['que'])}</span></td><td data-l='Lo que tomamos'>{r['tomamos']}</td>"
        f"<td data-l='Lo que evitamos'>{r['evitamos']}</td><td data-l='Fuente'>{' '.join(f'<a href={chr(34)}{u}{chr(34)}>{E(t)}</a>' for t, u in r['fuentes']) or '<span class=muted>Referencia tuya</span>'}</td></tr>"
        for r in REFERENTES)
    return f"""
<section id="referentes" class="wrap">
  <h2>1. Referentes actuales</h2>
  <p class="sub">Qué hacen otras apps con un personaje y qué aprendemos de cada una. {tag("fte")} Esto es <b>inspiración</b>:
  los diseños de la sección 2 son nuestros y no copian ninguno de estos.</p>
  <div class="tablewrap"><table class="t stack">
    <thead><tr><th>Referente</th><th>Lo que tomamos</th><th>Lo que evitamos</th><th>Fuente</th></tr></thead>
    <tbody>{filas}</tbody></table></div>
  <div class="grid2">
    <div class="note"><span class="lbl">Lo que se repite en los que funcionan</span>
      <ul><li>El personaje <b>es opcional</b> y se apaga fácil (Copilot con Mico, según la prensa).</li>
      <li>Tiene <b>pocos estados bien hechos</b> que se mezclan, no cientos de animaciones sueltas (Duolingo y Notion, con Rive).</li>
      <li><b>No castiga</b> lo que no hiciste (Finch).</li>
      <li>Aparece cuando <b>aporta algo</b>, no cuando el sistema cree que hace falta (la lección de Clippy).</li></ul></div>
    <div class="note warn"><span class="lbl">Lo que no queremos para Yala</span>
      <ul><li>La culpa como motor: «Duo está triste» funciona como meme, no como trato.</li>
      <li>Burlarse del gasto (el «roast mode» de Cleo): en finanzas, un chiste sobre lo que gastaste es un juicio.</li>
      <li>Un amigo que habla en jerga local (Pablito): la marca de Yala pide español neutro.</li>
      <li>Ditto inspira la idea de <b>forma maleable</b>; no se usa ni su forma ni su color ni su nombre.</li></ul></div>
  </div>
</section>"""


def lamina(d, nombre, concepto):
    f = FICHAS[d]
    expr = "".join(f'<figure class="mini">{Y.yalitto(d, expr=e)}<figcaption>{Y.EXPR_NOMBRE[e]}</figcaption></figure>' for e in Y.EXPR)
    formas = "".join(f'<figure class="mini">{Y.yalitto(d, forma=fm)}<figcaption>{fm.capitalize()}</figcaption></figure>' for fm in Y.FORMAS[d])
    colores = "".join(f'<figure class="mini sm">{Y.yalitto(d, color=c)}<figcaption>{c.capitalize()}</figcaption></figure>' for c in Y.COLORES[d])
    detalles = "".join(f'<figure class="mini sm">{Y.yalitto(d, detalle=a)}<figcaption>{a.capitalize()}</figcaption></figure>' for a in Y.DETALLES)
    sil = "".join(f'<figure class="mini sil">{Y.yalitto(d, forma=fm)}</figure>' for fm in Y.FORMAS[d][:3])
    tam = "".join(f'<span class="szbox" style="width:{s}px;height:{s}px">{Y.yalitto(d)}</span>' for s in (24, 32, 48, 72))
    extra = f'<div class="block"><h4>{f["extra_titulo"]}</h4><div class="strip">{f["extra"]()}</div><p class="muted">{f["extra_nota"]}</p></div>' if f.get("extra") else ""
    return f"""
<article class="lamina" id="dir-{d}">
  <div class="lam-head">
    <div class="lam-hero">{Y.demo(d, "saludo")}</div>
    <div>
      <p class="kicker">Dirección {nombre[0]}</p>
      <h3>{E(nombre)}</h3>
      <p class="lead2">{E(concepto)}. {f["idea"]}</p>
      <div class="pc"><div><span class="lbl ok">A favor</span><ul>{''.join(f'<li>{x}</li>' for x in f['pro'])}</ul></div>
      <div><span class="lbl ko">En contra</span><ul>{''.join(f'<li>{x}</li>' for x in f['contra'])}</ul></div></div>
    </div>
  </div>
  <div class="block"><h4>Silueta y tamaños</h4>
    <div class="strip">{sil}<span class="sep"></span>{tam}</div>
    <p class="muted">En un solo color, para comprobar que se reconoce sin el suyo. A 24 y 32 pt es como se vería junto a un texto de la app.</p></div>
  <div class="block"><h4>Expresiones</h4><div class="strip">{expr}</div>
    <p class="muted">Ocho caras con las mismas piezas: ojos, cejas y boca. Ninguna llora ni se enfada.</p></div>
  <div class="block"><h4>Lo que la persona puede cambiar</h4>
    <p class="mini-t">Forma</p><div class="strip">{formas}</div>
    <p class="mini-t">Color</p><div class="strip">{colores}</div>
    <p class="mini-t">Un detalle</p><div class="strip">{detalles}</div></div>
  {extra}
  <div class="grid2">
    <div class="note"><span class="lbl">Cambia</span><ul>{''.join(f'<li>{x}</li>' for x in f['cambia'])}</ul></div>
    <div class="note"><span class="lbl">No cambia nunca (para que siga siendo Yalitto)</span><ul>{''.join(f'<li>{x}</li>' for x in f['fijo'])}</ul></div>
  </div>
</article>"""


def sec_direcciones():
    nav = "".join(f'<a href="#dir-{d}">{E(n)}</a>' for d, n, _ in Y.DIRECCIONES)
    return f"""
<section id="direcciones" class="wrap">
  <h2>2. Cinco direcciones visuales</h2>
  <p class="sub">{tag("pro")} Cinco materiales distintos: líquido, vidrio, línea, papel y aparato. Las cinco comparten el mismo
  «esqueleto» de cara y de estados, así que todo lo de las secciones 4 y 5 se puede ver con cualquiera. Hubo una sexta,
  <b>Brote</b> (una plantita que crece si ahorras), y se descartó: convierte el ahorro en una moral.</p>
  <nav class="pills">{nav}</nav>
  {''.join(lamina(d, n, c) for d, n, c in Y.DIRECCIONES)}
</section>"""


def sec_personalizar():
    # configurador de la dirección A: forma × color pre-dibujados
    grid = "".join(f'<div class="cfg-y" data-f="{fm}" data-c="{c}">{Y.yalitto("gota", forma=fm, color=c, state="reposo", faces=["reposo"])}</div>'
                   for fm in Y.FORMAS["gota"] for c in Y.COLORES["gota"])
    fbtn = "".join(f'<button type="button" data-f="{fm}" class="{"on" if i == 0 else ""}">{Y.yalitto("gota", forma=fm, color="grafito")}<span>{fm.capitalize()}</span></button>'
                   for i, fm in enumerate(Y.FORMAS["gota"]))
    cbtn = "".join(f'<button type="button" data-c="{c}" class="dot {"on" if i == 0 else ""}" style="--c:{Y.PALETAS[c]}" aria-label="{c}"></button>'
                   for i, c in enumerate(Y.COLORES["gota"]))
    return f"""
<section id="personalizar" class="wrap">
  <h2>3. Que cada persona defina su Yalitto</h2>
  <p class="sub">Tu idea era que el usuario pueda definir su forma. Funciona si se elige <b>de un menú corto</b>, no dibujando:
  así siempre se reconoce, siempre contrasta y siempre cabe en un hueco de 24 pt. Pruébalo con la dirección A.</p>
  <div class="cfg">
    <div class="cfg-phone">
      <div class="ph-bar"><span>Ajustes</span><b>Tu Yalitto</b><span></span></div>
      <div class="cfg-stage">{grid}</div>
      <p class="cfg-label">Forma</p><div class="cfg-forms">{fbtn}</div>
      <p class="cfg-label">Color</p><div class="cfg-colors">{cbtn}</div>
      <div class="cfg-rows">
        <div class="row"><span>Mostrar a Yalitto</span><span class="sw on"></span></div>
        <div class="row"><span>Nombre</span><span class="muted">Yalitto</span></div>
        <div class="row"><span>Movimiento</span><span class="muted">Completo · Sutil · Quieto</span></div>
        <div class="row"><span>Dónde aparece</span><span class="muted">Vacíos, avisos, Yala IA</span></div>
      </div>
      <p class="ph-foot">Si activas Reducir movimiento en el iPhone, Yalitto se queda quieto aunque aquí diga «Completo».</p>
    </div>
    <div class="cfg-text">
      <h4>Qué se puede cambiar</h4>
      <ul><li><b>Forma</b>: entre 3 y 5 moldes por dirección.</li><li><b>Color</b>: de una paleta de 6 a 8 tonos, todos con contraste
      para la cara en modo claro y oscuro.</li><li><b>Un detalle</b>: antena, gorro, auriculares o brillo. Uno, no varios.</li>
      <li><b>Nombre</b>: el que quiera; la app nunca lo usa en avisos del sistema.</li>
      <li><b>Movimiento</b> y <b>dónde aparece</b>, o apagarlo del todo.</li></ul>
      <h4>Límites</h4>
      <ul><li>Sin dibujo libre, texto ni fotos: no se puede convertir en otra marca ni en algo ofensivo.</li>
      <li>La cara no se toca: proporción y posición de ojos y boca son la identidad.</li>
      <li>Ningún detalle habla de dinero (sin bolsas, monedas ni billetes): Yalitto no es un premio por gastar o ahorrar.</li>
      <li>Nada se desbloquea pagando ni con rachas. {tag("hip", "Decisión tuya")} si algún detalle fuera Pro.</li></ul>
      <h4>«Toma forma» un momento</h4>
      <p>Lo más cercano a Ditto: además de su molde, Yalitto puede <b>tomar un instante la forma</b> de lo que está explicando
      y volver a la suya. Por ejemplo, un sobre en la Bandeja o una burbuja en Yala IA.</p>
      <div class="strip">{Y.yalitto("gota")}<span class="arrow">→</span>{Y.yalitto("boleta", forma="sobre", color="lila")}<span class="arrow">→</span>{Y.yalitto("gota", expr="feliz")}</div>
      <p class="muted">Dibujo de concepto: el cambio dura menos de un segundo y con Reducir movimiento se omite.</p>
    </div>
  </div>
</section>"""


def phone(img, overlays, alt):
    return f'<div class="phone"><img src="{img64(img)}" alt="{E(alt)}">{overlays}</div>'


def ov_y(state, left, top, w, mask=None):
    m = (f'<div class="mask" style="left:{mask[0]}%;top:{mask[1]}%;width:{mask[2]}%;height:{mask[3]}%;--m:{mask[4]}"></div>'
         if mask else "")
    return m + f'<div class="ov-y" style="left:{left}%;top:{top}%;width:{w}%">{dirswap(state)}</div>'


def ov_b(texto, left, top, w, botones=None, cola=None):
    b = f'<div class="bb">{"".join(f"<span>{E(x)}</span>" for x in botones)}</div>' if botones else ""
    c = f" tail-{cola}" if cola else ""
    return f'<div class="ov-b{c}" style="left:{left}%;top:{top}%;width:{w}%">{texto}{b}</div>'


def widget_mock():
    return f"""<div class="phone home">
  <div class="home-grid">
    <div class="wdg">{dirswap("cerca")}<div><p class="w-t">Comidas fuera</p><p class="w-n">Te quedan S/ 470</p><p class="w-s">8 días · 74 %</p></div></div>
    <div class="wdg priv">{dirswap("reposo")}<div><p class="w-t">Comidas fuera</p><p class="w-n">74 %</p><p class="w-s">Montos ocultos</p></div></div>
    {''.join('<span class="appi"></span>' for _ in range(8))}
  </div>
  <p class="home-cap">Pantalla de inicio · dos widgets pequeños</p></div>"""


def ajustes_mock():
    return f"""<div class="phone sheet">
  <div class="ph-bar"><span>‹ Ajustes</span><b>Apariencia</b><span></span></div>
  <div class="sheet-y">{dirswap("reposo")}</div>
  <div class="cfg-rows">
    <div class="row"><span>Yalitto</span><span class="sw on"></span></div>
    <div class="row"><span>Personalizar</span><span class="muted">›</span></div>
    <div class="row"><span>Movimiento</span><span class="muted">Sutil ›</span></div>
    <div class="row"><span>En estados vacíos</span><span class="sw on"></span></div>
    <div class="row"><span>En avisos</span><span class="sw on"></span></div>
    <div class="row"><span>En Yala IA</span><span class="sw on"></span></div>
    <div class="row"><span>En widgets</span><span class="sw"></span></div>
  </div>
  <p class="ph-foot">También: mantener presionado a Yalitto → «Ocultar aquí».</p></div>"""


def cerca_mock():
    return f"""<div class="phone sheet">
  <div class="ph-bar"><span>‹</span><b>Comidas fuera</b><span></span></div>
  <div class="bcard"><p class="muted c">Noviembre de 2026</p><p class="c big">Te quedan S/ 180</p>
    <p class="muted c">S/ 1,620 de S/ 1,800</p><div class="bbar"><i style="width:90%"></i></div>
    <p class="row2"><span>90 % gastado</span><span>Faltan 8 días</span></p></div>
  <div class="cerca-y">{dirswap("cerca")}</div>
  <div class="ov-b static">Llevas el 90 % de Comer fuera y faltan 8 días.<div class="bb"><span>Ver movimientos</span><span>Ajustar</span></div></div>
  </div>"""


def sec_superficies():
    caps = {
        "panel": phone("01-panel.jpg", ov_y("saludo", 76, 18.6, 19) +
                       ov_b("Tienes 4 pendientes en la Bandeja. ¿Los revisamos?", 32, 28, 64, ["Revisar", "Ahora no"], "tr"), "Panel"),
        "registro": phone("02-registro-listo.jpg", ov_y("util", 34, 19, 32, mask=(28, 18, 44, 22, "#0a0614")) +
                          ov_b("Tu primer gasto quedó registrado. El próximo lo puedes dictar con Voz.", 12, 41, 76), "Nuevo registro, listo"),
        "bandeja": phone("03-bandeja.jpg", ov_y("ayuda", 79, 14.2, 16) +
                         ov_b("Aquí llega lo que apuntaste por voz, foto o Apple Pay. Revísalo y guárdalo. Te lo digo solo esta vez.", 22, 21.5, 74, None, "tr"), "Bandeja"),
        "pasado": phone("04-presupuesto-pasado.jpg", ov_y("pasado", 6, 14, 22) +
                        ov_b("En octubre pasaste Comer fuera por S/ 993. ¿Ajustamos el límite de noviembre o lo dejamos así?", 8, 46, 84, ["Ajustar", "Dejar así"]), "Presupuesto pasado"),
        "cerca": cerca_mock(),
        "vacio": phone("06-registros-vacio.jpg", ov_y("ayuda", 38, 43.5, 24, mask=(30, 44, 40, 12, "#0c0b2c")), "Registros vacío"),
        "error": phone("07-error-precios.jpg", '<div class="mask" style="left:1%;top:56.5%;width:98%;height:9.5%;--m:#060612"></div>' +
                       ov_y("error", 3, 55.5, 17) + ov_b("No pudimos cargar los precios. Reintentamos solos cuando vuelva la conexión.", 21, 57.8, 75, ["Reintentar"]), "Error"),
        "ia": phone("08-yala-ia.jpg", ov_y("reposo", 29, 9.2, 8) + ov_y("pensando", 3, 49, 15), "Yala IA"),
        "widget": widget_mock(),
        "ajustes": ajustes_mock(),
    }
    tarjetas = []
    for s in SUPERFICIES:
        tipo = tag("cap", "Captura + maqueta") if s["tipo"] == "cap" else tag("maq")
        tarjetas.append(f"""
<article class="surf" id="sup-{s['id']}">
  <div class="surf-ph">{caps[s['id']]}</div>
  <div class="surf-tx">
    <p class="kicker">{tipo} {('<span class="tag v1">Propuesta para v1</span>' if s['v1'] else '<span class="tag later">Más adelante</span>')}</p>
    <h3>{E(s['titulo'])}</h3>
    <dl><dt>Aparece</dt><dd>{s['aparece']}</dd><dt>Hace</dt><dd>{s['hace']}</dd>
    <dt>Se oculta</dt><dd>{s['oculta']}</dd><dt>Valor</dt><dd>{s['valor']}</dd></dl>
    {f'<p class="risk"><b>Riesgo:</b> {s["riesgo"]}</p>' if s.get('riesgo') else ''}
  </div>
</article>""")
    return f"""
<section id="superficies" class="wrap">
  <h2>4. Dónde vive en Yala</h2>
  <p class="sub">Pantallas reales de Yala 2.3 (simulador iPhone 17 Pro, datos ficticios, 6 y 7 de noviembre) con Yalitto
  encima. {tag("cap")} es la pantalla; el personaje y los globos son {tag("maq")}. Los textos de los globos son propuesta.
  <b>Regla de base:</b> Yalitto aparece cuando ayuda a hacer o entender algo; si no, no está. No vive fijo en ninguna pantalla.</p>
  {''.join(tarjetas)}
  <div class="note"><span class="lbl">Dónde NO aparece</span><ul>
    <li><b>Mientras escribes</b> en Nuevo registro, en un formulario o con el teclado abierto: ahí la tarea manda.</li>
    <li><b>En la guía del usuario nuevo</b>: ya se decidió que va sin mascota.</li>
    <li><b>En las notificaciones</b>: no se anima y competiría con el icono de la app.</li>
    <li><b>Encima de una cifra</b>: nunca tapa un monto ni un botón.</li>
    <li><b>En capturas para compartir</b> (exportar, informes): es de la persona, no del documento.</li></ul></div>
</section>"""


# storyboard: (expresión, pose=(dy, sx, sy, grados), texto)
STORY = {
    "reposo":   [("reposo", None, "Quieto"), ("reposo", (0, 1.02, .97, 0), "Respira"), ("dormido", None, "Parpadea"), ("reposo", None, "Se queda quieto tras dos ciclos")],
    "saludo":   [("reposo", None, "Entra"), ("reposo", (0, 1.08, .9, 0), "Toma impulso"), ("feliz", (-18, .95, 1.06, 0), "Salta"), ("feliz", (0, 1, 1, -7), "Se inclina: «hola»")],
    "util":     [("reposo", None, "Guardado"), ("feliz", (3, 1.03, .96, 0), "Asiente"), ("feliz", (-2, 1, 1, 0), "Aparece el ✓"), ("reposo", None, "Vuelve a lo suyo")],
    "ayuda":    [("reposo", None, "Tocas «?»"), ("curioso", (0, 1, 1, 7), "Se inclina hacia la ayuda"), ("curioso", (0, 1, 1, 7), "Sale el globo"), ("reposo", None, "Espera; no insiste")],
    "pensando": [("pensando", None, "Escribes"), ("pensando", (0, 1, 1, -3), "Piensa"), ("pensando", (0, 1, 1, 3), "Puntos"), ("feliz", None, "Llega la respuesta")],
    "error":    [("reposo", None, "Falla la conexión"), ("uy", (6, 1.04, .92, 0), "«Uy», se encoge un poco"), ("uy", (3, 1, .97, 0), "Explica qué pasó"), ("reposo", None, "Ofrece reintentar")],
    "cerca":    [("reposo", None, "Llega al 90 %"), ("mira", (0, 1, 1, 4), "Mira la barra"), ("mira", (0, 1, 1, 4), "Dice cuánto queda"), ("reposo", None, "Se retira")],
    "pasado":   [("reposo", None, "Pasa el 100 %"), ("sereno", None, "Sereno, sin drama"), ("sereno", (2, 1, .98, 0), "Ofrece opciones"), ("reposo", None, "Decides tú")],
}


def sec_movimiento():
    sb = []
    for sid, nombre, faces, cuando, dice, dura in Y.ESTADOS:
        frames = "".join(f'<figure class="frame">{Y.yalitto("gota", expr=e, pose=p, extra=(Y.estado_extra(sid) if i in (2,) else ""))}<figcaption>{i + 1}. {E(t)}</figcaption></figure>'
                         for i, (e, p, t) in enumerate(STORY[sid]))
        sb.append(f'<div class="sb-row"><h4>{E(nombre)}</h4><div class="strip frames">{frames}</div></div>')
    protos = "".join(f"""
<article class="proto">
  <div class="proto-stage">{dirswap(sid)}</div>
  <h4>{E(nombre)}</h4>
  <dl><dt>Cuándo</dt><dd>{E(cuando)}</dd><dt>Qué dice</dt><dd>{E(dice)}</dd><dt>Duración</dt><dd>{E(dura)}</dd></dl>
</article>""" for sid, nombre, faces, cuando, dice, dura in Y.ESTADOS)
    return f"""
<section id="movimiento" class="wrap">
  <h2>5. Cómo se mueve</h2>
  <p class="sub">{tag("pro")} Prototipos en CSS y SVG, los mismos en las cinco direcciones. Se repiten en bucle para poder
  mirarlos; en la app, cada uno sale <b>una vez</b>. Usa el selector de abajo para cambiar de Yalitto y «Más lento» para verlos
  con calma. «Simular Reducir movimiento» enseña lo que vería quien lo tiene activado: la expresión final, sin movimiento.</p>
  <div class="protos">{protos}</div>
  <h3 class="s3">Storyboard (dirección A)</h3>
  <p class="sub">Los fotogramas clave de cada estado. En el PDF, esto sustituye a la animación.</p>
  {''.join(sb)}
  <div class="grid2">
    <div class="note"><span class="lbl">Reglas de movimiento</span><ul>
      <li>Un estado = un gesto corto. Nada de bucles largos: tras dos ciclos de reposo, quieto.</li>
      <li>Error y presupuesto pasado se <b>encogen o se serenan</b>; nunca tiemblan ni sacuden (sacudir es «lo hiciste mal»).</li>
      <li>Sin confeti, lágrimas, sudor ni corazones rotos.</li>
      <li>Vibración: como mucho la ligera que la app ya usa al guardar. Yalitto no añade la suya.</li>
      <li>Sin sonido.</li></ul></div>
    <div class="note"><span class="lbl">Con Reducir movimiento activado</span><ul>
      <li>Ningún salto, inclinación ni cambio de forma.</li>
      <li>Se muestra directamente la expresión final y el globo aparece con un fundido.</li>
      <li>El parpadeo y la respiración se apagan.</li>
      <li>Lo mismo si la persona elige «Quieto» en Ajustes, aunque el sistema no tenga activado Reducir movimiento.</li></ul></div>
  </div>
</section>"""


def sec_reglas():
    hace = "".join(f"<li>{x}</li>" for x in HACE)
    nohace = "".join(f"<li>{x}</li>" for x in NO_HACE)
    pres = "".join(f"<tr><td><b>{a}</b></td><td>{b}</td></tr>" for a, b in PRESENCIA)
    tono = "".join(f"<tr><td><b>{a}</b></td><td class='no' data-l='Así no'>{b}</td><td class='si' data-l='Así sí'>{c}</td></tr>" for a, b, c in TONO)
    return f"""
<section id="reglas" class="wrap">
  <h2>6. Qué hace, qué no hace y cómo habla</h2>
  <div class="grid2">
    <div class="note ok"><span class="lbl">Hace</span><ul>{hace}</ul></div>
    <div class="note warn"><span class="lbl">No hace</span><ul>{nohace}</ul></div>
  </div>
  <div class="callout"><span class="lbl">La prueba de valor frente a decoración</span>Antes de poner a Yalitto en un sitio nuevo,
  una pregunta: <b>si lo quitamos, ¿la persona entiende o hace algo peor?</b> Si la respuesta es no, es decoración y no va.
  Con esa prueba salen las propuestas de v1 de la sección 4: vacíos, error, primera utilidad, presupuesto y Yala IA.</div>
  <h3 class="s3">Presencia, desactivar y accesibilidad</h3>
  <div class="tablewrap"><table class="t stack"><tbody>{pres}</tbody></table></div>
  <h3 class="s3">Tono: adulto, sin moralizar ni infantilizar</h3>
  <p class="sub">Español neutro y frases de la voz de marca. Yalitto describe y ofrece; no opina sobre en qué gastas.</p>
  <div class="tablewrap"><table class="t tono stack"><thead><tr><th>Momento</th><th>Así no</th><th>Así sí</th></tr></thead><tbody>{tono}</tbody></table></div>
  <div class="grid2 alto">
    <div>{phone("05-presupuestos-mes-pasado.jpg", "", "Presupuestos del mes pasado")}</div>
    <div class="note"><span class="lbl">Hoy en la app {tag("cap")}</span>
    <p>La lista de presupuestos ya dice «Pasaste tu presupuesto, ¡el próximo período será mejor!». La voz de marca la permite,
    pero con un personaje al lado se lee como consuelo o como sermón. Si Yalitto entra, conviene que ese texto pase a
    describir y ofrecer: «Te pasaste por S/ 993. ¿Ajustamos el límite?».</p>
    <p class="muted">Los presupuestos salen dos veces en esta captura. Pasa con la semilla de datos de prueba en 2.3; no es parte de
    la propuesta (ver «Encontrado» en la ficha).</p></div>
  </div>
</section>"""


def sec_tecnica():
    filas = "".join(f"<tr><th>{E(c)}</th>{''.join(f'<td>{v}</td>' for v in vals)}</tr>" for c, *vals in TECNICA_FILAS)
    notas = "".join(f'<div class="note"><span class="lbl">{E(t)}</span>{b}</div>' for t, b in TECNICA_NOTAS)
    return f"""
<section id="tecnica" class="wrap">
  <h2>7. Técnica: cómo se construiría</h2>
  <p class="sub">Comparación cualitativa. <b>No hay cifras de peso ni de batería medidas en Yala</b>: no se ha prototipado en la app.
  Donde una fuente da un dato, va con su enlace y es dato de quien lo publica.</p>
  <div class="grid3">{notas}</div>
  <div class="tablewrap"><table class="t cmp"><thead><tr><th></th><th>SwiftUI nativo</th><th>Lottie</th><th>Rive</th></tr></thead>
  <tbody>{filas}</tbody></table></div>
  <div class="callout"><span class="lbl">Recomendación técnica</span>Empezar en <b>SwiftUI nativo</b>: los cinco personajes de este
  documento son formas simples (los mismos trazados que aquí están en SVG pasan a <code>Path</code>), los estados son pocos y la
  personalización de forma y color es un parámetro. No añade dependencias ni activos que descargar. <b>Rive</b> es el plan B si
  más adelante se quiere un personaje con muchas expresiones que se mezclan o que hable al ritmo de la voz de Yala IA.
  <b>Lottie</b> encaja peor: es muy bueno para animaciones cerradas, pero cambiar la forma según el usuario es justo lo que más le cuesta.</div>
  <div class="note"><span class="lbl">Cómo medirlo antes de decidir {tag("hip")}</span><ul>
    <li>Prototipo de un estado (saludo) en SwiftUI con la dirección elegida, en una rama aparte.</li>
    <li>Instruments en el iPhone de pruebas: CPU y energía con Yalitto a la vista en reposo, y tras sus dos ciclos.</li>
    <li>Tamaño de la app antes y después (en nativo debería notarse poco; es lo que hay que comprobar).</li>
    <li>Si se prueba Rive, lo mismo con su runtime, y comparar.</li></ul></div>
</section>"""


def sec_decision():
    cols = "".join(f"<th>{E(n)}</th>" for _, n, _ in Y.DIRECCIONES)
    filas = "".join(f"<tr><td>{E(c)}</td>{''.join(f'<td class=\"sc\">{v}</td>' for v in vals)}</tr>" for c, *vals in COMPARA)
    dec = "".join(f"<li><b>{a}</b> {b}</li>" for a, b in DECISIONES)
    return f"""
<section id="decision" class="wrap">
  <h2>8. Recomendación y lo que decides tú</h2>
  <p class="sub">Puntuación de criterio propio (●●● = mejor), no de usuarios: no hubo entrevistas ni pruebas con personas. {tag("hip")}</p>
  <div class="tablewrap"><table class="t cmp"><thead><tr><th>Criterio</th>{cols}</tr></thead><tbody>{filas}</tbody></table></div>
  <div class="reco">
    <div class="reco-y">{Y.demo("gota", "saludo")}</div>
    <div><span class="lbl">Recomendación</span>
    <p><b>A · Gota</b>, con las reglas de este documento. Es la que cumple tu idea de forma definible por el usuario sin
    perder identidad, se lee bien a 24 pt y se construye en SwiftUI sin dependencias.</p>
    <p><b>Lo que cuesta:</b> es la más «mascota» de las cinco y la más cercana a lo que ya se ve en otras apps (Copilot presentó
    en 2025 un personaje con forma de mancha que cambia de color). La diferencia la ponen la cara fija, los moldes y el tono.</p>
    <p><b>Alternativas:</b> <b>E · Bit</b> si prefieres que el personaje sea la cara de Yala IA y no de toda la app.
    <b>C · Trazo</b> si quieres lo más sobrio y lo más propio de una app de finanzas, a cambio de menos cariño.</p></div>
  </div>
  <div class="note"><span class="lbl">Decide Jürgen</span><ol class="dec">{dec}</ol></div>
</section>"""


def sec_fuentes():
    li = "".join(f'<li><a href="{u}">{E(t)}</a> — {E(n)}</li>' for t, u, n in FUENTES)
    return f"""
<section id="fuentes" class="wrap">
  <h2>Fuentes</h2>
  <p class="sub">Consultadas el 7 de noviembre de 2026. Las de prensa y blogs se citan como lo que son: lo que dice esa fuente.</p>
  <ul class="src">{li}</ul>
  <p class="muted">Capturas: Yala Dev compilada desde <code>origin/2.3</code> el 7-nov-2026, simulador iPhone 17 Pro con iOS 27.2,
  modo oscuro, semilla de datos ficticios «realista» con Pro activado. Nuevo registro y Registros vacío salen de las revisiones de
  vistas 2.3 del 6 y 7 de noviembre.</p>
</section>"""


# ---------------------------------------------------------------- página

def page():
    css = (AQUI / "estilo.css").read_text()
    js = (AQUI / "app.js").read_text()
    nav = [("inicio", "Inicio"), ("referentes", "Referentes"), ("direcciones", "Direcciones"), ("personalizar", "Personalizar"),
           ("superficies", "Dónde vive"), ("movimiento", "Movimiento"), ("reglas", "Reglas"), ("tecnica", "Técnica"),
           ("decision", "Decisión")]
    navh = "".join(f'<a href="#{a}">{b}</a>' for a, b in nav)
    sel = "".join(f'<button type="button" data-dir="{d}" class="{"on" if i == 0 else ""}">{Y.yalitto(d)}<span>{E(n.split(" · ")[1])}</span></button>'
                  for i, (d, n, _) in enumerate(Y.DIRECCIONES))
    body = (sec_portada() + sec_referentes() + sec_direcciones() + sec_personalizar() + sec_superficies() +
            sec_movimiento() + sec_reglas() + sec_tecnica() + sec_decision() + sec_fuentes())
    return f"""<!doctype html>
<html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Yalitto · exploración</title>
<meta name="description" content="Exploración de UX de Yala 2.3: cinco direcciones visuales para una mascota, dónde viviría en la app y cómo se movería.">
<style>{css}</style></head>
<body class="dir-gota">
<nav class="top noprint"><div class="wrap">{navh}</div></nav>
<div class="selector noprint" role="group" aria-label="Elegir Yalitto">
  <div class="sel-dirs">{sel}</div>
  <div class="sel-opts"><label><input type="checkbox" id="rm"> Simular Reducir movimiento</label>
  <label><input type="checkbox" id="slow"> Más lento</label></div>
</div>
{body}
<footer class="wrap foot">Yala · exploración de UX 2.3 · Yalitto es un nombre provisional · nada de esto está en la app.</footer>
<script>{js}</script>
</body></html>"""


if __name__ == "__main__":
    out = RAIZ / "yalitto.html"
    out.write_text(page())
    print("ok", out, f"{out.stat().st_size / 1024:.0f} KB")
