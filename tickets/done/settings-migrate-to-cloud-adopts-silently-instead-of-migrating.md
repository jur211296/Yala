---
id: settings-migrate-to-cloud-adopts-silently-instead-of-migrating
status: done
priority: high
area: "modo-nube, settings"
created: 2026-09-10
updated: 2026-09-23
source: "medido durante `cloud-sign-in-discovers-account-kind` (bloque [I], paso 3 del rediseño de sesiones)"
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - pide finanzas creadas desde otro aparato y SQL; StorageMigrationIdentityBlockUITests
---

# «Migrar a la nube» sobre una cuenta que ya tiene datos no migra: adopta, y no lo dice

## El problema, en lenguaje de usuario

Tengo mis finanzas en este iPhone y quiero llevarlas a la nube. Voy a Ajustes → «¿Dónde viven tus
datos?» → «Migrar a la nube», acepto el consentimiento y **dos confirmaciones destructivas**, y entro
con mi cuenta de Google. Esa cuenta ya tenía datos de Yala en la nube (de otro móvil, o de un intento
anterior). Yala **no sube lo mío**: descarga lo que ya había y sigue como si nada. Mis meses de
histórico local se quedan donde estaban y nadie me avisa de que la migración que pedí no ocurrió.

## Lo medido (2026-09-10, árbol `8964c734`)

- La puerta **no consulta `GET /account/exists`** antes de nada: lo que decide es
  `StorageMigrationSignInLogic.decide` (`Yala/App/Logic/StorageMigrationSignInLogic.swift:64-77`), y sus
  inputs son **solo locales** — `hasSession`, el proveedor del Keychain y el hash del faro
  (`StorageSettingsView.swift:545-555`).
- El descubrimiento llega **después**, en el claim: `MigrationWorkExecutor.performClaim`
  (`:228-258`) recibe `existing_stable`, y `MigrationStateMachine` (`:618-621`) lo enruta a
  `.adoptBackendAccount` con el comentario «Already migrated & stable → returning-user. **NEVER
  re-migrate/re-seed**». Correcto para lo que esa máquina protege, y **no es lo que el usuario pidió**.
- `runAdoptFlow` (`MigrationWorkExecutor.swift:1145`) **no sube el corpus local**: hace quiescencia,
  orphan-reconcile, fast-forward del History y persiste el par `.cloud` + `mirrorOffArmed`.
- El copy solo cambia si el **mirror de CloudKit** ya trajo un `CloudMigrationMarker` de otro
  dispositivo del mismo Apple ID (`StorageSettingsView.swift:180`). Una cuenta poblada **por otra vía**
  —por ejemplo la cuenta de grupos que se promovió a completa— no dispara ese copy, porque
  `markerDecision()` mira una fila local del mirror, no el backend.
- El único bloqueo que existe hoy (`StorageMigrationSignInLogic.Decision.blockedOtherAccount`, `:43`)
  compara el hash del faro contra la sesión viva. **No mira el tipo de cuenta ni pregunta al backend.**

## Por qué no lo arregló el paso 3

El bloque [I] dejó las **tres celdas de esta puerta en la tabla** (`CloudIdentityRoutingLogic`, con
test), pero **sin cableado**, y por dos razones medidas: (1) el sign-in de esta puerta ocurre *dentro*
de `startMigration`, así que preguntar `exists` antes exige reordenar el flujo y tocar
`CloudMigrationController`, que el runbook del rediseño avisa que colisiona entre pasos; (2) la celda
«solo grupos → promover **mi asociada**» necesita saber cuál es la asociada, y esa identidad **no se
persiste hoy** (la puerta de Grupos solo escribe `groups.hadSessionEver`) — la trae el ticket 10.

## Lo que se espera

`Destination.blockedAccountIsComplete` y `.promoteAssociatedAccountThenCutover` ya existen y ya están
probados: lo que falta es que esta puerta **pregunte antes de cobrar dos confirmaciones destructivas**
y presente el bloqueo con sus dos salidas en vez de adoptar en silencio.

## Criterios de aceptación

- [x] La puerta consulta `CloudIdentityDiscovery` **antes** de las confirmaciones destructivas, no después. *Con la
      sesión de sus grupos, sí: al tocar, antes del consentimiento. Sin sesión, justo después de firmar, que va tras las
      confirmaciones (D2, Jürgen): firmar antes dejaba una sesión abierta mientras se leen los diálogos.*
