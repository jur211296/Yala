---
name: desasociar-no-finge-exito
description: PR #144 — si el borrado local falla al soltar la cuenta de grupos, la app lo dice y no limpia la asociación; la review cazó 2 ALTAS en mi propio rediseño y el device-QA NO es simulable
metadata:
  type: project
---

**`detach-failure-looks-like-success` cerrado en código el 2026-09-11 (PR #144), a `qa/`.** Siguiente
high de la cola del rediseño de sesiones tras el paso 10.

El defecto: «Desasociar» en Ajustes → «¿Dónde viven tus datos?» → Grupos limpiaba la asociación aunque el
borrado local hubiera fallado, así que la pantalla decía que había soltado la cuenta con los grupos
enteros en el teléfono.

**Why:** es de la familia de `freshStartWipeFailed` —un borrado que no ocurre y una UI que dice que sí— y
lo dejó abierto la review del paso 10.

**How to apply** (lo que hay que saber si se retoma):

- **La decisión de producto**: se ofrece **terminar el borrado**, no rehacer la asociación ni repetir el
  gesto. Repetirlo vuelve a entrar por el push-all DESPUÉS del teardown, y un gasto añadido entre medias
  lo deja bloqueado para siempre. `retryDetachPurge` hace el borrado y su remate, y nada más.
- **`GroupsDetachPendingPurge` va SELLADA con el `sub`** y hay que nombrarla en las TRES fronteras que
  borran el dominio (relevo de humano, boot-wipe de sign-out, reset de `-uitest-reset`): esas funciones
  son listas de keys, no barridos por prefijo.
- **Lo que NO es simulable, y su motivo**: el botón «Terminar de soltar la cuenta» necesita un `sub`, y
  `-uitest-fake-cloud-session` no propaga `currentUserID` a propósito. Hace falta el seam de
  `uitest-seam-for-a-seeded-groups-association` (ticket propio, medium) — el mismo que le falta a la celda
  «asociada sin sesión viva» desde el paso 10.
- **Falta device-QA de dos teléfonos y NO es simulable**: que tras el fallo la pestaña Grupos siga entera,
  que «Terminar» funcione sin sesión viva, y que re-asociar después no duplique los gastos conservados.

**La review adversarial fue en DOS vueltas y la segunda es la que enseña**: tres lentes sobre el arreglo,
y una cuarta sobre el rediseño que esas tres me obligaron a hacer — ver
[[la-correccion-de-la-lente-reintroduce-el-bug]]. En total 14 mutantes verificados.

Deja cuatro tickets: la atomicidad del `save()` que cruza dos archivos, el seam de asociación, el voseo
del bloque es-AR y el breadcrumb que no cierra al lanzar.
