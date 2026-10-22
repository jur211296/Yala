# «Volviendo a iCloud…» al 95 %: techo + salida (callejón 2.1)

## Contexto
Ticket: `tickets/backlog/reverse-upload-has-no-ceiling-and-no-exit.md` (high).
Hito Jürgen: lanzar 2.1 (modo nube sin callejones). Este es must-fix: la reversa puede quedarse al 95 % para siempre con la nube ya cerrada a escritura; «Retomar» no ayuda; sin tope de tiempo.

Hermano: `reverse-claim-rejection-has-no-way-out-in-the-client` (barra al 15 % sin salida) — si al medir cabe el mismo arreglo de salida, anótalo o ábrelo; no ensanches el alcance sin medida.

## DIURNO (6:00–21:00 Lima)
Puedes AskUserQuestion a Jürgen para producto/acceso.

## Que se pide
1. Medir y dar **techo** (tiempo/presupuesto) y **salida honesta** cuando el export CloudKit no drena (copy + acción: cancelar/retomar con verdad / volver a un estado usable).
2. Que la persona no quede sin red (nube cerrada + iCloud sin progreso) sin explicación ni botón útil.
3. Tests según el repo.
4. Gate, commit, `tickets/` + `docs/TICKETS.md`, PR, merge a 2.1 si OK, `/cerrar-total`. Bugs → ticket. No Kanban/store.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit/board/merge/`/cerrar-total` sin preguntar. Solo parar ante decisión/acceso real. UI tests CI advisory.

## Que NO
marketing/; no ship-blockers de otro tema (Siri, CSV) salvo ticket propio si aparecen.

## Como se sabe que esta bien
Si el export no drena: no se queda al 95 % eterno sin mensaje/salida. Board + `/cerrar-total`.

## Avisos Frank
Webhook Mini (URL/key local): (1) decisión/acceso; (2) PR/preview; (3) `/cerrar-total` + resumen usuario; (4) sin siguiente — una vez. NO: test rojo a reclasificar, build retry, CI advisory.

## Paso 0 — decisiones

> D1–D4 las contestó **Jürgen** (2026-09-16, 12:0x Lima), las cuatro con la recomendada. D5–D14 son técnicas
> y mías, resueltas sobre lo medido; se discuten en el PR.

### Hechos medidos que cambian el ticket

- **«Una sola copia» es verdad a medias.** En `reverseUpload` el backend conserva, congelada, la copia que
  `reverseVerify` dio por igual a la local justo antes de `reverse_freeze` (`reverse_complete` y
  `reverse_abort` no borran datos: `qa/cloud/README.md`). Lo único que vive solo en el teléfono es lo que la
  persona escribe después del congelado.
- **Hay un disparador determinista.** Sin cuenta de iCloud el store se monta `.localNoMirror`, que adjunta el
  espejo (medido 2026-08-10, `SwiftDataConfiguration.attachesCloudKitMirror`); `isMirrorConfirmedOn` da
  `true`, la quiescencia se cumple sin import (`SubcategoryDedupGate`: «sin import previo… nada que
  esperar»), y la reversa llega a `reverseUpload` y no sale nunca. `ReverseEligibility` no mira iCloud.
- **El error de «sin cuenta» no llega como `CKError`** (es `NSCocoaErrorDomain 134400`), así que
  `iCloudSyncService.lastExportError` no lo recoge; y `.notAuthenticated` tampoco (sale antes por
  `mirrorReportedNotAuthenticated`).
- **La máquina prohíbe hoy echar atrás tras el montaje** («POST-mount → HOLD, NEVER rollback») y la salida
  DEBUG deja el teléfono en `.icloud` sin descongelar.
- **El muestreo falla ABIERTO por su entrada** (`reverseUploadStatus`): filas `failed` o un fetch de
  `SyncIdentity` que lanza cuentan como «nada pendiente» y cierran la reversa como hecha. Otro objeto → ticket.

### Producto (Jürgen)

**D1 · ¿Dónde queda la persona cuando la subida no avanza?** → **vuelve a la nube**: se cancela la vuelta,
se descongela la nube de Yala, se pide cerrar y reabrir Yala una vez y se dice por qué.

**D2 · ¿Cuándo se da por hecho que no avanza?** → **tiempo SIN avanzar**: 15 min si iCloud ya dijo que no
(lleno o cuenta inutilizable), 72 h si no se sabe. Un corpus grande que sube despacio nunca llega al tope.

