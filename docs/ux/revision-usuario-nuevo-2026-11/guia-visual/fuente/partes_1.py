"""Partes 1 y 2: bienvenida y onboarding."""
from pantallas import *

C = "../capturas/"          # capturas de la revisión (6-nov)
SIM = "capturas-simulador/"  # capturas tomadas para esta guía


def A(code, titulo, origen, que, screens, pros, contras, lens, esf="", riesgo="", reabre=None, estado=(), conteo="", despues=-1):
    return dict(code=code, titulo=titulo, origen=origen, que=que, screens=screens, pros=pros, contras=contras, lens=lens,
                esf=esf, riesgo=riesgo, reabre=reabre, estado=list(estado), conteo=conteo, despues=despues)


def L(*pairs):
    keys = ["P1", "P2", "P3", "P4", "P5", "P6", "P7"]
    return {k: v for k, v in zip(keys, pairs)}


# =============================================================== 1. BIENVENIDA
def home_tap():
    return home_screen("Yala")


A1 = A("A1", "Avisar del reinicio desde el selector", "src",
       "«Es mi primera vez» avisa <b>antes</b> de que Yala se va a cerrar una vez, y la pantalla del reinicio trae un botón que la cierra por la persona.",
       [phone(selector(first_note="Yala se cerrará una vez para guardar en tu iCloud.", chg=True), "onb", step=1, mark=MQ,
              cap="Ana lee el aviso <b>antes</b> de elegir"),
        phone(reabre(bottom(btn("Cerrar Yala y volver a entrar", cls="chg tap"),
                            '<div class="mini center" style="margin-top:4px">Si no se cierra sola, sal a la pantalla de inicio</div>')),
              "onb", step=2, mark=MQ, cap="Tras «Seguir así», un botón cierra Yala por ella"),
        phone(home_tap(), "home", step=3, mark=MQ, cap="Vuelve a abrir Yala desde la pantalla de inicio"),
        phone(paso_nombre(tap=False), "onb", step=4, mark=MQ, cap="Paso 1 de 7, como hoy")],
       ["Barato: copy y un botón", "Quita la sorpresa: sabe qué va a pasar", "El botón le ahorra buscar el ícono"],
       ["Sigue habiendo salida de la app", "Cerrar la app por programa es frágil y Apple lo desaconseja: revisarlo con la App Store"],
       L(("M", "ya no le parece un fallo"), ("M", "entiende antes; igual sale"), ("A", "sigue teniendo que salir"),
         ("B", "le da igual"), ("B", "su camino no pasa aquí"), ("M", "igual que hoy"), ("M", "el botón evita buscar el ícono")),
       esf="S", riesgo="Bajo-medio", conteo="Igual que hoy: 4 pantallas y 1 salida antes del paso 1",
       estado=[("nov", "Cerrar la app por programa: no validado con la revisión de la App Store")])

A2 = A("A2", "Diferir la conexión a iCloud", "src",
       "Empieza en local <b>sin reiniciar</b>; Yala se conecta a iCloud sola en la siguiente vez que la abra, con un aviso discreto.",
       [phone(icloud(), "onb", step=1, mark=MQ, cap="«Seguir así», como hoy"),
        phone(paso_nombre(tap=True).replace('class="otop"', 'class="otop"'), "onb", step=2, mark=MQ,
              cap="Entra <b>directo</b> al paso 1: no hay pantalla de reinicio"),
        phone(panel([note('<b style="color:#fff">Tus datos están en este iPhone.</b> La próxima vez que abras Yala se conectan solos con tu iCloud privado.', cls="chg"),
                      balance(), actions(), sec("Tus finanzas", right=""), acc_chips()]), "app", step=3, mark=MQ,
              cap="En el Panel, una línea discreta explica qué falta"),
        phone(panel([balance_after(), actions(),
                      sec("Últimos registros", right=""), rec("Almuerzo", "Alimentación", "18.50")]) + toast("Listo: Yala ya guarda en tu iCloud privado", cls="chg"),
              "app", step=4, mark=MQ, cap="Al día siguiente, la conexión se hace sola")],
       ["Elimina la salida en el momento más frágil", "Nada fuera de la app para nadie"],
       ["Durante la primera sesión los datos no están en iCloud", "Hay que migrar el almacenamiento con datos dentro", "Reabre la decisión L1-4"],
       L(("B", "no sale de la app"), ("B", "no sale de la app"), ("B", "va directo"), ("B", "va directo"), ("B", "sin cambios"),
         ("B", "no sale"), ("B", "nada fuera de la app")),
       esf="L", riesgo="Alto: arranque de SwiftData con CloudKit", reabre="L1-4",
       conteo="3 pantallas y 0 salidas antes del paso 1",
       estado=[("hip", "Que la conexión diferida funcione sin perder datos es hipótesis técnica"),
               ("nov", "Necesita review adversarial y su propio encargo")])