- [x] Cuenta destino `complete` → bloqueo con sus dos salidas; **cero escrituras** y cero claim. *Las salidas son «Usar
      otra cuenta» y «Entendido» (D4, Jürgen).*
- [x] Cuenta destino `groups_only` que ES la asociada → promoción + cutover (necesita el ticket 10).
- [x] Cuenta destino `groups_only` que NO es la asociada → «una cuenta a la vez».
- [x] Cuenta nueva → el cutover de hoy, sin cambios. *Salvo con otra cuenta asociada para grupos, que también para
      (D13, Jürgen).*
- [x] Los tests de `StorageMigrationSignInLogic` y de la máquina de migración siguen verdes.

## Depende de

`groups-account-association-in-storage-row` (paso 10) para la celda de la promoción.

---

## Lo que la medición cambió de este ticket (2026-09-16)

**No era una adopción: era una fusión.** «Yala no sube lo mío» es falso. `existing_stable` → `.adoptBackendAccount` →
`runAdoptFlow` → `runAdoptOrphanReconcile`, que sube a la cuenta toda fila local que el backend no conoce: las 6
entidades de identidad sintética sin `syncID` reciben uno fresco y caen a huérfanas, y las 10 de identidad propia
(`Budget.id`, `Account.shortcutID`…) no están en el backend de otra cuenta. Mecanismo medido con
`adoptReconcile_nilIdentity_backfilledAndUploaded` y `collectAdoptInventory`; que en un iPhone que nunca migró sea el
corpus entero es inferido de ahí. Único freno: un backend enumerado vacío. La persona mezclaba sus datos con los de esa
cuenta, y la mezcla llegaba a todos los dispositivos de la cuenta.

**El claim ve lo que `/account/exists` no dice.** `claim_account` (`qa/cloud/g15_01_account_kind.sql`) promueve la fila
ligera de grupos (`created`) y contesta `existing_stable` a toda cuenta con lo personal reclamado: la completa **y la que
volvió a iCloud**, que el servidor da como `groups_only` y que sigue congelada (`reverse_complete` no toca
`reverse_frozen_at`; `/sync/push` la rechaza con 409). Por esa cuenta la comprobación sola no bastaba.

**La dependencia está hecha.** `groups-account-association-in-storage-row` (paso 10) persiste la asociada, así que la
celda de la promoción se pudo cablear.

## Lo que se decidió (2026-09-16)

El detalle, con el porqué de cada una, está en el Paso 0 del encargo
(`encargos/lanzados/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating.md`). Las de Jürgen:

- **Cuándo se comprueba** (D2): sin sesión en la nube, tras las dos confirmaciones y justo después de firmar; con la
  sesión de sus grupos, al tocar «Activar la nube», antes del consentimiento.
- **Solo grupos sin ninguna asociada → migra** a esa cuenta, como hacía el claim (D3). La celda bloqueaba el 2026-09-10
  porque entonces nadie podía saber cuál era la asociada.
- **Salidas del aviso** (D4): «Usar otra cuenta» (abre Apple/Google sin repetir consentimiento ni confirmaciones) y
  «Entendido». Con la sesión de sus grupos, solo «Entendido».
- **La cuenta que volvió a iCloud se para en el claim** (D10), con su aviso propio.
- **Una cuenta nueva con otra cuenta asociada para grupos también para** (D13), con «Ya usas otra cuenta para tus
  grupos». La hoja lo decía y «Usar otra cuenta» llevaba a romperlo.
- **El segundo dispositivo del mismo iCloud antes de que llegue la marca** queda bloqueado en esa ventana (D14, ticket
  aparte).
- **Otro Apple ID** (D15): se permitirá con el inicio de sesión web de Apple, en ticket aparte. Mientras tanto, si la
  cuenta rechazada era de Apple, la hoja lo dice junto a «Usar otra cuenta».
- **Con otro dispositivo migrando esa cuenta, parar y avisar** (D18): «Migrar» no le sigue ni le releva, porque con otro
  iCloud mezclaría dos corpus. Una migración abandonada por su líder ya no tiene salida desde aquí: va al ticket de D14.

Y lo técnico que cambió la review adversarial (D16, cuatro lentes): «Reintentar» tras un fallo seguía (la cuenta que
creó el intento se reconoce por su sello de claim); la intención de migrar se journalea (`MigrationState`, schema 6),
porque la ventana del relanzamiento dura todo lo que el claim pase aparcado; la sesión rechazada se cierra antes de
devolver el runner al inicio; un paso al claim que no hace nada también para con aviso; y el aviso se consume cuando la
hoja monta.