**D3 · ¿Qué ve mientras espera?** → **cuántos faltan + «Cancelar y seguir en la nube»** con confirmación,
disponible siempre en esa fase; si el dispositivo no tiene iCloud activo, lo dice.

**D4 · ¿Se cierra también la entrada sin iCloud?** → **ticket aparte**: la señal disponible mide iCloud
Drive, no CloudKit, y podría esconder el botón a quien sí puede volver.

### Técnicas (mías)

**D5 · Qué es «avanzar»** → que la cifra de pendientes baje por debajo de la **más baja vista** en este
intento. La primera observación sella el reloj; la cifra más baja y el instante del último avance van al
journal (`reverseUploadLowestPending`, `reverseUploadProgressAt`). Por qué: es la letra de D2, y la cifra
SUBE cuando la persona escribe durante la espera; con el mínimo, escribir no reinicia nada. Descartada: la
cifra de capturadas, que baja con cada borrado y retrasaría ver un avance real (sesgo hacia abortar).

**D6 · La causa (15 min o 72 h)** → `definitive` solo con la palabra de CloudKit: `lastExportError` en
`quotaExceeded`/`notAuthenticated`/`managedAccountRestricted`/`userDeletedZone` (la MISMA tabla de
`ICloudCutoverGateLogic.decide`, reusada) o `mirrorReportedNotAuthenticated`. Sin token de iCloud Drive la
causa es `unknown` (72 h), pero el copy lo dice y el botón de cancelar está ahí. Por qué: D2 dice «iCloud ya
dijo que no», y la regla del repo es que el token de Drive nunca decide solo. Descartada: tratar «sin
Drive» como definitivo, que acortaría la espera a quien tiene Drive apagado y CloudKit sano.

**D7 · A qué fase vuelve el journal** → a la fase ORIGEN (`done`/`notStarted`, inyectada desde
`reverseOriginRaw`, molde de `reverseOtherLeader`), no a `reverseFailedRollback`. Por qué: en
`reverseFailedRollback` el motor de la nube no arranca hasta que alguien toca «Reintentar»
(`isDomainStablePhase == false`), y el tope salta con la persona ausente: quedaría en la nube sin
sincronizar y sin nadie que lo diga. En la fase origen, tras el relanzamiento, el motor arranca solo y sube
lo escrito durante la espera. Descartada: cambiar `isDomainStablePhase(.reverseFailedRollback)`, que
alcanza también al aborto pre-montaje (otro objeto).

**D8 · Efectos de la salida, en orden** → `[.rearmMirrorOff, .reverseRollback]`. Primero lo local, que no
puede lanzar (`StorageModePersistence.writeCloudArmed`, el escritor único del par): así, si
`reverse_abort` falla sin red, el teléfono ya pide relanzar y el motor no puede arrancar con el espejo
montado (`personalMountMismatch`); el aborto queda journaleado y lo reintenta el siguiente resume. Efecto
NUEVO y no `.disableMirrorAndRelaunch`: ese se resuelve por observación en el resume y dispara
`mirrorRelaunchCompleted`, inválido desde `done`, que además corta el drenaje del resto de pendientes.

**D9 · Dónde vive el «por qué»** → `reverseAbortReasonRaw` en el journal: sobrevive al relanzamiento, lo
pintan la tarjeta de relanzar y, después, la tarjeta de «Volver a iCloud». Se limpia al empezar otra vuelta
y al completarla. Sin botón de descartar: menos escritura del journal y la frase sigue siendo cierta.
`cancelled` no lleva nota (la persona lo hizo).

**D10 · Alcance del botón** → solo en `reverseUpload`. Otras esperas post-montaje (p. ej.
`reverseReconcile(.awaitingQuiescence)`) no tienen tope y son otro objeto.

**D11 · Canarios** → `cloudReverseUploadWaiting` (detalle `advancing|stalled` + tramo de horas sin avanzar
+ causa; dedupe por proceso para no inundar con el refresco de 30 s) y `cloudReverseUploadAborted` (motivo).

