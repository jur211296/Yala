"""Actualización del 16-nov-2026: de la guía de la 2.3 (1) a la de la 2.3 (2).

Aplica sobre `inventario.json` (la versión del 15-nov) y lo reescribe. No se aplica dos veces: si los ítems ya tienen
`build`, para. Añade tres campos:
- `build`: "1" (2.3 (1)), "2" (2.3 (2)), "web" (Yala web, fuera de la app) o "no" (todavía no en TestFlight).
- `nuevo_guia`: true si el ítem es nuevo o cambió desde la guía del 15-nov.
- `cambio_guia`: una línea con qué cambió en la guía.

Fuentes: los PR mergeados en `2.3` entre el corte de la 2.3 (1) (merge del barrido final) y el de la 2.3 (2) (merge
de Yala web en producción, base del PR del número de build), los PR en cola de auto-merge y la medición del 16-nov en
producción (ver README).
"""
import json
import os

AQUI = os.path.dirname(os.path.abspath(__file__))
RUTA = os.path.join(AQUI, "inventario.json")
items = json.load(open(RUTA))
if any("build" in x for x in items):
    raise SystemExit("Ya aplicada: inventario.json tiene el campo build.")

by = {x["id"]: x for x in items}
NUEVA = "Solo se ve en una instalación nueva. Míralo en el iPhone 14 de pruebas (o en otro teléfono con TestFlight): no borres Yala en tu teléfono personal."
COLA = "Todavía en cola de merge: no está en la 2.3 (2). Llega en la próxima build de TestFlight."

for x in items:
    x["build"] = "no" if x["seccion"] == "fuera" else "1"
    x["nuevo_guia"] = False
    x["cambio_guia"] = ""
    if x["seccion"] == "ambos":
        x["orden"] = 50


def upd(id_, cambio, **kw):
    x = by[id_]
    x.update(kw)
    x["nuevo_guia"] = True
    x["cambio_guia"] = cambio
    return x


def add(pr, n, **kw):
    x = {"pr": pr, "id": f"{pr}-{n}", "tipo": "funcion", "por_que": "", "estado": "listo", "activar": "", "pro": False,
         "como_probar": "", "orden": 0, "build": "2", "nuevo_guia": True, "cambio_guia": "Nuevo en la 2.3 (2)."}
    x.update(kw)
    if x["seccion"] == "ambos" and "orden" not in kw:
        x["orden"] = 50
    assert x["id"] not in by, x["id"]
    items.append(x)
    by[x["id"]] = x
    return x


B2 = dict(seccion="existente", estado="listo", activar="", build="2")
YA = "Antes decía «no está en este build»: ya está en la 2.3 (2)."

# ---------------------------------------------------------------- lo que el 15-nov estaba fuera y ya está en la 2.3 (2)
upd("930-1", YA, **B2, titulo="Al pasar tus datos a la nube, el cifrado y las fotos se ven de entrada",
    ruta="Ajustes › Dónde viven tus datos › pasar a tu cuenta de Yala (hoja de antes de activar)",
    que_cambio="La hoja de antes de activar dice a la vista, una línea cada uno: «Yala puede ver tus datos» (para soporte y funciones inteligentes; no hay cifrado de extremo a extremo), «Las fotos de tus recibos no viajan» (fila nueva) y «Exportar una copia antes». Desaparece «Ver los detalles».",
    por_que="Sabes qué aceptas antes de tocar «Continuar», sin buscarlo en un pliegue.",
    como_probar="Con tus datos en iCloud, abre la hoja de pasar a tu cuenta de Yala y lee las tres líneas; sal con «Cancelar» si no quieres pasarte.")
upd("910-1", YA, **B2, titulo="«Volver a tu iCloud» en una hoja de tres pasos que dice la verdad",
    ruta="Ajustes › Dónde viven tus datos (con tus datos en tu cuenta de Yala) › Volver a tu iCloud",
    que_cambio="El botón (ya no naranja) abre una hoja en tres fases: qué pasa con cada cosa (tus datos bajan al teléfono y suben a tu iCloud, tu cuenta de Yala sigue abierta para tus grupos, tus finanzas se quedan guardadas en ella sin usarse); qué hacer con lo que ya hay en tu iCloud, con su cifra («Sumarlos a mis datos», «Empezar sin ellos» en rojo, «Ahora no»), y confirmar repitiendo lo elegido. Antes prometía «sin perder nada» en globos de letra pequeña.",
    por_que="La decisión que mueve tus datos se toma leyendo lo que va a pasar.",
    como_probar="Ábrela y recorre las fases sin confirmar: «Ahora no» no mueve nada. Confirmar, solo en el iPhone 14 de pruebas.")
