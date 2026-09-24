---
id: adopt-after-the-cutover-needs-a-marker-the-leader-never-exported
status: done
priority: medium
area: "modo-nube, migración, adopt"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `claim-grants-a-takeover-after-the-leader-passed-the-cutover` (2026-09-24), lente de consumidores"
---

# El adopt tras el cutover pide un marcador que el líder puede no haber exportado

## El problema, en lenguaje de usuario

El teléfono A llega al paso en que el servidor ya da la activación por buena, pero se queda sin conexión antes de dejar su
marca en iCloud. Más de una hora después, el teléfono B quiere entrar en la cuenta y tiene algo escrito que la nube no
conoce. B no puede entrar: la app le dice que no puede comprobar que esos datos son de esta cuenta. Si A vuelve, se
arregla solo; si A no vuelve (o su activación se deshizo porque la marca nunca llegó a iCloud), B no entra nunca con sus
datos.

## Lo medido (2026-09-24, leyendo el código)

- `migrated_at` lo estampa `confirmCutoverServer` en `cutover(.pending) → .serverConfirmed`, ANTES de escribir y exportar
  el marcador (`MigrationStateMachine.swift`, el bloque «cutover — STRICT order»).
- Desde g16_04, con `migrated_at` puesto y el lease vencido, `claim_account` da `existing_stable` → adopt. Antes daba el
  relevo, y la identidad de la ida probaba el linaje por identidades compartidas (`checkForwardLineage`), sin marcador.
- El adopt exige el marcador de la cuenta en el store local en cuanto hay una fila huérfana o sin identidad fuera de las
  tablas exentas (`MigrationWorkExecutor.adoptLineageGate` / `adoptLineageProven`); sin él, `.lineageUnproven`.
- Dos casos: (1) A dormido en `cutover(.markerWritten)` con el marcador sin exportar — B bloqueado hasta que A exporte; (2)
  A agota el tope del marcador (`markerExportStalled`) y vuelve a iCloud BORRANDO el marcador, con `migrated_at` puesto y
  la migración abierta en el servidor (residual ya escrito en ese `case`) — B bloqueado mientras A no reintente.
- En `cutover(.mirrorOff)` (el «cierra y reabre Yala») el marcador ya está exportado: ahí el adopt de B sí prueba linaje.

## Candidatas (decisión técnica, sin medir)

- Cliente: en el adopt, sin marcador, aceptar como prueba de linaje lo mismo que la ida (`checkForwardLineage`: alguna
  identidad compartida con el backend). Hay que medir que no reabre `adopt-uploads-a-foreign-corpus-without-a-lineage-check`.
- Servidor: una señal de «marcador exportado» (una acción de `migration_progress`) y que la rama de g16_04 la exija; sin
  ella, el relevo de antes. Cambia el protocolo del líder.

## Criterios de aceptación

- [x] Un segundo teléfono con datos propios entra en una cuenta cuyo líder pasó el cutover del servidor sin exportar el
      marcador, o hay una salida escrita para ese caso. **Por el adopt** (la bienvenida de una instalación nueva o
      reinstalada, el seguidor, la reentrada tras un adopt que salió), cerrado. **Desde Ajustes** el teléfono que ya tenía
      Yala no llega al adopt sin marcador: ve «Migrar a la nube» y la puerta de «Migrar» lo para con «Esa cuenta ya tiene
      finanzas personales». Esa puerta es de `settings-migrate-blocks-a-second-device-before-its-marker` (decisión D18 de
      Jürgen: parar y avisar) y queda como está; su salida escrita sigue siendo la del aviso.

Relacionado, no duplicado: `cutover-marker-without-a-session-locks-out-the-second-device` (el marcador existe pero con el
hash vacío). Las dos candidatas de aquí cerrarían también ese.

## Decisión (2026-09-24, Frank en autónomo — el encargo la delega)

**La candidata de cliente.** El adopt da el linaje por probado con el marcador de la cuenta **o** con una fila viva de la
cuenta que ya esté en el teléfono. La de servidor devolvía el relevo que Jürgen retiró en #239 («B adopta, no espera ni
releva») y cambiaba el protocolo del líder; la de cliente usa la misma prueba que ya guarda el relevo, que sube el corpus
entero. El Paso 0 (D1–D5) está en `encargos/lanzados/2026-09-24-adopt-after-the-cutover-needs-a-marker-the-leader-never-exported.md`.

## Qué cambia para quien usa la app

**El segundo teléfono del mismo iCloud ya no se queda fuera cuando el primero se paró justo después de que el servidor diera
la activación por buena.** Antes, si el primero no llegó a dejar su marca en iCloud, el segundo con algo propio que subir
acababa en «no pudimos comprobar que vengan de ella» y no entraba hasta que el primero volviera. Ahora entra: sus cuentas y
movimientos, que iCloud le trajo del primero y que la nube ya tiene, bastan como prueba, **siempre que iCloud le haya traído
ya todo lo que el primero subió** en las listas donde va a añadir algo. Si falta algo, no sube nada —subirlo sería
duplicar los movimientos del primero— y sale con el texto de siempre, que ya dice «espera a que iCloud termine de traerlos».
Entra por la bienvenida (una instalación nueva o reinstalada); desde Ajustes, un teléfono que ya tenía Yala sigue viendo
«Migrar a la nube» y su aviso (ticket aparte, `settings-migrate-blocks-a-second-device-before-its-marker`). **Un teléfono con los datos de otra
persona o de otro iCloud sigue sin subir nada**: no comparte ninguna fila con la cuenta, y sale con el mismo texto de antes.

