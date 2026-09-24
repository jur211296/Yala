---
id: adopt-uploads-a-foreign-corpus-without-a-lineage-check
status: qa
priority: medium
area: "modo-nube, migración"
created: 2026-09-16
updated: 2026-09-24
source: "residual declarado de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (Paso 0 · D9), 2026-09-16"
---

# El adopt sube a la cuenta todo lo que el backend no conoce, sin mirar si esos datos son de esa cuenta

## El problema, en lenguaje de usuario

Tengo mis finanzas en este iPhone, en mi iCloud. Por un camino raro —ver abajo— la app termina «activando la nube» en
este teléfono con una cuenta que ya tenía datos de otra persona o de otro iCloud. Mis movimientos se suben a esa cuenta y
se mezclan con los suyos, y la mezcla llega a todos sus dispositivos. Nadie me pregunta.

## Lo medido (2026-09-16, rama `encargo/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating`)

- `MigrationWorkExecutor.runAdoptOrphanReconcile` sube como huérfana **toda fila local cuya identidad no está en el
  backend**: las 6 entidades de identidad sintética sin `syncID` reciben uno fresco antes del diff, y las 10 de identidad
  propia (`Budget.id`, `Account.shortcutID`…) no están en el backend de otra cuenta. Lo fija
  `adoptReconcile_nilIdentity_backfilledAndUploaded` (`MigrationWorkExecutorTests`). Su único freno es un backend
  enumerado vacío (`abortedEmptyBackend`).
- Está diseñado para el segundo dispositivo del mismo Apple ID, donde el corpus local ES el del líder y solo las filas
  de la ventana del cutover son huérfanas. **No comprueba que lo sea.**
- `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` cerró los caminos normales: «Migrar a la nube» ya no
  llega al adopt con una cuenta que tiene lo personal (comprobación previa + `ForwardClaimIntent.migrateOnly` en el claim).

## Los caminos que quedan

1. **Un seguidor de un líder con otro corpus, cuando entra por un adopt.** `claiming_in_progress` → `waitingForLeader` →
   `leaderCompleted` → adopt, sin mirar la intención (`follower_ignoresTheIntent`, `MigrationRunnerTests`). Con dos
   dispositivos del mismo Apple ID es el caso diseñado. Con dos corpus distintos mezcla. Desde el 2026-09-16 «Migrar a la
   nube» ya no se hace seguidor (D18 de Jürgen: `claiming_in_progress` vuelve al inicio con aviso); quedan las entradas de
   adopt (Welcome, la tarjeta del marcador).
2. **El relevo de un líder callado.** Si «Migrar» pasa la comprobación con la cuenta aún nueva, otro dispositivo la reclama,
   y el claim de éste se queda aparcado más de 60 min, `claim_account` le da el turno (`created`) y sube su corpus encima
   de lo que el otro alcanzó a subir. El SQL está medido; que ocurra, con un claim aparcado tanto tiempo, es inferido.

**El otro camino se cerró en el mismo PR que abrió este ticket.** Un relanzamiento con el claim a medias adoptaba porque
la intención de migrar vivía en memoria, y la review midió que la ventana no era una petición: dura todo lo que el claim
pase aparcado por la red. La intención se journalea ahora con la transición al claim (`MigrationState.forwardClaimIntentRaw`,
schema 6) y la fija `afterRelaunch_theJournaledIntentStillRefuses`.

3. **La sesión de la persona anterior, tras «Empezar desde cero»** (review de
   `fresh-start-keeps-a-groups-session-that-migrate-promotes`, 2026-09-17, inferido). `wipeAllUserData` no borra
   `CloudMigrationMarker`, así que un teléfono que lo conservaba sigue enseñando «Activar en este dispositivo». Con la
   sesión que dejó abierta la persona anterior, el faro de su Apple ID casa con esa sesión, `decide` da
   `.reuseLiveSession` y `continueToClaim` va directo al claim con `.adoptIfExisting`: el corpus de la persona nueva sube a
   la cuenta de la anterior. La comprobación de identidad no corre en el adopt, y **la guarda de linaje de abajo no lo
   pararía**: el marcador sí está en local. No está medido si la fila del marcador sobrevive al borrado de la zona en el
   relevo. La sesión superviviente, entera, en `previous-person-cloud-session-survives-fresh-start-and-reinstall`.