add(910, 2, area="Nube e iCloud", seccion="existente", tipo="mejora",
    titulo="Activar la nube con un borrado pendiente: una hoja explica cada caso",
    ruta="Ajustes › Dónde viven tus datos › Activar (con un «Empezar de cero» sin terminar)",
    que_cambio="Si quedó pendiente un borrado de iCloud, activar la nube abre una hoja: sin empezar, «ese borrado no se hace y tus datos de iCloud se quedan»; a medias, «lo que había en tu iCloud ya se borró». Opciones: activar conservando, «Terminar de borrar y empezar de cero» (abre la hoja de borrado con su «¿seguro?») y «Ahora no». Si terminar quita también los grupos y la cuenta de Yala del teléfono, lo dice.",
    por_que="Antes un globo con «Activar sin borrar» no decía qué no se borraba.",
    como_probar="Solo aparece con un borrado pendiente: pruébalo en el iPhone 14 (Empezar de cero, cancelar a mitad y volver a activar).")
upd("916-1", YA, **B2, titulo="«Cambiar de cuenta» en una fila, y soltar la cuenta con cada consecuencia",
    ruta="Ajustes › Dónde viven tus datos › fila «Tu cuenta de Yala · La usan tus grupos» › Cambiar de cuenta",
    que_cambio="La tarjeta «Grupos» con el botón naranja «Desasociar» pasa a una fila de datos (Tu cuenta de Yala · Apple o Google · correo · La usan tus grupos) con un enlace discreto «Cambiar de cuenta ›». La hoja de soltar dice qué pasa siempre (los grupos salen del teléfono y siguen en la cuenta) y cada botón su consecuencia: «Dejar en mis cuentas lo que pagué» (con cuántos y cuánto) o «Quitar también eso de mis cuentas». «Cancelar» siempre a la vista.",
    por_que="Lo más llamativo de la pantalla ya no es la acción que más rompe.",
    como_probar="Abre la hoja y lee las dos consecuencias; sal con «Cancelar».")
add(916, 2, area="Nube e iCloud", seccion="existente", tipo="mejora",
    titulo="Si «Activar la nube» se para por la cuenta, ofrece «Cambiar de cuenta»",
    ruta="Ajustes › Dónde viven tus datos › Activar › aviso «Esta cuenta ya tiene sus propios datos» (o «Ya usas otra cuenta para tus grupos»)",
    que_cambio="El aviso ya no termina en «Entendido»: «Cambiar de cuenta» cierra el aviso y abre la misma hoja de consecuencias. Los siete textos que decían «desasocia en Grupos» ahora dicen «toca Cambiar de cuenta», en los 16 idiomas.",
    como_probar="Solo sale si la cuenta con la que entras no sirve; en el iPhone 14, entra con una cuenta que ya tenga datos.")
upd("899-1", YA, **B2, titulo="Archivar una cuenta la saca del saldo y conserva su historial",
    ruta="Panel › una cuenta › Editar › Archivar (o Ajustes › Cuentas)",
    que_cambio="La cuenta archivada deja de sumar en el saldo (cifra del Panel, su curva, «en N cuentas», widgets, Yala IA) y deja de salir entre las cuentas del Panel y al registrar. Sus gastos e ingresos siguen en Registros, el Panel y Estadísticas. Antes, archivar encendía «Excluir de las estadísticas» y los gastos de esa tarjeta desaparecían de todos los meses. Las que archivaste antes (también en la 2.1 y la 2.2) vuelven a enseñar su historial, sin migrar nada.",
    por_que="Una tarjeta cancelada deja de pesar en tu saldo sin borrar lo que gastaste con ella.",
    como_probar="Archiva una cuenta con gastos: el saldo cambia y sus gastos siguen en Registros. Desarchívala después.")
add(899, 2, area="Ajustes y Pro", seccion="existente", tipo="texto",
    titulo="Cuenta archivada: sin «Excluir» y con un aviso que dice qué pasa",
    ruta="Cuenta archivada › Editar",
    que_cambio="Con la cuenta archivada no se enseña «Excluir de las estadísticas» (no haría nada) y un aviso explica que no suma en el saldo pero conserva su historial. En los 16 idiomas.")
