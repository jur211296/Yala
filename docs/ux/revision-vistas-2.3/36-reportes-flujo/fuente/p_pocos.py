"""Problema 7: con una semana de datos, el plan sugerido no tiene ingresos y anuncia «Te faltan al mes S/ 2,573»."""
from ui import ic, cat
from flujo import rtop, screen


def _row(name, catname, sub, amt):
    return (f'<div class="crow"><span class="okc">{ic("check", 9, sw=3)}</span>{cat(catname, 22)}<div class="ct"><b>{name}</b>'
            f'<small>{sub}</small></div><div class="cr"><span class="ca"><small>S/</small>{amt}</span></div></div>')


def _start(amount="16,472", cents="00"):
    return (f'<div class="cfhero"><span class="ecap">¿Con cuánto empiezas?</span>'
            f'<div class="eamt"><small>S/</small>{amount}<small>.{cents}</small></div>'
            f'<div class="cfl">Lo que tienes hoy en tus 2 cuentas · <em>Cambiar el monto</em></div></div>')


A = {
    "code": "A", "titulo": "Pedir el ingreso que falta antes de sumar",
    "que": ("Si no hay ningún ingreso en el historial, la pantalla no da el resumen todavía: pregunta <b>«¿Cuánto "
            "recibes al mes?»</b> con un campo y «Aún no lo sé». Con la cifra, el resumen sale completo; sin ella, dice "
            "«Gastos al mes S/ 2,573 · falta tu ingreso» en lugar de «Te faltan»."),
    "screens": [
        screen(rtop(plan=False) + _start() +
               '<div class="ecard chg"><b style="font-size:12px">¿Cuánto recibes al mes?</b>'
               '<div class="note2">Aún no vemos ingresos en tus registros. Con esta cifra tu plan sale completo.</div>'
               '<div class="fld big" style="margin-top:6px"><span class="funit">S/</span><span class="fph">0.00</span></div>'
               '<div class="plink">Aún no lo sé</div></div>',
               cap="Primero el ingreso que no conocemos.", step=1),
        screen(rtop(small=True, plan=False) +
               '<div class="ecard chg"><div class="rowkv"><span>Ingresos al mes</span><b>S/ 3,000.00 (escrito)</b></div>'
               '<div class="rowkv"><span>Gastos al mes</span><b>S/ 2,573.00</b></div>'
               '<div class="rowkv"><b>Te sobran al mes</b><b>S/ 427.00</b></div></div>'
               '<div class="btn pri" style="margin:4px 0">Crear mi plan</div>',
               cap="El resumen ya cuadra.", step=2),
    ],
    "pros": ["Quita una cifra alarmante que no es verdad («te faltan S/ 2,573»).",
             "El ingreso es lo único que una semana de datos no puede adivinar.",
             "«Aún no lo sé» deja seguir sin bloquear."],
    "contras": ["Una pregunta más en el armado (solo cuando no hay ingresos).", "Un ingreso escrito a mano no se actualiza solo."],
    "conteo": "1 campo + Crear", "esf": "medio", "riesgo": "bajo",
    "lens": {"P1": ("B", "escribe su sueldo"), "P2": ("B", "una pregunta clara"), "P3": ("M", "un campo más"),
             "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("M", "¿en qué moneda?"), "P7": ("B", "—")},
}

B = {
    "code": "B", "titulo": "Con pocos datos, no se sugiere el plan: se explica cuándo estará",
    "que": ("Con menos de un mes de historial, la pantalla dice «Tu plan se arma solo con un mes de registros: faltan "
            "23 días» y ofrece armarlo a mano («Empezar en blanco»). Hoy el mínimo existe solo para el vacío total."),
    "screens": [
        screen(rtop(plan=False) + _start() +
               '<div class="emp chg">' + ic("calendar", 20, sw=1.7) +
               '<span>Tu plan se arma solo con un mes de registros</span><small>Llevas 7 días: faltan 23. Mientras, '
               '«Ver proyectado» usa tu ritmo.</small><div class="btn sec sm">Empezar en blanco</div></div>',
               cap="Espera honesta, con salida.", step=1),
    ],
    "pros": ["No enseña cifras que salen de una semana.", "Coherente con «Registra … por al menos un mes» del vacío."],
    "contras": ["Quien quiere planificar desde el día 1 tiene que hacerlo a mano.", "Esconde lo que sí se sabe (los pagos planificados)."],
    "conteo": "—", "esf": "bajo", "riesgo": "medio",
    "lens": {"P1": ("M", "quiere armarlo ya"), "P2": ("B", "nada que no entienda"), "P3": ("B", "—"),
             "P4": ("A", "lo bloquea"), "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("B", "—")},
}

C = {
    "code": "C", "titulo": "Decir qué falta en el propio resumen",
    "que": ("Mismo armado, pero el resumen no dice «Te faltan al mes»: dice <b>«Aún no sabemos tus ingresos»</b> en la "
            "fila de ingresos y deja la última fila como «Gastos al mes S/ 2,573». Un enlace «Agregar un ingreso» abre la "
            "hoja de línea que ya existe."),
    "screens": [
        screen(rtop(small=True, plan=False) +
               '<div class="ecard">' + _row("Alquiler", "Hogar", "Pago planificado", "2,200") + '</div>' +
               '<div class="ecard chg"><div class="rowkv"><span>Ingresos al mes</span><b style="color:#ffd166">Aún no los vemos</b></div>'
               '<div class="rowkv"><span>Gastos al mes</span><b>S/ 2,573.00</b></div>'
               '<div class="plink">+ Agregar un ingreso</div></div>'
               '<div class="btn pri" style="margin:4px 0">Crear mi plan</div>',
               cap="El resumen nombra el hueco.", step=1),
    ],
    "pros": ["Cambio pequeño: un texto y un enlace a una hoja que existe.", "No alarma ni bloquea."],
    "contras": ["El plan creado sigue sin ingresos: «Este mes te faltan» aparece después.", "Depende de que la persona toque el enlace."],
    "conteo": "1 toque opcional", "esf": "bajo", "riesgo": "bajo",
    "lens": {"P1": ("B", "—"), "P2": ("M", "puede crear sin ingreso"), "P3": ("M", "no toca el enlace"),
             "P4": ("B", "—"), "P5": ("N", "—"), "P6": ("B", "—"), "P7": ("B", "—")},
}

POCOS = {
    "slug": "17-pocos-datos", "corto": "7 · Primera semana", "num": 7, "sev": "Media",
    "titulo": "Con una semana de datos, el plan sugerido no tiene ingresos y anuncia «Te faltan al mes S/ 2,573»",
    "problema": ("Con la semilla de la primera semana (7 días), «¿Con cuánto empiezas?» dice S/ 16,472 en dos cuentas, "
                 "pero el armado no tiene la sección «Lo que entra»: el sueldo aún no está en el historial. El resumen "
                 "termina en <b>«Te faltan al mes S/ 2,573»</b> y deja crear el plan así. Después, el mes dirá «Este mes te "
                 "faltan». Es la cifra más alarmante de la zona y sale de la falta de datos, no del dinero de la persona. "
                 "Toca la primera semana, que es justo la del usuario nuevo (revisión del usuario nuevo, PR 837)."),
    "hoy": [("capturas/d10-flujo-pocos-datos.jpg", "Primera semana: S/ 16,472 y sin «Lo que entra»."),
            ("capturas/d11-flujo-pocos-datos-scroll.jpg", "Solo pagos planificados."),
            ("capturas/d12-flujo-pocos-datos-scroll2.jpg", "«Te faltan al mes S/ 2,573» y «Crear mi plan».")],
    "hoy_conteo": "Más → Flujo de caja → 2 desplazamientos → una cifra que asusta",
    "evid": [("obs", "Capturas del 7-nov con la semilla «minimal» (7 días)."),
             ("cod", "<code>CashFlowSetupView</code>: «Aún no hay datos… al menos un mes» solo sale sin ninguna sugerencia; "
                     "con una semana sí hay sugerencias (los pagos planificados)."),
             ("hip", "Que la persona lea «te faltan» como un problema real es lectura de perfiles (P2, P3).")],
    "alts": [A, B, C],
    "reco": ("A",
             "Pregunta lo único que falta y no bloquea («Aún no lo sé»). C es el arreglo mínimo si A no entra ahora; "
             "B bloquea a P4 y esconde lo que sí se sabe."),
    "hoy_lens": {"P1": ("M", "lo ve mal, sabe por qué"), "P2": ("A", "«te faltan» asusta"), "P3": ("A", "se queda con la cifra"),
                 "P4": ("M", "agrega el ingreso a mano"), "P5": ("N", "—"), "P6": ("M", "—"), "P7": ("M", "—")},
    "decide": ["¿El armado pregunta «¿Cuánto recibes al mes?» cuando no hay ingresos en el historial (A)?",
               "Si no, ¿el resumen deja de decir «Te faltan» y nombra el hueco (C)?"],
}
