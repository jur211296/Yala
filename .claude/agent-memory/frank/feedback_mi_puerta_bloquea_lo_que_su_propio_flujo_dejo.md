---
name: mi-puerta-bloquea-lo-que-su-propio-flujo-dejo
description: Una puerta que clasifica por el estado del servidor tiene que reconocer el estado que dejó un intento ANTERIOR de su propio flujo; el 16-sep mi comprobación bloqueaba para siempre «Reintentar» tras un fallo
metadata:
  type: feedback
---

**Antes de cablear una puerta que decide por el estado remoto, recorre qué estado deja en el servidor un intento
fallido del mismo flujo, y pásalo por la puerta.** Si el primer paso del flujo cambia el estado que la puerta mira,
el reintento se encuentra con su propia huella y la lee como ajena.

**Why:** en `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (2026-09-16) la comprobación bloqueaba
toda cuenta `complete`. Pero el claim de «Migrar» deja la cuenta `complete` en cuanto contesta `created`, antes de
subir nada. Un rollback posterior («Reintentar») volvía a `notStarted` con la sesión viva, y la puerta decía «Esa
cuenta ya tiene finanzas personales» sobre la cuenta que este mismo teléfono acababa de crear, cuando el servidor le
habría dado `created` otra vez al mismo líder. Lo cazaron dos lentes de la review por separado; ningún test mío lo
veía porque todos partían de `notStarted` limpio. El arreglo fue la excepción del sello `.proceedMigration`.

**How to apply:** al diseñar la tabla de una puerta, añade una fila por cada salida de fallo del flujo que protege
(rollback, reintento, kill a medias) con el estado remoto que deja. Si el fixture de los tests arranca siempre de
cero, escribe también el caso «segundo intento». Relacionado: [[mi-arreglo-rompe-la-premisa-de-otro-guard]],
[[mi-salida-nueva-es-un-camino-muerto]].
