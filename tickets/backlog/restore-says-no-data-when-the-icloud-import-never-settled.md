---
id: restore-says-no-data-when-the-icloud-import-never-settled
status: backlog
priority: high
area: "welcome, icloud, restore"
created: 2026-09-17
updated: 2026-09-17
source: "review adversarial de `reinstall-without-network-has-no-cloud-door` (lente de poblaciones), 2026-09-17"
---

# Restaurar dice «no hay datos» cuando la búsqueda de iCloud se agotó, y ofrece borrar sin preguntar

## El problema, en lenguaje de usuario

Estreno móvil o reinstalo Yala, tengo mi histórico en iCloud y toco «Restaurar desde iCloud». La
pantalla busca, tarda, y me contesta **«No encontramos tus datos. No hay datos asociados a tu cuenta de
iCloud»** — con mis datos ahí. Debajo, el botón grande dice «Empezar desde cero», **y ese botón no
pregunta nada**: un toque y arranco vacío.

Pasa cuando el primer import de CloudKit no ha terminado en 90 segundos: histórico grande, conexión
lenta, o iCloud entregando por lotes.

## Medido (2026-09-17)

- `RestoreProgressView.startFlow` recibe `settled` de `waitForImportQuiescence(timeout: 90)` y lo usa
  **solo para la fase visual y el breadcrumb**: llama a `onSettled(counts ?? …vacío)` igual si el
  import asentó que si se agotó el tope (`RestoreProgressView.swift`, la cola de `startFlow`).
- `waitForImportQuiescence` documenta él mismo que devuelve `false` por timeout
  (`iCloudSyncService.swift`, su `- Returns:`).
- Con el resumen vacío, `WelcomeRestoreView` va a `resolveEmptyState`, y si el config está comprobado
  y no hay faro, el desenlace es `.notFound`.
- `notFoundView` pone `startFresh` de botón PRIMARIO **llamando directo a `onStartFresh`**, sin el
  `confirmationDialog` que sí usan `.found`, `.cloudPaused` y `.cloudUnverified`.

## Por qué no se arregló en el ticket del que sale

`reinstall-without-network-has-no-cloud-door` (opción 2, 17-sep) cerró la mitad del canal de
remote-config y **descartó `settled` como señal a propósito**: un usuario realmente nuevo, con el store
vacío, tampoco dispara `.importEvent` y agota el mismo tope, así que usarlo tal cual convertiría «no
hay datos» en «no pudimos comprobar» para toda instalación nueva, y tras 90 s de espera. La señal
correcta tiene que distinguir «CloudKit no contestó» de «CloudKit dijo que no hay nada», y eso pide
mirar el error del import (`lastImportError`, `hasObservedImportActivity`), no el tope.

## Por qué la población es MAYOR que la del ticket del que sale

Aquel necesitaba reinstalar **y** no tener red. Este solo necesita que el import tarde más de 90 s,
que es lo normal con un histórico grande — y el desenlace incluye un botón destructivo sin confirmar.

## Lo que hay que decidir (Jürgen)

1. **Distinguir el timeout del vacío** con la señal del propio import (`hasObservedImportActivity` +
   `lastImportError`), y decir «seguimos trayendo tus datos» en vez de negarlos.
2. **Subir el tope** de los 90 s, o hacerlo adaptativo mientras los conteos sigan creciendo.
3. **Como mínimo, confirmar antes de «Empezar desde cero»** en `.notFound` cuando la búsqueda no
   asentó. Es el cambio más barato y el que evita la pérdida.

## Criterios de aceptación

- [ ] Un import que no asienta en el tope NO produce el mensaje que niega los datos.
- [ ] Ningún desenlace de búsqueda no concluyente ofrece borrar sin confirmación.

## Relación con otros tickets

- `reinstall-without-network-has-no-cloud-door` — de donde sale; cerró el canal hermano.
- `restore-start-fresh-keeps-the-imported-corpus` — el otro lado de «Empezar desde cero» aquí.

## Decisión Jürgen (2026-09-17)

**1+3 (lo más robusto entre solo-1 y 1+3):**

1. Distinguir timeout vs vacío con la señal del import — decir «seguimos trayendo tus datos» en vez de negar que existan.
3. Además, confirmar antes de «Empezar desde cero» en `.notFound` cuando la búsqueda/import no asentó (red de seguridad contra borrado a ciegas).

No ahora: solo subir/adaptar el tope de 90 s (opción 2) como remedio principal.

Cola: reverse #194 mergeado; Jürgen reanudó cola A 2026-09-20 ~22:00 Lima — este ticket es el siguiente.

