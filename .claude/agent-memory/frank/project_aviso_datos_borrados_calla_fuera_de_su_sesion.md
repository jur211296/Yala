---
name: aviso-datos-borrados-calla-fuera-de-su-sesion
description: PR #162 — el aviso «tus datos fueron eliminados de iCloud» ya pasa por el eje de sesión; la premisa del ticket era falsa y lo que cierra es el aviso auto-infligido tras «Vaciar datos».
metadata:
  type: project
---

**PR #162, mergeado el 2026-09-14.** El aviso de la gracia de 5 s pasa por
`DestructiveScopeLogic.wipeSignalObeyedByThisSession` — tercera superficie del mismo eje que gobierna
el borrado por señal remota. Cuatro líneas de código.

**Why:** la decisión de Jürgen fue la opción 1 del ticket, callar, con el riesgo escrito: en esa celda
también se calla un hueco transitorio real de CloudKit.

**How to apply:** lo que vale para el yo-futuro no es el arreglo, son las dos correcciones.

- **La premisa del ticket era falsa, y la del encargo la heredaba.** Atribuía el aviso al espejo de
  CloudKit de un teléfono prestado. Esa celda no lo ejercita por ninguno de los dos lados: un
  solo-grupos desde el 10-sep monta `.neutralNoMirror` (sin espejo que baje las filas) y uno anterior
  recibe `hasPrivateSession = true` del backfill, así que el guard no lo calla. **Lo que sí llega es
  el aviso AUTO-INFLIGIDO tras «Vaciar datos» en solo-grupos**: ese camino es el único de los cinco
  borrados deliberados que no cancela la gracia, y su aterrizaje repone `hasCompletedOnboarding` a
  mano. Queda en `wipe-data-does-not-cancel-the-remote-wipe-grace`: hoy lo tapa el eje, no está
  cerrado. Ver [[la-premisa-del-encargo-tambien-se-mide]].
- **Una hipótesis mía quedó refutada y conviene no repetirla:** creí que la población mayor era el
  modo nube, porque el canal de la cuenta borra `Account`/`Category` por tombstone
  (`SyncApplyEngine.applyToEntity`). El mecanismo es real pero **`storageMode` es siempre `.icloud`
  hoy** — Modo Nube DARK, y `.cloud` solo lo escribe el cutover. Antes de contar una celda como
  población, comprueba si está encendida.

**Lo que deja vivo, y el `high` es una decisión suya:** `remote-wipe-alert-skips-the-router` — ese
aviso lo enciende un `Task` de 5 s escribiendo `@State` directo, mientras su hermano (el intent de la
misma señal) sí pasa por `RouterEntryGate`; y el flag es blocker de la matriz, así que una
presentación descartada deja la cola de avisos muerta hasta matar la app. Con él,
`shell-and-wipe-alert-read-the-session-axis-differently`.

**Y un hecho medido que no es decisión:** widget, Siri y notificaciones cuelgan de
`isSignOutWipeArmed()`, no del borrado, así que un vaciado que llega por el espejo no las toca — **los
recordatorios de pagos del dueño se siguen entregando con sus montos en el teléfono prestado**.
Anotado con coordenadas en `after-session-redesign-review-widgets-siri-applepay-and-web-copy`, que
hasta ese día era una lista sin medir.

**Device-QA: NO simulable** (no hay seam que haga desaparecer las filas bajo el proceso vivo).

Relacionado: [[el-eje1-marca-sesion-privada]] · [[el-scan-de-adyacencia-no-fija-el-orden]] ·
[[rediseno-sesiones-dos-ejes]]
