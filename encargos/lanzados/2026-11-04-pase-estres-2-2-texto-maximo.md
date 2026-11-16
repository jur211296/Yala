# Lote 2.2: arreglos del pase de estrés con el texto al máximo (chip de cuenta, hoja de varios registros y neto de Grupos)

Base: origin/2.2 en jur211296/Yala. Una sola sesión, un PR contra 2.2 y un cierre. Con Dynamic Type al máximo (accesibilidad XXXL), en iPhone y en iPad, y en modo claro y oscuro, arregla estas tres cards del tablero:
1. «Pase de estrés 2.2: con el texto al máximo, el chip de una cuenta en «Tus finanzas» saca el icono de su cápsula». El icono tiene que quedar dentro de la cápsula.
2. «Pase de estrés 2.2 (C): con el texto al máximo, la hoja de varios registros deja la lista en una franja y corta el total y «Guardar»». La lista tiene que poder desplazarse con un alto útil, y el total y «Guardar» tienen que verse completos.
3. «Pase de estrés 2.2 (C): con el texto al máximo, el neto de Grupos sale menor que «Te deben» y sus botones se cortan». El neto debe tener la jerarquía correcta y los botones no se cortan.
Toma capturas de antes y después de cada arreglo y ponlas en el PR. Mueve las tres cards a «in qa» con un guion de prueba. Respeta el README de marca: sin degradados ni glows.

Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Chip de cuenta: ¿cómo vuelve el icono a su cápsula?** → el cuadrito del icono escala con el texto (`@ScaledMetric`
con techo) y el glifo se topa a ese cuadrito; a tamaño normal mide los 24 pt de siempre.
Por qué: hoy el marco es fijo (24 pt) y el glifo `caption` crece a AX5, así que se sale por la izquierda.
Alternativa descartada: quitar el icono a AX (pierde la identidad de la cuenta).

**D2 · Grupos: ¿escala el neto o se topan los lados?** → las dos, solo a tamaños de accesibilidad: el neto escala con
`@ScaledMetric` relativo a `largeTitle` con techo, y las líneas de «Debes / Te deben» (y el rótulo del neto) se topan en
AX2. El token `panelHeroAmount` NO se toca: el hero del Panel queda fuera (va a «Encontrado»).
Por qué: con `minimumScaleFactor 0.6` el neto nunca baja de 36 pt y las líneas topadas miden 33: la jerarquía se
garantiza aunque el neto sea largo. Tocar el token cambiaría la cifra de seis pantallas que nadie pidió.

**D3 · Botones «Nuevo gasto / Nuevo grupo»** → a tamaños de accesibilidad se apilan, uno por fila a todo lo ancho, y
la píldora deja dos líneas a AX. A tamaño normal, la fila de siempre.
Por qué: lo pide la card y es el molde de `AdaptiveRowStack` (forma por tamaño de texto, no por contenido).

**D4 · Hoja de varios registros** → a AX el aviso ámbar entra en el scroll (bajo el resumen) y los botones de abajo se
apilan; el total va encima de «Quitar todos» (`AdaptiveRowStack`). Mismo arreglo en su gemelo de voz.
Por qué: lo que crece con el texto fijo abajo es lo que deja la lista en una franja.

**D5 · Capturas** → antes y después con un conductor XCUITest temporal (no se commitea), en simuladores propios creados
para el pase (17e, 17 Pro Max, iPad Pro 11), AX5, oscuro y claro. Se borran al cerrar.
