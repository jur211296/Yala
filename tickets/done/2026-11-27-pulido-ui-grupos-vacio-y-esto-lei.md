---
id: 2026-11-27-pulido-ui-grupos-vacio-y-esto-lei
status: done
priority: medium
area: "groups, image-entry"
created: 2026-11-27
updated: 2026-11-27
source: "decisión de Jürgen del 27-nov-2026 (t2011u): dos cards del tablero de Yala 2.3"
---

# Grupos y Personas sin gastos con los botones arriba, y «Esto leí» en grande con fondo de card y deslizar

## Qué pidió Jürgen

1. **Grupos y Personas sin gastos**: la fila de registro (Nuevo gasto, Voz, Foto, Yala IA) sube justo debajo de los
   chips, como cuando hay gastos; solo «Sin gastos» queda centrado. Antes iba centrada junto a «Sin gastos» y dejaba un
   hueco arriba.
2. **«Esto leí» en grande**: las tarjetas con el fondo de card del Panel y deslizar para rechazar (lectura nueva) o
   eliminar (ya guardada), con la misma confirmación que los botones de siempre y su alternativa para VoiceOver.

## Decisiones (Paso 0 del encargo)

- Fondo: el de los **widgets del Panel** (relleno de tarjeta del tema y su borde), no `CardBackgroundView`, que es el
  degradado de las tarjetas de cuenta (Jürgen, 27-nov).
- Deslizar una guardada **borra el registro que creó**, con la pregunta de «Eliminar» de un registro (Jürgen, 27-nov). Lo
  de un grupo no se desliza.
- Deslizar una nueva = «Descartar» del editor: a Archivados, sin pregunta, con «Deshacer».
- «En grande» = la hoja se VE grande (su borde de arriba pegado a la barra de estado), no el detent elegido: la captura
  de Jürgen era la hoja de media altura subida por el teclado, con el gris del sistema detrás y la tarjeta del mismo
  gris. Ahí el fondo pasa a sólido; a media altura nada cambia.
- Quitar la última fila cierra la hoja; si lo que queda ya está guardado, se cierra como al guardar.

## Hecho cuando

- Grupo y persona sin gastos: botones bajo los chips, «Sin gastos» centrado en lo que sobra (XCUITest con capturas).
- «Esto leí» en grande: fondo de card en claro y oscuro; deslizar descarta, elimina con confirmación, y la última o la
  única cierran la hoja (XCUITest). A media altura, sin cambios.

## Resolución (2026-11-27)

- Vacío de Grupos y Personas: la columna se ancla arriba y solo «Sin gastos» se estira en lo que sobra. Con texto de
  accesibilidad o girado (poco alto), el vacío va en un scroll con alto mínimo: medido girado a AX5, sin él «Sin gastos»
  quedaba bajo el borde y el título se montaba sobre la fila de botones. `ViewThatFits` no eligió el scroll (medido).
- «Esto leí»: con la hoja vista grande el fondo pasa a sólido y cada tarjeta lleva el relleno y el borde de los widgets del
  Panel; el deslizar vive en `Logic/PulidoGruposVacioEstoLei/`. Tres trampas medidas al probarlo: (1) la capa que cierra la
  tarjeta abierta colgada DESPUÉS del `.offset` cubre el botón que asoma y se come su toque; (2) un modificador que se
  pone o se quita según «en grande» cambia la identidad de la tarjeta, y al subir el teclado se rehacía sin el campo en
  edición: el deslizar tiene una sola estructura, encendida o apagada; (3) por lo mismo, el sólido no puede ser otra
  variante de `yalaScreenBackground` (cada variante es otra estructura): es una capa fija que cambia de opacidad.
- Pruebas: 15 unitarias y 5 XCUITest (grupo, persona, AX5 girado, varios con eliminar + descartar la última, única en
  grande), los cinco rojos en la base por el motivo esperado y verdes con el cambio, en claro y oscuro.
