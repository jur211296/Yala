---
id: reverse-upload-has-no-ceiling-and-no-exit
status: done
priority: high
area: "modo-nube, migración"
created: 2026-09-10
updated: 2026-09-23
source: "review adversarial de `reverse-cutover-cerrado-para-cuentas-born-cloud` (2026-09-10), lente de rules + lente de backend"
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - exige cerrar iCloud en el iPhone; la espera con iCloud se ve en reverse-cutover-cerrado-para-cuentas-born-cloud
---

# «Volviendo a iCloud…» al 95 % puede quedarse ahí para siempre, y con la nube ya cerrada

## El problema, en lenguaje de usuario

Pulso «Volver a iCloud». La barra avanza hasta el 95 %, pone «Volviendo a iCloud…» y **no se mueve
más**. Hay un botón «Retomar» que no cambia nada. No hay ningún mensaje que me explique qué falta ni
cuánto puede tardar.

Y mientras estoy ahí, **mis datos están en una sola copia**: en el teléfono. La nube de Yala ya quedó
cerrada a escritura al empezar la reversa, y a iCloud —por hipótesis— no está llegando nada. No pierdo
nada mientras el teléfono viva, pero pierdo la red.

## Por qué pasa

La reversa no sube el corpus a mano: monta el mirror de CloudKit y deja que
`NSPersistentCloudKitContainer` exporte solo. La fase `reverseUpload` **sondea** ese progreso y no
avanza hasta que drene:

- `Yala/Services/CloudSync/MigrationWorkExecutor.swift` · `reverseUploadStatus()` →
  `pending = report.exportPending + report.noMetadata`; `pending == 0 ? .drained : .pending(count:)`.
- `Yala/Services/CloudSync/MigrationRunner.swift` · `driveReverseUpload()` → con `pending` emite un
  breadcrumb, refresca el lease y `return false` («stop retomable»). **No consulta ningún reloj.**

Y ahí se queda:

- **No hay tope.** El presupuesto por tiempo journaleado existe **solo para la ida**
  (`MigrationState.markerWrittenSince`, sellado en la arista `cutover(.markerWritten)`, evaluado con
  `ICloudCutoverGateLogic`). Un `grep` de `ICloudCutoverGateLogic` en `Yala/` da **un solo consumidor**,
  y es el de la ida. Esto choca de frente con la regla del repo, que se pagó con ese mismo caso:
  `.claude/rules/swiftdata-cloudkit.md` — «toda espera por un export del mirror lleva tope, y el tope va
  por TIEMPO journaleado, no por intentos».
- **La cadencia no es un timer**: boot + foreground + tap (`MigrationForegroundRekick`). Si el usuario no
  abre la app, no se re-sondea.
- **Un fallo fatal en esa fase HOLDEA, nunca rueda atrás**: `MigrationStateMachine.swift` —
  `case (.reverseUpload, .fatalError): return .transition(next: .reverseUpload, effects: [])`, con el
  comentario «fatalError POST-mount → HOLD the state, NEVER rollback». El `.reverseRollback` solo cuelga
  de los terminales PRE-mount.
- **En producción no hay escape.** `StorageSettingsView` solo ofrece `resetAfterRollback()`, que es no-op
  fuera de `failedRollback`/`reverseFailedRollback`. El «Forzar salida (escape hatch)» vive en
  `CloudSyncDebugView` y es `DEV_BUILD` only.
- **El backend está congelado.** El orden es `reverseFreezeBackend` → `reverseMountMirror` →
  `reverseReconcile` → `reverseUpload`, así que al llegar aquí `reverse_frozen_at` ya está estampado y
  `gateway/src/sync/routes.ts` responde **409 `yala_account_reverting`** a `/sync/push` y `/prefs/push`.
  Lo único que des-congela es `reverse_abort`, y ningún camino de producción lo alcanza desde aquí.

## Por qué es `high` AHORA y no antes

Porque hasta el 2026-09-10 esto lo alcanzaba «el líder migrado — el único caso real actual» (lo dice
`MigrationRunner`). `reverse-cutover-cerrado-para-cuentas-born-cloud` abrió la reversa a las cuentas
nacidas en la nube, y tras el fresh start de ese día **eso es toda la población**. Además, para un
born-cloud el mirror tiene que exportar **el corpus entero** —no un delta—, así que la espera es
estructuralmente mucho más larga: el `pending` inicial son todas sus filas.