**D12 · Lo que se abre como ticket y no se toca** → (a) la entrada a «Volver a iCloud» sin iCloud (D4);
(b) el muestreo que falla abierto; (c) lo que el espejo IMPORTÓ durante la espera sube a la nube tras la
salida (el drenaje solo excluye `outboxSaveAuthor`); residual documentado; (d) `canRunDomain` no mira efectos
pendientes: sin red en el momento de la salida, el motor puede chocar con el 409 del congelado y pararse
hasta el siguiente arranque; se documenta, se busca duplicado antes de abrirlo.

**D13 · Tests** → unit en la máquina, el journal, el runner, el executor, la lógica de causa y el derivador
de UI; mutantes sobre el tope, el orden de efectos, el sello del reloj y el mínimo. Sin XCUITest positivo:
no hay seam que ponga `.cloud` (precedente en `.claude/rules/gateway-attest.md`); guion de device en el
ticket.

**D14 · Review adversarial** → sí: toca la máquina de migración y dónde vive la copia de los datos. Lentes:
máquina/journal, seguridad de los datos tras la salida, UI/copy contra el estado, y la regla de área.

### Ficheros

`MigrationStateMachine.swift` · `ICloudCutoverGateLogic.swift` · `MigrationState.swift` ·
`MigrationRunner.swift` · `MigrationWorkExecutor.swift` · `CloudMigrationController.swift` ·
`StorageSettingsView.swift` · lógica de copy nueva en `Yala/App/Logic/` · `L10n.swift` + 16
`Localizable.strings` · `MetricsService.swift` · breadcrumbs en `CloudSyncEngine.swift` · sus tests ·
`qa/coverage-index.json` · la regla `swiftdata-cloudkit.md` · tickets.

### Tras la review adversarial (cuatro lentes, 2026-09-16)

> D15–D17 las contestó **Jürgen** (13:1x Lima), las tres con la recomendada. El resto son arreglos de hallazgos
> que no tocaban decisiones suyas.

**Corrección de un «hecho medido» de arriba.** «Sin cuenta de iCloud la reversa llega a `reverseUpload` y no
sale nunca» es cierto para un migrado o un adoptador, **no para una cuenta nacida en la nube**: el muestreo solo
emparejaba filas con testigo `SyncIdentity`, y lo creado en ese teléfono no tiene (solo lo crean
`backfillIdentities` —ida y adopt— y el pull de filas nuevas). Cero pares ⇒ `.drained` ⇒ la vuelta se daba por
hecha al instante, sin comprobar nada.

**D15 · ¿El muestreo cuenta las filas sin testigo, en este PR?** → **sí**. La espera cuenta todas las filas vivas:
con su testigo si lo tienen y, si no, con uno scratch sin insertar (molde de `isMarkerExported`). Para una cuenta
nacida en la nube la vuelta deja de ser instantánea: espera a la subida real, con techo y con «Cancelar».

**D16 · Yala cerrada 72 h a mitad de la vuelta** → **aceptarlo y decirlo**. Con la app cerrada el espejo no sube
(inferido), así que ese tiempo cuenta como sin avanzar y la primera observación al abrir sale a la nube. Salir es
seguro y el siguiente intento aprovecha lo que ya subió; la nota aconseja reintentar con Yala abierta.

**D17 · Tres casos raros de volver a la nube** → **tickets aparte**: (a) filas borradas que el espejo re-importa
después del barrido suben a la nube; (b) en el 2.º dispositivo de una cuenta ya revertida, tras salir no se puede
reintentar; (c) un `reverse_abort` rechazado por otro líder deja la nube congelada con «Todo al día».

**Arreglado sin preguntar (no tocaba decisiones suyas):**
- **Empezar otra vuelta con `reverse_abort` pendiente lo borraba** (`handle` reemplaza los pendientes) y la vuelta
  nueva se clavaba al 30 % con la nube congelada. Ahora `submit(.reverseActivated)` drena antes; si no puede, no
  empieza y la pantalla lo dice (`storage.errors.reversePendingExit`).
- **Un «iCloud lleno» ya resuelto seguía mandando**: `lastExportError` no se limpia con un éxito. La reversa solo
  lo cree si su fecha (`iCloudSyncService.lastExportErrorAt`, nueva y aditiva) es posterior al último export con
  éxito. El latch en sí sigue en `icloud-export-error-latch-never-clears`.
- **Sin token de Drive la pantalla afirmaba que los datos «no pueden llegar»**: ahora el aviso es condicional, la
  cifra se enseña con todos los mensajes y el motivo de salida es `stalled`, no «no estaba disponible».
