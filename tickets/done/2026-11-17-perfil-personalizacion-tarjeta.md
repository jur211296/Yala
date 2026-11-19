---
id: 2026-11-17-perfil-personalizacion-tarjeta
status: done
priority: medium
area: "profile, settings"
created: 2026-11-17
updated: 2026-11-18
source: "pedido de Jürgen del 17-nov, 20:53 Lima (encargo 2026-11-18-perfil-personalizacion-tarjeta)"
---

# Perfil: personalización de verdad, al nivel de las tarjetas de cuentas

«La vista de perfil es MUY pobre y la personalización aún peor»: un ícono en un círculo con un lápiz, el campo Nombre y
«Dónde viven tus datos». Elegir ícono era una rejilla de 12 símbolos de un solo color. Entra en 2.3.

## Qué quedó (variante A, «Tarjeta de perfil»)

- **«Detalles personales» rediseñada.** Arriba, una tarjeta de perfil con el fondo de las tarjetas de cuentas
  (degradado, patrón y brillo), el avatar grande y el nombre: es la vista previa en vivo de cada toque. Tocar el avatar
  ofrece elegir, cambiar o quitar la foto. Debajo: el nombre; «Tu avatar» con cuatro pestañas (Símbolo, Emoji,
  Iniciales, Foto); «Color del avatar»; «Fondo de la tarjeta»; «Volver al perfil de siempre» y, al final y más pequeño,
  «Dónde viven tus datos».
- **Avatar**: 36 símbolos (los 12 de antes primero, en su orden), 36 emojis o las iniciales del nombre (sin nombre, la
  pestaña dice que hay que escribirlo). Rejillas de tres filas que se desplazan a lo ancho. La foto sigue local y manda
  si la hay; elegir símbolo, emoji o iniciales la quita, como antes elegir un icono.
- **Color del avatar**: «Del tema», los 14 colores del editor de tarjetas y «Otro color». El símbolo o las iniciales
  van en blanco o casi negro, el que más se lea.
- **Fondo de la tarjeta**: las 27 plantillas de las tarjetas de cuentas. «Tu color» se tiñe con el color del avatar o,
  sin él, con el del tema. El contraste del nombre lo garantiza la misma lógica de las tarjetas de cuentas.
- **La cabecera de Ajustes es la misma tarjeta de perfil** (Jürgen, 18-nov, al elegir la A: «el perfil se muestra
  como tarjeta»): avatar, fondo, nombre y «Yala Pro»; tocarla abre «Detalles personales», como «Editar perfil».
- **El botón de perfil de la barra** enseña el avatar elegido con su color. Sin nada personalizado se ve como antes.
- **Dónde se guarda**: el símbolo sigue en `userProfileIcon` (la versión publicada lo sigue leyendo) y lo nuevo en la
  preferencia sincronizada `userProfileStyle` (JSON corto, `ProfileStyleLogic`). Viaja por iCloud o la cuenta de Yala
  como las demás; «Vaciar mis datos» la borra. Sin migración: estilo vacío = el perfil de siempre.

## Pruebas

- `YalaTests/PerfilPersonalizacion/ProfileStyleTests` (6 suites).
- `YalaUITests/PerfilPersonalizacion/PerfilPersonalizacionUITests` (2 casos; el primero cae si no se guarda el estilo).

## Device-QA (iPhone 14, cuando se pueda; no bloquea)

1. Ajustes › Editar perfil: elegir un emoji, un color y el fondo «Aurora»; tocar «Listo». La barra del Panel y la
   cabecera de Ajustes enseñan el emoji sobre ese color.
2. En otro dispositivo con la misma cuenta, el mismo avatar llega solo (iCloud o cuenta de Yala).
3. Elegir una foto: manda la foto en este teléfono; en el otro se sigue viendo el emoji.
4. Abrir la app 2.2 publicada en un segundo teléfono: sigue viendo el último símbolo elegido, no un círculo vacío.
