Yala
# Decidido 9-nov 2.3 · Nuevo registro: categorías recientes y el buscador que entiende «café»
card: tablero-2-3-categorias-recientes-y-el-buscador-q-4xrs
toca: Yala/App/Views/Transactions/, Yala/App/Views/Categories/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisión 21 (C2 + C3). Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/32-nuevo-registro/ficha.md.

## Encargo y criterio de terminado
Implementar SOLO este punto:
1. Al empezar hay categorías a un toque y buscar «café» encuentra algo. Opción C2 + C3: fila con las 3 categorías más usadas + «Más…» en el formulario (de arranque: Restaurantes, Supermercados y Taxis y apps); y el buscador de la hoja entiende palabras del día a día («café», «uber», «menú»), traducidas en los 16 idiomas.

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

Hechos medidos antes de decidir: `origin/2.3..origin/2.2` = 0 commits (2.3 ya tiene todo lo de 2.2); el punto sigue vivo en
`origin/2.3` (la hoja solo enseña «Recientes» con historial y `CategorySearchLogic` mira nombre y grupo); el PR de la barra
sobre el teclado (abierto) también toca `NewTransactionView`, así que el cambio en ese fichero va acotado.

**D1 · ¿Dónde va la fila de categorías?** → Bajo el importe (y su equivalencia), antes de las píldoras «Mi parte /
Favorito / Recurrente», centrada, como en la maqueta C2. Por qué: es lo maquetado y decidido. Alternativa descartada:
junto a los chips de abajo (aleja la categoría del importe que se acaba de escribir).

**D2 · ¿Cuándo se ve?** → Solo en un registro nuevo de gasto o ingreso: no al editar, no en transferencia, no en un
registro de grupo de solo lectura, y no si no hay ninguna categoría que ofrecer. Por qué: al editar ya hay categoría y
la transferencia no lleva. Alternativa descartada: también al editar (ruido sin caso).

**D3 · ¿Qué tres salen?** → Las más usadas en los últimos 100 registros (los que el formulario ya carga), contando solo
categorías elegibles a mano; a igualdad, la usada más recientemente. Si no llegan a tres, se completan con las de
arranque (Restaurantes, Supermercados, Taxis y apps) sin repetir. Por qué: «las 3 más usadas» + «de arranque para quien
empieza» de la decisión 21, sin un salto brusco el día que se apunta el primer gasto. Alternativa descartada: arranque
solo con cero registros (la fila pasaría de 3 a 1 chip tras el primer café).

**D4 · ¿Y en un ingreso?** → Solo las más usadas, sin arranque; sin historial de ingresos, la fila no sale. Por qué: la
decisión eligió arranque solo de gasto; inventar «Sueldo» sería decidir producto. Alternativa descartada: arranque de
ingreso (no decidido).

**D5 · ¿La fila se queda tras elegir?** → Sí, con la elegida rellena con su color; la categoría elegida sigue saliendo
también en el chip de abajo, como hoy. Por qué: es la pantalla 2 de la maqueta y deja cambiar de un toque. Alternativa
descartada: esconderla (cambiar de idea pediría la hoja).

**D6 · ¿Cómo se reconoce una categoría de arranque?** → Por su nombre en cualquiera de los 16 idiomas
(`L10n.allLocalizedValues`), como ya se reconocen las de sistema. Si la persona la borró o la renombró, no se ofrece.
Por qué: la categoría se guarda con el nombre del idioma en que se sembró. Alternativa descartada: añadir una clave de
semilla al modelo (migración SwiftData por una fila de chips).

**D7 · ¿Qué palabras entiende el buscador?** → Una lista por categoría sembrada de uso diario (24: comida, súper, taxis,
transporte, combustible, farmacia, salud, ropa, tecnología, regalos, belleza, alquiler, servicios, teléfono, streaming,
bares, espectáculos, viajes, gimnasio, educación, comida de mascota, sueldo…), en el catálogo de textos y en los 16
idiomas, con marcas y modismos de cada uno. Casan si contienen lo escrito (desde 2 letras), sin tildes ni mayúsculas.
Por qué: «café», «uber» y «menú» son los ejemplos; el resto evita que el buscador entienda tres palabras y nada más.
Alternativa descartada: las 62 categorías (muchas no tienen palabra cotidiana distinta de su nombre).

**D8 · ¿La hoja enseña la palabra que coincidió?** → No: la rejilla se queda como está. Por qué: la decisión 21 pide que
el buscador entienda la palabra, no cambiar la tarjeta; meter un pie en una rejilla de 4 columnas a 2 líneas la rompe
con texto grande. Alternativa descartada: el pie «café, menú» de la maqueta (queda como mejora si Jürgen lo pide).

**D9 · Prueba de regresión** → Unit (lógica de las tres y del buscador con palabras) + XCUITest con la semilla
`una-cuenta` (sin registros): salen las tres de arranque, un toque elige Restaurantes, y «café» en la hoja da
Restaurantes. Por qué: la zona del formulario es determinista en `qa/coverage-index.json`.
