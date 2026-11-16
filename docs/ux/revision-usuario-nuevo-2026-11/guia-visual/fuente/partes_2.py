"""Partes 3 y 4: primer Panel y Primeros pasos."""
from partes_1 import A, L, C, SIM
from pantallas import *

# =============================================================== 3. PRIMER PANEL
def steps_d1(prog="0 de 7 completados", cls=""):
    return steps_card("Primeros pasos", prog, next_step="Registra tu primer gasto", foot=("Ver los pasos ⌄", "Minimizar ⌃"), cls=cls)


def tend_text(cls="chg"):
    return widget("Saldo", empty("bars", "Con registros en 3 días distintos verás cómo cambia tu saldo.", cls=""), cls=cls)


C1 = A("C1", "Panel del día 1 reducido", "src",
       "Hasta el primer registro, el Panel enseña solo el balance, «Nuevo registro», Primeros pasos y las cuentas. Tendencias, Planificación y Últimos registros <b>aparecen cuando tienen algo que mostrar</b>.",
       [phone(panel([balance(), actions(tap_new=True), steps_d1(), sec("Tus finanzas", right=""), acc_chips(),
                     '<div class="mini center chg" style="margin-top:14px;padding:8px;border-radius:10px">Tendencias, Planificación y Últimos registros aparecen cuando tengas datos</div>']),
              "app", step=1, mark=MQ, cap="Día 1: nada vacío a la vista"),
        phone(registro_sheet(), "sheet", step=2, mark=MQ, cap="Anota «Almuerzo», S/ 18.50"),
        phone(panel([balance_after(), actions(), sec('Últimos registros<span class="badge">NUEVO</span>', right="", cls="chg"),
                     rec("Almuerzo", "Alimentación", "18.50"), steps_d1("1 de 7 completados"), sec("Tus finanzas", right=""), acc_chips()]),
              "app", step=3, mark=MQ, cap="Con el primer gasto aparece «Últimos registros»"),
        phone(panel([balance(amount="−96", cents="30", note1="Gastaste S/ 96.30 este mes", note2="Te quedan S/ 1,403.70", out="96.30"), actions(),
                     sec('Tendencias<span class="badge">NUEVO</span>', right="", cls="chg"), widget("Saldo", chart([.9, .82, .7], height=60)),
                     sec("Últimos registros", right=""), rec("Taxi", "Transporte", "22.00"), rec("Mercado", "Alimentación", "55.80")]),
              "app", step=4, mark=MQ, cap="Con registros en 3 días, aparece Tendencias")],
       ["Nada vacío a la vista (F12)", "Un solo camino claro el día 1"],
       ["Quien quiere verlo todo no sabe que existe", "Hay que decidir cuándo aparece cada sección (umbrales sin medir)",
        "La configuración del Panel viaja entre aparatos"],
       L(("M", "no ve gráficas hasta tener datos"), ("B", "un solo camino"), ("B", "solo usa Nuevo registro"), ("M", "no sabe que existe Tendencias"),
         ("B", "menos ruido"), ("M", "las monedas aparecen con los datos"), ("B", "menos cosas en pantalla")),
       esf="M", riesgo="Medio: PanelDefaults y su sincronización", conteo="Día 1: 4 bloques a la vista (hoy, 7)",
       estado=[("hip", "Umbrales («3 días distintos») propuestos, no medidos")])