upd("894-1", YA, **B2, tipo="arreglo", titulo="Grupos: apuntar un pago ya no se duplica",
    ruta="Grupos › un grupo › Saldar / Apuntar pago",
    que_cambio="Si al guardar un pago algo fallaba a medias, reintentar dejaba dos pagos. Ahora se guarda confirmado de una vez y, si falla, no queda nada a medias: reintentar deja uno.",
    como_probar="Apunta un pago en un grupo de prueba y comprueba que sale una sola vez.")
add(894, 2, area="Grupos", seccion="existente", tipo="arreglo",
    titulo="Grupos: corregir un monto del reparto deja lo que escribes",
    ruta="Grupos › Nuevo gasto › reparto por monto, porcentaje o partes",
    que_cambio="Tocar el campo dejaba el cursor delante: borrar no hacía nada y «150» sobre «200.00» acababa en «1,200.00». Ahora el cursor va al final y sigue al final al reformatear la cifra.",
    como_probar="En un reparto por monto, toca un importe, bórralo y escribe otro.")
add(894, 3, area="Grupos", seccion="existente", tipo="mejora",
    titulo="Grupo archivado: no deja apuntar gastos ni saldar desde dentro",
    ruta="Grupos › un grupo archivado",
    que_cambio="Ya no salen el «+» de Gastos ni «Saldar», igual que la lista no lo ofrecía. Se puede seguir confirmando o rechazando pagos, editando y «Saldar primero» para salir del grupo.")
add(894, 4, area="Grupos", seccion="existente", tipo="mejora",
    titulo="Grupos: el saldo inicial pregunta antes de reemplazar otro",
    ruta="Grupos › un grupo › Ajustes › Saldo inicial (dueño o admin)",
    que_cambio="Añadir uno entre dos personas que ya tienen otro en esa moneda lo cambiaba sin avisar. Ahora sale «Ya hay un saldo inicial entre Ana y Beto · Ahora dice: Beto le debe a Ana · S/ 75.00» con «Cancelar» o «Reemplazar». Con pagos confirmados, el texto ya no habla de «borrar el gasto».")
add(894, 5, area="Grupos", seccion="existente", tipo="arreglo",
    titulo="«Importar todo el historial» sale la primera vez que llevas los gastos de grupo a tus cuentas",
    ruta="Grupos › Ajustes (o los de un grupo) › Registrar gastos de grupos en mis cuentas personales",
    que_cambio="Al encender el interruptor, la oferta de importar el historial solo salía si ya había algo reflejado. Ahora sale si hay gastos de grupo que importar.")
upd("943-1", YA, **B2, tipo="accesibilidad", titulo="VoiceOver nombra los selectores que se leían sin nombre",
    ruta="Filtros de Registros, formulario de grupo, saldar en otra moneda, saldo inicial de Flujo de caja, color de icono",
    que_cambio="Con VoiceOver: «Modo del filtro, Mostrar solo», «Cómo se reparte un gasto nuevo», «Moneda del pago», «Fecha del saldo» y «Color personalizado». También la hora de una notificación y el interruptor de cada widget en Configurar Panel. Nada cambia a la vista.")
upd("924-1", YA, **B2, titulo="Tendencias dice contra qué compara, y las tres pestañas comparan hasta hoy",
    ruta="Estadísticas › Tendencias (bajo el título)",
    que_cambio="Tendencias tiene el mismo «Comparado con…» y sus dos chips («Con el mes anterior» / «Con <mes> del año pasado») que Resumen y Distribución. Antes no tenía selector y su comparación cambiaba sin avisar. En un período en curso, las tres pestañas comparan hasta el día equivalente a hoy (antes Distribución y Tendencias cortaban en el último día con movimientos).",
    por_que="La comparación ya no cambia por debajo según la pestaña.",
    como_probar="Abre Tendencias, cambia el chip y compara la cifra con Resumen.")
