# Cuatro arreglos de 2.1 hallados en el QA guiado del 19-oct: asociación de Grupos vieja, borrado de iCloud que se corta, grupos que no bajan y la música que no vuelve

## Contexto
Son cuatro cards de 2.1 halladas por Jürgen en el QA guiado del 19-oct (sesión `Yala--qa-guiado-2-1-tf17`, iPhone de QA). Mientras 2.1 esté en QA, sus correcciones van primero. Las cuatro cierran solas. Lee cada card entera con `tablero ver <id>` antes de empezar: el contexto (MEDIDO / INFERIDO), el siguiente paso y el criterio de hecho están ahí. Lo INFERIDO es una hipótesis: verifícala antes de arreglar.

1. `tablero-donde-viven-tus-datos-dice-que-tus-grupo-cq2i` (high) · «Dónde viven tus datos» dice que tus grupos usan una cuenta vieja y bloquea «Activar la nube». Medido en código: `GroupsAccountAssociation.read()` cae al iCloud-KV del Apple ID cuando no hay registro local, y la puerta de `CloudMigrationController` (`isAssociated(sub:)`) bloquea con `.anotherGroupsAccountAssociated`. Hipótesis: el camino que conserva la sesión de grupos al entrar en privado (`lateNoticeKeptGroupsSessionSub`) no reescribe la asociación con la cuenta viva.
2. `tablero-volver-a-icloud-empezar-sin-ellos-falla-9ttd` (high) · «Volver a iCloud › Empezar sin ellos» falla con un iCloud grande porque el borrado se corta a los 2 minutos (`ICloudPersonalCorpusProbe.foreignWipeDeadline = 120`). Se pide que el borrado no dependa de un plazo fijo: que siga mientras avance, o que retome desde donde quedó sin que la persona lo repita, con progreso visible; y que el texto del fallo no culpe a la conexión cuando fue el plazo.
3. `tablero-al-volver-a-tu-cuenta-de-grupos-por-ya-t-ewkw` (high) · Al volver a tu cuenta de Grupos por «Ya tengo una cuenta», tus grupos no aparecen hasta cerrar y abrir Yala. Hipótesis: tras el alta por la bienvenida, el canal de Grupos no hace su primer pull hasta el siguiente arranque (`GroupsLoopRestartLogic.shouldStart`).
4. `tablero-al-cancelar-la-voz-la-musica-de-otra-app-8171` (medium) · Al cancelar la voz, la música de otra app no vuelve a sonar. Medido: `AudioRecorderService` llama a `setActive(false)` sin `.notifyOthersOnDeactivation` en sus dos salidas.

## Qué se pide
- Arreglar las cuatro, cada una con su test de la decisión (lógica pura donde se pueda) y su control: el caso en que el comportamiento viejo sí era el correcto. Para la 2, un test del bucle con un corpus por encima del plazo.
- Ticket en `tickets/qa/` por card (o actualizar el que exista), índice de QA y `docs/TICKETS.md` al día.
- Cada card en `in qa` a nombre de `jurgen` con un guion corto de device-QA en `siguientePaso` (repetir A · C1 sin desasociar; 4nt6 con 1.500 o más movimientos en iCloud; D5 paso 1 sin relanzar; B · micrófono paso 3). Si alguna no necesita su iPhone, a `done`.
- Si al verificar una hipótesis descubres que la card ya está resuelta en 2.1 o en 2.2, no la dupliques: dilo en el PR y en la card.