C2 = A("C2", "Estados vacíos con acción", "src",
       "Cada sección vacía dice para qué sirve y trae <b>su botón</b>. Tendencias dice cuándo tendrá sentido en vez de dibujar un punto.",
       [phone(panel([balance(), actions(), sec("Tendencias", right=""), tend_text()], title=None), "app", step=1, mark=MQ,
              cap="Tendencias explica cuándo tendrá datos"),
        phone(ptop("Panel de Ana") + sec("Planificación", right="")
              + '<div class="wrow">' + widget("Pagos planificados", empty("calendar", "¿Pagas algo cada mes?", action="Agregar"), cls="chg")
              + widget("Presupuestos", empty("calendar", "Ponle un límite a tus gastos", action="Crear").replace('class="btn pri sm"', 'class="btn pri sm tap"'), cls="chg") + '</div>'
              + sec("Últimos registros", right="") + widget("Registros", empty("list", "Aún no anotas nada", action="Nuevo registro"), cls="chg", q=False)
              + tabbar(), "app", step=2, mark=MQ, cap="Cada vacío trae su botón"),
        phone(presupuesto_hoy(), "sheet", step=3, mark=MQ, cap="El botón abre el editor de presupuesto"),
        phone(ptop("Panel de Ana") + sec("Planificación", right="")
              + '<div class="wrow">' + widget("Pagos planificados", empty("calendar", "¿Pagas algo cada mes?", action="Agregar"))
              + widget("Presupuestos", '<div style="font-size:10.5px;margin-top:4px"><b>Comida</b><div class="pbar"><i style="width:3%"></i></div><small style="color:rgba(255,255,255,.6)">S/ 18.50 de S/ 600</small></div>') + '</div>'
              + sec("Últimos registros", right="") + rec("Almuerzo", "Alimentación", "18.50") + tabbar(), "app", step=4, mark=MQ,
              cap="El presupuesto ya está en el Panel")],
       ["Ataca F11 de frente: «no encuentro cómo crear»", "Barato", "No esconde nada"],
       ["Más botones en un Panel que ya tiene «Nuevo registro»", "Copy nuevo en 16 idiomas"],
       L(("B", "ve qué puede crear"), ("B", "cada vacío dice qué hacer"), ("B", "lo ignora"), ("B", "va directo"), ("M", "botones que no le tocan"),
         ("M", "igual que hoy"), ("M", "más botones con texto grande")),
       esf="S", riesgo="Bajo", conteo="1 toque del Panel al editor de presupuesto (hoy: 2, en otra pestaña)")

C3 = A("C3", "Gráficas de ejemplo", "src",
       "Las gráficas vacías dibujan un <b>ejemplo atenuado</b> rotulado «Ejemplo» hasta que haya datos reales.",
       [phone(panel([balance(), actions(), sec("Tendencias", right=""), widget("Saldo", chart([.4, .55, .5, .7, .62, .8], example=True, height=70), cls="chg"),
                     sec("Planificación", right=""),
                     widget("Presupuestos", '<span class="exl" style="position:static;display:inline-block">EJEMPLO</span><div style="font-size:10.5px;margin-top:4px;opacity:.55"><b>Comida</b><div class="pbar"><i style="width:53%"></i></div><small>S/ 320 de S/ 600</small></div>', cls="chg")]),
              "app", step=1, mark=MQ, cap="Día 1: ejemplos atenuados con su rótulo"),
        phone(panel([balance(amount="−96", cents="30", note1="Gastaste S/ 96.30 este mes", note2="Te quedan S/ 1,403.70", out="96.30"), actions(),
                     sec("Tendencias", right=""), widget("Saldo", chart([.9, .82, .7], height=70)), sec("Planificación", right=""),
                     widget("Presupuestos", empty("calendar", "Aún no tienes presupuestos"))]),
              "app", step=2, mark=MQ, cap="Con datos, la línea real reemplaza al ejemplo")],
       ["Enseña para qué sirve cada gráfica"],
       ["En finanzas, un número que no es tuyo puede leerse como tuyo", "Va contra el cuidado con las cifras que la app ya tiene (la marca ≈)",
        "VoiceOver tiene que decir «ejemplo» en cada cifra"],
       L(("M", "entiende la gráfica"), ("A", "puede creer que el ejemplo es suyo"), ("B", "no mira"), ("M", "le sobra"), ("M", "confunde"),
         ("A", "cifras ajenas, con monedas"), ("M", "VoiceOver debe decir «ejemplo»")),
       esf="S-M", riesgo="Medio-alto: confusión con datos reales", conteo="Igual que hoy",
       estado=[("hip", "Que se lea como dato propio es el riesgo; sin prueba de pasillo no se sabe cuánto")])

