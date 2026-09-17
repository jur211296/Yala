---
name: sesion-anterior-tras-empezar-de-cero
description: PR #190 (2026-09-17) — «Activar la nube» ya no usa la sesión de la persona anterior en un teléfono sellado; en qa por pasos en iPhone; la reinstalación sin sello espera una decisión de Jürgen con cuatro opciones
metadata:
  type: project
---

«Activar la nube» se para con «Esta cuenta puede ser de otra persona» en un teléfono que pasó por «Empezar desde cero», si
la sesión no la abrió el intento y no hay cuenta asociada. Ticket `fresh-start-keeps-a-groups-session-that-migrate-promotes`,
en `qa`.

**Why:** Jürgen decidió la noche del 16-sep «no promover una sesión preexistente; pedir que elija o bloquear», y aplazó
cerrar la sesión en «Empezar desde cero» a una medición del cursor de Grupos. Elegí bloquear (D1) y limitarlo a teléfonos
sellados (D2); las dos están en el PR como lo más discutible.

**How to apply:**

- Lo que espera es el QA en iPhone del ticket: 13 pasos, montaje por reinstalación, SQL de staging. El paso 7 dice si el
  teléfono quedó sellado. Si no quedó, es el caso del ticket hermano, no un fallo del arreglo.
- **`previous-person-cloud-session-survives-fresh-start-and-reinstall` (high) espera decisión**, con cuatro opciones:
  cerrar la sesión en el relevo, purgarla en el primer arranque tras instalar, las dos, o preguntar. Tras reinstalar no
  queda sello y el registrador asocia la sesión anterior (`true`), así que ninguna regla de la puerta lo ve. No lo
  reabras parcheando otra puerta: la raíz es la sesión.
- Si alguien propone «quitar el sello de la regla» para no molestar a quien empieza de cero en su propio iPhone: eso
  reabre el bug; su coste está aceptado en D1.
- Relacionado: [[migrar-a-la-nube-no-adopta]], [[un-registro-no-prueba-la-eleccion]].
