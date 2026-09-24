---
id: migration-takeover-uploads-without-a-lineage-check
status: qa
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "Paso 0 · D6 de `adopt-uploads-a-foreign-corpus-without-a-lineage-check` (2026-09-24): el camino 2 de ese ticket no pasa por el adopt"
---

# El dispositivo que toma el relevo de una migración abandonada sube su corpus sin comprobar que sea el de esa cuenta

## El problema, en lenguaje de usuario

Empiezo a activar la nube en un teléfono y a mitad se queda sin conexión más de una hora. Mientras tanto, otro teléfono
entra en la misma cuenta y termina la activación él. Si ese otro teléfono tiene los MISMOS datos (el mismo iCloud), no
pasa nada. Si tiene otros —otro iCloud, otra persona—, sus datos se suben encima de lo que el primero alcanzó a subir, y
la cuenta queda con una mezcla de los dos.

## Lo medido (2026-09-24, leído en el código, sin ejecutar)

- `claim_account` (`qa/cloud/g15_01_account_kind.sql`, rama «Lease expiry (§g.1)»): con `migration_in_progress` y un
  líder que lleva más de 60 min sin latir, un claim con `p_migration=true` de OTRO dispositivo se queda el liderazgo y
  contesta `created`. El cliente no lo distingue de un `created` normal: `MigrationStateMachine.claimTransition` va a
  `assigningIdentity` → `uploadingSnapshot` y sube su corpus entero.
- Llegan ahí tres entradas, las tres con `migration=true`:
  1. «Migrar a la nube» que pasó la comprobación con la cuenta aún nueva y cuyo claim se quedó aparcado.
  2. El seguidor (`waitingForLeader`) que ve `leaderVanished` y vuelve a `claimingMigration`.
  3. El claim de un ADOPT (`ForwardClaimIntent.adoptIfExisting`), que también manda `migration=true`.
- La guarda de linaje del adopt (`adopt-uploads-a-foreign-corpus-without-a-lineage-check`) no cubre esto: vive en el
  reconcile del adopt, y el relevo es la subida del LÍDER. Y su prueba —el `CloudMigrationMarker`— no sirve aquí: el
  líder callado nunca llegó al cutover, así que nunca lo escribió.

## Por qué no se cerró junto al adopt

Hace falta otra prueba y otra salida, en el camino más caro de la migración. Candidata (sin medir): tras un `created`,
si el backend ya tiene filas personales VIVAS y ninguna está en el inventario local, el corpus no es el de quien empezó;
un relevo legítimo (mismo Apple ID) comparte las identidades que el líder callado asignó y exportó a CloudKit. Riesgos a
medir antes: el retraso de importación de esas identidades (falso bloqueo), y si conviene que el servidor diga que el
`created` es un relevo (un campo en la respuesta de `claim_account`) para no pagar la enumeración en cada alta.

## Criterios de aceptación

- [x] Un relevo cuyo corpus no comparte linaje con lo que el backend ya tiene no sube nada y sale con un texto honesto.
- [x] El relevo legítimo (mismo Apple ID, líder muerto a mitad) sigue terminando la migración (unit; en iPhone, el guion).
- [x] El alta normal (`created` sobre una cuenta vacía o solo de grupos) no paga una espera nueva.

## Decisión (2026-09-24, Frank en autónomo — el encargo la delega)

**Pista del servidor + prueba por identidad compartida, en la identidad y antes de tocar nada.** El Paso 0 entero (D1–D7)
está en `encargos/lanzados/2026-09-24-migration-takeover-uploads-without-a-lineage-check.md` y en el PR. Medido antes: el
Worker devuelve el JSON del RPC tal cual (campo nuevo sin deploy), y la subida del líder va por tablas en orden UTF-8 con
`accounts` primero, cuya identidad nace con la fila y viaja por CloudKit sin esperar al líder: el relevo legítimo comparte
identidades al instante, sin depender de que se importen las que el líder asignó.