A3 = A("A3", "Recrear el almacenamiento sin salir", "src",
       "Tras la comprobación, Yala cambia <b>en caliente</b> a la configuración con iCloud y sigue: ni reinicio ni espera larga.",
       [phone(icloud(), "onb", step=1, mark=MQ, cap="«Seguir así», como hoy"),
        phone('<div style="height:200px"></div><div class="spinner chg"></div>'
              + head(None, "Preparando tu espacio privado…", "Unos segundos. No cierres Yala.")
              + '<div class="prog" style="margin:10px 30px"><i style="width:62%"></i></div>', "onb", step=2, mark=MQ,
              cap="Pantalla de espera <b>dentro</b> de la app"),
        phone(paso_nombre(tap=False), "onb", step=3, mark=MQ, cap="Paso 1 de 7")],
       ["Ni reinicio ni salida", "Una sola pantalla de espera"],
       ["Puede ser inviable: SwiftData con CloudKit no está pensado para cambiar de contenedor con la app viva",
        "Hay que probarlo antes de proponerlo en serio"],
       L(("B", "no sale"), ("B", "no sale"), ("B", "una espera corta"), ("B", "—"), ("B", "sin cambios"), ("B", "no sale"),
         ("B", "nada fuera de la app")),
       esf="L", riesgo="Alto", reabre="L1-4", conteo="3 pantallas y 0 salidas antes del paso 1",
       estado=[("hip", "Hipótesis técnica sin comprobar: necesita prueba de concepto")])

A4 = A("A4", "Reinicio al final", "src",
       "El onboarding se hace antes (en memoria) y el reinicio llega <b>después</b> de «Así queda tu Yala», como un «guardar».",
       [phone(paso_nombre(tap=True), "onb", step=1, mark=MQ, cap="Tras «Seguir así», directo al paso 1"),
        phone(resumen7(btn_text="Guardar y abrir mi Yala").replace('class="btn pri tap"', 'class="btn pri tap chg"'),
              "onb", step=2, mark=MQ, cap="Al final, el botón dice qué va a pasar"),
        phone('<div style="height:150px"></div>' + logo(.8)
              + head("check", "Listo, Ana. Tu Yala está guardada",
                     "Para terminar de conectarla con tu iCloud privado, Yala se abre de nuevo. Vuelve a entrar y verás tu Panel.", chg=True),
              "onb", step=3, mark=MQ, cap="La salida llega cuando ya invirtió y entiende para qué"),
        phone(hoy_panel_dia1(), "app", step=4, mark=MQ, cap="Vuelve y entra directo a su Panel")],
       ["La persona ya invirtió y sabe para qué es", "El reinicio se vive como «guardar»"],
       ["Lo escrito tiene que sobrevivir al reinicio", "Si no vuelve, lo perdió todo", "Reabre la decisión L1-4"],
       L(("B", "sale con todo hecho"), ("M", "sale al final, ya sabe para qué"), ("M", "se lo encuentra al final"),
         ("B", "—"), ("B", "sin cambios"), ("B", "—"), ("M", "sigue saliendo de la app")),
       esf="M-L", riesgo="Alto: estado entre arranques", reabre="L1-4", conteo="Paso 1 sin salir; 1 salida tras el resumen",
       estado=[("hip", "Que se viva como «guardar» es hipótesis")])

