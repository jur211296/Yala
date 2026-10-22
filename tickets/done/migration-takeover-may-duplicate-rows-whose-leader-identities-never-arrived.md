---
id: migration-takeover-may-duplicate-rows-whose-leader-identities-never-arrived
status: done
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "review adversarial de `adopt-after-the-cutover-needs-a-marker-the-leader-never-exported` (2026-09-24), lente del dispositivo legítimo: el mismo mecanismo, en la ida"
---

# El relevo puede subir duplicados de lo que el líder callado ya subió, si sus identidades no llegaron por iCloud

## El problema, en lenguaje de usuario

Empiezo a activar la nube en el iPhone A, que sube parte de mis movimientos y se queda sin conexión más de una hora. El
iPhone B, con el mismo iCloud, toma el relevo y termina. Si iCloud no le había traído a B las marcas internas que A puso
a cada movimiento antes de subirlos, B sube los mismos movimientos con otras marcas y la cuenta queda con dos copias.

## Lo medido y lo inferido (2026-09-24)

- Medido en el adopt (el ticket de origen): sin marcador, la exportación del líder puede estar parada; la cuenta
  (`Account.shortcutID`, que nace con la fila) se comparte, pero las filas de identidad SINTÉTICA (movimientos,
  categorías, borradores, favoritos, comercios) siguen sin `syncID` en el otro teléfono, y el backfill les acuña una
  fresca. En el adopt se cerró exigiendo que, en cada tabla que sube, estén todas las filas vivas de la cuenta
  (`MigrationWorkExecutor.adoptSharedRowsProof`).
- **Inferido, sin medir:** el relevo (`checkForwardLineage` → `assignIdentity` → subida del snapshot) prueba el linaje con
  UNA fila compartida y luego sube todo su corpus. Si las identidades que el líder callado asignó (en el 35 %) y subió no
  llegaron a B, B las acuña de nuevo y sube su corpus entero con otras identidades encima del parcial del líder. Falta
  medir si algo lo evita ya (el rebind de `SyncIdentityService` con testigos, una deduplicación en el servidor, la
  verificación del snapshot).

## Medido (2026-09-24): SÍ duplicaba, y nada lo evitaba

- **El servidor solo deduplica por identidad**: las 16 tablas personales tienen `PRIMARY KEY (user_id, sync_id)`
  (`supabase-staging.ddl`), sin clave de contenido.
- **El rebind no tiene de dónde tirar**: `SyncIdentityService.backfillIdentities` reusa identidades por los testigos
  `SyncIdentity` locales, y esos testigos viven en el store de metadatos, que NUNCA se espeja a CloudKit
  (`SwiftDataConfiguration.syncMetaSchema`): el relevo no tiene ninguno del líder.
- **La verificación no lo caza, lo consolida**: `verify()` hace `pullAndApplyOnce` ANTES de `verifyIntegrity`, así que baja
  las copias del líder al store local (su `sync_id` no existe aquí ⇒ fila nueva) y el Merkle cuadra con el libro doble.
- **Un test lo fijaba como contrato**: `forwardLineage_foreignCorpusUnproven_sameICloudProven` daba `proven` a un relevo con
  la categoría del líder ausente y otra categoría sin identidad por subir.

## Arreglo

`checkForwardLineage` exige, además de una fila compartida, la misma cobertura que el adopt
(`MigrationWorkExecutor.adoptSharedRowsProof`, la misma función): en cada tabla con algo que subir, todas las filas vivas
del backend ya en local. Si falta alguna, `ForwardLineageOutcome.accountRowsMissing(table:missing:)`: no se asigna
identidad ni se sube nada. El Merkle tiene que dar la enumeración por completa antes de cualquier veredicto, también el de
«llegó todo» (hasta hoy una compartida probaba sin él).

`driveIdentity` espera: cada pasada vuelve a preguntar (si iCloud trae las identidades, sigue), y a los 15 min sale con un
motivo propio, `leaderRowsNotArrived`, y su texto (`storage.failed.stepLeaderRowsNotArrived`, 16 idiomas): «otro de tus
dispositivos ya subió parte de tus datos y a este todavía no le han llegado todos por iCloud, así que no subimos nada para
no duplicarlos… Abre Yala con conexión en ese otro dispositivo, espera a que iCloud termine de traer tus datos a este y
vuelve a intentarlo». La primera versión reusaba el texto de `lineageUnproven`, y dos lentes de la review lo tumbaron: dice
que los datos «no coinciden» y pide revisar la cuenta, y aquí es la cuenta buena. En la bienvenida es la misma pantalla
(`.lineageExit`, que ahora lleva el motivo) con su frase.

## La review adversarial (3 lentes)

- **Cazó un error mío de premisa**: yo escribí que los testigos `SyncIdentity` viajan por CloudKit; son locales
  (`SwiftDataConfiguration.syncMetaSchema`, `cloudKitDatabase: .none`). La conclusión se mantiene y está corregida aquí,
  en la regla y en el docblock.
- **El texto** (arriba).
- **Residuales a tickets propios**: un borrado durante la espera deja el relevo (y el adopt) bloqueado para siempre
  (`lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait`); las identidades que el líder exporta tarde
  pueden pisar las del relevo (`displaced-leader-late-identity-export-can-rekey-the-relief-corpus`).

## Criterios de aceptación

- [x] Medido si el relevo duplica en ese caso: sí (arriba).
- [x] El relevo no sube una fila cuya identidad del líder no llegó: espera y, a los 15 min, sale con el texto de «espera a
      que iCloud termine de traer tus datos», con motivo y texto propios. Tests: `MigrationWorkExecutorTests` (`forwardLineage_leaderIdentitiesNotArrived_blocksUntilTheyDo`,
      `forwardLineage_orphanWithIdentity_alsoNeedsTheAccountRows`, el de enumeración incompleta) y `MigrationRunnerTests`
      (`forwardLineage_accountRowsMissing_*`), `ForwardStepCeilingLogicTests` (texto en los 16 idiomas y la fase de la
      bienvenida) y `WelcomeAdoptExitTests`. Mutantes: 6 de 6 muertos.

## Sin device-QA

El escenario —el líder sube parte, se queda sin red más de una hora sin exportar sus identidades a iCloud, y el segundo
iPhone toma el relevo antes de que lleguen— no se monta con fiabilidad en dos teléfonos: depende de cuándo exporta
CloudKit. Mismo criterio que #240.
