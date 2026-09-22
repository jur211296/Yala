---
name: volver-de-la-puerta-no-estrena-permiso
description: PR #205 — el descarte aparca su reloj en vez de olvidarlo; en qa con guion de 3 casos en iPhone, y deja dos residuales con ticket propio
metadata:
  type: project
---

**PR #205, mergeado a `2.1` el 2026-09-22 de madrugada. Ticket en `qa`: necesita teléfono.**

Cierra el recorrido de tres toques que dejó abierto #204: «Empezar desde cero» → confirmar →
«Volver» → Restaurar estrenaba el permiso del guard de frontera de cuenta. La confirmación pasa de
`noteRestoreFinished` (apaga y olvida) a `noteRestoreDiscardRequested` (apaga y APARCA el reloj); el
estreno lo hereda mientras tenga menos de 600 s y lo consume siempre.

**Why:** el criterio 1 del ticket pedía cerrar ese recorrido concreto, no un techo absoluto — el
propio ticket ya declaraba inalcanzable cualquier techo, porque matar la app estrena todo.

**How to apply:**

- **El QA solo muerde con la descarga VIVA.** En un restore pequeño el import asienta antes de llegar
  al botón y el descarte es un no-op: parecerá que el fix no hace nada. El guion del ticket lo dice
  en su primer párrafo, con tres casos (el abuso, el dueño encerrado, y arrepentirse pronto).
- **Dos residuales con ticket propio, y el segundo es MÁS BARATO que lo que este PR cerró**:
  `wiped-state-reaches-the-discard-gate-with-the-window-open` (el séptimo camino a la puerta, el
  único sin diálogo, no apaga nada) y `restore-retry-reopens-the-session-window-every-90-seconds`
  (un toque cada 91 s en la población sin ningún import, sin pasar por la puerta). Si Jürgen pregunta
  «¿ya está cerrado el techo?», la respuesta honesta es que no y que el segundo ticket es por dónde
  seguir.
- Los tres `600` del subsistema salen ya de `ICloudRestoreInProgressLogic.sessionWindowHardCap`.

Relacionado: [[project_salir_y_volver_no_renueva_con_descarga_vieja]],
[[feedback_mi_arreglo_quita_la_salida_que_habia]].
