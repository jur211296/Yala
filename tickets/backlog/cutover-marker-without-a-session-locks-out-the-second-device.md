---
id: cutover-marker-without-a-session-locks-out-the-second-device
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
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