C4 = A("C4", "Orden de avisos del día 1", "src",
       "Primeros pasos va <b>primero</b>; «Este es tu resumen» se funde con él; la oferta Pro espera al primer registro.",
       [phone(panel([balance(), actions(),
                     steps_card("Primeros pasos", "Aquí ves cuánto gastas y cuánto te queda. Empieza por aquí:", next_step="Registra tu primer gasto",
                                foot=("Aviso 1 de 2", "Ver el siguiente ›"), cls="chg"),
                     sec("Tus finanzas", right=""), acc_chips()]), "app", step=1, mark=MQ,
              cap="Lo primero que ve es la guía, sin tocar nada"),
        phone(panel([balance_after(), actions(), notice("Lleva tus finanzas al siguiente nivel", "Voz, foto, resumen con IA y cuentas ilimitadas.",
                                                        tag="PRO", cls="pro chg", foot=("Aviso 2 de 2", "Ver el siguiente ›"), btn_text="Ver Yala Pro"),
                     sec("Últimos registros", right=""), rec("Almuerzo", "Alimentación", "18.50")]),
              "app", step=2, mark=MQ, cap="La oferta Pro llega después del primer gasto")],
       ["Ataca F9 y F10", "Coherente con L1-12, que alejó la oferta del final del alta", "Barato"],
       ["Menos exposición a Pro el día 1"],
       L(("M", "igual"), ("B", "ve la guía primero"), ("B", "sin cambios para él"), ("B", "sin oferta el día 1"), ("M", "—"),
         ("M", "—"), ("B", "un aviso menos")),
       esf="S", riesgo="Bajo", conteo="Primeros pasos con 0 toques (hoy, tras «Ver el siguiente»)")

C5 = A("C5", "Interruptor «Panel simple»", "src",
       "Un modo del Panel con solo balance, acciones y últimos registros, que la persona activa o apaga en Configurar Panel.",
       [phone(sheet_top("Configurar Panel", right_on=True) + group(toggle_row("Panel simple", True, "Solo balance, acciones y últimos registros", cls="chg tap"))
              + sh_sec("Secciones") + group(*[f'<div class="lrow" style="opacity:.4">{ic("lines", 12)}<div class="lt"><span>{n}</span></div></div>'
                                              for n in ["Tus finanzas", "Tendencias", "Planificación", "Salud", "Distribución"]]),
              "sheet", step=1, mark=MQ, cap="Se activa en Configurar Panel"),
        phone(panel([balance_after(), actions(), sec("Últimos registros", right=""), rec("Almuerzo", "Alimentación", "18.50")]),
              "app", step=2, mark=MQ, cap="El Panel queda en lo esencial")],
       ["Da control", "Útil también a P7"],
       ["Otra preferencia que mantener", "No resuelve el día 1 si no viene activado"],
       L(("M", "lo ve todo si no lo activa"), ("M", "solo si lo encuentra"), ("B", "ideal"), ("B", "elige"), ("M", "—"), ("M", "—"),
         ("B", "si lo encuentra")),
       esf="M", riesgo="Bajo-medio", conteo="2 toques para activarlo; no cambia el día 1")

