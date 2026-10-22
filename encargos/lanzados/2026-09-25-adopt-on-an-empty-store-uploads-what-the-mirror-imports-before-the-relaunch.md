# Un adopt sobre store vacío no pide linaje; lo que iCloud importa antes de relanzar se sube a la cuenta ajena

## Contexto
Cola A autónoma (callejón nube: adopt / migración / claim / restore…). Acaba de mergear a 2.1 el PR #247 (`markerless-adopt-stays-blocked-while-another-device-writes-to-the-account`): si el líder no dejó marca en iCloud, el siguiente adoptador con todos los datos de la cuenta deja la suya y los que llegan después ya no se quedan esperando. Residual low nuevo `markerless-adopt-without-full-coverage-never-relays-the-marker` (no tocarlo ahora). `adopt-rekeyed-rows-without-a-unique-lineage-key-still-duplicate` sigue en backlog esperando canario (no lanzar).

Ticket: `tickets/backlog/adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch.md` (medium, modo-nube/migración). Review adversarial del padre `adopt-uploads-a-foreign-corpus-without-a-lineage-check` (lente bypass H1). Premisa medida: la guarda de linaje del adopt solo corre con `pendingUploads > 0`; la quiescencia da true antes del primer import; tras relanzar un token ausente hace full rescan y sube lo que el espejo acabó de importar a una cuenta que no es la del iCloud local.

Quien recibe este encargo arranca en contexto limpio.

## Que se pide
1. Al arrancar: mueve el ticket a `in-progress`, actualiza `docs/TICKETS.md`, y deja el board al día.
2. Cierra el agujero: un adopt sobre store vacío no debe mezclar en la cuenta de nube lo que iCloud importa después (entre el adopt y el relanzamiento), ni saltarse la prueba de linaje cuando el corpus local aparece tarde. Opción robusta / good-practice (norma Jürgen: nunca la más simple).
3. Canarios/tests que midan el caso (store vacío al adoptar → import iCloud posterior → no sube corpus ajeno / no mezcla).
4. Si la review saca residuales, créalos como tickets propios antes de cerrar.
5. Gate, PR a `2.1`, merge, board (`done` si no hace falta QA manual en iPhone; si hace falta → `in qa`), actualizar `docs/TICKETS.md`, memoria/estado según plantilla del repo, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, índice `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo: implementa hasta cerrar. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen (día 06:00–21:00 Lima: AskUserQuestion vía aviso al bot; de noche elige lo recomendado o aplaza el ticket). Board: create/move directo en `tickets/` (sin inbox Tim).

## Que NO hay que tocar
- `marketing/` / Web/
- Relanzar o reabrir `markerless-adopt-without-full-coverage-never-relays-the-marker` (low) ni `adopt-rekeyed-rows-without-a-unique-lineage-key-still-duplicate` (espera canario)
- Paralelizar otro ticket de Cola A
- Pedir OK de continuación por volumen de ficheros

## Como se sabe que esta bien
- Criterios del ticket cumplidos y medidos (test/canario, no solo prosa)
- PR mergeado a `2.1`
- Ticket e índice al día; `/cerrar-total` limpio
- Resumen de cierre en lenguaje de usuario (Necesita de ti → Cambiado → Encontrado)

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

## Paso 0

**Medido (2026-09-25, en el código).**
- El adopt corre con el espejo de CloudKit ADJUNTO en tres entradas: «Activar la nube en este dispositivo» de Ajustes
  (MainTab monta `.iCloudMirror`/`.localNoMirror`), el resume del arranque y el «Ya tengo una cuenta» de un Welcome que se
  mató a mitad (el fichero del store ya existe y `hasShownWelcomeChooser == true`, así que el arranque siguiente no monta
  neutro). El Welcome de una instalación limpia monta NEUTRO: ahí no hay espejo, no importa nada y no hay agujero.
- Con el espejo adjunto nada fuerza el relanzamiento: la tarjeta de Almacenamiento dura lo que la persona tarde en
  reabrir, y el espejo sigue importando. El drain traduce todo lo que no escribió el motor (`CloudSyncEngine.swift:1778`),
  imports incluidos, y la línea base se avanzó en el paso 3: lo importado después sube en el primer drain tras relanzar.
- Ninguna guarda para con el store vacío: la del Welcome (`CrossAccountEntryGuardLogic`) deja pasar sin filas locales,
  Ajustes no tiene guarda cruzada, la de linaje devuelve `nil` con cero filas relevantes y la quiescencia es `true` antes
  del primer import.
- **Corrección a la premisa del ticket:** anclar la línea base sin transacción personal no cerraría nada. Un teléfono real
  siempre tiene una (los tipos de cambio que siembra el arranque), así que el ancla existe; y lo que se importa DESPUÉS del
  paso 3 queda por encima de cualquier ancla.

**Decisiones (auto-contestadas, modo autónomo).**
- D1 · **El adopt no da por contestada la pregunta del linaje mientras el corpus de iCloud no haya llegado.** Con el espejo
  adjunto y ninguna fila local que pida linaje (las 16 entidades menos los tipos de cambio), le pregunta a CloudKit
  directamente, sin el espejo, si ese iCloud tiene alguna de esas filas. Si la tiene, espera a que el import la baje, y
  entonces decide la guarda de siempre, con su salida de siempre. Si no la tiene, o no hay cuenta de iCloud, entra.
- D2 · Va en el reconcile, después de leer el inventario local y ANTES de la red del backend, con un desenlace propio
  (`awaitingICloudCorpus`) → `adoptRetry`: techo largo del efecto (72 h → `effectStalled`), «Cancelar» y la tarjeta de
  progreso de siempre. Sin texto nuevo. Una sonda que falla es `transient`: nunca se entra sin respuesta.
- D3 · La sonda es un lector nuevo en `ICloudPersonalCorpusProbe`: enumera las zonas del espejo y para en el PRIMER
  registro `CD_<entidad>` que cuente, bajando solo metadatos (`desiredKeys: []`, el plan B que ese fichero ya escribe para
  su propia lista). Los tipos salen de `CloudSyncEngine.personalEntityNames` menos `ExchangeRate`, y un test los ata a la
  exención del adopt: si una cambia, la otra también.
- D4 · Dos seams en el ejecutor con el default en la verdad del host de test (`false`: sin espejo), y producción los
  inyecta en `makeExecutor`. Un test de cableado lo fija.
- D5 · Descartadas: exigir `hasCompletedFirstImport` (un iCloud sin nada que importar no lo enciende nunca: dejaría fuera
  al 2.º teléfono de una cuenta nacida en la nube) y la salida por gracia de `BootSaveGateLogic` (falla abierta con un
  import lento: es el agujero). También anclar la línea base (medido arriba: no cambia nada).
- D6 · Canario `cloudAdoptICloudCorpusChecked` (`found|none|noAccount|failed:<motivo>`, una vez por proceso y desenlace):
  cuánto pasa en la flota y si la sonda funciona en producción.
- D7 · Lo que queda, con ticket: con iCloud VACÍO al adoptar, lo que OTRO teléfono del mismo Apple ID escriba en ese
  iCloud antes del relanzamiento sube igual. Con el corpus de la cuenta, lo que llega después es de su linaje; con uno
  ajeno, el adopt no termina.
- D8 · CloudKit no existe en el simulador: el lector nuevo pide device-QA → ticket a `qa` con su guion. No frena el merge.
