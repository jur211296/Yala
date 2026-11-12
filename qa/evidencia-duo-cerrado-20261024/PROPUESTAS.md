# iPhone Duo cerrado · ancho de la página: A o B

Jürgen, 24-oct. Cada imagen trae tres columnas: **antes** (2.2 de hoy), **A** (la que queda aplicada) y **B** (maqueta,
solo en capturas). Duo cerrado, semilla de la ficha, tema oscuro.

## Qué pasaba

La barra vertical ocupa una columna de unos 100 pt a la derecha. Lo normal de la página (widgets, textos, botones) ya
acababa antes de esa columna. Lo que se desliza de lado (las tarjetas de cuentas, los chips de cuentas, las tarjetas del
Welcome) llegaba hasta el borde físico, por detrás de la barra. Por eso se veía disparejo: unas piezas sí, otras no.

## A · todo en el ancho seguro (aplicada)

Nada de la página pasa por detrás de la barra; solo el fondo llega al borde. Cuentas y chips se cortan en el mismo borde
que los widgets. En el Welcome, las tarjetas laterales asoman lo mismo a cada lado.

- **A favor:** todo alinea con todo; ningún botón queda debajo de la barra; es lo que pide Apple.
- **En contra:** la columna de la barra sigue viéndose como una franja aparte, sobre todo en el Welcome, donde no hay
  barra y solo están la hora y el wifi.

## B · la página por debajo del cristal

La página usa todo el ancho y la barra flota encima, como hacían las cuentas.

- **A favor:** la barra se lee como parte de la página; el Welcome queda centrado en la pantalla y el titular cabe en dos
  líneas.
- **En contra:** en las páginas los botones de la barra tapan cosas que se tocan o se leen: «Todo el tiempo», el
  desplegable de «Tus finanzas», el «Te deben» de Grupos, los importes de la derecha de Presupuestos y Registros. Y
  otras quedan dentro de la columna de la barra, como el botón de preferencias de los widgets. Para usarla habría que
  apartar a mano cada control de esa columna, pantalla por pantalla.

## Qué dice Apple

`app-resizability` (skill oficial de Xcode 27.1) y el HIG del Duo: contenido y controles dentro del área segura; bajo
la barra, solo fondos, fotos o mapas. Y no mezclar: unos bloques bajo la barra y otros no. A es esa regla. B solo es
válida para fondos, y en Yala casi todo lo que llegaría a esa columna es contenido.

## Recomendación

**A en toda la app**, que es lo que queda en el PR. Hay una excepción que sí cabe en la regla de Apple, porque ahí no hay
barra: **el Welcome en B** (captura 01). Si lo quieres así, es un cambio pequeño en otra sesión.

## Lo que queda aplicado además (opción 2 de la barra)

- El avatar va en la barra vertical en las siete páginas (Panel, Registros, Estadísticas, Planificación, Grupos, Más,
  Reportes). Ya no queda una barra suelta arriba con el avatar.
- Cuando no cabe todo (el Panel), las pestañas se pliegan en un botón y caben bandeja, Filtros, Configurar y avatar.
- «Seleccionar» de Registros desaparece de arriba en el Duo cerrado; sigue en «···».
- Abierto no cambia: el avatar se queda arriba y las pestañas no se pliegan. Solo la tarjeta de cuenta del Panel
  abierto en horizontal deja de pasar por debajo del «···», por la misma regla A.
