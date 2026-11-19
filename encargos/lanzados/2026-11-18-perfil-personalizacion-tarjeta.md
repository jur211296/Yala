Yala
# Perfil con personalización de verdad, al nivel de las tarjetas de cuentas
---
toca: Yala/App/Views/Profile/,Yala/App/Views/Shared/ProfileToolbarButton.swift,Yala/App/Services/AppPreferences.swift,Yala/Services/CloudSync/PreferenceMergeLogic.swift,Yala/Resources/de.lproj/PerfilPersonalizacion.strings,Yala/Resources/en-GB.lproj/PerfilPersonalizacion.strings,Yala/Resources/en.lproj/PerfilPersonalizacion.strings,Yala/Resources/es-419.lproj/PerfilPersonalizacion.strings,Yala/Resources/es-AR.lproj/PerfilPersonalizacion.strings,Yala/Resources/es-ES.lproj/PerfilPersonalizacion.strings,Yala/Resources/es.lproj/PerfilPersonalizacion.strings,Yala/Resources/fr.lproj/PerfilPersonalizacion.strings,Yala/Resources/it.lproj/PerfilPersonalizacion.strings,Yala/Resources/ja.lproj/PerfilPersonalizacion.strings,Yala/Resources/nl.lproj/PerfilPersonalizacion.strings,Yala/Resources/pl.lproj/PerfilPersonalizacion.strings,Yala/Resources/pt-BR.lproj/PerfilPersonalizacion.strings,Yala/Resources/pt-PT.lproj/PerfilPersonalizacion.strings,Yala/Resources/pt.lproj/PerfilPersonalizacion.strings,Yala/Resources/zh-Hans.lproj/PerfilPersonalizacion.strings,YalaTests/PerfilPersonalizacion/,YalaUITests/PerfilPersonalizacion/,tickets/done/2026-11-17-perfil-personalizacion-tarjeta.md
esfuerzo: medium
cierre: cierra-sola
---

Pedido de Jürgen del 17-nov (20:53 Lima), con capturas de «Detalles personales» y «Elegir icono». Base 2.3, un PR. Solo la vista de perfil y su personalización (`Profile/ProfileView`, `PersonalDetailsView`, el botón de perfil de la barra).

## Problema
Jürgen: «La vista de perfil es MUY pobre y la personalización aún peor». Hoy es un ícono en un círculo con un lápiz, el campo Nombre y un texto de «Dónde viven tus datos». Elegir ícono es una grilla de 12 símbolos de un solo color.

## Lo que quiere
- Un nivel de personalización como el de las cuentas estilo tarjeta (mira cómo se personalizan colores, fondos y estilos de las tarjetas de cuentas y reúsa ese lenguaje visual, sin modificar sus archivos).
- Ideas a evaluar: tarjeta de perfil con vista previa en vivo; color o degradado de fondo; más íconos y emojis o iniciales; color del ícono; quizá foto; que el botón de perfil de la barra refleje lo elegido. Elige lo que dé más valor sin volverlo complejo.
- Que la vista de perfil se sienta propia y bonita, no un formulario. Lo de «Dónde viven tus datos» queda secundario.
- Lo nuevo se guarda en las preferencias y se sincroniza como las demás (iCloud o cuenta de Yala), con migración segura para quien ya tiene ícono elegido.

## Cómo entregar
- Propón 2 o 3 variantes en maquetas, elige la recomendada e impleméntala. Lo menor, con la opción recomendada, anotado en «Decidido sin consultar».
- Tests de la lógica nueva en `YalaTests/PerfilPersonalizacion/` y prueba de UI en `YalaUITests/PerfilPersonalizacion/`.
- Capturas antes y después (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad).
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después lado a lado y las variantes.
- Commits y PR sin firma de IA. Toca solo lo declarado. Textos nuevos en `PerfilPersonalizacion.strings` de cada `.lproj`, nunca en `Localizable.strings`. Nunca un botón debajo del otro.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto).
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas en semiautónomo, sin Jürgen delante: las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · Qué variante se construye** → A (confirmada por Jürgen el 18-nov, que añade: «el perfil se muestra como tarjeta»), «Tarjeta de perfil»: tarjeta con el fondo del catálogo de las tarjetas de cuentas, el avatar grande y el nombre, con vista previa en vivo encima de los controles.
Por qué: es la que reusa el lenguaje de las tarjetas que pidió y la que convierte el formulario en algo propio. Descartadas: B «Avatar grande» (solo cambia el círculo, se queda corta) y C «Portada a todo lo ancho» (otra pieza visual nueva sin precedente en la app).

**D2 · Qué se puede personalizar** → avatar con símbolo (36, los 12 de antes primero), emoji (36) o iniciales; foto como hasta ahora; color del avatar (los 14 del editor de tarjetas + «Del tema» + «Otro color»); fondo de la tarjeta (las 27 plantillas de las tarjetas de cuentas).
Por qué: cubre las ideas del encargo sin volverlo complejo. Descartados: patrón propio y chip (de tarjeta bancaria, no de perfil) y emoji libre por teclado (la lista basta y evita texto que no es un emoji).

**D3 · Dónde se guarda** → el símbolo sigue en `userProfileIcon`; lo nuevo en una preferencia sincronizada nueva, `userProfileStyle` (JSON corto, familia «vacío vale»), como `accountCardDesigns`.
Por qué: un iPhone con la versión publicada sigue leyendo un símbolo válido; meterlo todo en `userProfileIcon` le dejaría el avatar en blanco. Coste aceptado: tocar tres ficheros fuera de `toca:` con una línea cada uno (`DataWipeService` para que «Vaciar mis datos» la borre, y dos tests que cuentan las preferencias sincronizadas), más `qa/coverage-index.json`, que el contrato de QA exige.

**D4 · Migración** → no hay que mover nada: estilo vacío = lo de siempre (símbolo guardado, colores del tema). Quien ya eligió un símbolo lo ve igual en la barra y en Ajustes hasta que personalice.
Por qué: cero escritura al actualizar. Alternativa descartada: migración que reescribe la preferencia al arrancar (escribiría y sincronizaría a todo el parque sin necesidad).

**D5 · La foto** → sigue local y manda si existe; el avatar elegido se conserva detrás y es el que ven los otros dispositivos. Elegir símbolo, emoji o iniciales quita la foto, como antes elegir icono.
Por qué: la foto no sincroniza; sin esto, el otro teléfono vería el muñeco por defecto.

**D6 · Dónde se refleja** → la tarjeta en «Detalles personales» y en la cabecera de Ajustes; el avatar elegido en el botón de perfil de la barra.
Por qué: son las tres superficies del encargo, y Jürgen pidió que el perfil se muestre como tarjeta.

**D7 · Cuándo se guarda** → al cerrar la hoja («Listo» o deslizando), como el nombre hoy.
Por qué: un solo punto de guardado y una sola subida por cambio; la vista previa ya enseña cada toque.

**D8 · «Dónde viven tus datos»** → se queda, al final y más pequeño.