La segunda pasada (D19, dos lentes) añadió: la migración terminada cambia su sello y deja de abrir la comprobación;
«Usar otra cuenta» solo abre la elección si sigue sin haber sesión; y un rechazo se avisa una sola vez aunque un `resume`
lo vea después.

## Qué cambia para la persona

«Activar la nube» ya no mezcla tus datos con los de una cuenta que ya tenía los suyos. Si la cuenta que eliges ya guarda
finanzas personales, Yala no mueve nada y te lo dice: «Esa cuenta ya tiene finanzas personales». Puedes probar con otra
cuenta desde el mismo aviso, o usar los datos de esa cuenta cerrando sesión y entrando con ella. Si elegiste Apple, el
aviso te recuerda que con Apple se entra siempre con la cuenta del dispositivo. Si la cuenta volvió a iCloud, el aviso
dice que volver a la nube con ella todavía no está disponible. Si este iPhone ya usa otra cuenta para tus grupos, dice
que solo puede haber una y cómo cambiarla. Y si la cuenta es nueva, o es la de tus grupos, la migración sigue como
siempre. Si otro de tus dispositivos está pasando esa cuenta a la nube, también para con el mismo aviso: termina allí.

Con la sesión de tus grupos, el aviso sale al tocar «Activar la nube», antes de aceptar nada. Si Yala no puede preguntar
a la nube, dice «No pudimos comprobar tu cuenta. Inténtalo de nuevo en un momento. No cambiamos nada.»

## Qué se tocó

| Pieza | Qué hace |
|---|---|
| `StorageMigrationIdentityGateLogic` (nuevo) | La comprobación: fila de Ajustes de la tabla [I] → sigue / bloqueo con motivo / no se pudo preguntar, con la excepción de la cuenta que reclamó este dispositivo. Y el motivo de una parada en el claim |
| `CloudIdentityRoutingLogic` | «Solo grupos + ninguna asociada» pasa a promover; «cuenta nueva + otra asociada» pasa a bloquear |
| `CloudMigrationController` | `continueToClaim` (la puerta entre firmar y el claim), `preflightMigrationIdentity` (el adelanto con sesión viva), el cierre de la sesión que abrió el intento, y el aviso de un claim devuelto al inicio también desde `resume` |
| `MigrationRunner` + `MigrationStateMachine` + `MigrationState` | `ForwardClaimIntent.migrateOnly`, journaleada con la transición al claim (schema 6): con «Migrar», `existing_stable` y `claiming_in_progress` emiten `.claimRefusedExistingAccount` (`claimingMigration → notStarted`, sin efectos) en vez de adoptar o seguir al líder |
| `MigrationWorkExecutor` + `CloudClaimActionStore` | `discardLastClaimStamp`: el sello del claim devuelto no se queda, y el anterior se repone. Y el `complete` del líder cambia `.proceedMigration` por `.routeReturningUser` |
| `StorageSettingsView` + `StorageMigrationBlockedView` (nuevo) | El adelanto al tocar, la hoja del aviso con la nota de Apple, y «Usar otra cuenta» → Apple/Google por `onDismiss` |
| `L10n` + 16 `.strings` | Once claves: tres avisos con sus variantes, la nota de Apple, el botón y «No pudimos comprobar tu cuenta» |
| `MetricsService` + `CloudSyncBreadcrumb` | Canario `cloudMigrationExistingAccountBlocked` con `<motivo>@<gate\|claim>` y dos rastros |
| `UITestHooks` + lanzador | Seams `-uitest-fake-migration-identity` (la respuesta de la puerta) y `-uitest-pending-migration-block` (un aviso ya publicado) |
| `CloudSyncDebugView` | El panel DEBUG fija la intención de siempre antes de conducir la máquina |

**Tests:** `StorageMigrationIdentityGateLogicTests` (la tabla de Ajustes de punta a punta, textos y títulos por motivo),
`MigrationIdentityGateWiringTests` (cuerpos enteros de la puerta, el runner y la hoja), `MigrationRunnerTests` §10c,
`MigrationStateMachineTests` R11c, `MigrationWorkExecutorTests` (el sello), `MigrationStateJournalTests` (la intención
sobrevive al save), `CloudIdentityRoutingLogicTests` y `StorageMigrationIdentityBlockUITests` (cuatro casos: la hoja al
tocar, el camino que sigue, «Usar otra cuenta» → Apple/Google y «Entendido»).

