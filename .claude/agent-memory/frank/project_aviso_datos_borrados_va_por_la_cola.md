---
name: aviso-datos-borrados-va-por-la-cola
description: PR #164 — el aviso de vaciado remoto dejó de encenderse desde una tarea de fondo y viaja por la cola del router; el brick de la matriz y su cura quedaron medidos con mutantes en simulador
metadata:
  type: project
---

El aviso «tus datos fueron eliminados de iCloud» ya no se enciende a pelo desde la gracia de cinco
segundos: viaja por la cola (`.presentRemoteWipeNotice`) y sólo se presenta con el anchor libre. Sus
dos ramas aterrizan explícito, y una red suelta la matriz de readiness si la presentación no monta.

**Why:** era un `high` del review de #162 con tres daños: desmontaba lo que hubiera presentado, podía
brickear el router para toda la sesión, y su botón expulsaba al onboarding por el camino genérico.

**How to apply:**

- **La premisa del encargo era falsa en el CASE**: decía «reusa `.remoteWipe`», y ese intent no
  presenta el aviso — **borra** (`handleRemoteWipeSignal` → `performLocalWipeForRemoteSync`). La vía
  sí era la del encargo. Si vuelve a aparecer «como el otro productor», mide qué hace el otro.
- **Lo que la review cazó de lo MÍO**: la red cubría «la presentación no montó» pero no «montó y se
  cayó después», y la regla de `swiftui-ds.md` nombra las dos. El bucle ya no termina en `satisfied`.
- **Lo que queda abierto**, con su sitio: `orphan-alerts-behind-fullscreen-covers` sigue aparte (es
  el mecanismo general, y ahora tiene un molde escrito al lado);
  `wipe-data-does-not-cancel-the-remote-wipe-grace` ganó una **segunda celda** —
  `performLocalWipeForRemoteSync` con `skipOnboarding` repone `hasCompletedOnboarding` y no cancela
  la gracia, y ahí el eje NO tapa el aviso. Se anotó en ese ticket en vez de abrir uno nuevo.
- El molde técnico (condición viva + sonda a UIKit + desarme) vive en `.claude/rules/swiftui-ds.md`,
  no aquí: es cómo se comporta el código.

Relacionado: [[el-oraculo-del-mutante-es-el-efecto-que-produce]],
[[la-premisa-del-encargo-tambien-se-mide]].
