---
id: migration-takeover-uploads-without-a-lineage-check
status: backlog
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

- [ ] Un relevo cuyo corpus no comparte linaje con lo que el backend ya tiene no sube nada y sale con un texto honesto.
- [ ] El relevo legítimo (mismo Apple ID, líder muerto a mitad) sigue terminando la migración.
- [ ] El alta normal (`created` sobre una cuenta vacía o solo de grupos) no paga una espera nueva.