- **Copy**: las notas en pasado (sobreviven al relanzamiento), el techo corto dicho sin prometer tiempo, sin
  «tendrás que» (BRAND-VOICE §8), y texto en `.secondary` con el icono naranja (el naranja como texto da 2,2:1).
  El botón pasa a `YalaSecondaryButton`.
- **Reloj adelantado al sellar**: un sello futuro se re-sella con la observación en vez de aplazar el techo. La
  segunda pasada midió el precio: un sello futuro también aparece si el reloj equivocado es el de AHORA (fecha
  puesta atrás a mano durante la espera), y al corregirla la espera puede salir de golpe. Los dos casos exigen tocar
  la fecha más que el techo; queda como caso raro con ticket (D17):
  `reverse-upload-ceiling-trusts-a-clock-set-back-during-the-wait`.
- **La salida se cuenta al journalearla**, no tras `reverse_abort`: la tarjeta de relanzar aparece antes.
- **«Cancelar» usa la pre-espera de quiescencia de `resume()`** en vez de rendirse en silencio a los 120 s.
- **La confirmación se resetea** si la espera termina con ella abierta.

**Segunda pasada de review, sobre los arreglos (dos lentes: código y copy). Arreglado sin preguntar:**
- **El drenaje antes de otra vuelta ejecutaba CUALQUIER pendiente**, no solo la salida. Lo cazaron las dos lentes.
  Un líder al que otro dispositivo le quitó la lease vuelve a `done` con `.runLeaderReconcileFromFrozenCloudKit`,
  que lanza `other_leader` en cada intento; antes `handle` lo reemplazaba y «Volver a iCloud» era su única salida, y
  el drenaje la cerraba para siempre con un aviso que culpaba a la conexión. Ahora solo se drena con la salida
  pendiente (`ReverseExitPending`, `.reverseRollback`), y el aviso sale solo en ese caso.
- **El aviso de salida pendiente se cerraba solo** entre 0 y 30 s: sale justo con un pendiente, que es lo que
  dispara el re-kick de la pantalla, y `resume()` borraba `lastError`. El re-kick en segundo plano ya no lo borra
  (`resume(clearingError:)`); una acción de la persona, sí.
- **Un «Cancelar» que vencía la pre-espera de 300 s se perdía** sin decirlo. Queda apuntado en memoria y lo ejecuta
  el siguiente `resume()` que pase la pre-espera, antes de retomar.
- **Copy que prometía lo que no se mide**: «Si no liberas espacio en unos minutos» condicionaba la salida a un gesto
  de la persona, y el reloj cuenta desde el último avance. Ahora dice «Si la subida no avanza en unos minutos». La
  confirmación de «Cancelar» mandaba cerrar Yala antes de que la salida quedara guardada: ahora dice que Yala lo
  pedirá. La nota `stalled` añade «Comprueba que iCloud esté activo», la pista útil para un iPhone sin iCloud. El
  aviso de salida pendiente ya no afirma que «hace falta conexión»: también sale con la salida en marcha.

**Con ticket (casos raros, D17):**
- `reverse-upload-ceiling-trusts-a-clock-set-back-during-the-wait` — el reloj, arriba.
- `reverse-upload-sample-walks-every-row-twice-on-the-main-thread` — cada observación recorre dos veces todas las
  filas en el hilo principal (la segunda pasada ya existía para los migrados; desde D15 la paga toda cuenta nacida en
  la nube), cada 30 s con la pantalla abierta. Sin medir en device.
- Una sesión caducada con el `reverse_abort` pendiente deja el aviso de salida pendiente para siempre: anotado en
  `reverse-abort-rejected-leaves-a-frozen-cloud-saying-up-to-date`, que es la misma nube congelada por otra causa.
- `storage-actions-release-the-working-flag-under-a-running-resume` — anterior a este ticket: «Volver a iCloud»
  confirmado durante un re-kick no hace nada y baja `isWorking` con el `resume()` aún en vuelo.

**Aceptado sin ticket:** tras una salida automática, la petición de relanzar solo se ve en «Dónde viven tus datos»,
igual que en el paso 4 de la ida; hasta el siguiente arranque en frío el motor está parado. Y `userDeletedZone` se
lee como «iCloud no disponible» porque es la tabla de la ida, sin medir cómo lo entrega el espejo.