## La tarjeta de adopt la ve más gente desde el 2026-09-23

`adopt-claim-stays-parked-with-no-ceiling` hizo que la tarjeta de adopt («Activar la nube en este dispositivo») salga
también SIN marcador de CloudKit cuando el claim de un adopt anterior de este teléfono salió por su techo o por «Cancelar»
(`MigrationState.adoptClaimExitRaw`, `CloudMigrationController.offersAdoptReentry`). Es la salida de ese adopt, y la
tarjeta sigue sin pasar por la comprobación de identidad: con la sesión borrada la persona elige cuenta en el chooser, y
si el claim contesta `created` o promueve una cuenta solo-grupos, la migración sigue sin la puerta de «Migrar». La marca
solo la deja un adopt que este teléfono empezó (el Welcome, con su guard cross-cuenta; o la tarjeta con marcador), así
que la población es la de quien ya intentaba entrar en su cuenta. Medido por lectura, no ejecutado.

## Opciones, sin decidir

- **Guarda de linaje dentro del escritor** (`runAdoptFlow`): adoptar solo si el `CloudMigrationMarker` del líder está en
  el store local, que es la prueba de que este dispositivo espeja el corpus de esa cuenta. Lo cierra, pero un
  segundo dispositivo cuyo espejo aún no importó el marcador dejaría de adoptar hasta que llegue, y hace falta una salida
  para el efecto pendiente que no sea «reintentar para siempre». **El faro (`CloudBeacon`) no vale como prueba**: lo
  escribe también el alta born-cloud, que no tiene corpus en CloudKit.

## Criterios de aceptación

- [x] Ni el seguidor de un adopt ni un relevo suben a una cuenta un corpus que no desciende de esa cuenta, o el caso se
      decide y se documenta como aceptado. **El adopt, cerrado** (seguidor y toda entrada del adopt). **El relevo, a su
      ticket** (`migration-takeover-uploads-without-a-lineage-check`): no pasa por el adopt y el marcador no le sirve.
- [x] El segundo dispositivo del mismo Apple ID sigue adoptando, con sus huérfanas de la ventana (unit; en iPhone, el
      guion de abajo).

## Decisión (2026-09-24, Frank en autónomo — el encargo la delega)

**Guarda de linaje dentro del escritor**, la opción de arriba, con dos precisiones medidas: solo se exige cuando hay algo
que subir, y va antes del guard de backend vacío. El Paso 0 entero (D1–D8) está en el encargo
`encargos/lanzados/2026-09-24-adopt-uploads-a-foreign-corpus-without-a-lineage-check.md` y en el PR.

## Qué cambia para quien usa la app

**Un teléfono cuyos datos no vienen de la cuenta en la nube ya no los sube a ella al activar la nube.** Si llega al
adopt con movimientos, cuentas o categorías que la cuenta no conoce y no tiene el rastro que deja la cuenta en su iCloud,
no sube nada, no cambia nada, y tras 15 minutos sin poder comprobarlo sale con un texto que lo dice: *«No pudimos entrar en
tu cuenta de la nube: este dispositivo tiene datos que esa cuenta no tiene y no pudimos comprobar que vengan de ella, así
que no los juntamos. Lo que tienes en este dispositivo sigue aquí. Si llevaste a la nube los datos de este iCloud desde
otro dispositivo, comprueba que entras con esa misma cuenta y espera a que iCloud termine de traerlos antes de volver a
intentarlo.»* Al reintentar puede elegir otra cuenta: esa salida no deja la tarjeta atada a la que falló.