**Y el mecanismo del que todo esto depende no está medido en este repo.**
`Yala/App/Logic/WelcomeMirrorRelaunchLogic.swift` lo dice de su puño: que un mirror adjuntado en un
arranque POSTERIOR exporte lo escrito en la ventana sin mirror es «plausible pero **NO está medido**».
La dirección contraria sí se midió en device (`groups-only-second-launch-mounts-icloud-mirror`, iPhone,
2026-09-09): un mirror diferido **importa**. Que **suba** es lo que falta.

## Lo que hay que decidir (es de producto, no técnico)

1. **¿Cuánto es «demasiado»?** El tope de la ida distingue `definitive` (CloudKit ya dijo que no entra:
   900 s) de `unknown` (aún no se sabe: 259 200 s = 3 días), con **fail-open**: la ambigüedad nunca
   aborta. La reversa necesita su equivalente, y el número no es evidente: un corpus born-cloud grande
   puede tardar horas legítimamente.
2. **¿Qué se le ofrece al llegar al tope?** Un terminal `reverseFailedRollback` deja al usuario en modo
   nube con el backend descongelado (hay que abortar) y el mirror montado — hay que comprobar que ese
   estado es sano. La alternativa es un estado «sigue subiendo, puedes usar la app» que hoy no existe.
3. **¿Y mientras espera?** Como mínimo, decir cuántas filas quedan: el sondeo ya tiene el número
   (`pending(count:)`) y hoy no se muestra. Existe el precedente exacto de copy honesto para la ida
   (`controller.isWaitingICloudExport`), y en la reversa **no se pinta nada**.

## Criterios de aceptación

- [ ] La espera de `reverseUpload` tiene tope por **tiempo journaleado** (no por intentos), con su
      clasificación fail-open, en el molde de `ICloudCutoverGateLogic`.
- [ ] Al agotarse hay una salida que **des-congela el backend** y deja un estado que el usuario entiende.
- [ ] Durante la espera la pantalla dice algo verdadero (cuántas filas faltan, o que puede tardar).
- [ ] Hay un canario que distingue «va lento» de «no avanza», visible en la flota.

## Fuera de alcance

Medir si el mirror exporta de verdad: eso es device-QA y está en el guion de
`reverse-cutover-cerrado-para-cuentas-born-cloud`. Este ticket es lo que hay que hacer **suponiendo que
alguna vez no lo haga**.

## Relacionado

- `reverse-claim-rejection-has-no-way-out-in-the-client` — el gemelo en la fase anterior: un **rechazo**
  del claim deja la barra clavada en 15 % por el mismo motivo (ninguna salida para `.rejected`).
- `.claude/rules/swiftdata-cloudkit.md`, la regla del tope por tiempo y la del cuarteto de cierre con el
  orden invertido (residual documentado de la misma familia).

## Lo que se decidió (2026-09-16)

Jürgen contestó las tres preguntas de arriba, las tres con la recomendada, y una cuarta que salió al medir:

1. **Cuánto es «demasiado»** → tiempo **SIN AVANZAR**, no total: 15 min si CloudKit ya dijo que no entra
   (iCloud lleno, cuenta inutilizable) y 72 h si no se sabe. Un corpus grande que sube despacio avanza y no
   llega nunca al techo.
2. **Qué se ofrece al llegar** → **volver a la nube**: se cancela la vuelta, se descongela el backend, se pide
   cerrar y reabrir Yala una vez y se dice por qué.
3. **Y mientras espera** → cuántas filas faltan, o que iCloud está lleno o no disponible, y un botón
   **«Cancelar y seguir en la nube»** con confirmación, disponible durante toda la espera.
4. **La entrada sin iCloud** (hallazgo de la medición) → ticket aparte:
   `reverse-offered-on-a-device-without-icloud`.

El árbol de decisiones completo, con las técnicas y su motivo, está en el Paso 0 del encargo
(`encargos/lanzados/2026-09-16-reverse-upload-has-no-ceiling-and-no-exit.md`) y viaja al PR.

### Dos premisas de este ticket que no se sostenían

- **«Mis datos están en una sola copia: en el teléfono»** es verdad a medias. En `reverseUpload` el backend
  conserva, congelada, la copia que `reverseVerify` dio por igual a la local justo antes de congelar
  (`reverse_complete` y `reverse_abort` no borran nada, `qa/cloud/README.md`). Lo único que vive solo en el
  teléfono es lo que la persona escribe durante la espera.
- **«Suponiendo que alguna vez no lo haga»** se queda corto: hay un caso DETERMINISTA. Sin cuenta de iCloud
  el store se monta `.localNoMirror`, que adjunta el espejo; la reversa llega a `reverseUpload` y no drena
  nunca. `ReverseEligibility` no mira iCloud.