A5 = A("A5", "Juntar presentación y selector", "src",
       "El carrusel queda arriba y las tres opciones abajo, <b>en una sola pantalla</b>.",
       [phone('<div style="height:10px"></div>' + logo(.7)
              + '<div class="bigcard chg" style="margin:12px 20px;text-align:center;align-items:center">'
              + tint("users", "#38bdf8", 30) + '<b>Gastos compartidos</b><small>Reparte con quien sea.</small>'
              + '<div class="dd" style="justify-content:center;margin-top:4px"><i></i><i class="on"></i><i></i><i></i><i></i><i></i><i></i><i></i></div></div>'
              + '<h2 style="text-align:center;font-size:17px;margin:4px 0 10px">Tus finanzas personales, <span style="color:#ff4fa8">sin esfuerzo.</span></h2>'
              + group(opt("sparkle", "Es mi primera vez en Yala", "Empieza desde cero.", color="#ec4899", chev=True, cls="tap"),
                      opt("cloud", "Ya tengo una cuenta", "Recupera tus datos.", color="#38bdf8", chev=True),
                      opt("users", "Dividir gastos con amigos", "Crea un grupo o entra a uno.", color="#f59e0b", chev=True), cls="chg"),
              "onb", step=1, mark=MQ, cap="Una pantalla: presentación arriba, opciones abajo"),
        phone(icloud(), "onb", step=2, mark=MQ, cap="Comprobación de iCloud, como hoy"),
        phone(reabre(), "onb", step=3, mark=MQ, cap="El reinicio sigue")],
       ["Una pantalla menos (F2, F3)", "Barato y sin riesgo técnico"],
       ["La presentación pierde espacio", "Más texto a la vez: peor con texto grande (P7)", "No toca el reinicio"],
       L(("M", "el reinicio sigue"), ("A", "el reinicio sigue"), ("A", "sigue saliendo"), ("M", "una pantalla menos"),
         ("B", "ve su opción antes"), ("M", "igual"), ("A", "pantalla más cargada")),
       esf="S", riesgo="Bajo", conteo="3 pantallas y 1 salida antes del paso 1")

BIENVENIDA = dict(
    slug="01-bienvenida", num=1, titulo="Bienvenida y entrada", corto="Bienvenida",
    problema="Antes del primer paso, la persona recorre dos pantallas y tiene que <b>salir de Yala y volver a abrirla</b>.",
    fricciones="F1 reinicio obligatorio · F2 once pantallas · F3 dos pantallas antes de decidir",
    caso="Ana instala Yala en un iPhone <b>sin iCloud activo</b> y toca «Es mi primera vez».",
    hoy=[(C + "01-arranque.jpg", "Presentación: «Empezar»"), (C + "02-selector.jpg", "Selector: tres caminos"),
         (C + "03-primera-vez.jpg", "Sin iCloud: «Seguir así»"), (C + "04-reabre-yala.jpg", "<b>Sale</b> de la app y vuelve a abrirla"),
         (C + "05-onb-paso1-nombre.jpg", "Recién aquí empieza el paso 1 de 7")],
    hoy_nota="Capturas del 6-nov. Esta noche se repitió el camino en la build de 2.3 (simulador iPhone 17 Pro, sin iCloud): mismas pantallas y mismos textos, reinicio incluido.",
    hoy_lens=L(("M", "el reinicio le parece un fallo"), ("A", "no entiende por qué salir"), ("A", "lo deja ahí"), ("M", "molestia"),
               ("B", "su camino no pasa por aquí"), ("M", "molestia"), ("A", "instrucción fuera de la app")),
    alts=[A1, A2, A3, A4, A5],
    decide=dict(pregunta="¿Se toca el arranque del almacenamiento (A2, A3 o A4, que reabren L1-4) para quitar la única salida de la app, o se queda con lo barato (A1, A5) hasta medir cuánta gente no vuelve?",
                ejes=["<b>Riesgo técnico</b>: A2, A3 y A4 tocan SwiftData con CloudKit, la zona donde un bug sale más caro.",
                      "<b>Evidencia</b>: hoy nadie sabe cuántos se pierden en el reinicio; la pantalla no emite telemetría (F21).",
                      "<b>Se combinan</b>: A1 y A5 son compatibles entre sí y con cualquiera de las otras."]),
)

# =============================================================== 2. ONBOARDING
def moneda(step=2, total=3, tap=True):
    return (onb_top(step, total) + '<div style="height:44px"></div>'
            + head("dollar", "¿En qué moneda llevas tu dinero?", "La principal. Luego puedes sumar cuentas en otras monedas.")
            + group(f'<div class="lrow sel" style="background:#fff;color:#1b1747"><i class=fpe></i> <div class="lt"><span>Sol peruano</span></div><span class="lr" style="color:#4a4775">PEN</span>{ic("check", 12, sw=3)}</div>',
                    row("<i class=fus></i> Dólar estadounidense", "USD", chev=False), row("<i class=feu></i> Euro", "EUR", chev=False), row("Ver todas", "54", chev=True))
            + bottom(btn("Siguiente", cls="tap" if tap else "")))