**El segundo teléfono del mismo iCloud sigue entrando igual**, con lo que escribió durante la activación: su iCloud ya
trajo ese rastro. Y **el que no tiene nada que subir** —el segundo teléfono de una cuenta que nació en la nube, un
teléfono recién instalado— entra como siempre, sin rastro que pedir. Los tipos de cambio que la app descarga sola al
arrancar no cuentan como datos de nadie.

## Cómo está hecho

- `MigrationWorkExecutor.runAdoptOrphanReconcile`: tras el plan preliminar, si hay huérfanas o filas sin identidad, exige
  un `CloudMigrationMarker` con `accountHash == CloudBeacon.hash(sub de la sesión)` (`adoptLineageProven`, por
  `fetchInventory`, paso `adopt-lineage`). Sin él → `.lineageUnproven`, ANTES del backfill, del encolado, del push y del
  guard de backend vacío, y otra vez sobre el plan DEFINITIVO (el que sube). `ExchangeRate` no dispara la exigencia
  (`adoptLineageExemptTables`): es caché que el arranque siembra antes del Welcome. Rastro `adoptReconcileLineageUnproven`.
- `runAdoptFlow` lo traduce a `MigrationExecutorError.adoptLineageUnproven`, sin llegar al paso 5 (el modo sigue en iCloud).
- `MigrationRunner`: `AdoptEffectBlocker` gana `lineageUnproven` y un `init?(_ error:)` que clasifica; comparte el reloj
  CORTO (15 min) con la base local, y la salida la nombra la causa de la observación que lo vence →
  `AdoptClaimExit.effectLineageUnproven` → texto `storage.failed.adoptEffectLineageUnproven` (16 locales), el mismo en
  Almacenamiento y en la bienvenida. «Reintentar» lleva a la tarjeta de adopt como las otras salidas del efecto, pero
  esta salida journalea la marca SIN cuenta (`adoptClaimAccountHash = nil`): la cuenta del intento es la sospechosa, y
  atarla bloqueaba entrar con la buena (`AdoptClaimScope.blocksReentry`).
- Los caminos del ticket: **1** (el seguidor) cerrado; **2** (el relevo) a `migration-takeover-uploads-without-a-lineage-check`;
  **3** (la sesión de la persona anterior) lo cierra `previous-person-cloud-session-survives-fresh-start-and-reinstall`
  (en `qa`), que purga esa sesión — esta guarda no lo pararía, el marcador sí está.

## Red

- `MigrationWorkExecutorTests`: 7 nuevos — corpus ajeno y 2.º dispositivo sobre el MISMO inventario (sin marcador nada; con
  él las dos huérfanas), marcador de otra cuenta / sin hash / sin sesión, solo filas sin identidad, nada que subir sin
  marcador, orden frente al backend vacío, marcador ilegible = `.localFailure`, y `runAdoptFlow` que no cambia el modo. Los
  11 tests del reconcile que suben algo ganan el marcador del líder (`seedLeaderMarker`), y el E2E de staging también.
- `MigrationRunnerTests` §16-bis: sale a los 900 s con su marca (899 no); las dos causas comparten el reloj y la última
  nombra la salida, en los dos órdenes.
- `AdoptEffectCeilingLogicTests` / `WelcomeAdoptExitTests`: clasificación, WIRE, texto propio y traducido en los 16 locales
  sin afirmar el estado de la nube; las seis salidas explicadas en la bienvenida.
- `MigrationWorkExecutorTests` también: solo tipos de cambio → adopta sin marcador (y con una fila de usuario al lado, no);
  una fila que llega entre el plan preliminar y el definitivo → bloquea. `MigrationRunnerTests`: la salida por linaje suelta
  la cuenta de la marca y la de la base local la conserva.
- **12 mutantes, 12 muertos**: sin guarda · cualquier marcador · solo huérfanas · siempre exigirla · sin sesión = probado ·
  `runAdoptFlow` que sigue · linaje al techo largo · linaje con el texto de la base local · marcador ilegible = red · sin
  excepción de tipos de cambio · sin la guarda del plan definitivo · marca atada a la cuenta.

