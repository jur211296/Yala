---
name: project-adopt-sobre-nube-espera-decision
description: El adopt sin salida sobre un teléfono en modo nube espera que Jürgen elija A/B/C (13-nov); los fallos 1 y 2 del lote ya están en el PR borrador
metadata:
  type: project
---

El lote de fallos altos de 2.3 (13-nov, sesión nocturna) quedó en checkpoint: PR en borrador con la hoja de éxito de la
Bandeja arreglada y el reimport de Grupos verificado (ya estaba arreglado desde el 29-oct), y el adopt parado en una
decisión de producto.

**Why:** «Empezar de cero» del Welcome retira la sesión pero deja el modo en `.cloud`; el adopt que sigue no tiene
«Cancelar» ni techo. La ficha dejaba la salida abierta y el encargo pedía no elegirla. Recomendé A: cerrar el origen
(que «Empezar de cero» deje el teléfono como recién instalado, como «Cerrar sesión») + no adoptar sobre `.cloud` +
canario.

**How to apply:** si la card «Espera decisión» vuelve contestada, la continuación implementa la opción elegida sobre la
rama del PR borrador (no rehace los fallos 1 y 2). Antes de construir, mide que «Empezar de cero» siga sin escribir
`.icloud` (grep `StorageModePersistence.write(.icloud` fuera de `SwiftDataConfiguration`).