B1 = A("B1", "Tres pasos y lo demás por defecto", "src",
       "Nombre → moneda → saldo. Una cuenta «Mi dinero», las categorías estándar y «Llevar el control» se crean solas y se cambian después.",
       [phone(paso_nombre(1, 3), "onb", step=1, mark=MQ, cap="Paso <b>1 de 3</b>: nombre"),
        phone(moneda(), "onb", step=2, mark=MQ, cap="Paso 2 de 3: moneda, con la del iPhone preelegida"),
        phone(paso_saldo(3, 3, zero_chip=True), "onb", step=3, mark=MQ, cap="Paso 3 de 3: saldo, con «0 por ahora» a la vista"),
        phone(hoy_panel_dia1() + toast("Creamos «Mi dinero Soles» y tus categorías. Cámbialo cuando quieras.", icon="check", cls="chg"),
              "app", step=4, mark=MQ, cap="Llega al Panel; un aviso dice qué se creó solo")],
       ["Llega al Panel en 4 pantallas desde el selector (F2, F8)", "Cada pregunta se entiende sin explicación"],
       ["Pierde la personalización temprana (tipo de cuenta, modo)", "Si «0 por ahora» hace el saldo opcional, reabre L1-7"],
       L(("M", "teclea menos; no importa"), ("B", "3 preguntas claras"), ("B", "corto de verdad"), ("B", "lo ajusta después"),
         ("N", "no pasa por aquí"), ("M", "solo una moneda al inicio"), ("B", "menos pantallas")),
       esf="M", riesgo="Medio: lo que se crea alimenta Panel, widgets y nube", reabre="L1-7 (solo si el saldo pasa a opcional)",
       conteo="3 preguntas (hoy, 7)")

B2 = A("B2", "Una sola pantalla", "src",
       "Un formulario único con nombre, moneda y saldo; el resto, plegado en «Personalizar más».",
       [phone(onb_top(back=False, close=True) + head(None, "Empecemos", "Tres datos y entras a tu Yala.")
              + field("¿Cómo te llamamos?", "Ana") + field("Moneda", "<i class=fpe></i> Sol peruano · PEN")
              + field("¿Cuánto tienes hoy?", "1,500", unit="S/")
              + f'<div class="lrow chg" style="margin-top:8px;border-radius:12px;background:rgba(255,255,255,.06)">{ic("chev-d", 12)}<div class="lt"><span>Personalizar más</span><small>Tipo de cuenta, uso y categorías</small></div></div>'
              + bottom(btn("Empezar", cls="tap")), "onb", step=1, mark=MQ, cap="Todo en una pantalla"),
        phone(onb_top(back=False, close=True) + head(None, "Empecemos", "")
              + field(None, "Ana") + field(None, "<i class=fpe></i> Sol peruano · PEN") + field(None, "1,500", unit="S/")
              + '<div class="flab">Tipo de cuenta</div>' + chips(["Todo junto", "Banco", "Ahorros", "Tarjeta", "Efectivo"], ("Todo junto",))
              + '<div class="flab">Uso</div>' + seg(["Llevar el control", "Solo anotar"], 0)
              + '<div class="flab">Categorías</div>' + seg(["Recomendadas", "Las creo yo"], 0)
              + bottom(btn("Empezar")), "onb", step=2, mark=MQ, cap="Si abre «Personalizar más», ve todo junto"),
        phone(hoy_panel_dia1(), "app", step=3, mark=MQ, cap="Panel")],
       ["Lo más corto posible", "P3 y P4 contentos"],
       ["Una pantalla densa es peor para P2 y P7", "Pierde el tono de acompañamiento"],
       L(("B", "rápido"), ("M", "todo junto abruma"), ("B", "lo más rápido"), ("B", "va directo"), ("N", "no pasa por aquí"),
         ("M", "la moneda queda escondida"), ("A", "pantalla densa con texto grande")),
       esf="M", riesgo="Medio", conteo="1 pantalla (hoy, 7)")