- **Y para una cuenta nacida en la nube pasaba lo contrario** (lo cazó la review): el muestreo solo veía filas
  con testigo `SyncIdentity`, lo creado en ese teléfono no tiene, y la vuelta se daba por hecha **al instante**,
  sin comprobar que algo hubiera llegado a iCloud. Decisión de Jürgen: se arregla aquí (D15 del Paso 0).

## Qué cambia para la persona

- **Mientras espera**, la pantalla de «Dónde viven tus datos» deja de ser una barra muda: dice «Subiendo tus
  datos a iCloud. Puedes seguir usando Yala.» y cuántos datos quedan por subir, o que iCloud no tiene espacio,
  o que el dispositivo no tiene iCloud disponible.
- **Puede cancelar cuando quiera**: «Cancelar y seguir en la nube» → confirmación → «Tus datos siguen en la
  nube» → cerrar y reabrir Yala → vuelve a su nube, que ya no está congelada, y lo que anotó mientras
  esperaba sube.
- **Si no cancela y la subida se clava**, a los 15 min (iCloud dijo que no) o a las 72 h (no se sabe) la app
  hace lo mismo sola, y después le explica por qué en la tarjeta de «Volver a iCloud». Con Yala cerrada no sube,
  así que tras 72 h sin abrirla la vuelta sale al abrir (D16, aceptado).
- **Una cuenta nacida en la nube ya no «vuelve» al instante**: espera a que sus datos lleguen de verdad.
- **Si intenta volver a iCloud con la salida anterior a medias** (sin red), la app no empieza y lo dice, en vez de
  dejar la vuelta nueva clavada al 30 % con la nube congelada. El aviso se queda hasta que lo cierra.
- **Si toca «Cancelar» mientras iCloud sigue importando**, el «sí» no se pierde: se hace en cuanto iCloud termina.

## Qué se tocó

- `MigrationStateMachine`: eventos `reverseUploadStalled(stalledSeconds:cause:returnTo:)` y
  `reverseUploadCancelled(returnTo:)`; efecto nuevo `.rearmMirrorOff`; presupuestos en `MigrationPolicy`.
- `ICloudCutoverGateLogic.swift`: `ReverseUploadBlocker` + `ReverseUploadBlockerLogic` (la causa, reusando la
  tabla de `CKError` de la ida) y `ReverseUploadAbortReason`.
- `MigrationState` (schema v4): `reverseUploadLowestPending`, `reverseUploadProgressAt`,
  `reverseAbortReasonRaw`.
- `MigrationRunner`: observación con el reloj del último avance, `cancelReverseUpload()`,
  `lastReverseUploadSample`, limpieza de los campos en la reserva, al drenar, en el reset y en la
  normalización.
- `MigrationWorkExecutor`: `.rearmMirrorOff` = `StorageModePersistence.writeCloudArmed`; la causa con sus
  señales y fechas; `collectReverseUploadPairs` (todas las filas vivas, con testigo scratch las que no tienen).
- `iCloudSyncService`: `lastExportErrorAt` (aditivo; ningún lector previo cambia).
- `MigrationRunner.submit`: `reverseActivated` drena la salida pendiente antes de empezar, y solo esa
  (`ReverseExitPending`); cualquier otro pendiente se reemplaza como antes.
- `CloudMigrationController`: el aviso de salida pendiente sale solo con esa salida; el re-kick en segundo plano no
  borra un aviso sin leer (`resume(clearingError:)`); un «Cancelar» que vence la pre-espera queda apuntado y lo
  ejecuta el siguiente `resume()`.
- `CloudMigrationController` + `StorageSettingsView` + `ReverseUploadWaitingCopyLogic`: el copy de la espera,
  el botón con su confirmación, la variante de la tarjeta de relanzar y la nota posterior. 16 claves en los
  16 idiomas.
- `MetricsService`: `cloudReverseUploadWaiting` (dedupe por proceso) y `cloudReverseUploadAborted`.

## Residuales, con ticket

- `reverse-upload-sample-reads-unreadable-rows-as-drained` — el muestreo cuenta «no pude leer» como «nada
  pendiente» y cierra la vuelta como hecha.
- `cloud-engine-can-start-with-a-reverse-abort-pending` — sin red al salir, el motor puede chocar con el 409
  del congelado y pararse hasta el siguiente arranque.