PANEL = dict(
    slug="03-primer-panel", num=3, titulo="Primer Panel", corto="Panel",
    problema="El día 1 el Panel enseña secciones vacías <b>sin botón</b>, una gráfica de <b>un solo punto</b> y una oferta Pro, y la guía queda en el aviso 2 de 3.",
    fricciones="F9 guía detrás · F10 Pro el día 1 · F11 vacíos sin acción · F12 gráfica de un punto",
    caso="Ana acaba de terminar el alta: <b>S/ 1,500</b> en una cuenta y cero registros. Después anota <b>«Almuerzo» S/ 18.50</b>.",
    hoy=[(C + "12-primer-panel.jpg", "Aviso 1 de 3: «Este es tu resumen»"), (C + "13-aviso-2-primeros-pasos.jpg", "Primeros pasos es el aviso 2"),
         (C + "14-aviso-3-pro.jpg", "Aviso 3: oferta Pro el día 1"), (C + "19-panel-widgets-vacios.jpg", "Planificación vacía, sin botón"),
         (C + "20-tendencias-vacia.jpg", "Tendencias con un solo punto"),
         (SIM + "sim-01-panel-dia1-finanzas-plegada.jpg", "Build de 2.3: «Tus finanzas» plegada", ("obs", "Simulador hoy"))],
    hoy_nota="Capturas del 6-nov y, la última, del simulador esta noche con la build de 2.3: avisos, candados en Voz y Foto y la gráfica de un punto siguen iguales. Cambia «Tus finanzas»: en una instalación nueva salió <b>plegada</b>, con chips.",
    hoy_extra="",
    hoy_lens=L(("M", "gráficas sin datos"), ("A", "no sabe qué tocar primero"), ("B", "solo usa «Nuevo registro»"), ("M", "candados y oferta Pro"),
               ("M", "—"), ("M", "—"), ("M", "avisos en carrusel")),
    alts=[C1, C2, C3, C4, C5],
    decide=dict(pregunta="¿Qué hace el Panel del día 1 con lo vacío: lo esconde (C1), lo explica con un botón (C2) o dibuja un ejemplo (C3)?",
                ejes=["<b>C4 se suma a cualquiera</b>: es solo el orden de los avisos, barato y sin riesgo.",
                      "<b>C1 y C2 se combinan bien</b>: lo que aparece, aparece con su botón.",
                      "<b>C3 choca con el cuidado con las cifras</b>: es la única opción con riesgo de leer un dato ajeno como propio."]),
)

# =============================================================== 4. PRIMEROS PASOS
def d1_card(prog, items, nxt="Registra tu primer gasto", cls="chg"):
    return steps_card("Primeros pasos", prog, next_step=nxt, items=items, foot=None, cls=cls, btn_text="Empezar")


D1 = A("D1", "Solo lo que construye tus finanzas", "src",
       "La guía baja a <b>4 pasos que dejan algo útil</b>: primer gasto, presupuesto, pago que se repite y otra cuenta. Voz y foto pasan a una sugerencia aparte; Ajustes y Pro salen de la lista.",
       [phone(panel([balance(), actions(), d1_card("0 de 4", [("now", "Registra tu primer gasto"), ("todo", "Ponle un límite al mes"),
                                                             ("todo", "Agrega un pago que se repite"), ("todo", "Agrega otra cuenta")])]),
              "app", step=1, mark=MQ, cap="4 pasos, todos construyen algo"),
        phone(panel([balance_after(), actions(), d1_card("1 de 4", [("done", "Registra tu primer gasto"), ("now", "Ponle un límite al mes"),
                                                                   ("todo", "Agrega un pago que se repite"), ("todo", "Agrega otra cuenta")],
                                                         nxt="Ponle un límite al mes")]),
              "app", step=2, mark=MQ, cap="Tras «Almuerzo», el siguiente es el presupuesto"),
        phone(panel([balance(amount="−96", cents="30", note1="Gastaste S/ 96.30 este mes", note2="3 registros", out="96.30"), actions(),
                     notice("¿Y si lo dices en voz alta?", "Ya anotaste 3 gastos. Prueba decir «almuerzo 18 con 50».", tag="SUGERENCIA", cls="chg", btn_text="Probar con la voz")]),
              "app", step=3, mark=MQ, cap="Voz y foto llegan como sugerencia al tercer registro")],
       ["Cada paso deja algo útil (F13)", "La lista es más corta"],
       ["Menos descubrimiento de funciones Pro", "Reabre en parte L5-1, que fijó el orden de los 7"],
       L(("M", "le falta «importar»"), ("B", "cada paso deja algo"), ("M", "aún hay lista"), ("M", "aún hay lista"), ("B", "—"),
         ("B", "incluye otra cuenta"), ("B", "lista más corta")),
       esf="S", riesgo="Bajo", reabre="L5-1 (en parte)", conteo="4 pasos (hoy, 7)")