def chat_head():
    return '<div class="otop"><span class="circ">' + ic("x", 12, sw=2.6) + '</span><span class="sp"></span><span class="pill">Armando tu Yala · 2 de 6</span><span class="sp"></span><span style="width:28px"></span></div>'


def who():
    return '<div class="who"><i></i>Yala</div>'


B4 = A("B4", "Conversación guionizada, sin IA (V3)", "src",
       "Las mismas preguntas en forma de conversación: Yala escribe, la persona responde con botones y puede tocar «¿Qué es esto?». <b>Sin mascota y sin IA</b>: cada texto está escrito de antemano.",
       [phone(chat_head() + who() + bubble("¡Hola! Te hago unas preguntas y dejamos tu Yala lista. ¿Cómo te llamo?")
              + bubble("Ana", "me") + who() + bubble("Encantada, Ana. ¿Para qué quieres usar Yala?")
              + '<div class="chips" style="justify-content:flex-end;margin-top:6px"><span class="chip on tap">Llevar el control de mi dinero</span><span class="chip">Solo anotar gastos</span></div>',
              "chat", step=1, mark=MQ, cap="Nombre y uso, respondidos con un toque"),
        phone(chat_head() + bubble("Llevar el control de mi dinero", "me") + who()
              + bubble("¿Dónde tienes tu dinero? Si no estás segura, elige «Todo junto».")
              + '<div class="chips" style="justify-content:flex-end"><span class="chip on">Todo junto</span><span class="chip">Banco</span><span class="chip">Tarjeta</span><span class="chip">Efectivo</span></div>'
              + f'<div style="text-align:right;margin-top:8px"><span class="chip tap" style="background:transparent;color:#a5a6ff">{ic("question", 11)} ¿Qué es esto?</span></div>'
              + bubble("<b>Cuenta corriente</b> es la de tu banco para el día a día. <b>Todo junto</b> junta todo tu dinero en una sola cuenta: lo puedes separar después.", "info chg"),
              "chat", step=2, mark=MQ, cap="«¿Qué es esto?» explica sin salir de la pregunta"),
        phone(chat_head() + bubble("Todo junto", "me") + who()
              + bubble("Creo «Mi dinero Soles» en soles. ¿Cuánto hay ahí más o menos?")
              + '<div class="fld big" style="margin-top:8px"><span class="funit">S/</span><span class="fv">1,500</span></div>'
              + '<div class="chips" style="justify-content:flex-end;margin-top:6px"><span class="chip">No lo sé, ayúdame</span><span class="chip on tap">Listo</span></div>',
              "chat", step=3, mark=MQ, cap="El saldo sigue en un campo explícito"),
        phone(chat_head().replace("2 de 6", "6 de 6") + who() + bubble("¡Listo, Ana! Así queda tu Yala:")
              + group(row("Mi dinero Soles", "S/ 1,500", icon="card", color="#5b5cf0", chev=False),
                      row("Categorías comunes", "11", icon="grid", color="#ec4899", chev=False),
                      row("Llevar el control", "", icon="target", color="#22b35e", chev=False))
              + bubble("Tus datos quedan en este iPhone y en tu iCloud. Nadie más los lee.")
              + bottom(btn("Empezar a usar Yala", cls="tap")), "chat", step=4, mark=MQ, cap="Cierra con el resumen dentro de la conversación")],
       ["Cercano para quien duda (P2)", "Explica sin costo ni red", "100 % predecible: textos revisados en 16 idiomas"],
       ["No acorta: son las mismas preguntas", "P3 y P4 lo viven como más lento", "VoiceOver en una conversación pide diseño cuidadoso", "Mucho texto nuevo que traducir"],
       L(("M", "igual de largo"), ("B", "le explican cada término"), ("A", "más lento que un formulario"), ("M", "conversación lenta"),
         ("N", "no pasa por aquí"), ("M", "puede preguntar por la tarjeta"), ("M", "burbujas largas; VoiceOver por diseñar")),
       esf="M-L", riesgo="Medio", conteo="6 preguntas en 1 conversación (hoy, 7 pantallas)",
       estado=[("hip", "Que ayude a P2 y estorbe a P3 y P4 es hipótesis: la prueba de pasillo lo confirma o lo tumba")])