add(924, 2, area="Estadísticas", seccion="existente", tipo="accesibilidad",
    titulo="VoiceOver lee cada gráfica con su conclusión y sus cifras",
    ruta="Estadísticas y Panel: tendencia, entradas y salidas, tartas, día de la semana, necesidades",
    que_cambio="La tendencia dice «bajó de S/ 76,100 a S/ 73,357. El punto más bajo…» (antes «12 puntos»); las tartas, el total y las tres partes mayores con su porcentaje; el día de la semana, el de más y el de menos gasto. En el rotor salen «Describir gráfica» y el sonido de la gráfica. Con «Ocultar montos» no se dice ninguna cifra.")
upd("922-1", YA, **B2, titulo="Registros: al tocar un día, el calendario se pliega a su semana",
    ruta="Registros › Calendario › toca un día",
    que_cambio="El mes se pliega a la semana del día («9–15 nov 2026 ▾» en lugar del mes) y la página sube para que el resumen («Gastaste S/ 113.00») y los registros del día queden debajo, también con texto grande. Tocar la semana (o el día otra vez) despliega el mes; dentro de la semana pasas de día en día.",
    por_que="Ves los registros del día sin desplazarte.",
    como_probar="En Registros › Calendario toca un día con gastos y luego la semana.")
add(922, 2, area="iPad", seccion="existente", tipo="visual",
    titulo="iPad: el calendario de Registros a una columna y el título entero",
    ruta="iPad › Registros › Calendario",
    que_cambio="Con la vista calendario, Registros pasa a una sola columna al ancho legible, como en el iPhone; con la lista vuelve el split. El título de la columna se lee entero («Registros») y «Seleccionar» va con su icono.")
upd("920-1", YA, **B2, orden=24.5, titulo="Nuevo registro: tus 3 categorías más usadas a un toque",
    ruta="+ › Nuevo registro › fila bajo el importe",
    que_cambio="Bajo el importe sale una fila con las 3 categorías que más usas y «Más…». Un toque deja la categoría puesta sin abrir la hoja. Quien empieza, sin registros, ve Restaurantes, Supermercados y Taxis y apps.",
    por_que="La categoría más habitual queda a un toque.",
    como_probar="Abre Nuevo registro y toca una de las tres; en una instalación nueva mira las tres de partida.")
by["920-1"]["seccion"] = "ambos"
add(920, 2, area="Nuevo registro", seccion="existente", tipo="funcion",
    titulo="El buscador de categorías entiende «café», «uber» o «wong»",
    ruta="Cualquier hoja de categorías (Nuevo registro, Bandeja, favoritos, pagos planificados, Grupos) › buscar",
    que_cambio="«café», «menú» o «almuerzo» llevan a Restaurantes; «uber» o «cabify» a Taxis y apps; «bodega» o «wong» a Supermercados: 24 categorías de uso diario con marcas y modismos de cada idioma (el chino y el subte en Argentina, Mercadona en España).",
    como_probar="En la hoja de categorías escribe «cafe» o «uber».")
upd("912-1", YA, **B2, titulo="Nota de salud honesta: sin suelo de 50 y sin castigos de golpe",
    ruta="Panel › Tus finanzas › tarjeta de la nota; Estadísticas › Resumen",
    que_cambio="El ritmo cuenta los días desde tu último registro con 3 días de gracia (desde el cuarto baja 8 puntos por día). Pasarse de un presupuesto resta según cuánto (un 10 % resta 1 punto; el doble lo deja en 30). La nota va de 0 a 100. En «Tus finanzas» del Panel hay una tarjeta chata con el anillo y un paso concreto («Registra esta semana para subir tu ritmo»), visible aunque la sección esté plegada; nunca dice «vas mal». Quien actualiza la ve encendida una vez, salvo que la hubiera apagado a mano.",
    por_que="La nota refleja cómo vas sin desanimar ni premiar de más.",
    como_probar="Mira la tarjeta en el Panel y tócala para ver el desglose.")
by["912-1"]["seccion"] = "ambos"
add(912, 2, area="Panel", seccion="existente", tipo="texto",
    titulo="Novedades 2.3: tarjeta «Tu nota de salud, más precisa»",
    ruta="Novedades de la versión (al abrir tras actualizar)",
    que_cambio="Una tarjeta nueva en las novedades dice qué cambió en la nota y cómo subirla.",
    como_probar="Sale en las novedades de la versión si vienes de la 2.2.")
