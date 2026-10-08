---
id: detach-purge-failed-copy-says-groups-remain-after-a-cursor-only-failure
status: backlog
priority: low
area: "modo-nube, groups, l10n"
created: 2026-10-01
source: "review adversarial de `groups-purge-save-crosses-two-stores-without-atomicity` (lente de consumidores)"
updated: 2026-10-08
---

# El aviso de «No pudimos soltar la cuenta» dice que los grupos siguen en el iPhone cuando ya no están

## El problema, en lenguaje de usuario

Suelto mi cuenta de grupos y el borrado falla. El aviso dice «Tus grupos siguen en este iPhone y la cuenta no se
soltó», y la sección de Ajustes repite «Quedó a medias: tus grupos siguen en este iPhone». Pero la pestaña Grupos
está vacía: en un caso concreto los grupos ya se borraron.

## Lo medido

Desde `groups-purge-save-crosses-two-stores-without-atomicity` el borrado del desasociar va en `save()` separados,
en este orden: outbox → filas de Grupos → cursor. Si falla el último (el del cursor, store sync-meta) con el
outbox vacío, quedan las filas borradas y el cursor vivo. Es el único corte con las filas ya fuera, y es
reparable: «Vuelve a intentarlo» lo termina (`retryDetachPurge`, idempotente). Lo que miente es el texto:

- `storage.groups.detachPurgeFailedBody` (es: «Tus grupos siguen en este iPhone y la cuenta no se soltó…»)
- `storage.groups.detachPendingBody` (es: «Quedó a medias: tus grupos siguen en este iPhone…»), durable mientras
  `GroupsDetachPendingPurge` siga armada.

La ventana es estrecha: hace falta que el store sync-meta falle justo en el `save()` del cursor.

## Qué haría falta

Un texto que sea verdad en los dos casos («la cuenta no se soltó del todo; vuelve a intentarlo para terminar»),
sin afirmar dónde están los grupos, en los 16 idiomas y con `BRAND-VOICE.md`. O separar los dos casos con un
motivo que el borrado devuelva.

## Medido en 2.1 (triage 2026-10-08)

- `DataWipeService.deleteLocalGroupsRows` sigue guardando por tramos en el orden outbox → `GroupBridgePreference` → Grupos → cursor, así que un fallo solo en el `save()` del cursor deja las filas ya borradas.
- `storage.groups.detachPurgeFailedBody` y `storage.groups.detachPendingBody` siguen afirmando «Tus grupos siguen en este iPhone» en todos los idiomas (p. ej. `es.lproj`, `en.lproj`). Sin commits sobre esas claves desde el 2026-10-01.

Triage 2026-10-08: abierto · low → low · el texto sigue afirmando que los grupos están cuando el corte del cursor ya los borró; ventana estrecha y «Vuelve a intentarlo» lo termina.