## Qué cambia para quien usa la app

**Un teléfono que toma el relevo de una activación a medias ya no sube sus datos encima de los que otro dispositivo empezó a
subir, si no son los mismos.** No sube nada, no cambia nada, y a los 15 minutos sale con un texto que lo dice: *«No pudimos
activar la nube: esa cuenta ya tiene datos en la nube y los de este dispositivo no coinciden con ellos, así que no los
juntamos. Lo que tienes en este dispositivo sigue aquí. Comprueba que entras con la cuenta correcta. Si es la tuya y este
dispositivo usa el mismo iCloud, espera a que iCloud termine de traer tus datos y vuelve a intentarlo.»* (16 locales), en
Almacenamiento y en la bienvenida. «Reintentar» vuelve a comprobarlo: si sus datos llegaron, entra.

**El segundo teléfono del mismo iCloud sigue terminando la activación** que el primero dejó a medias: tiene sus cuentas y
movimientos por iCloud, y eso es la prueba. **Quien activa la nube en una cuenta nueva o solo de grupos no nota nada**: el
servidor le dice que la cuenta no tiene datos y no se comprueba.

## Cómo está hecho

- **Servidor** (`qa/cloud/g16_03_claim_reports_personal_writes.sql`, aplicada en staging y producción, md5 `c96106b7…`):
  todo `created` de `claim_account` lleva `has_personal_writes` (fila en `sync_seq_counters`). Los cinco `created`, no solo
  el del relevo: la respuesta perdida de un relevo se reintenta por la rama del mismo líder.
- `CloudAccountClient.claimReportingPersonalWrites` lee la pista (opcional: un servidor sin g16_03 no tumba el decode);
  `MigrationWorkExecutor.performClaim` la guarda y `MigrationRunner.driveClaim` la journalea en
  `MigrationState.forwardLineageUnverified` (schema 16) en el MISMO save de la transición a la identidad. `false` no
  comprueba; `true`, la ausencia y un `nil` de una fila anterior a la v16, sí.
- `MigrationWorkExecutor.checkForwardLineage`: inventario local primero (`localFailure` sin tocar la red), enumeración del
  backend, y `proven` en cuanto una fila viva del backend está en su tabla local. «No hay filas vivas» y «no comparte
  ninguna» exigen el Merkle completo (`transient` si no). `exchange_rates` no cuenta.
- `driveIdentity` lo pregunta ANTES de `assignIdentity()`. Probado → journalea `false`. `unproven` →
  `ForwardStepBlocker.lineageUnproven`, techo corto del paso (15 min), salida `failedRollback` con
  `ForwardStepExitReason.lineageUnproven`. Texto: `StorageFailureCopyLogic.forwardLineageMessage`; bienvenida:
  `CloudWelcomeSignInPhase.lineageExit`, con la flecha y «Reintentar». La pista se journalea en `handle` al entrar en la
  identidad, así que la toma también el seguidor que recibe el relevo.

## Red

- `MigrationWorkExecutorTests` §linaje de la ida (7): corpus ajeno `unproven` y el mismo iCloud `proven` sobre el MISMO
  backend, sin mutar nada; la identidad en otra tabla no prueba; backend vacío y solo tipos de cambio = sin datos, y un tipo
  de cambio compartido no prueba; un tombstone no es fila viva; red e incompleta = `transient`, pero una compartida prueba
  sin Merkle; inventario ilegible = `localFailure` sin red; la pista de `performClaim` (true/ausente/false/sin respuesta).
- `MigrationRunnerTests` §linaje (8): sin datos no pregunta y termina; con datos o sin pista pregunta una vez y termina; sin
  filas vivas termina; `unproven` no asigna ni sube, 899 s sigue y 900 s sale con su motivo y rollback; el relevo del
  SEGUIDOR también comprueba y no hereda un `false` anterior; la red espera el largo; el inventario ilegible es la base
  local; una fila pre-v16 comprueba y la prueba se journalea.
