---
id: forcesync-returns-ok-without-touching-the-network
status: backlog
priority: very-low
area: "modo-nube, sync"
created: 2026-09-10
source: "review adversarial de la primera pasada de `groups-entry-on-a-mirrored-store-still-blocks-the-owner` (2026-09-10); rescatado a `2.1` el 2026-09-11 — vivía solo en una rama sin PR"
updated: 2026-10-08
---

# `forceSync` contesta `.ok` sin tocar la red, y eso hace inservible cualquier «ya está subido»

## Lo medido (2026-09-10)

`iCloudSyncService.forceSync` devuelve `.ok` **sin tocar la red ni guardar** si ya hay un sync en vuelo. Y
su watchdog devuelve el estado a `.idle` a los 8 s cuando no llega ningún evento, así que «ya no está
sincronizando» significa también «todavía no ha empezado».

Las dos cosas juntas hacen que `forceSync` **no pueda usarse como testigo de que algo subió**: el estado
que más lo dispara —el espejo importando durante el Welcome— es justo donde miente.

## Por qué sigue vivo después del paso 9

El paso 9 (`session-exits-one-verb-per-session`) construyó un testigo propio para SU caso —el historial de
SwiftData contra el ancla del último export con éxito— y **no usa `forceSync`**. Pero el método sigue
teniendo sus otros consumidores, y para ellos el `.ok` mentiroso sigue ahí.

## Lo que hay que mirar

- Los call-sites de `forceSync` y cuáles interpretan su `.ok` como «llegó».
- Si el `.ok` del early-return debería ser un caso propio (`.coalesced`) para que el llamador decida.
- El watchdog de 8 s: distinguir «terminó» de «no empezó» necesita otra señal, no un timeout.

## Criterios de aceptación

- [ ] Ningún consumidor puede confundir «coalescido» con «subido».
- [ ] El caso «no ha empezado» es distinguible de «terminó» en el estado que publica el servicio.

## Medido en 2.1 (triage 2026-10-08)

- El early-return sigue igual: `guard !status.isSyncing else { return .ok }` (`iCloudSyncService.swift:670`). El watchdog de 8 s sigue en `:491-496`, y el estado no distingue «no empezó» de «terminó» (AC 2 sin hacer).
- Solo queda un consumidor: `iCloudSyncSettingsView.swift:213` (descarta el resultado) y `:261` (solo lo usa para la nota de «sin conexión»). Ninguno lee `.ok` como «subido», así que el AC 1 se cumple de hecho. Además, el botón se deshabilita con `status.isSyncing` (`:256`) y casi nunca llega al early-return.
- Sí leen `status.isSyncing` como «quieto» el gate de guardado del arranque (`AppBootstrapper.swift:1547`) y el del dedup (`CategoryDeduplicationService.swift:208`). El watchdog solo los afecta tras un «Sincronizar ahora» manual.
- Queda una trampa latente para el próximo que quiera usar `forceSync` como testigo de «ya está subido», no un fallo que alguien pueda recorrer hoy.

Triage 2026-10-08: abierto · medium → very-low · el `.ok` sin red (`iCloudSyncService.swift:670`) y el watchdog de 8 s siguen, pero el único consumidor (`iCloudSyncSettingsView.swift:261`) no lo lee como «subido»: es una trampa latente.
