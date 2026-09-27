---
id: prefs-push-purge-drops-a-change-made-during-the-upload
status: backlog
priority: medium
area: "modo-nube, sync, preferencias"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial de `prefs-outbox-reads-an-unreadable-file-as-corrupt-and-overwrites-it` (2026-09-26), lente de caminos equivalentes; previo a ese diff"
---

# Si cambias una preferencia mientras se sube la anterior, el cambio nuevo no llega a tus otros dispositivos

## El problema, en lenguaje de usuario

Cambias una preferencia, Yala empieza a subirla, y antes de que termine la vuelves a cambiar. Cuando la subida de la
primera termina, Yala borra de la cola también la segunda: tus otros dispositivos se quedan con el primer valor.

## Por qué pasa (leído el 2026-09-26; la carrera, inferida y sin ejecutar)

- `CloudSyncRuntime.syncPrefsOnce` lee las entries, hace `await prefsClient.push(wire)` y con los `applied`/`noop`
  llama a `PrefsOutbox.removeEntries(keys:)`, que borra **por key sin comparar el HLC** de lo que se subió.
- `PreferenceSyncService` y el runtime son `@MainActor`, pero el `await` del push suelta el actor: un `set()` en esa
  ventana encola la misma key con un HLC nuevo, y la purga se la lleva.

## Criterios de aceptación

- [ ] La purga tras el push solo retira una entry si su HLC es el que se subió; una más nueva se queda y sube en el
  ciclo siguiente.
- [ ] Test con el `enqueue` intercalado entre la lectura y la purga, y control con la entry sin cambios.