## Residuales, con ticket

- `adopt-uploads-a-foreign-corpus-without-a-lineage-check`: el seguidor (`claiming_in_progress`) de un líder con otro
  corpus sigue adoptando.
- `settings-migrate-blocks-a-second-device-before-its-marker` (D14).
- `cloud-sign-in-cannot-choose-another-apple-id` (D15).
- `fresh-start-keeps-a-groups-session-that-migrate-promotes`: tras «Empiezo de cero», la sesión de grupos de la persona
  anterior sobrevive y «Migrar» la promueve (ya pasaba en `2.1`).
- `migration-activation-drops-pending-effects-it-never-restores`: tocar tira los pendientes de la fase de origen, y
  las salidas no los devuelven (ya pasaba en `2.1`).
- `migrate-attempt-session-survives-a-relaunch-mid-attempt`: un relanzamiento a mitad del intento deja viva la sesión
  que abrió, y el aviso de después sale genérico.
- `blocked-sign-in-still-binds-the-subscription-to-that-account`: firmar vincula la suscripción aunque la cuenta se
  rechace (latente: la resolución de Pro por cuenta está apagada).
- `storage-groups-section-stays-active-during-the-migrate-check`: «Desasociar» sigue activo durante la comprobación al
  toque.
- `migrate-card-keeps-promising-an-account-the-check-refused`: tras «Entendido» la tarjeta sigue diciendo «Usarás tu
  cuenta de Yala actual…» (copy, lo decide Jürgen).
- `migrate-before-the-groups-association-arrives-splits-the-accounts`: en un iPhone restaurado, migrar antes de que llegue
  la asociación de grupos puede dejar lo personal y los grupos en cuentas distintas.
- Añadido a `groups-only-session-storage-screen-says-data-lives-in-icloud`: en una sesión solo-grupos, el aviso pide
  desasociar en una sección que allí no existe.
- `settings-migrate-blocks-a-second-device-before-its-marker` recoge también la migración abandonada por su líder y la
  reinstalación a medias (D18).

Aceptado sin ticket: si la cuenta vuelve a iCloud entre la comprobación y el claim, el aviso dice «ya tiene finanzas
personales» en vez de «volvió a iCloud» (`blockForClaimRefusal`). No cambia nada en la cuenta ni en el teléfono.

## QA en iPhone

**Por qué en iPhone:** hace falta firmar con Apple o Google de verdad y que el servidor conteste sobre una cuenta real; el
simulador no firma. La hoja y sus botones ya los prueba el XCUITest con respuestas fingidas
(`StorageMigrationIdentityBlockUITests`); aquí se mira que la respuesta DE VERDAD llega y que no se escribe nada.

**Montaje común:**

1. Un iPhone de pruebas con un build de este cambio (`Yala Dev` desde Xcode, contra **staging**), en «Tu cuenta en tu
   iCloud privado», con algunos movimientos y **sin** cuenta de grupos asociada (Ajustes → «¿Dónde viven tus datos?» →
   la sección «Grupos» ofrece asociar una cuenta).
2. Dos cuentas de Google de prueba en staging: **A**, que ya tiene finanzas personales en la nube (creada con «Es mi
   primera vez» → «Tu cuenta en la nube» en otro dispositivo), y **B**, sin cuenta Yala.
3. En el SQL Editor de Supabase (staging), el id de A: `select id from auth.users where email = '<correo de A>';`.
   Apunta lo que hay:
   `select kind, personal_claimed_at, reverted_at, reverse_frozen_at, migration_in_progress, leader_device_id from public.profiles where id = '<id A>';`
   y `select count(*) from public.tx_items where user_id = '<id A>';`.

**Caso 1 · cuenta con finanzas personales, sin sesión.**

1. «Activar la nube» → consentimiento → las dos confirmaciones → Google con **A**.
2. Sale la hoja «Esa cuenta ya tiene finanzas personales», con «Usar otra cuenta» y «Entendido», y **sin** la nota de
   Apple. Captura.
3. **No se escribió nada:** repite las dos consultas del montaje. `leader_device_id`, `migration_in_progress` y el
   recuento de `tx_items` son los de antes.
