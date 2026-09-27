---
id: prefs-push-purge-drops-a-change-made-during-the-upload
status: done
priority: medium
area: "modo-nube, sync, preferencias"
created: 2026-09-26
updated: 2026-09-26
qa-status: not-replicable
qa-date: 2026-09-26
qa-notes: la carrera cae dentro de una peticion de red y no se puede provocar a mano en un iPhone; la fijan los unit con el enqueue dentro del push
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

- [x] La purga tras el push solo retira una entry si su HLC es el que se subió; una más nueva se queda y sube en el
  ciclo siguiente.
- [x] Test con el `enqueue` intercalado entre la lectura y la purga, y control con la entry sin cambios.

## Resuelto (2026-09-26)

**Para el usuario:** si cambias una preferencia mientras Yala sube la anterior, el cambio nuevo se queda en la cola y sube
en la siguiente sincronización; tus otros dispositivos acaban con el valor nuevo.

- `PrefsOutbox.removeEntries(pushed:)` recibe `key → hlc` de lo que viajó y solo retira la entry si conserva ese HLC
  (igualdad exacta: cada `enqueue` emite uno estrictamente mayor). La firma vieja por key desaparece.
- `CloudSyncRuntime.syncPrefsOnce` toma el HLC del wire enviado (la respuesta no lo trae); un resultado con `reason` o de
  una key que no viajó no purga nada.
- Regla en `swiftdata-cloudkit.md` («La purga del outbox de preferencias tras el push compara el HLC que viajó»).

**Verificado:** `PrefsOutboxTests#removeEntries_*` y `CloudSyncRuntimeTests#syncCycle_prefsStep_changeDuringPush_*`,
`…_noChangeDuringPush_*`, `…_purgesOnlyCleanResultsOfSentKeys` (el stub de red encola la misma key DENTRO del push, entre
la lectura del ciclo y la purga). Mutantes muertos: purgar por key, no purgar nunca, tomar el HLC actual del outbox en vez
del enviado, purgar todo lo enviado sin mirar la respuesta, comparar con `<=`. Review adversarial de tres lentes sin
hallazgos altos ni medios sobre el diff.

**Encontrado y fuera de alcance, con ticket:** `prefs-pull-overwrites-a-pending-local-change-on-screen` (el pull del mismo
ciclo pinta un ciclo el valor que acaba de subir), `prefs-push-retries-a-rejected-key-forever` y
`metrics-drain-purge-drops-unsent-events-when-the-spool-is-full` (el gemelo del patrón en la cola de métricas).
