Yala
# Decidido 9-nov 2.3 · Nuevo registro: barra sobre el teclado (después del merge de 2.2)
card: tablero-2-3-barra-sobre-el-teclado-al-registrar-exy3
toca: Yala/App/Views/Transactions/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 20 y 68. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/32-nuevo-registro/ficha.md. Se construye después del merge de 2.2, que este lote ya espera.

## Encargo y criterio de terminado
Implementar SOLO estos 3 puntos:
1. Con el teclado abierto, lo que falta y «Guardar» quedan a la vista. Opción G1: barra fina sobre el teclado con lo que falta y «Guardar». Abrir el teclado de entrada queda como está («No abrir»).
2. «Para guardar, falta…» deja de montarse sobre «Etiquetas» y «Guardar» (lo resuelve G1).
3. En el iPad, el importe deja de abrir un teclado flotante encima de la hoja: hoja a tamaño de página o teclado acoplado.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, sesión nocturna): las recomendaciones se dan por buenas. Se discuten en el PR.

**D0 · ¿2.3 ya tiene lo de 2.2?** → Sí: `git rev-list --count origin/2.3..origin/2.2` = 0 (medido al arrancar). Se sigue.

**D1 · ¿Dónde va la barra G1: barra de accesorios del sistema (`ToolbarItemGroup(placement: .keyboard)`) o la `safeAreaBar` que ya lleva «Guardar»?** → La `safeAreaBar` de `SaveAreaPlacement`: sin teclado pinta lo de siempre (línea + «Guardar»); con teclado, la barra fina.
Por qué: se apoya en el área segura del teclado, queda pegada encima de él sin depender del estilo que iOS 26 dé a los accesorios, y es el mismo sitio que la persona ya conoce. Alternativa descartada: el accesorio del sistema, que envuelve cada pieza en su propio cristal y no controla la altura.

**D2 · ¿Qué lleva la barra?** → Las pastillas obligatorias (cuenta y categoría; en transferencia, origen y destino) con su valor o su nombre, con el borde de «falta» de siempre, y «Guardar». Tocar una abre su hoja; al cerrarla se vuelve al campo que tenía el teclado.
Por qué: es la maqueta G1 (pantallas 1 y 3). Alternativa descartada: enseñar solo lo que falta (la barra cambiaría de forma a cada elección).

**D3 · ¿Se esconden las pastillas del formulario mientras se escribe?** → No. Siguen en el contenido; la línea «Para guardar, falta…» y el «Guardar» del contenido salen mientras hay teclado (los sustituye la barra).
Por qué: Etiquetas y las divisas de tarjeta no están en la barra y tienen que poder alcanzarse; esconderlas hace saltar el formulario al abrir y cerrar el teclado. Alternativa descartada: ocultarlas, como sugiere el texto de la maqueta.

**D4 · Texto grande** → `ViewThatFits`: pastillas + «Guardar»; si no cabe, solo lo primero que falta + «Guardar»; si no, solo «Guardar».
Por qué: lo pide la propia maqueta («dos chips y el botón, o solo Falta: Categoría»).

**D5 · Punto 2 (la línea sobre «Etiquetas»)** → Medido en 2.3 actual. Con teclado lo resuelve D1: la línea deja de estar en el contenido y lo que falta lo dice la barra. Sin teclado ya lo resolvió el arreglo de 2.2 que 2.3 tiene desde el merge corto («Guardar» en una `safeAreaBar` que difumina lo de detrás): la captura de la revisión es de antes de ese merge. No se porta nada a mano; queda fijado por dos casos (con y sin teclado, «Etiquetas» puede quedar entera por encima de la barra).

**D6 · Punto 3 (iPad)** → «Teclado acoplado», no «hoja a tamaño de página». Medido en el iPad Air 11: a tamaño de página el teclado numérico flotante seguía saliendo encima del formulario; lo abre el teclado `.decimalPad` del iPad. En el iPad los cuatro campos de importe del formulario (importe, los dos de la transferencia y la tasa) usan `.numbersAndPunctuation`, que sale solo acoplado; todos filtran lo que se escribe. En el iPhone no cambia. Alternativa descartada: tamaño de página (probado y retirado: no quita el flotante y estiraba el formulario a 1.400 pt).

**D6b · ¿Qué identificador lleva «Guardar» de la barra?** → El mismo que el de abajo (`new_transaction_save`): nunca están los dos a la vez, y así los XCUITest que guardan con el teclado abierto lo siguen encontrando, ahora encima del teclado. Las pastillas de la barra llevan ids propios (`new_transaction_keyboard_*_chip`) porque conviven con las del formulario.

**D7 · Copy** → Sin textos nuevos: las pastillas y «Guardar» reutilizan los suyos. Si hace falta uno (p. ej. el nombre de la barra para VoiceOver), en los 16 idiomas.

**D8 · Tests** → `YalaUITests/Flows/KeyboardSaveBar23UITests` (área determinista del formulario en `qa/coverage-index.json`), rojo contra el código de antes y verde después; las capturas salen de sus adjuntos.