- `reverse-cancel-pushes-what-the-mirror-imported-during-the-wait` — el drenaje solo excluye su propio autor.
- `reverse-offered-on-a-device-without-icloud` — la decisión D4.
- `reverse-exit-on-a-reverted-account-rejects-the-retry` — D17 (b).
- `reverse-abort-rejected-leaves-a-frozen-cloud-saying-up-to-date` — D17 (c).
- `reverse-exit-leaves-a-partial-copy-in-icloud` — lo que ya subió se queda en iCloud sin dueño.
- `reverse-upload-ceiling-trusts-a-clock-set-back-during-the-wait` — con la fecha puesta atrás durante la espera, al
  corregirla la vuelta puede salir de golpe.
- `reverse-upload-sample-walks-every-row-twice-on-the-main-thread` — cada observación recorre dos veces todas las
  filas en el hilo principal.
- **Aceptado sin ticket (D16):** tras 72 h con Yala cerrada, la salida llega al abrir, antes de que el espejo
  pueda subir nada. Seguro, y el siguiente intento aprovecha lo subido.

## QA en iPhone

**Por qué en iPhone:** llegar a la espera exige una cuenta en la nube de verdad, y el simulador no crea cuentas
sin el secreto de attest (`.claude/rules/gateway-attest.md`). **El techo por tiempo no se recorre a mano**
—son 15 min con iCloud lleno o 72 h—: lo fijan los unit tests con reloj inyectado. Aquí se ve la cancelación,
que usa los mismos efectos, y el copy.

**Montaje:** un iPhone de pruebas con un build que incluya este cambio (`Yala Dev` desde Xcode, contra staging)
y **sin sesión de iCloud** (Ajustes → tu nombre → Cerrar sesión). Sin iCloud la espera no drena nunca, que es
justo el caso que hay que ver. Una cuenta nacida en la nube en ese iPhone, con algunos movimientos.

1. **Ajustes → «Dónde viven tus datos» → «Volver a iCloud»**, pasa las dos confirmaciones, y cuando lo pida
   cierra Yala del todo y vuelve a abrirla.
2. **La espera.** Vuelve a «Dónde viven tus datos». Tiene que decir «Si iCloud no está activo en este
   dispositivo, tus datos no pueden llegar a iCloud…», enseñar «Pendientes de subir: N» (N = tus movimientos,
   categorías, etc.) y «Cancelar y seguir en la nube». Captura.
   - **Si en vez de eso la vuelta TERMINA** (la app queda en modo privado), el muestreo no vio las filas. Hay dos
     causas y el guion no las separa: que siga sin contar las filas sin testigo (rojo de este ticket, D15) o que
     el espejo sin cuenta no cree sus tablas de metadata, con lo que todas las filas salen `failed` (el residual
     `reverse-upload-sample-reads-unreadable-rows-as-drained`). Anótalo en los dos, con captura del panel DEBUG.
3. **Anota un gasto** mientras espera (servirá en el paso 6).
4. **Cancelar.** Toca «Cancelar y seguir en la nube» → confirma «Sí, seguir en la nube». Tiene que aparecer
   «Tus datos siguen en la nube» pidiendo cerrar y reabrir, **sin** frase de «No pudimos…» (lo pediste tú).
   Captura.
5. **Relanza.** Cierra Yala del todo y ábrela. En «Dónde viven tus datos»: «Tu cuenta en la nube», la sección de
   sincronización y la tarjeta de «Volver a iCloud» **sin nota**.
6. **La nube ya no está congelada.** El gasto del paso 3 tiene que subir: en el panel DEBUG («Modo Nube ·
   Auth») el outbox baja a 0 sin error, o se ve en otro dispositivo con la misma cuenta. Un 409
   `yala_account_reverting` aquí significa que el `reverse_abort` no llegó.
7. **Con iCloud (opcional, el camino feliz no debe cambiar):** inicia sesión en iCloud, repite «Volver a
   iCloud» y deja que termine. Durante la espera se ve «Subiendo tus datos a iCloud» y la cifra de pendientes
   bajando; al terminar, modo privado.

### Criterios de aceptación de QA

- [ ] La espera dice algo verdadero (la cifra, o que iCloud no está disponible).
- [ ] «Cancelar y seguir en la nube» devuelve a la nube tras relanzar, sin nota.
- [ ] Lo anotado durante la espera sube a la nube después.
- [ ] Con iCloud sano, la vuelta sigue terminando en modo privado.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Exige cerrar la sesión de iCloud en tu único iPhone. El texto de la espera con iCloud se ve en `reverse-cutover-cerrado-para-cuentas-born-cloud`, que sigue en `qa`.
