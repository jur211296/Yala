---
name: tope-90s-no-cierra-con-import-bajando
description: PR #203 (2026-09-21) — el tope del restore ya no apaga la ventana de sesión con el import vivo; en qa con guion de 7 pasos y un residual con ticket propio
metadata:
  type: project
---

**PR #203, mergeado a `2.1` el 2026-09-21.** El tope de 90 s de «Restaurar desde iCloud» ya no cierra la
ventana de sesión cuando el import de CloudKit sigue trayendo filas, así que el dueño legítimo deja de
encontrarse un «estos datos son de otra persona» sobre los suyos entrando. Ticket en `tickets/qa/` con
**guion de siete pasos para iPhone**: no se monta en simulador — hace falta un histórico que CloudKit
tarde más de 90 s en bajar, en Production.

**Why:** cierra el residual medium de #200 por el eje del DESENLACE; #199/#200/#201 cerraron la misma
familia por el abandono y la cancelación.

**How to apply:** si vuelve el tema, el criterio vive en
`ICloudRestoreInProgressLogic.closesTheSessionWindow` (dos términos crudos, **no** el desenlace del
copy) y quien suelta la titularidad es `WelcomeRestoreView.onDisappear`, no la pantalla de progreso.
Abierto y medido: `leaving-and-reentering-restore-renews-the-hard-cap` (backlog) — salir de Restaurar y
volver renueva el tope duro, porque el testigo del import es un latch monótono del proceso. No es
regresión y el tercer criterio de #203 no lo nombraba.

La review de tres lentes cazó **tres defectos míos**, dos de ellos el bug sin arreglar: ver
[[feedback_dos_derivados_del_mismo_enum_no_son_independientes]],
[[feedback_al_quitar_un_apagado_incondicional_busca_quien_lo_usaba]] y
[[feedback_el_scan_de_un_modifier_no_ancla_a_que_vista_cuelga]].
