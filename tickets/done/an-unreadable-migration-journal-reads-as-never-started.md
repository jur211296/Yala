---
id: an-unreadable-migration-journal-reads-as-never-started
status: done
priority: very-high
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-22
source: "barrido del patrón durante `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (2026-09-22)"
---

# Si el registro de la migración no se deja leer, la app dice que nunca empezó — y borra el motivo por el que paró

## El problema, en lenguaje de usuario

La app guarda en qué punto va el paso de tus datos a la nube (o la vuelta a iCloud), y también por qué se paró
si se paró. Si esa anotación no se deja leer, la pantalla de Almacenamiento no dice «no he podido comprobarlo»:
dice que **la migración nunca empezó**. Y de paso **borra el motivo del aborto**, que es justo lo que la persona
necesitaba para saber qué hacer.

## Por qué pasa (medido el 2026-09-22 en este árbol)

Dos sitios, y el segundo es el que convierte un problema de lectura en un problema de ESTADO:

1. `CloudMigrationController.readJournalSnapshot:1229` — el `catch` devuelve `(.notStarted, 0)` **y además limpia
   `cutoverBlocker`, `reverseAbortReason` y `hasPendingReverseExit`**. O sea que una lectura fallida no solo miente:
   destruye la nota que explicaba la parada.
2. `MigrationPhaseStore.journaledPhase:119` — el `catch` devuelve `.notStarted`.

Y `notStarted` **es fase ESTABLE** (`MigrationRuntimeGate`): es la fase de un dispositivo ADOPTADO, la que deja
pasar el gate del par `.cloud` + `mirrorOffArmed`. Leer una fase ilegible como estable es exactamente lo que ese
gate existe para impedir — el invariante está escrito en `.claude/rules/swiftdata-cloudkit.md`, sección «El par
que apaga el mirror».

Tres vecinos de la misma pantalla, con el mismo patrón y `try?` en vez de `catch`:

| Sitio | Devuelve | Consecuencia |
|---|---|---|
| `CloudMigrationController.refreshSyncBanner:1166` | `0` | `syncNeedsSignIn = false`: el aviso «tienes N sin subir» no sale |
| `CloudMigrationController.reverseEligibility:1244` | `hasCKMap = false` | el dispositivo sale NO elegible para la vuelta a iCloud |
| `CloudMigrationController.dryRunCounts:1269` | `0` por entidad | «Ver qué migraría» dice **cero** |

## Qué habría que decidir antes de hacerlo

1. **¿Cuál es el `notStarted` honesto?** No hay hoy una fase «no lo sé». Puede hacer falta un estado nuevo, o que
   la pantalla lo pinte como un error en vez de como una fase.
2. **La limpieza de `cutoverBlocker`/`reverseAbortReason` es una escritura, no una lectura.** Es probable que la
   respuesta más barata y más segura sea sacarla del `catch`, sin tocar el resto.
3. Los tres del `try?` son de la superficie de la pantalla y su default seguro puede no ser el mismo que el del
   journal; conviene decidirlos uno a uno.

## Criterios de aceptación

- [x] Una lectura fallida del journal NO se presenta como `notStarted` — en ninguno de los dos lectores.
- [x] Y no borra el motivo del aborto (ni los otros cinco motivos, ni el freno de la vuelta).
- [x] La pantalla de Almacenamiento dice algo honesto en ese caso.
- [x] Test con la lectura lanzando + control positivo.

## Relacionado

- `verify-reads-a-failed-local-fetch-as-an-empty-outbox` — el mismo patrón sobre el fetch de `SyncOutbox`, cerrado.

## Qué se hizo (2026-09-22)

**Para quien usa la app:** si el registro del paso de sus datos a la nube (o de la vuelta a iCloud) no se deja leer, la
pantalla «¿Dónde viven tus datos?» ya no dice que nunca empezó: dice que no pudo comprobarlo, que por ahora no se pueden
mover y que lo sigue intentando. No borra el motivo de la última parada, y en cuanto la lectura vuelve la pantalla es la
de siempre, con ese motivo intacto. Por detrás, con el registro ilegible la app ya no arranca la sincronización, no corre
tareas en segundo plano sobre datos a medio cargar, no retoma una migración a ciegas y no empieza una nueva.

**Premisas corregidas al medir:** las coordenadas del ticket eran anteriores a #214, y la pantalla no tenía tres `try?`
sino cuatro (faltaba `markerDecision`). El detalle de las decisiones está en el Paso 0 del encargo y en la regla de
`.claude/rules/swiftdata-cloudkit.md` que empieza por «Un journal que no se deja leer NO es `notStarted`».

1. **La lectura fallida tiene su propio valor**: `JournaledPhaseRead.unreadable` (no un case de `MigrationPhase`).
   `MigrationPhaseStore.currentPhase` pasa a `currentPhaseRead` y los siete consumidores deciden hacia el lado que no
   concede: BGTasks con la disciplina transitoria, motor parado, remap bloqueado, drenaje de preferencias sin drenar.