D2 = A("D2", "Guía según lo que eligió", "src",
       "Los pasos salen de lo elegido en el alta: «Solo anotar» ve 2; «Llevar el control» ve 4.",
       [phone(panel([balance(), actions(), d1_card("0 de 2", [("now", "Registra tu primer gasto"), ("todo", "Mira en qué gastaste")])]),
              "app", label="Si eligió «Solo anotar»", step=1, mark=MQ, cap="Dos pasos, sin presupuestos"),
        phone(panel([balance(), actions(), d1_card("0 de 4", [("now", "Registra tu primer gasto"), ("todo", "Ponle un límite al mes"),
                                                             ("todo", "Agrega un pago que se repite"), ("todo", "Agrega otra cuenta")])]),
              "app", label="Si eligió «Llevar el control»", step=2, mark=MQ, cap="Cuatro pasos, como D1")],
       ["P3 no ve presupuestos que no quiere", "Barato si se apoya en el paso de uso que ya existe"],
       ["Más casos que probar", "Necesita B5 o, al menos, el paso 2 de hoy"],
       L(("M", "según lo que elija"), ("B", "lo justo"), ("B", "2 pasos"), ("B", "4 pasos útiles"), ("B", "—"), ("M", "—"), ("B", "menos pasos")),
       esf="S-M", riesgo="Bajo", conteo="2 o 4 pasos según el uso",
       estado=[("hip", "Los 2 pasos de «Solo anotar» son ilustrativos: la revisión no los fija")])

D3 = A("D3", "Sin lista: la siguiente acción", "src",
       "No hay tarjeta de N pasos. Después de cada logro aparece <b>una sola sugerencia</b>, en el momento en que tiene sentido.",
       [phone(panel([balance_after(), actions(),
                     notice("Primer gasto anotado", "¿Le pones un límite a tu comida del mes? Yala te avisa antes de pasarte.", tag="SIGUIENTE",
                            cls="chg", btn_text="Poner un límite"),
                     sec("Últimos registros", right=""), rec("Almuerzo", "Alimentación", "18.50")]),
              "app", step=1, mark=MQ, cap="Tras el primer gasto: una sugerencia, no una lista"),
        phone(panel([balance_after(), actions(),
                     notice("Límite de Comida listo", "¿Pagas algo cada mes, como el alquiler? Te avisamos antes del día.", tag="SIGUIENTE",
                            cls="chg", btn_text="Agregar un pago"),
                     sec("Planificación", right=""), widget("Presupuestos", '<div style="font-size:10.5px"><b>Comida</b><div class="pbar"><i style="width:3%"></i></div><small>S/ 18.50 de S/ 600</small></div>')]),
              "app", step=2, mark=MQ, cap="Tras el presupuesto: el pago"),
        phone(panel([balance_after(), actions(),
                     notice("Alquiler agendado para el 5", "¿Tienes tarjeta de crédito? Agrégala y verás lo que debes.", tag="SIGUIENTE",
                            cls="chg", btn_text="Agregar cuenta")]),
              "app", step=3, mark=MQ, cap="Tras el pago: otra cuenta")],
       ["Elimina el contador (F8)", "Se siente como ayuda, no como tarea"],
       ["Pierde la vista de conjunto", "P4 no puede ir directo a lo que quiere", "Hay que fijar reglas de cuándo sugerir"],
       L(("M", "no ve el conjunto"), ("B", "una cosa a la vez"), ("B", "lo ignora"), ("M", "no puede ir directo"), ("B", "—"),
         ("M", "la cuenta llega tarde"), ("B", "una tarjeta a la vez")),
       esf="M", riesgo="Bajo-medio", conteo="0 contadores; 1 sugerencia a la vez")