## Qué NO hay que tocar
- No tocar los iPhone ni el iPad de Jürgen: los está usando el QA guiado. Todo en simulador.
- Nada de 2.2. Si tocas archivos que cambiaron en 2.2 (por ejemplo `ShellDataAlertsModifier.swift` o lo de nube e iCloud del PR #560), anota en el PR qué habrá que mirar al traer 2.1 a 2.2.
- No rediseñar los flujos de migración, vuelta a iCloud ni alta de Grupos más allá de lo necesario para cada arreglo. Si alguno pide una decisión de diseño o de texto que no está en la card, deja la propuesta en la card a nombre de `jurgen` en espera de decisión y sigue con las demás.
- No pedir OK a Jürgen: cierra sola con /cerrar-total.

## Dependencias
La sesión arranca ya sobre `origin/2.1`, sin esperar CI ni merge de ningún PR anterior (el PR #562 está en cola de merge a 2.1). Justo antes de abrir el PR: `git fetch` y un solo rebase sobre `origin/2.1`; el build y el simulador van una vez después de ese rebase. PR contra 2.1. No esperes el CI para cerrar: el PR entra cuando el CI sale en verde.

## Mini (pipeline serial, sin preguntar)
1) Limpiar sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees ya cerrados. 2) Build con `xcodebuild -jobs 2` sin simulador encendido. 3) Bootear un solo simulador (antes, `xcrun simctl list devices booted`). 4) Tests. 5) Apagar y borrar ese simulador. Prohibido solapar build, simulador y UITests.
Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de un worktree vivo (el del QA guiado). Si un borrado falla, dilo en el cierre.

## Cómo se sabe que está bien
- Se cumple el `hechaCuando` de cada una de las cuatro cards, con tests nuevos en verde y su control.
- `/gate` en verde en lo tocado; capturas de antes y después en `capturas/` para lo que se vea en pantalla (asociación de Grupos, borrado con progreso, grupos que aparecen).
- PR a 2.1 abierto y en cola de merge; cards movidas como se pide arriba.
- En el resumen de cierre, indica qué pruebas debe repetir la sesión del QA guiado.
- CIERRE: cierra sola, /cerrar-total sin esperar a Jürgen.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Un PR o cuatro?** → Un PR contra `2.1` con un solo commit.
Por qué: el encargo pide un PR y las cuatro van al mismo QA guiado; y el sello del `/gate` es la huella del árbol entero contra HEAD, así que partirlo en un commit por card dejaría tres commits sin sello propio. Alternativa descartada: cuatro PR, que multiplican rebase y CI sin aislar nada que importe.

**D2 · Voz: ¿solo las dos salidas que nombra la card?** → Las dos y una tercera: si la grabación falla al arrancar con la sesión ya activa, también se suelta avisando.
Por qué: es el mismo síntoma (la música no vuelve) por el mismo patrón, y el CLAUDE.md pide todas las instancias. Alternativa descartada: dejarla, que deja la música muda tras un error de micro.

**D3 · Las hipótesis INFERIDAS de las cards 1 y 3** → se verifican en código antes de arreglar; si la causa es otra, se arregla la causa medida y se dice en la card y en el PR.
Por qué: lo pide el encargo y la regla «mide antes de obedecer».

**D4 · Borrado de iCloud (card 2): ¿qué sustituye al plazo fijo?** → Un plazo SIN AVANCE: el borrado sigue mientras cada tanda borre algo y solo se corta si pasa un rato sin avanzar; progreso visible con lo borrado; texto propio para el corte por estancamiento que no culpa a la conexión.
Por qué: es la primera opción que da la card («seguir mientras avance») y el molde que el repo ya usa en las esperas de la migración (tiempo sin avanzar, no total). Alternativa descartada: reanudar sola en otro intento, que necesita estado durable y un disparador nuevo.

**D5 · Capturas** → Antes y después en simulador para lo que se pueda montar con los seams existentes; lo que solo se ve con CloudKit real o con backend real (borrado de un iCloud grande, grupos que bajan de producción) se cubre con tests y queda para el device-QA, y se dice.
Por qué: CloudKit no existe en el simulador y el encargo prohíbe tocar los iPhone.

**D6 · Cierre de cards** → Las cuatro a `in qa` a nombre de `jurgen` con su guion; ninguna a `done`, porque las cuatro piden el iPhone para verse de verdad.

**D7 · Review adversarial (cards 1-3, sync y borrado en iCloud)** → tres lentes; se corrigieron cinco hallazgos: el registrador no asocia con el retiro de la sesión anterior armado; la pestaña no arranca el canal con un cierre o un desasociar en curso; la espera que pide CloudKit se acota al plazo sin avance; un fallo de red por registro cuenta como red; y el reloj del corte es monotónico. Se aceptan sin cambio: sin tope total (un feed que avanza sin fin no se ve posible con un token real) y el texto «vuelve a intentarlo» también para fallos que reintentar no arregla (mejor que culpar a la conexión).