B5 = A("B5", "Plantillas por intención", "src",
       "El paso de uso ofrece 3-4 puntos de partida; cada uno preconfigura pasos, Panel, categorías y la guía.",
       [phone(onb_top(2, 4) + '<div style="height:40px"></div>' + head("target", "¿Para qué vas a usar Yala?", "Te dejamos todo listo para eso. Puedes cambiarlo luego.")
              + '<div class="cards2 chg">'
              + '<div class="bigcard">' + tint("edit", "#f59e0b", 26) + '<b>Solo anotar mis gastos</b><small>Rápido, sin presupuestos</small></div>'
              + '<div class="bigcard on tap">' + tint("target", "#5b5cf0", 26) + '<b>Controlar mi sueldo</b><small>Cuánto entra, cuánto sale y límites</small></div>'
              + '<div class="bigcard">' + tint("import", "#22b35e", 26) + '<b>Vengo de Excel</b><small>Trae tus cuentas y movimientos</small></div>'
              + '<div class="bigcard">' + tint("piggy", "#ec4899", 26) + '<b>Ahorrar para algo</b><small>Una meta y cuánto te falta</small></div></div>',
              "onb", step=1, mark=MQ, cap="Elige un punto de partida, no una configuración"),
        phone(onb_top(3, 4) + '<div style="height:40px"></div>' + head("check", "Te preparamos esto", "Para «Controlar mi sueldo»")
              + group(row("Panel con balance y límite del mes", "", icon="grid", color="#5b5cf0", chev=False),
                      row("Categorías de uso diario", "6", icon="food", color="#22b35e", chev=False),
                      row("Guía de 4 pasos", "", icon="list", color="#f59e0b", chev=False), cls="chg")
              + bottom(btn("Seguir", cls="tap")), "onb", step=2, mark=MQ, cap="Ve qué se configura antes de aceptarlo"),
        phone(paso_saldo(4, 4), "onb", step=3, mark=MQ, cap="Saldo, como hoy"),
        phone(panel([balance(), actions(),
                     widget("Límite del mes", empty("calendar", "Ponle un tope a lo que gastas", action="Crear límite"), cls="chg"),
                     sec("Tus finanzas", right=""), acc_chips()]), "app", step=4, mark=MQ, cap="Panel ya pensado para controlar el sueldo")],
       ["Cada perfil ve menos", "Base del revelado progresivo", "«Vengo de Excel» abre la puerta a importar (E4)"],
       ["Más combinaciones que probar", "La persona puede no reconocerse en ninguna", "Panel por defecto distinto por plantilla: viaja a la nube"],
       L(("B", "«Vengo de Excel» lo lleva a importar"), ("M", "puede no reconocerse"), ("B", "«Solo anotar» es corto"),
         ("B", "elige lo suyo"), ("N", "no pasa por aquí"), ("M", "falta «varias monedas»"), ("B", "menos cosas en pantalla")),
       esf="M", riesgo="Medio: Panel por defecto distinto por plantilla", conteo="4 preguntas, con Panel a medida")

B6 = A("B6", "Mejorar lo actual sin recortar", "src",
       "Los mismos 7 pasos con tres arreglos: «Todo junto» preelegido con una línea de ayuda por tipo, y un resumen que describe el camino privado.",
       [phone(onb_top(3, 7) + '<div style="height:40px"></div>' + head("wallet", "¿Dónde está tu dinero?", "Elige con qué cuenta empiezas. Luego puedes agregar más.")
              + group(opt("wallet", "Todo junto en una sola cuenta", "Recomendado si no estás segura", checked=True, color="#ec4899", cls="chg"),
                      opt("bank", "Cuenta corriente", "La del banco que usas a diario", color="#ec4899"),
                      opt("piggy", "Ahorros", "Lo que no tocas", color="#38bdf8"),
                      opt("card", "Tarjeta de crédito", "Lo que debes al banco por tus compras", color="#a855f7"))
              + bottom(btn("Siguiente", cls="tap")), "onb", step=1, mark=MQ, cap="«Todo junto» ya viene elegido: Siguiente se activa solo"),
        phone(paso_saldo(5, 7), "onb", step=2, mark=MQ, cap="El saldo, igual que hoy"),
        phone(resumen7(priv=[("phone", "En este iPhone y tu iCloud"), ("eye", "Sin rastreo ni anuncios"), ("user", "Sin cuenta ni registro"),
                             ("sparkle", "Yala IA solo si la activas")], chg_priv=True), "onb", step=3, mark=MQ,
              cap="El resumen habla del camino que eligió (F7)")],
       ["Barato", "No reabre nada", "Arregla el texto del resumen (F7)"],
       ["No ataca el largo (F2, F8)", "Sigue el «0 de 7» después"],
       L(("M", "igual de largo"), ("M", "ayuda en cada tipo"), ("M", "sigue largo"), ("B", "—"), ("N", "no pasa por aquí"),
         ("A", "sigue igual"), ("M", "7 pantallas")),
       esf="S", riesgo="Bajo", conteo="7 pasos (sin cambio)")

