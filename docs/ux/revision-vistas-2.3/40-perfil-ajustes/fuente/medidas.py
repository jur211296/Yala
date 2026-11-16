"""Lo medido en el simulador (9-nov-2026) y las notas de texto grande e iPad, para paginas.py."""

EFIC_MED = [
    ("Abrir Ajustes desde el Panel, sin registros (semilla «sin-registros»)",
     "130 ms de mediana (129,6-139,4; la primera, 432)",
     "Marca <code>PERF ajustes</code> de la app (<code>LoadTimeMarks</code>: empieza al tocar el avatar y acaba en el <code>onAppear</code> "
     "de la lista), leída del registro del simulador. 7 aperturas seguidas en el mismo arranque."),
    ("Lo mismo con dos años de registros (semilla «realista», 2.342)", "345 ms de mediana (340,2-348,9; la primera, 644)", "Igual."),
    ("Lo mismo con diez años de registros (semilla «pesado»)", "~1.020 ms (1.017-1.024; la primera, 1.950)",
     "Igual. Crece con los registros aunque Ajustes solo cuenta cuántos hay (<code>fetchCount</code>)."),
    ("Abrir Ajustes desde <b>Más</b> (sin el Panel delante), dos años", "216 ms de mediana (198-219; la primera, 522)",
     "La misma marca, tocando el avatar de Más. Separa lo que cuesta el Panel al presentar la hoja."),
    ("Lo mismo desde Más, diez años", "~470 ms de mediana (465-485; la primera, 765)",
     "Igual. Desde Más cuesta la mitad, pero también crece con los registros: una parte es del Panel y otra de lo que comparten "
     "(la hoja de Ajustes o las páginas que siguen montadas debajo)."),
    ("Largo de la lista de Ajustes", "4 pantallas a tamaño normal, 8 con AX3",
     "Deslizamientos iguales hasta que dos capturas seguidas no cambian: 3 a tamaño normal y 7 con AX3 (iPhone 17 Pro)."),
]
AX_CAP = {
    "ax-a01-ajustes.jpg": "Ajustes: la cabecera, media pantalla.",
    "ax-a01-ajustes-abajo-1.jpg": "«Personaliza-ción»; iconos que no crecen (problema 7).",
    "ax-a01-ajustes-abajo-2.jpg": "«Notificacio-nes» (problema 7).",
    "ax-a01-ajustes-abajo-3.jpg": "«Sincroniza-ción»; aún en Datos.",
    "ax-d00-ajustes-datos.jpg": "Datos.",
    "ax-d01-exportar.jpg": "Exportar: el botón se corta («Exportar 2,342 reg…»).",
    "ax-g02-personalizacion.jpg": "Personalización: bien.",
    "ax-g02-personalizacion-abajo-1.jpg": "Idioma: tres líneas a cada lado.",
    "ax-g02-personalizacion-abajo-2.jpg": "Interruptores: bien.",
    "ax-h05-faq.jpg": "Preguntas frecuentes: bien.",
    "ax-m01-mas.jpg": "Más: subtítulos cortados («…en un l…»).",
    "ax-r01-pro-gratis.jpg": "Pro: los planes llenan la pantalla.",
    "ax-r01-pro-gratis-abajo-1.jpg": "La prueba; «Qué incluye» aún más abajo.",
}
AX_NOTE = ('<p class="sub">Lo que falla con texto grande va al problema 7 (palabras partidas, iconos que no crecen, lista larguísima). '
           'Además: el botón de Exportar corta su texto («Exportar 2,342 reg…»), las tarjetas de Más cortan los subtítulos y en Yala Pro '
           '«Qué incluye Pro» queda a cuatro o más pantallas. Preguntas frecuentes, interruptores y Vaciar datos parten bien.</p>')
IPAD_CAP = {
    "ipad-a01-ajustes.jpg": "Ajustes en lista y detalle: «Elige un ajuste para verlo aquí».",
    "ipad-g02-personalizacion.jpg": "Personalización al lado de la lista: bien.",
    "ipad-h05-faq.jpg": "Preguntas frecuentes al lado: bien.",
    "ipad-r01-pro-gratis.jpg": "Yala Pro sin precios: la App Store no contestó (estado de error).",
    "ipad-d00-ajustes-datos.jpg": "Con Pro.",
    "ipad-d01-exportar.jpg": "Exportar, en una hoja centrada sobre Ajustes.",
}
IPAD_NOTE = ('<p class="sub">En el iPad Pro 13 Ajustes es lista y detalle: la lista de 31 filas sigue igual de larga, pero lo elegido se '
             've al lado y no hace falta volver atrás. Exportar sale en una hoja centrada que tapa los dos lados. La lista '
             'estrecha a la izquierda con un detalle muy ancho deja mucho aire en Personalización y Pro. Ya hay una card abierta '
             'sobre el tamaño de la hoja de Ajustes en el iPad («En iPad, Ajustes puede no salir con lista y ajuste lado a lado según desde dónde lo abras»).</p>')