D4 = A("D4", "Mantener 7 con otro marco", "src",
       "Los mismos 7 pasos, sin «0 de 7»: el progreso se cuenta en positivo y <b>«Ocultar»</b> está disponible desde el primer día.",
       [phone(panel([balance_after(), actions(),
                     steps_card("Primeros pasos", "1 hecho", next_step="Prueba el registro por voz",
                                items=[("done", "Registra tu primer gasto"), ("todo", "Prueba el registro por voz"), ("todo", "Prueba el registro con foto"),
                                       ("todo", "Pon tu primer presupuesto"), ("todo", "Agrega un pago que se repite")],
                                foot=("Ver los 7", "Ocultar"), cls="chg")]),
              "app", step=1, mark=MQ, cap="«1 hecho» en vez de «1 de 7»; «Ocultar» visible"),
        phone(panel([balance_after(), actions(), sec("Últimos registros", right=""), rec("Almuerzo", "Alimentación", "18.50")])
              + toast("Guía oculta. Vuelve a ella en Más › Primeros pasos", icon="check", cls="chg"),
              "app", step=2, mark=MQ, cap="Se oculta sin volver a las 3 sesiones")],
       ["Barato", "Respeta lo decidido en el lote 5"],
       ["No reduce el número de pasos"],
       L(("M", "—"), ("M", "siguen siendo 7"), ("M", "la puede ocultar"), ("B", "la oculta el día 1"), ("B", "—"), ("M", "—"), ("M", "lista larga")),
       esf="S", riesgo="Bajo", conteo="7 pasos; ocultar con 1 toque")

D5 = A("D5", "La guía vive fuera del Panel", "src",
       "La lista completa vive en Más › Primeros pasos; el Panel solo enseña <b>el paso siguiente</b> en una línea.",
       [phone(panel([balance_after(), actions(),
                     f'<div class="lrow chg" style="background:rgba(255,255,255,.07);border-radius:12px;margin:6px 0">{tint("target", "#5b5cf0", 24)}<div class="lt"><span>Siguiente: ponle un límite al mes</span><small>Primeros pasos · 1 de 7</small></div></div>',
                     sec("Últimos registros", right=""), rec("Almuerzo", "Alimentación", "18.50")]),
              "app", step=1, mark=MQ, cap="En el Panel, una sola línea"),
        phone(nav_title("Más") + group(row("Primeros pasos", "1 de 7", icon="target", color="#5b5cf0", cls="chg tap"),
                                       row("Grupos", "", icon="users", color="#f59e0b"), row("Importar", "", icon="import", color="#22b35e"),
                                       row("Ajustes", "", icon="gear", color="#64748b")) + tabbar("Más"),
              "app", step=2, mark=MQ, cap="La lista completa, en Más"),
        phone(sheet_top("Primeros pasos", right=None) + steps_card("Primeros pasos", "1 de 7", items=[
            ("done", "Registra tu primer gasto"), ("todo", "Prueba el registro por voz"), ("todo", "Prueba el registro con foto"),
            ("todo", "Pon tu primer presupuesto"), ("todo", "Agrega un pago que se repite"), ("todo", "Conoce lo que puedes personalizar"),
            ("todo", "Prueba Yala Pro gratis 1 mes")], foot=None), "sheet", step=3, mark=MQ, cap="Se puede volver a ella cuando quiera")],
       ["El Panel se aligera", "Se puede volver a la guía"],
       ["Una entrada más en Más", "La lista queda lejos para quien la necesita"],
       L(("M", "—"), ("M", "la lista queda lejos"), ("B", "una línea"), ("B", "no estorba"), ("B", "—"), ("M", "—"), ("M", "una entrada más en Más")),
       esf="S", riesgo="Bajo", conteo="1 línea en el Panel; lista a 2 toques")