- `CloudAccountClientTests` (4), `ForwardStepCeilingLogicTests` (textos, WIRE, 16 locales, aviso del claim, fase de la
  bienvenida), `WelcomeAdoptExitTests` (cableado de la pantalla y del poll), `CloudSyncSchemaParityTests` (schema 16).

## Review adversarial (3 lentes, 2026-09-24)

Arreglado en este PR: el relevo del SEGUIDOR no journaleaba la pista y podía heredar un `false` anterior (dos lentes); la
salida retiraba el sello `.proceedMigration`, lo que no cortaba el bucle —el adopt lo reabre— y dejaba sin reintento al
relevo legítimo bloqueado en falso (dos lentes): se quitó y «Reintentar» es la recuperación; el texto culpaba a «otro
dispositivo» y no decía que esperar a iCloud y reintentar lo arregla en el caso legítimo; la bienvenida recupera «Reintentar».

A ticket propio: `displaced-migration-leader-keeps-uploading-after-a-takeover` (medium: el primer teléfono vuelve y sigue
subiendo encima; previo a este ticket) y `welcome-cancel-during-the-identity-step-does-not-return-to-the-chooser` (low).

Residuales aceptados, sin ticket: un build v15 que actualiza con la subida del relevo ya empezada no comprueba; la
enumeración se repite en cada pasada mientras dura `unproven`; la identidad reparada por dispositivo
(`repairCollapsedIdentityUUIDs`) puede retrasar la prueba del legítimo hasta que CloudKit la converge.
- SQL: 14 escenarios contra el motor de producción (control negativo, nuevo 14/14, mutante «pista siempre false» 3 rojos).
- **13 mutantes, 13 muertos**: sin comprobación · `nil` falla abierto · sin pista no comprueba · pista solo en `driveClaim`
  (el seguidor) · la prueba sin journalear · cruce sin tabla · sin la excepción de tipos de cambio · sin Merkle · pista en
  cualquier estado · `unproven` como red · la bienvenida genérica · el cierre conserva la pista · inventario ilegible como
  red. Un 14.º («la pista no se resetea al empezar el claim») sobrevivía porque esa línea sobraba: se quitó.

## QA en iPhone (device) — el relevo legítimo termina

La comprobación se prueba en unit con un backend fabricado; lo que solo un iPhone dice es que un teléfono del MISMO iCloud,
al tomar el relevo, tiene de verdad las cuentas que el primero subió. Hacen falta **dos dispositivos con el MISMO Apple ID**
(o uno y reinstalar Yala en él) y el build de este PR (Yala Dev). Tarda algo más de una hora por la espera del relevo.

**Montaje**

1. En los dos: Ajustes → [tu nombre] → iCloud → Yala activado. Comprueba que los dos ven las mismas cuentas.
2. Una cuenta de Apple o Google NUEVA para la nube (sin datos en Yala).

**Pasos**

1. En el **A**: Perfil → «Tu cuenta de Yala» → «Dónde viven tus datos» → «Activar la nube». Entra con la cuenta nueva.
2. En cuanto la barra pase de «Subiendo tus datos» (sobre el 55 %), pon el **A** en modo avión y ciérralo desde el
   selector de apps. No lo vuelvas a abrir hasta el paso 6.
3. Espera **61 minutos**.
4. En el **B**: si ya tenía Yala, bórrala y reinstálala; espera a ver tus cuentas (iCloud las trae). En la bienvenida, «Ya
   tengo una cuenta» y entra con la MISMA cuenta nueva del paso 1.
5. **Esperado:** el B termina de activar la nube (puede pedir reabrir la app) y NO sale «…otro dispositivo ya empezó a subir
   datos a esa cuenta…». Tras reabrir, ves tus datos.
6. Quita el modo avión del **A** y ábrelo: puede decir que otro dispositivo tomó el relevo. Es lo esperado.

Si en el paso 5 sale ese texto, anota cuánto tardó y manda una captura: sería el relevo legítimo bloqueado.
