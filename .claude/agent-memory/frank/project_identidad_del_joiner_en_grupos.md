---
name: identidad-del-joiner-en-grupos
description: La tanda de «quién soy yo» en Grupos — qué se cerró el 4 y el 5-sep, qué falta (device-QA de dos teléfonos) y qué NO hay que volver a proponer (el segundo call-site de refreshCurrentUserFlags)
metadata:
  type: project
---

**La familia de bugs de «al recién llegado a un grupo no se le reconoce» está cerrada en código; lo
que falta es device-QA de dos teléfonos.** Tres tickets, tres noches:

- `5ca4dd47` (4-sep) — cinco resolvedores, incluida la pantalla de detalle que decía «No participaste».
- PR #64 (5-sep) — los catorce consumidores restantes. El del dinero era el bridge.
- Sigue abierto `groups-equal-split-shows-not-participating-on-peer`, que es el **mismo** montaje de QA.

**Why:** todo colgaba de que `SplitMember.isCurrentUser` es device-local y el pull nunca lo enciende
— solo `refreshCurrentUserFlags`, y solo en el arranque. Por eso el force-quit «arreglaba» el bug, y
por eso los síntomas parecían inconexos (saldo vacío, «Pagado por» en blanco, avisos que no llegan):
eran rutas distintas colgando de la misma identidad.

**How to apply:**

- **No vuelvas a proponer el segundo call-site de `refreshCurrentUserFlags`.** Es la vía de una línea
  y la review adversarial la marcó como el vector de mayor daño de la tanda: device-wide, `save()`
  dentro del camino de sync, y arrastra un backfill que adjudica identidad por coincidencia de
  `displayName` — dos personas con el mismo nombre visible y le das el grupo a la equivocada. Ya se
  descartó con razones; reabrirlo es rehacer la discusión.
- **El montaje de QA es el mismo para los tres, y la precondición es frágil:** B se une por enlace y
  **NO relanza la app** antes de que A cree el gasto. Si B relanza, el flag se enciende y no
  reproduce nada. Cuando Jürgen haga esa sesión de dos teléfonos, cubre los tres de una.
- **Lo que quedó fuera a propósito** está en `joiner-flag-residuals-cosmetic-and-service-guard`
  (`low`): badges «(tú)» y la red de servidor `cannotRemoveSelf`. Al alinearlos, **usar la unión
  `flag || resuelto`, no la sustitución** — una zona migrada puede tener dos filas del mismo humano.

**Medido el 2026-09-05, contra el servidor, y vale para futuras dudas de este canal:** un miembro
`pendingApproval` **sí** lee su propia fila (`is_group_member` incluye ese estado) y `member_key`
viaja siempre por ser el `sync_id_source` de `group_members`. O sea: la identidad del recién llegado
está disponible en el cliente desde el primer pull. Relacionado:
[[decisiones-que-esperan-a-jurgen]], [[mis-mediciones-fallan-por-el-filtro]].