## Review adversarial (3 lentes, 2026-09-24)

Arreglado en este PR: los tipos de cambio sembrados al arrancar dejaban fuera al 2.º dispositivo de una cuenta nacida en la
nube (lente del dispositivo legítimo); la guarda decidía con el plan preliminar y subía el definitivo (lente de bypass); la
marca atada a la cuenta equivocada bloqueaba entrar con la buena, y el texto aconsejaba esperar cuando la causa era la
cuenta (lente de runner y copy).

A ticket propio:
- `adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch` (medium): con el store vacío no hay nada
  que comprobar, y lo que el espejo importa antes de relanzar lo sube el primer drain (el baseline no ancla sin transacciones).
- `cutover-marker-without-a-session-locks-out-the-second-device` (low): un marcador escrito sin sesión lleva el hash vacío.
- `migration-takeover-uploads-without-a-lineage-check` (medium): el relevo, camino 2.

Residuales aceptados, sin ticket:
- **El reloj corto cuenta tiempo de pared.** Una observación sin marcador, 20 min en segundo plano, y al volver la
  quiescencia puede pasar antes de que el import arranque: sale en el acto. Es recuperable (la tarjeta vuelve y el
  reintento pasa en cuanto llega el marcador) y es el mismo reloj que ya usa la base local; los caminos legítimos
  normales (la tarjeta con marcador, el seguidor tras el cutover) llegan con el marcador ya en local.
- **Durante esos 15 min la tarjeta dice «Activando la nube…» al 60 %**, sin aviso: el mismo precedente que la base local
  ilegible (D4 de `adopt-effect-retries-forever-with-no-ceiling`).

## QA en iPhone (device) — el segundo dispositivo sigue entrando

La guarda se prueba en unit con un marcador fabricado; lo que solo un iPhone dice es que el marcador REAL que importa
CloudKit trae el hash de la cuenta. Hacen falta **dos dispositivos con el MISMO Apple ID** y el build de este PR (Yala Dev).

**Montaje**

1. En los dos: Ajustes → [tu nombre] → iCloud → Yala activado. Abre Yala en los dos y comprueba que ves los mismos datos.
2. Ten a mano la cuenta de Apple o Google con la que vas a activar la nube.

**Pasos**

1. En el **A**: Perfil → «Tu cuenta de Yala» → «Dónde viven tus datos» → en «Migrar a la nube», «Activar la nube». Entra con tu
   cuenta y espera a que termine.
2. En el **B**, antes de tocar nada de la nube: crea un gasto nuevo, por ejemplo «QA linaje», de 1.
3. En el **B**: Perfil → «Tu cuenta de Yala» → «Dónde viven tus datos». Debe salir «Activar la nube en este dispositivo»; toca «Activar
   en este dispositivo» y entra con la MISMA cuenta.
4. **Esperado:** el B termina de activar (puede pedir reabrir la app) y NO sale el texto «…no pudimos comprobar que vengan
   de ella…».
5. En el **A**, abre Registros: el gasto «QA linaje» del B tiene que aparecer (puede tardar un minuto).

Si en el paso 4 sale ese texto, anota cuánto tardó en salir y manda una captura: sería el caso legítimo bloqueado.

**Caso B (opcional) — el 2.º dispositivo de una cuenta nacida en la nube.** Es el que la review cazó: ese teléfono nunca
tiene el rastro, y la app lo deja entrar porque no trae datos suyos.

1. Con una cuenta que creaste desde la bienvenida con «Es mi primera vez en Yala» → «Tu cuenta en la nube», instala Yala de cero en otro
   dispositivo (o bórrala y reinstálala).
2. En la bienvenida, «Ya tengo una cuenta» y entra con esa misma cuenta.
3. **Esperado:** entra y ves tus datos de la nube. NO sale «…no pudimos comprobar que vengan de ella…», ni a los
   15 minutos.
