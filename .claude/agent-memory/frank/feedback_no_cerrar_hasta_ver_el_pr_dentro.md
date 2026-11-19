---
name: no-cerrar-hasta-ver-el-pr-dentro
description: Regla de Jürgen (19-nov 12:55): el auto-merge se arma pero la sesión no cierra hasta ver su PR (y cada PR que mergea) dentro de 2.3
metadata:
  type: feedback
---

Se deja el auto-merge activado, pero **no se cierra hasta ver el PR mergeado en 2.3**, y lo mismo con cada PR
que la sesión mergea. Si aparece un conflicto o el CI falla, la sesión hace el rebase o el arreglo y vuelve a
esperar. Si tras 45 minutos el CI sigue sin pasar por algo ajeno al PR, se anota en el cierre con el motivo.

**Why:** el 19-nov siete PR llevaban días con el auto-merge armado sin entrar (chocaban con 2.3 o tenían un rojo
propio del CI) mientras sus sesiones ya habían cerrado; Jürgen veía la build sin los cambios que creía dentro.

**How to apply:** en `/cerrar-total` en modo cola, `autoMergeRequest` no nulo ya no basta para cerrar: espera
`state: MERGED` (con un Monitor, no sondeos a mano) y vuelve a traer 2.3 si queda en DIRTY.
Relacionado: [[desatascar-prs-en-serie-saca-el-indice]], [[autonomo-hasta-el-final]].
