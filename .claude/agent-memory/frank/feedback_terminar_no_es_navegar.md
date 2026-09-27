---
name: terminar-no-es-navegar
description: «Un borrado consumado termina su trabajo» cubre lo DURABLE; la navegación tras una .task cancelada sale en nombre de una pantalla ya desmontada
metadata:
  type: feedback
---

Al quitar un `guard !Task.isCancelled` tras un efecto consumado, **separo lo durable (desarmes, preferencias,
testigos) de la navegación (`onProceed`, portales)**. Lo durable corre siempre; la navegación solo con la vista montada.

**Why:** el 2026-09-27 (#276) copié el molde del gemelo `wipeDevice` —«un borrado consumado termina su trabajo»— y
metí `onProceed()` en el «trabajo». La lente de montajes midió que una `.task(id:)` cancelada ya está DESMONTADA (en
`.wiping` no hay otra forma de cancelarla) y que una invitación de grupo que sustituye el step lo provoca: el
`onProceed` relanzaba o bajaba el cover encima de la invitación. Y la premisa del ticket («spinner eterno») era falsa
por lo mismo: no había pantalla colgada, había estado durable sin aplicar.

**How to apply:** ante un «termina aunque se cancele», pregunta primero QUÉ cancela esa tarea. Si solo es el
desmontaje, la cancelación significa «ya no hay pantalla», y el cierre del gesto se parte en dos. El gemelo que heredó
el molde entero queda en el ticket `private-gate-device-wipe-navigates-after-its-gate-unmounted`. Relacionado:
[[feedback_mi_fix_hereda_la_forma_del_bug]], [[feedback_el_molde_no_traslada_sus_precondiciones]].