CATS_EXTRA = dict(
    titulo="Pieza que se suma a cualquiera: las categorías (F6)",
    sub="Hoy se siembran 11 grupos y 62 subcategorías sin preguntar. Dos formas de bajar el número que ve la persona:",
    screens=[
        phone(sheet_top("Categoría", right=None) + sh_sec("Las de todos los días")
              + group(*[row(n, "", icon=CAT[n][0], color=CAT[n][1]) for n in ["Alimentación", "Transporte", "Compras", "Hogar", "Entretenimiento", "Personal"]], cls="chg")
              + group(row("Ver todas", "11", icon="list", color="#64748b")),
              "sheet", label="(a) Enseñar 6, guardar 11", mark=MQ, cap="Se siembran las 11 igual; el selector muestra primero las 6 de uso diario. <b>No cambia datos</b>."),
        phone(onb_top(6, 7) + '<div style="height:40px"></div>' + head("grid", "¿En qué gastas más?", "Elige las que usas. «Otros» va siempre.")
              + '<div class="chips chg" style="justify-content:center">' + "".join(
                  f'<span class="chip{" on" if n in ("Alimentación", "Transporte", "Hogar", "Servicios") else ""}">{n}</span>'
                  for n in ["Alimentación", "Transporte", "Hogar", "Servicios", "Compras", "Salud", "Entretenimiento", "Educación"]) + '</div>'
              + bottom(btn("Siguiente")), "onb", label="(b) Preguntar y sembrar solo esas", mark=MQ,
              cap="Cambia lo que se siembra: afecta a la nube y a los nombres por idioma"),
    ])

V_EXTRA = dict(
    titulo="El onboarding conversacional: IA, guion o mezcla",
    sub="B4 es la forma «guion» (V3). Estas son las otras tres maneras de conversar que estudió la revisión, con el mismo momento: Ana no sabe qué es «cuenta corriente».",
    screens=[
        phone(chat_head() + who() + bubble("¿Dónde tienes tu dinero?") + bubble("no sé, en el banco y un poco en efectivo creo", "me")
              + who() + bubble("Entiendo: creo «Banco» y «Efectivo». ¿Cuánto hay en cada una?")
              + note(f'{ic("wifi", 11)} Necesita conexión, el servidor de Yala y App Attest. Nombre y saldo salen del teléfono <b>antes</b> del consentimiento de IA.', cls="chg")
              + '<div class="fld" style="position:absolute;left:14px;right:14px;bottom:24px"><span class="fph">Escribe tu respuesta…</span></div>',
              "chat", label="V1 · IA en servidor", mark=MQ, cap="Texto libre que entiende un modelo en el servidor"),
        phone(chat_head() + who() + bubble("¿Dónde tienes tu dinero?") + bubble("no sé, en el banco y un poco en efectivo creo", "me")
              + who() + bubble("Entiendo: creo «Banco» y «Efectivo». ¿Cuánto hay en cada una?")
              + note(f'{ic("phone", 11)} Procesado en tu iPhone. Solo en aparatos con Apple Intelligence; en el resto, el guion de B4.', cls="chg")
              + '<div class="fld" style="position:absolute;left:14px;right:14px;bottom:24px"><span class="fph">Escribe tu respuesta…</span></div>',
              "chat", label="V2 · IA en el dispositivo", mark=MQ, cap="Igual por fuera; nada sale del teléfono"),
        phone(chat_head() + who() + bubble("¿Dónde tienes tu dinero?")
              + '<div class="chips" style="justify-content:flex-end"><span class="chip">Todo junto</span><span class="chip">Banco</span><span class="chip">Tarjeta</span></div>'
              + f'<div style="text-align:right;margin-top:8px"><span class="chip tap chg">{ic("sparkle", 11)} Pregúntale a Yala</span></div>',
              "chat", label="V4 · Mixto (paso 1)", mark=MQ, cap="El guion de siempre, más un botón para preguntar"),
        phone(chat_head() + dim() + '<div style="position:absolute;left:0;right:0;bottom:0;z-index:8;background:#16151f;border-radius:22px 22px 0 0;padding:16px 14px 30px">'
              + head("sparkle", "¿Usar Yala IA para esta duda?", "Tu pregunta se envía a nuestro servidor para responderla. Tu nombre y tu saldo no se envían.")
              + btn("Preguntar con Yala IA") + btn("Ver la explicación escrita", "sec") + '</div>',
              "chat", label="V4 · Mixto (paso 2)", mark=MQ, cap="La IA solo con consentimiento en ese momento"),
    ],
    tabla=[("Opción", "Costo de IA", "Sin conexión", "Privacidad", "Riesgo propio"),
           ("V1 · IA en servidor", "Por cada alta, también las que nunca se activan; hoy el plan gratis no tiene chat", "No funciona", "Datos fuera antes del consentimiento", "Puede entender mal un importe"),
           ("V2 · IA en el dispositivo", "Cero", "Funciona", "Nada sale", "Solo en aparatos compatibles: dos caminos que mantener"),
           ("V3 · Guion (B4)", "Cero", "Funciona", "Nada sale", "Más texto; no responde preguntas libres"),
           ("V4 · Mixto", "Solo cuando se usa", "El guion siempre funciona", "IA solo con consentimiento", "Más piezas; la respuesta debe ceñirse al paso"),
           ("V5 · Formulario mejorado (B1/B6)", "Cero", "Funciona", "Nada sale", "No responde dudas")],
    nota="Datos de partida medidos en el código por la revisión: Yala IA es Pro; el plan gratis no tiene chat en el servidor; no hay medida del costo de una conversación de onboarding. Esta guía no añade cifras.",
)