4. «Entendido». La tarjeta vuelve a «Activar la nube» y **ya no dice «Usarás tu cuenta de Yala actual…»**: la sesión de A
   se cerró.
5. Abre la pestaña Grupos: sigue ofreciendo crear o asociar una cuenta (A no quedó asociada).

**Caso 2 · «Usar otra cuenta».**

6. Repite el 1 hasta la hoja y toca «Usar otra cuenta». Se abre directamente la elección Apple/Google, **sin**
   consentimiento ni confirmaciones. Captura.
7. Elige Google con **B**. La migración empieza como siempre (barra de progreso). Déjala terminar solo si ese iPhone
   puede quedarse en la nube; si no, usa un dispositivo desechable para este paso.

**Caso 3 · con Apple.** Solo si el Apple ID del iPhone ya tiene una cuenta Yala con finanzas personales.

8. «Activar la nube» → consentimiento → confirmaciones → Apple. La hoja sale con la nota «Con Apple, Yala usa siempre la
   cuenta de este dispositivo. Para usar otra, elige Google.» Captura.

**Caso 4 · cuenta que volvió a iCloud.** En staging, con A, monta en una sola ejecución:

```sql
begin;
select set_config('yala.kind_write', txid_current()::text, true);
update public.profiles set kind = 'groups_only', reverted_at = now(), reverse_frozen_at = coalesce(reverse_frozen_at, now()) where id = '<id A>';
commit;
```

9. «Activar la nube» → consentimiento → confirmaciones → Google con A. Sale «Esta cuenta volvió a iCloud». Captura.
10. Repite las consultas: nada cambió salvo lo que montaste. Deshaz con los valores que apuntaste:
    `begin; select set_config('yala.kind_write', txid_current()::text, true); update public.profiles set kind = '<antes>', reverted_at = <antes>, reverse_frozen_at = <antes> where id = '<id A>'; commit;`

**Caso 5 · con la sesión de tus grupos (la comprobación va al toque).** Asocia **C**, una cuenta solo de grupos, desde
la sección «Grupos». Monta que C tenga finanzas personales:
`begin; select set_config('yala.kind_write', txid_current()::text, true); update public.profiles set kind = 'complete' where id = '<id C>'; commit;`

11. «Activar la nube» (la tarjeta dice «Usarás tu cuenta de Yala actual…»). La hoja sale **al tocar, antes del
    consentimiento**, y solo con «Entendido». Captura.
12. Deshaz el `kind` de C. Toca otra vez: ahora va al consentimiento. **Cancela ahí**: seguir promovería C y migraría
    este iPhone a la nube, que es el camino normal y no hace falta recorrerlo.

**Caso 6 · otra cuenta asociada y una cuenta nueva.** Hace falta la asociación de C **sin** sesión en la nube, y eso
solo pasa en otro dispositivo: la asociación viaja por iCloud y la sesión no. Usa un segundo iPhone con el mismo Apple
ID, en «Tu cuenta en tu iCloud privado» y sin sesión, con C asociada en el primero (caso 5). Si su sección «Grupos» no
muestra C, este caso no se puede montar: anótalo y sigue.

13. En el segundo iPhone: «Activar la nube» → consentimiento → confirmaciones → Google con **B** (sin cuenta Yala). Sale
    «Ya usas otra cuenta para tus grupos», con el correo de C. Captura. En staging, B sigue sin fila en
    `public.profiles`.

**Caso 7 · sin conexión.** Con la sesión de grupos (caso 5 deshecho) y modo avión: el toque sigue al consentimiento, y
tras las confirmaciones sale «No pudimos comprobar tu cuenta. Inténtalo de nuevo en un momento. No cambiamos nada.».
Nada cambia en staging.

### Criterios de aceptación de QA

- [ ] Con una cuenta que ya tiene finanzas personales, o que volvió a iCloud, no se escribe nada en la cuenta y el aviso
      lo dice.
- [ ] Tras el aviso, la sesión que abrió el intento queda cerrada y esa cuenta no aparece asociada para grupos.
- [ ] «Usar otra cuenta» abre la elección sin repetir consentimiento ni confirmaciones, y con una cuenta nueva migra.
- [ ] Con la sesión de sus grupos, el aviso sale al tocar y solo con «Entendido».
- [ ] Con otra cuenta asociada, una cuenta nueva también para.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Pide una cuenta con finanzas creadas desde otro aparato y SQL en staging. La hoja y sus botones los prueba `StorageMigrationIdentityBlockUITests`.