upd("983-2", "Antes decía «solo decidido»: ya está en la 2.3 (2).", **B2, area="Registros",
    titulo="«Hacer recurrente» desde un registro",
    ruta="Registros › mantén pulsado un registro › Hacer recurrente; o su detalle › Recurrente",
    que_cambio="Abre el editor de recurrentes ya relleno (monto, moneda, categoría, cuenta, nota y el día del registro como día de cobro, cada mes). Al guardar, ese registro queda como el primer pago, ya pagado: no se crea otro gasto ni sale un borrador repetido en la Bandeja.",
    por_que="Un gasto que ya se repite (Netflix, el hosting) pasa a recurrente sin volver a escribirlo.",
    como_probar="Mantén pulsado un gasto mensual › Hacer recurrente › Guardar, y míralo en Planificación › Pagos.")
add(990, 1, area="Bandeja y Yala IA", seccion="existente", tipo="funcion",
    titulo="Bandeja: «Guardar y hacer recurrente»",
    ruta="Bandeja › un borrador › bajo «Guardar»",
    que_cambio="Aprueba el borrador como siempre y pasa al editor de recurrentes ya relleno. No sale en lo que ya viene de un recurrente, una suscripción o un grupo.")
add(990, 2, area="Planificación", seccion="existente", tipo="funcion",
    titulo="Pagos planificados: «Desde un registro»",
    ruta="Planificación › Pagos › Desde un registro (junto a «Nuevo pago planificado»)",
    que_cambio="Abre tus registros de los últimos 6 meses con buscador; el que elijas abre el editor de recurrentes relleno.")
add(990, 3, area="Planificación", seccion="existente", tipo="mejora",
    titulo="Hacer recurrente sin duplicados: ofrece vincular al que ya existe",
    ruta="Cualquiera de las tres entradas de «Hacer recurrente»",
    que_cambio="Si ya hay un recurrente parecido (misma moneda y tipo, monto ±15 %, mismo comercio), pregunta «Vincular a «Cloudflare»» o «Crear otro recurrente». Vincular marca ese vencimiento como pagado y retira el borrador pendiente del mismo vencimiento.")

# ---------------------------------------------------------------- nuevo en la 2.3 (2)
add(994, 1, area="Panel", seccion="ambos", orden=32.5,
    titulo="Panel: «Tu saldo hoy» en grande, «Tu dinero hoy» en chico y un «?» que explica los dos",
    ruta="Panel (arriba)",
    que_cambio="En grande, «Tu saldo hoy»: todas las cuentas, tarjetas incluidas, con su signo (con más deuda de tarjeta sale «S/ -609.50»; ya no dice «Debes hoy»). Debajo, en chico, «Tu dinero hoy»: lo mismo sin las tarjetas de crédito; solo sale si alguna cuenta queda fuera. El «?» abre una hoja con las dos cifras, un ejemplo con números y «Elegir qué cuentas suman». La línea del mes («Te queda» con sus flechas) sale del Panel: la cuenta Flujo de caja.",
    por_que="Ves lo que tienes y lo que de verdad puedes usar, sin que la tarjeta lo esconda.",
    como_probar="Con una tarjeta de crédito con gasto, mira las dos cifras y toca el «?».")
add(994, 2, area="Ajustes y Pro", seccion="existente", tipo="funcion",
    titulo="Cada cuenta elige si suma en «Tu dinero hoy»",
    ruta="Panel › una cuenta › Editar › «Sumar en «Tu dinero hoy»»; o el «?» del Panel › Elegir qué cuentas suman",
    que_cambio="Interruptor por cuenta, encendido en todo menos en la tarjeta de crédito. No sale en una cuenta archivada o excluida. El ajuste viaja a tus otros dispositivos.",
    como_probar="Apaga una cuenta de ahorro y mira cómo cambia «Tu dinero hoy».")
add(994, 3, area="Estadísticas", seccion="existente", tipo="texto",
    titulo="Estadísticas: «Tu saldo hoy» y «Tu saldo al cierre»",
    ruta="Estadísticas › Resumen y Tendencias",
    que_cambio="«Tienes hoy» pasa a «Tu saldo hoy» y «Tenías al cierre» a «Tu saldo al cierre», igual que en el Panel. En los 16 idiomas.")
