---
name: la-pantalla-se-monta-antes-de-decidir
description: Un `state` cuyo valor INICIAL ya pinta trabajo arranca ese trabajo antes de que el `.task` decida nada — y ese trabajo sobrevive al desvío
metadata:
  type: feedback
---

Cuando el `@State` de una vista **nace** en el caso que monta trabajo (una espera, un fetch), ese
trabajo arranca en el PRIMER render — antes de que el `.task` de la vista haya mirado nada. Y si el
trabajo no observa cancelación, **sobrevive al desvío**: el `state` cambia, la subvista se desmonta,
y la tarea sigue viva hasta su tope.

**Why:** el 21-sep, en `WelcomeRestoreView`, `state` nacía en `.searching` y eso montaba
`RestoreProgressView`, que arranca una espera de 90 s. En `.wiped` y en `.iCloudDisabled` esa espera
corría igual, invisible. Cuando el ticket anterior le dio a `.iCloudDisabled` un botón de «volver a
buscar», quien encendía iCloud y recargaba acababa con **DOS esperas vivas**, y la abandonada
apagaba la ventana de sesión de la buena: el bug que yo estaba arreglando, por dentro de una sola
pantalla. Lo cazó la review adversarial; yo había refutado el hallazgo y luego encontré el camino.

Su gemelo, misma sesión: con el espejo ya quieto, `waitForImportQuiescence` **vuelve sin
suspenderse**, así que el apagado de esa espera podía correr ANTES del encendido del `.task` padre.
Un apagado que llega antes de su encendido deja el estado sin dueño.

**How to apply:**

- Antes de cablear algo al `case` inicial de un `switch` sobre `@State`, pregunta **qué arranca ese
  case en el primer render** y qué pasa con ello cuando el `.task` desvíe a otro.
- La salida barata es una **puerta de montaje**: `if let <lo que la decisión produce> { ... }`. El
  dato llega por MONTAJE, no por re-disparo, así que no depende del orden de dos `.task` — y de paso
  el trabajo no arranca en los caminos que no lo necesitan.
- **`.task(id:)` NO es equivalente**: apoya la corrección en que SwiftUI vuelva a disparar, y si no
  lo hace la pantalla se queda girando para siempre. Si no puedes medir ese re-disparo, no lo uses
  como red.
- Y cuenta las entradas a ese `case` desde BOTONES: un reintento añadido por otro ticket convierte
  «una pantalla = un trabajo» en «una pantalla = dos».

Relacionado: [[feedback_mi_arreglo_abre_un_camino_inalcanzable]] · [[feedback_el_consumidor_lee_una_copia]]
