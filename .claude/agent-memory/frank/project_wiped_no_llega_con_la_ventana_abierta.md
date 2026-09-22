---
name: wiped-no-llega-con-la-ventana-abierta
description: PR #207 (2026-09-22) — el séptimo camino a «Empezar desde cero» ya apaga la ventana de sesión; ticket en qa con guion de dos teléfonos, y un residual (el remontaje) con ticket propio en backlog.
metadata:
  type: project
---

**PR #207 cerró `wiped-state-reaches-the-discard-gate-with-the-window-open`: el apagado de la ventana
de sesión subió a un punto único (`WelcomeRestoreView.discardImportAndStartFresh()`) por el que pasan
los siete caminos a la puerta de descarte.** El ticket quedó en `qa`; el hermano
`discard-gate-cannot-close-an-orphan-session-window` quedó en `backlog`, **medium**.

**Why:** cola A nocturna tras #206. `.wiped` era el único que pasaba el callback crudo, y su población
no es teórica: el sello del wipe viaja por el iCloud-KV, así que puede llegar de otro dispositivo
entre la primera búsqueda y el «volver a buscar».

**How to apply:**

- **El residual es una DECISIÓN de Jürgen, no una omisión mía.** El punto único solo apaga si esa
  instancia de la vista tiene el token y sigue siendo el dueño; quien sale de Restaurar y vuelve llega
  con `flowToken == nil`. Cerrarlo pide decidir si el descarte puede apagar una ventana ajena —que es
  justo lo que `noteRestoreAbandoned` existe para no hacer—. Si alguien retoma esa familia, ese ticket
  va primero.
- **El QA de este ticket pide DOS teléfonos con el mismo Apple ID** y un import vivo. No hay guion de
  simulador posible, y el guion de tres casos vive en el ticket.
- **`.wiped` no confirma con diálogo, y eso está ratificado dos veces** (en el escáner
  `bothStatesThatClaimDataStillConfirm` y en este ticket): su búsqueda concluye por acto de la propia
  persona. Si alguien propone añadirle diálogo, es un cambio de producto, no una coherencia pendiente.

Relacionado: [[el-contains-deja-sitio-a-una-sentencia-antepuesta]] (salió de su review) y
[[review-adversarial-caza-lo-mio]].