upd("900-1", "Cambió en la 2.3 (2): la cifra ahora es «Tu saldo hoy» y la línea «Te queda» salió del Panel.",
    titulo="Panel: la cifra grande no cambia con el período (en la 2.3 (2), «Tu saldo hoy»)",
    que_cambio=by["900-1"]["que_cambio"] + " En la 2.3 (2): el rótulo pasa a «Tu saldo hoy» (sin «Debes hoy»: un saldo negativo sale con su signo) y la línea «Te queda» de debajo sale del Panel; la cuenta Flujo de caja. Mira el ítem de «Tu dinero hoy».")
upd("900-2", "Cambió en la 2.3 (2): «Tienes hoy» y «Tenías al cierre» pasan a «Tu saldo hoy» y «Tu saldo al cierre».",
    que_cambio=by["900-2"]["que_cambio"] + " En la 2.3 (2), «Tienes hoy»/«Tenías al cierre» pasan a «Tu saldo hoy»/«Tu saldo al cierre».")
add(1002, 1, area="Panel", seccion="ambos", orden=23.5,
    titulo="Tus cuentas del Panel, como tarjetas bancarias",
    ruta="Panel › Tus finanzas › cuentas",
    que_cambio="Cada cuenta se ve como una tarjeta: degradado de su color, un patrón sutil, el ícono en un cuadrito, chip y, si quieres, «•••• 1256». Dice lo mismo de antes (tipo, monedas, «Por pagar» o «Saldo», el equivalente en tu moneda). Una cuenta que nunca diseñaste sale con un diseño de su mismo color. Si un color no da contraste, el fondo se ajusta solo. La tarjeta de Grupos va en grafito y no se diseña. Con «Ocultar montos» los dígitos también se ocultan.",
    por_que="Reconoces cada cuenta de un vistazo.",
    como_probar="Abre el Panel y mira tus cuentas: deberían verse con su color de siempre.")
add(1002, 2, area="Panel", seccion="ambos", orden=23.6,
    titulo="Diseña tu tarjeta: 27 plantillas, colores, patrones, íconos y últimos 4 dígitos",
    ruta="Panel › botón de paleta en la esquina de una cuenta (o mantén pulsado › Diseñar tarjeta)",
    que_cambio="Editor con vista previa en vivo: 27 plantillas en 6 grupos (degradados, metálicas, minimalistas, oscuras, pastel, con patrón), 16 colores más «Otro color», 7 patrones, 25 íconos, chip sí o no y los últimos 4 dígitos (nunca el número completo). «Volver al diseño original» lo deja como al principio. El diseño viaja a tus otros dispositivos.",
    como_probar="Diseña una cuenta, ponle 4 dígitos y vuelve al diseño original.")
add(996, 1, area="Panel", seccion="existente",
    titulo="La ficha de una cuenta, con las gráficas del Panel",
    ruta="Panel › toca una cuenta",
    que_cambio="La ficha suma: la curva del saldo con el día de hoy marcado y su escala; entradas y salidas del período con su cambio frente al anterior; el donut de categorías (suma lo mismo que lo gastado), y «Tus gastos más grandes» (los tres que más pesaron) antes de «Últimos registros». Se queda «Así se forma tu saldo», el estado de cuenta de la tarjeta, el selector de moneda, «Filtrar por esta cuenta» y Editar. Las gráficas no filtran al tocarlas.",
    por_que="Entiendes una cuenta sin salir de su ficha.",
    como_probar="Toca una cuenta con movimientos y luego una tarjeta de crédito.")
add(992, 1, area="Bienvenida y cuenta", seccion="nuevo", orden=19.5, tipo="arreglo",
    titulo="Tras «¡Tu cuenta está lista!» › «Empezar», el Panel espera tus datos en vez de mostrar S/ 0",
    ruta="Bienvenida › entrar con una cuenta que ya tiene datos › Empezar",
    que_cambio="El Panel enseña el esqueleto de carga hasta que llega la cuenta y luego el saldo; nunca S/ 0 con «Crear categorías». En la 2.3 (1) aún podía pasar: con 2 de 6 cuentas llegadas, el Panel pintaba S/ 0 durante unos 8 segundos.",
    activar=NUEVA + " Además pide una cuenta de Yala con datos.")