2. **La captura de identidad se aplaza**, no se decide: la deriva la primera lectura buena y cada primer plano la provoca.
3. **El controller tiene un solo lector** sobre una función pura; la rama ilegible no escribe ningún motivo. Arranque,
   re-kick y arranque del motor no deciden nada sin journal, y «Migrar» y «Volver a iCloud» vuelven a leer antes de
   empezar.
4. **Pantalla**: estado propio `.journalUnreadable`, tarjeta honesta sin botones que muevan datos, sección de Grupos
   conservada. No cuenta como «dentro» para la fila de Ajustes ni para la puerta del kill-switch. El Welcome lo lee como
   «sin dato en este tick».
5. **Los cuatro `try?`**: la cola que no se cuenta ofrece firmar sin cifra; el mapa que no se cuenta es
   `ReverseEligibility.mapUnreadable`; «Ver qué migraría» no enseña ceros inventados; el marcador que no se cuenta se lee
   «no hay» (lado seguro). El aviso de firmar pasa al molde de la nota de la vuelta: icono naranja y texto secundario
   (como texto, el naranja no llega a AA sobre la tarjeta blanca).

**Review adversarial (cuatro lentes) y lo que cambió por ella**, porque cazó dos defectos serios de este mismo arreglo:
- Un arranque con el journal ilegible dejaba el motor de la nube `.idle` hasta relanzar, con «Todo sincronizado» en
  pantalla: nadie re-evalúa `.idle`. Ahora el re-kick de cada primer plano lo arranca si la fase es estable.
- `.journalUnreadable` contaba como «dentro» (`uiState != .idle`): abría la fila bajo el kill a quien nunca empezó y
  apagaba la re-medición del kill antes de migrar. Ahora `StorageRowGateLogic.isEngaged`, con `switch` exhaustivo.
- Además: la derivación aplazada casi nunca se consumía en `.icloud` (hook de primer plano); las confirmaciones de migrar
  y volver cuelgan de la raíz de la pantalla (guard en las dos entradas); el Welcome pintaba un `.error` con salida y un
  «Reintentar» que repetía el sign-in (ahora `nil`); pt-PT en registro formal; y seis huecos de tests (scans parciales,
  seams que lanzan antes del fetch real, inventario de consumidores) cerrados con cuerpos enteros.

**Verificación:** suite unitaria completa (7556 tests en 747 suites) y los XCUITest de «¿Dónde viven tus datos?»
más Edge cases y Divisa (17 casos en 6 suites, con el nuevo `StorageJournalUnreadableUITests`, corrida sola según el
centinela). **33 mutantes, uno a uno: 33 muertos** (18 de cableado sin recompilar, 15 de comportamiento recompilando
cada uno). Captura en el simulador: la tarjeta se lee bien, con el icono naranja y la sección de Grupos debajo.

## Residuales con ticket propio

- `an-undecodable-migration-phase-reads-as-never-started`: un `phaseData` presente que no decodifica sigue leyéndose
  `notStarted` (camino distinto al del `fetch`, con fixture APPEND-ONLY; lo que no cubre es un downgrade).
- `apple-id-change-boot-check-runs-before-the-migration-guard-can-see`: en el arranque, el guard «no a mitad de una
  migración» de la comprobación del Apple ID consulta un controller que aún no existe (previo a este ticket).
- `cloud-sync-status-says-all-synced-with-changes-still-pending` (ampliado): el check verde con el motor `.idle` por el
  gate de dominio.

## Residuales aceptados, escritos para que nadie los dé por cerrados

- **Con el journal ilegible de forma persistente durante un adopt del Welcome, la pantalla espera sin salida.** Antes
  tampoco la tenía (pintaba `.adopting(0)` y el reintento re-reclamaba la cuenta); ahora no inventa progreso ni
  re-reclama. En una instalación nueva el store de sync-meta es nuevo, así que la población es la de una avería real.
- **Las acciones que ya estaban en vuelo (`resume`, `pollLeader`, los `cancel*`) no miran el testigo**: decide el runner,
  cuyas lecturas del journal lanzan y fallan cerradas.
- **Al arrancar el motor a mitad de proceso, el loop propio de Grupos que arrancó al ver el motor bloqueado sigue vivo**
  hasta que muera: es la misma situación que ya da el adopt en sesión, y la coalescencia de `syncCycleOnceCoalesced`
  impide que corran dos ciclos a la vez.
- **El panel DEBUG (`CloudSyncDebugView`) conserva sus `try?`**: solo `DEV_BUILD`, fuera del alcance de la pantalla.

## QA de dispositivo

No hace falta: el comportamiento nuevo solo aparece con el registro ilegible, que en un iPhone no tiene guion razonable
(sale con el store protegido antes del primer desbloqueo o con una avería de disco). Lo cubren el XCUITest con el seam
`-uitest-migration-journal-unreadable` y la suite unitaria, y en condiciones normales la pantalla no cambia (lo fija el
control del mismo XCUITest). El único cambio visible fuera de ese caso es de estilo: el aviso «Inicia sesión para subir N
cambios» lleva ahora el icono naranja y el texto en gris, como la nota de la vuelta de la misma pantalla.
