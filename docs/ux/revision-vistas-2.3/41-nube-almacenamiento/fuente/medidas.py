"""Lo medido en la zona 41: CPU en reposo, texto grande (AX3) e iPad."""

EFIC_MED = [
    ("CPU de la app en reposo, Ajustes abierto (en iCloud)", "6,5 % (3,8 s de CPU en 59 s)",
     "Simulador iPhone 17 Pro, iOS 27.2, Debug-Dev, semilla «realista». El conductor espera 60 s sin tocar nada; desde el Mac, "
     "<code>ps</code> lee cada 2 s el tiempo de CPU acumulado del proceso de la app. Una corrida."),
    ("Lo mismo con «Dónde viven tus datos» abierta (en iCloud)", "8,4 % (4,8 s en 57 s)", "Igual, mismo proceso, a continuación. +1,9 puntos sobre Ajustes."),
    ("Ajustes abierto, en la nube", "8,0 % (4,6 s en 57 s)", "Igual, con la cuenta nacida en la nube (gancho de prueba)."),
    ("«Dónde viven tus datos» abierta, en la nube", "8,5 % (4,9 s en 57 s)", "Igual. +0,5 puntos sobre Ajustes."),
]

AX_CAP = {
    "ax-a02-ajustes-filas-datos.jpg": "Ajustes: las dos filas.",
    "ax-s01-icloud-sin-sesion.jpg": "El estado, en media columna junto al icono.",
    "ax-s01-icloud-sin-sesion-abajo-1.jpg": "«Asociar una cuenta para grupos» en tres líneas.",
    "ax-h01-hoja-activar.jpg": "La hoja: el pie fijo ocupa casi la mitad.",
    "ax-h02-hoja-detalles.jpg": "Con los detalles: una rendija.",
    "ax-b01-bloqueo-datos-propios.jpg": "El bloqueo cabe.",
    "ax-p-upload.jpg": "Subiendo: «Cancelar la activ…» cortado.",
    "ax-p-upload-cancelar.jpg": "El globo de cancelar.",
    "ax-n04-borrar-y-volver.jpg": "«¿Borrarlos de tu iCloud?»: el globo llena la pantalla.",
    "ax-o02-hoja-cerrar-sesion.jpg": "La hoja de quitar datos: se lee bien.",
    "ax-o04-reabre-yala.jpg": "«Ya casi está»: los gestos, en columnas estrechas.",
    "ax-f02-nube-activa.jpg": "En la nube: el estado, apretado otra vez.",
}
AX_NOTE = ("<p class='sub'>Lo que se ve aquí alimenta el problema 8. Se leen bien la hoja de quitar datos y los bloqueos; se aprietan "
           "la tarjeta de estado (icono + texto en fila), la hoja de activar (pie fijo) y los globos de decisión anclados a un botón "
           "(«¿Borrarlos de tu iCloud?» ocupa toda la pantalla y su título se corta arriba). «Cancelar la activación» sale cortado.</p>")
IPAD_CAP = {
    "ipad-s01-icloud.jpg": "iPad Pro 13: Ajustes a la izquierda y la pantalla a la derecha.",
    "ipad-h01-hoja.jpg": "La hoja de activar, centrada, con un hueco vacío entre el texto y los botones.",
    "ipad-p-reverseUpload.jpg": "Volviendo a iCloud, en la columna de detalle.",
}
IPAD_NOTE = ("<p class='sub'>En el iPad Pro 13 todo cabe y se lee; las tarjetas ocupan la columna entera con textos de 11-12 pt. "
             "La hoja de activar sale centrada y su alto lo fija el pie, así que queda un hueco vacío en medio. Nada de esto llega "
             "a problema prioritario.</p>")