ONBOARDING = dict(
    slug="02-onboarding", num=2, titulo="Onboarding", corto="Onboarding",
    problema="Siete preguntas antes de ver la app, con el saldo obligatorio en la quinta, y al llegar otra lista de «0 de 7».",
    fricciones="F4 saldo · F5 tipos de cuenta · F6 62 subcategorías · F7 resumen · F8 «7 + 7»",
    caso="Ana se llama Ana, usa soles, tiene unos <b>S/ 1,500</b> en una cuenta y <b>no sabe qué es «cuenta corriente»</b>.",
    hoy=[(C + "05-onb-paso1-nombre.jpg", "1 de 7 · nombre"), (C + "06-onb-paso2.jpg", "2 de 7 · uso"),
         (C + "07-onb-paso3-cuentas.jpg", "3 de 7 · nada preelegido"), (C + "08-onb-paso4.jpg", "4 de 7 · cuenta y moneda"),
         (C + "09-onb-paso5-saldo.jpg", "5 de 7 · saldo obligatorio"), (C + "10-onb-paso6.jpg", "6 de 7 · categorías en bloque"),
         (C + "11-onb-paso7-resumen.jpg", "7 de 7 · «Datos en tu cuenta» sin tener cuenta")],
    hoy_nota="Capturas del 6-nov. Esta noche se recorrieron de nuevo en la build de 2.3: mismos pasos y mismos textos.",
    hoy_lens=L(("M", "quiere importar, no teclear"), ("A", "saldo y tipos de cuenta"), ("M", "5 pasos con «Solo anotar»"), ("B", "lo pasa rápido"),
               ("N", "no pasa por aquí"), ("A", "una moneda «principal», saldo de tarjeta"), ("M", "7 pantallas largas")),
    alts=[B1, B2, B4, B5, B6],
    extras=[CATS_EXTRA, V_EXTRA],
    decide=dict(pregunta="¿El alta se acorta (B1, B2, B5) o se acompaña más (B4)? Y, en cualquier caso, ¿el saldo sigue obligatorio?",
                ejes=["<b>B4 compite con B1/B5, no se suma</b>: las dos familias rehacen el onboarding. Hay que elegir una.",
                      "<b>B6 es independiente</b>: arregla el texto y la preselección sin acortar; vale como paso intermedio.",
                      "<b>La IA (V1)</b> no sirve como camino principal: no funciona sin conexión y saca datos antes del consentimiento. Si se quiere, va como V4."]),
)