add(992, 2, area="Bienvenida y cuenta", seccion="nuevo", orden=16.5, tipo="arreglo",
    titulo="Cancelar la entrada a una cuenta no deja nada de ella en el teléfono",
    ruta="Bienvenida › entrar con tu cuenta › Cancelar mientras conecta",
    que_cambio="Antes quedaban en el teléfono grupos, categorías y un gasto de la cuenta cancelada, y la entrada siguiente acababa en «este dispositivo tiene que quedar en blanco». Ahora todo queda a cero y la siguiente entrada vuelve a pedir la cuenta.",
    activar=NUEVA)
add(992, 3, area="Ajustes y Pro", seccion="existente", tipo="arreglo",
    titulo="«Vaciar mis datos» responde en cualquier punto del botón",
    ruta="Ajustes › Vaciar mis datos",
    que_cambio="Tocar el centro del botón abría Exportar. Ahora cualquier punto abre «¿Vaciar tus datos?»; «Exportar una copia antes» sigue abriendo Exportar.",
    como_probar="Toca el centro del botón y sal con «Cancelar»: no vacíes tus datos reales.")
add(992, 4, area="Grupos", seccion="existente", tipo="arreglo",
    titulo="Yala IA en Grupos ya no deja la descripción vacía, y el aviso nombra escribir",
    ruta="Grupos › un grupo › Yala IA",
    que_cambio="Con un gasto escrito, la descripción ya no queda vacía. El aviso de Yala IA dice «Escribes, dictas o eliges una foto del recibo», en los 16 idiomas.")
upd("961-1", "En la 2.3 (1) todavía podía salir S/ 0: el arreglo completo está en la 2.3 (2).")

# ---------------------------------------------------------------- funciones que cambian de estado
upd("818-1", "Ya está en la 2.3 (2); el conector todavía no está en producción.", build="2", seccion="existente",
    estado="todavia_no", area="Integraciones",
    titulo="Tu IA registra en Yala: Claude, ChatGPT y Grok dejan borradores en la Bandeja",
    ruta="Claude o ChatGPT con el conector de Yala › «apunta 25 soles de almuerzo» › Bandeja",
    que_cambio="Con Yala conectado a tu IA, le dices «apunta 25 soles de almuerzo» y el movimiento llega a la Bandeja con la etiqueta «Tu IA» y la IA que lo apuntó. Si nombró cuenta y categoría, sale listo para guardar; si no, la Bandeja las pide. Nada cuenta hasta que lo confirmas y la IA no puede cambiar ni borrar nada.",
    activar="La parte de la app ya está en la 2.3 (2), pero el conector no está desplegado en producción (medido el 16-nov: su dirección de producción responde «worker no encontrado»; la de staging sí responde). Sin conector nadie deja borradores. Hoy solo se prueba en Yala Dev con el conector de staging.")
upd("801-1", "Medido otra vez el 16-nov: el conector sigue sin producción.",
    activar="Medido el 16-nov: el conector de producción no existe todavía (Cloudflare responde «worker no encontrado»); solo staging. Falta desplegarlo, aplicar sus migraciones en Supabase producción y publicarlo en los directorios de Claude.")
upd("969-2", "Ya funciona en producción: el gateway se desplegó desde 2.3 el 16-nov.", estado="listo", activar="",
    como_probar="Reparte 6 recibos en un día con una cuenta Free: el sexto pide Yala Pro. Con Pro llegan a 50.",
    que_cambio=by["969-2"]["que_cambio"] + " El gateway de producción se desplegó el 16-nov desde 2.3, que ya trae este cupo (deducido del despliegue; no lo probé con 6 recibos).")
upd("840-2", "Medido otra vez el 16-nov: sigue apagado en producción.",
    activar="Medido el 16-nov en la configuración remota de producción: «Otra cuenta de Apple» al 0 % (staging 100 %). Falta configurar Apple Developer y el Supabase de producción y subir el porcentaje.")
WEB = ("1. En Safari (en el iPhone o el ordenador) abre app.yala-app.pe; no hay enlace desde la web pública. "
       "2. Entra con Apple o Google, la misma cuenta de la app. "
       "3. Necesitas tus datos en tu cuenta de Yala (Ajustes › Dónde viven tus datos). "
       "4. Lo que apuntes llega a la Bandeja del iPhone con la 2.3 (2); la 2.2 de la App Store no lo recoge.")