## Cómo está hecho

- `MigrationWorkExecutor.adoptLineageGate` recibe el inventario del que sale cada plan y la enumeración del backend (ya
  verificada contra el Merkle). Con filas que piden prueba: primero el marcador (`adoptLineageProven`; su tabla ilegible
  sigue siendo `.localFailure`), y sin él `adoptSharedRowsProof`: alguna fila viva compartida (`lineageSharedLiveRows`)
  **y**, en cada tabla del plan con algo que subir (fuera de `exchange_rates`), todas las filas vivas del backend ya en
  local. Sin eso, `.lineageUnproven` como antes (rastros `adoptReconcileLineageUnproven` / `adoptReconcileAccountRowsMissing`).
- `lineageSharedLiveRows` es el cruce de la ida, sacado a un helper que usan las dos (`checkForwardLineage` y el adopt):
  filas VIVAS, en su tabla, fuera de `exchange_rates`.
- Rastro nuevo `adoptReconcileLineageProvenBySharedRows` (conteos, sin PII).
- Medido antes: ninguna tabla personal tiene identidades fijas entre teléfonos (no hay `UUID(uuidString:)` de siembra; las
  entidades de sistema se acuñan por dispositivo, `SystemEntityMergePolicy`), así que un corpus de otro iCloud no comparte
  ninguna fila con la cuenta.
- Sin texto nuevo y sin cambio en el runner: `.lineageUnproven` sigue saliendo por el techo corto con `effectLineageUnproven`.

## Red

- `MigrationWorkExecutorTests` (145): el fixture `seedWindowCorpus` modelaba el corpus ajeno CON una fila compartida
  («lo único que los separa es el marcador»), que un teléfono real no puede tener. Ahora trae dos backends sobre el mismo
  inventario: la cuenta de la que desciende y una ajena. Nuevos: sin marcador, el ajeno no toca nada y el que comparte sube
  sus dos huérfanas; el marcador sigue probando solo; ni un tombstone, ni otra tabla, ni un tipo de cambio prueban; si a
  una tabla que sube le faltan filas de la cuenta (identidades del líder sin llegar) no sube nada, y cuando llegan sube
  solo la fila nueva; una fila que falta en una tabla que no sube, o en los tipos de cambio, no bloquea; la guarda del
  plan definitivo prueba con su propio inventario; el marcador ilegible para aunque haya fila compartida.
- **12 mutantes, 12 muertos** (y un control sin cambio, vivo): sin la segunda prueba · prueba sin filas compartidas ·
  cruce sin tabla · tombstones como vivas (dos formas) · sin la excepción de tipos de cambio · filas antes que marcador ·
  plan definitivo sin inventario · plan definitivo con el preliminar · sin cobertura · cobertura en todas las tablas ·
  cobertura también en tipos de cambio.

## Review adversarial (3 lentes, 2026-09-24)

Arreglado en este PR:
- **Una fila compartida no bastaba** (lente del dispositivo legítimo, alta): con la exportación del líder parada, la cuenta
  se comparte pero sus movimientos y categorías siguen aquí sin identidad; el backfill les acuñaba otra y el adopt subía el
  libro entero duplicado. El marcador lo impedía de hecho (se exporta después de las identidades). Ahora se exige la
  cobertura por tabla (`adoptSharedRowsProof`).
- La guarda definitiva con el inventario preliminar sobrevivía a los tests (lente de tests): test nuevo. Dos docblocks que
  aún decían «falta el marcador» y un fixture cuyo subcaso del tombstone no podía fallar.

Medido y no se toca:
- **Un store que ya mezcló la vuelta a iCloud** (lente del corpus ajeno): filas de la cuenta A + la zona de otro iCloud,
  y un adopt posterior de A daría la prueba por filas. Esa cuenta sigue con `reverse_frozen_at` tras `reverse_complete`
  (`qa/cloud/README.md`) y `/sync/push` la rechaza con 409 (`gateway/src/sync/routes.ts`): la mezcla no llega. Queda
  escrito en la regla.
- Las fichas de identidad sobreviven a «Empezar desde cero» y el backfill puede reasignar por contenido: anterior a este
  cambio, y su entrada (la sesión de la persona anterior) la cierra `previous-person-cloud-session-survives-fresh-start-and-reinstall`.
- **Desde Ajustes** el segundo teléfono que ya tenía Yala no llega al adopt sin marcador (lente del dispositivo legítimo):
  es la puerta de «Migrar», de `settings-migrate-blocks-a-second-device-before-its-marker`; nota añadida allí.

A ticket propio: `migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived` (medium, inferido): el
relevo prueba con una fila y sube su corpus entero; el mismo duplicado, en la ida.

Residual aceptado, sin ticket: si el segundo teléfono BORRÓ durante la ventana una fila del líder en una tabla donde además
escribió algo, la cobertura no se cumple nunca sin marcador; sale por el techo corto con el texto de siempre. Es la misma
postura que antes del cambio para ese caso, y el marcador, cuando llega, lo desbloquea.

## QA

Sin device-QA propio: el escenario pide un primer teléfono parado justo entre el cutover del servidor y la exportación del
marcador más de una hora, y no se monta con fiabilidad en un iPhone. El camino que sí se monta —el segundo teléfono con
marcador— es el guion de `adopt-uploads-a-foreign-corpus-without-a-lineage-check` (en `qa`), y no cambia.