CAPAS = dict(
    titulo="Las capas de ayuda alrededor de la guía",
    sub="Hoy conviven cinco mecanismos (banner GUÍA por pantalla, Primeros pasos, guía de Ajustes, «¡Listo!» en los 3 primeros registros y la cola de avisos). En Planificación se ven <b>dos banners GUÍA a la vez</b>. Tres maneras de ordenarlo, de la revisión (§9.3), con la misma pantalla:",
    screens=[
        shot(C + "21-planificacion.jpg", cap="Hoy: dos banners GUÍA en Planificación", label="HOY"),
        phone(planif_tab(0, empty("calendar", "Aún no tienes presupuestos", "Crea presupuestos para controlar mejor tus gastos.")).replace(
            'class="notice ', 'class="notice chg '), "app", label="Una guía por sesión", mark=MQ,
            cap="Como mucho una guía o aviso por sesión los primeros 7 días; el resto espera"),
        phone(nav_title("Planificación") + chips(["Presupuestos", "Pagos planificados"], selected=("Presupuestos",))
              + widget("Presupuestos", empty("calendar", "Un presupuesto es el máximo que quieres gastar en algo.", "Ejemplo: no más de S/ 600 en comida este mes.", action="Crear"), cls="chg", q=False)
              + tabbar("Planificación"), "app", label="Un solo sistema", mark=MQ, cap="El estado vacío ES la guía: sin banner aparte"),
        phone(nav_title("Planificación") + chips(["Presupuestos", "Pagos planificados"], selected=("Presupuestos",))
              + f'<div class="sec"><b>Presupuestos <span class="wq chg tap" style="width:16px;height:16px">?</span></b></div>'
              + empty("calendar", "Aún no tienes presupuestos", action="Nuevo presupuesto") + tabbar("Planificación"),
              "app", label="Ayuda a demanda", mark=MQ, cap="Sin banners; el «?» explica cuando se toca"),
    ])

GUIA = dict(
    slug="04-primeros-pasos", num=4, titulo="Primeros pasos (la guía de siete)", corto="Primeros pasos",
    problema="Siete tareas después de siete preguntas; <b>solo tres construyen</b> las finanzas de la persona, el resto presenta funciones o vende Pro.",
    fricciones="F8 «7 + 7» · F13 pasos que no construyen · F14 vuelve a desplegarse · F15 capas de guía",
    caso="Ana terminó el alta y anota <b>«Almuerzo» S/ 18.50</b>. ¿Qué le propone la guía después?",
    hoy=[(C + "13-aviso-2-primeros-pasos.jpg", "«0 de 7 completados»"), (C + "15-primeros-pasos-7.jpg", "Los 7 pasos desplegados"),
         (C + "16-panel-primeros-pasos-y-cuentas.jpg", "Voz y foto con candado en la lista")],
    hoy_nota="Capturas del 6-nov. En la build de 2.3 la guía sigue siendo el aviso 2 de 3 (comprobado esta noche en el simulador).",
    hoy_lens=L(("M", "—"), ("A", "«0 de 7» tras 7 pasos"), ("M", "le sobra"), ("A", "lo vive como ruido"), ("B", "—"), ("M", "—"), ("M", "lista larga")),
    alts=[D1, D2, D3, D4, D5],
    extras=[CAPAS],
    decide=dict(pregunta="¿La guía sigue siendo una lista (D1, D2, D4, D5) o pasa a ser una sugerencia en el momento justo (D3)? ¿Cuántos pasos y cuáles?",
                ejes=["<b>D1 y D2 se combinan</b>: 4 pasos útiles, y menos si eligió «Solo anotar».",
                      "<b>D3 elimina el contador</b>, que es lo que suma «7 + 7» (F8), pero pierde la vista de conjunto.",
                      "<b>Las capas</b> se deciden aparte: con cualquiera de las cinco, conviene un tope de interrupciones."]),
)
