---
id: cutover-marker-without-a-session-locks-out-the-second-device
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-25
source: "review adversarial de `adopt-uploads-a-foreign-corpus-without-a-lineage-check` (lente del dispositivo legítimo, H2), 2026-09-24"
---

# Un marcador del cutover escrito sin sesión deja fuera al segundo dispositivo cuando tiene algo que subir

## El problema, en lenguaje de usuario

Activo la nube en el iPhone. Justo después de que el servidor confirme, la app se cierra y al reabrir la sesión ya no
está. La activación termina igual. Mi iPad, con el mismo iCloud, había anotado un gasto durante la activación: al
activar la nube en él, nunca entra, y cada intento acaba en «no pudimos comprobar que vengan de ella».

## Lo medido (2026-09-24, leído en el código, sin ejecutar)

- El efecto `.writeCloudKitMarker` (`MigrationWorkExecutor`) escribe `accountHash: session.currentUserID.map(CloudBeacon.hash) ?? ""`.
  Entre `serverConfirmed`, `localModeSet` y `markerWritten` el runner no pide sesión: son pasos locales.
- Desde `adopt-uploads-a-foreign-corpus-without-a-lineage-check` el adopt exige, con algo que subir, un marcador cuyo hash
  sea el de la cuenta. Uno con el hash vacío no lo es, y nadie lo reescribe: el espejo del líder ya está apagado.
- Antes de ese ticket el hash vacío no tenía consecuencias.

## Opciones, sin decidir

- Que el líder no escriba el marcador sin la cuenta: tomar el hash del claim (lo tenía al reclamar) en vez de la sesión viva.
- Aceptar un marcador con hash vacío como prueba (abre un hueco: el corpus de este iCloud pudo migrar a OTRA cuenta).

## Criterios de aceptación

- [ ] El marcador del cutover siempre lleva el hash de la cuenta que migró, haya sesión o no en ese instante.

## Actualización (2026-09-24, `adopt-after-the-cutover-needs-a-marker-the-leader-never-exported`)

El bloqueo del segundo dispositivo ya no depende de este marcador: desde ese ticket el adopt acepta también como prueba de
linaje una fila VIVA de la cuenta en el store local, y el segundo dispositivo del mismo iCloud siempre tiene las cuentas y
movimientos que el líder subió. Un marcador con el hash vacío ya no deja fuera a nadie que comparta datos con la cuenta.
Queda el criterio de abajo como higiene del marcador (sigue siendo la primera prueba que se mira).

## Actualización (2026-09-25, `markerless-adopt-stays-blocked-while-another-device-writes-to-the-account`)

Un marcador con el hash vacío no es el de la cuenta. El primer adoptador que entra con cobertura total releva uno con el
hash bueno, y los teléfonos siguientes entran por él. El criterio de este ticket sigue abierto como higiene.