upd("984-1", "Yala web ya está en producción (16-nov).", seccion="existente", estado="activable", build="web",
    titulo="Yala web en producción: app.yala-app.pe",
    ruta="Navegador › app.yala-app.pe",
    que_cambio="Yala web funciona en producción: entras con Apple o Google, ves el mismo saldo que en el iPhone, apuntas borradores que llegan a la Bandeja y Grupos se lee y se escribe. Probado de punta a punta el 16-nov en el iPhone 14.",
    activar=WEB)
upd("970-2", "Ya en producción, no solo en staging.", estado="activable", build="web",
    ruta="Navegador › app.yala-app.pe", activar=WEB)
upd("972-1", "Ya en producción en la web; entrar con QR desde el iPhone sigue solo en Yala Dev.",
    estado="activable", build="web", ruta="Navegador › app.yala-app.pe › Estadísticas / Pagos",
    activar=WEB + " 5. La entrada con QR («Vincular un navegador» en el iPhone) todavía no: esa fila solo existe en Yala Dev.")
upd("988-1", "Ya en producción.", seccion="existente", estado="activable", build="web",
    ruta="Navegador › app.yala-app.pe › Grupos",
    que_cambio="En la web, Grupos ya no dice «Todo saldado» con deudas ni «Sin nombre»; un gasto añadido desde la web llega a la app con quién pagó y quién participa. En el móvil la web ya no se amplía sola al tocar un campo.",
    activar=WEB)
upd("970-1", "Medido otra vez el 16-nov: la app de TestFlight sigue sin apuntar a Yala web.",
    activar="Medido en el código de la 2.3 (2): la fila solo existe en Yala Dev y apunta a la web de staging; en la app de TestFlight no sale. Yala web ya está en producción, pero falta apuntar la app a ella.")
upd("613-1", "16-nov: quedó hecho el video v4 de la verificación de Google.",
    activar="Sigue en borrador y no se mergea hasta que Google apruebe. El 16-nov quedó hecho el video v4 de la verificación (la cuenta de origen, de punta a punta); falta que Google la apruebe.")

# ---------------------------------------------------------------- todavía no en TestFlight (en cola de merge)
for pr, n, area, tit, ruta, qc in [
    (1003, 1, "Grupos", "Traer un grupo de Splitwise o Tricount con los mismos saldos",
     "Grupos › Nuevo grupo › Traer un grupo de Splitwise o Tricount",
     "Eliges el CSV que exportó la otra app, ves una vista previa (personas, gastos, pagos, fechas y el saldo de cada persona) y dices quién eres. El grupo toma nombre y moneda del archivo y cada persona termina con el mismo saldo que tenía allá: el tuyo al crear el grupo, el de los demás cuando se unen y el dueño los empareja. Trae saldos, no cada gasto. Tricount no tiene formato oficial y falta validarlo con un export real."),
    (999, 1, "Grupos", "Grupos: voz, foto y Yala IA como en personal, y el «+» solo al desplazar",
     "Grupos › un grupo › Voz / Foto / Yala IA",
     "Voz con la hoja que escucha y la onda; Foto con Cámara, Fotos y Archivo (también PDF); Yala IA como el chat de personal, que responde con el reparto por persona. El «+» flotante del grupo solo sale al desplazar, como en el Panel. En un grupo archivado, la fila de arriba ya no ofrece apuntar."),
    (997, 1, "Registros", "Registros: filtros rápidos con icono, en la línea de Lista/Calendario y con selección múltiple",
     "Registros › filtros rápidos",
     "Sin el chip «Este mes»; Cuenta, Categoría y Más filtros con icono, en la misma línea que Lista/Calendario; varias cuentas a la vez; Categoría como el primer presupuesto del onboarding, y se aplica al cerrar la hoja."),
]:
    add(pr, n, area=area, seccion="fuera", estado="fuera", build="no", titulo=tit, ruta=ruta, que_cambio=qc,
        activar=COLA, cambio_guia="Nuevo en la guía: todavía no en TestFlight.")
by["1003-1"]["activar"] = "Mergeado en 2.3 el 16-nov a las 16:51, después de cortar la 2.3 (2): llega en la próxima build de TestFlight."
by["1003-1"]["cambio_guia"] = "Nuevo en la guía: mergeado, pero todavía no en TestFlight."

json.dump(items, open(RUTA, "w"), ensure_ascii=False, indent=1)
from collections import Counter
print(len(items), Counter(x["build"] for x in items), Counter(x["estado"] for x in items),
      "nuevos en la guía:", sum(x["nuevo_guia"] for x in items))
