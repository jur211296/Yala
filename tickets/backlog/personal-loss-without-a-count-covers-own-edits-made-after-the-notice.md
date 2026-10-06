---
id: personal-loss-without-a-count-covers-own-edits-made-after-the-notice
status: backlog
priority: low
area: "nube, sync, datos"
created: 2026-10-05
updated: 2026-10-05
source: "medición del encargo `stuck-groups-loss-without-a-count-covers-own-edits-made-after-the-notice` (2026-10-05): el gemelo personal del mismo hueco"
---

# En la nube, aceptar perder tus cambios «sin cifra» se lleva también lo que apuntes después

## El problema, en lenguaje de usuario

Rarísimo: al cerrar sesión en la nube sin App Attest (o con la sesión caducada y probada), el teléfono no consigue leer qué
cambios tuyos quedaron sin preparar justo cuando enseña el aviso. El aviso «Exportar / Cerrar sesión y perderlos» sale sin
cifra. Si la persona acepta, y antes de que el cierre termine apunta otro movimiento que tampoco se prepara, ese movimiento
se va con el cierre sin que ningún aviso lo haya contado.

## Por qué pasa (medido leyendo el código el 2026-10-05)

- `CloudMigrationController.pendingPersonalLoss()` lee el History con `uncapturedPersonalChangeKeys()`, que da `nil` si no
  se pudo leer o no hay runtime.
- `CloudSignOutFlowLogic.personalUploadBlockDecision` devuelve `.offerLoss` sin mirar esa mitad, así que la oferta sale con
  `PersonalLoss(uncaptured: nil)` (cifra `Int.max`).
- Lo aceptado (`PersonalLossAcceptance(offer:)`) guarda `uncaptured: nil`, y `coversUncaptured` →
  `CloudSignOutFlowLogic.lossHalfCovers(accepted: nil, now:)` cubre cualquier cosa: la continuación del paso 1 y el recuento
  pegado al borrado (`residualUncapturedAllowsSignOut`) dejan pasar cambios nuevos.

Es el mismo hueco que se cerró para Grupos en `stuck-groups-loss-without-a-count-covers-own-edits-made-after-the-notice`
(decisión A de Jürgen: sin poder contar, el atasco sin salida). Allí no se tocó la mitad personal porque el encargo era de
Grupos. Diferencia a pesar: en lo personal el History se lee siempre, no solo con la captura atascada, así que un `nil` puede
salir también con el drain sano.

## Propuestas (decide Jürgen)

- **A.** Lo de Grupos: con el History sin leer, sin salida (el aviso de la subida, o el del drain atascado si lo está), hasta
  poder contar. Y lo aceptado sin leer deja de cubrir cambios nuevos.
- **B.** Ofrecerla igual, pero que lo aceptado sin leer solo cubra «nada nuevo» (relectura buena antes del borrado).
- **C.** Dejarlo: hacen falta un fallo de lectura en la oferta y un cambio apuntado justo después.
