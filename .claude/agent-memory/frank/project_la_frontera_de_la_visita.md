---
name: la-frontera-de-la-visita
description: La familia «visita / sesión secundaria (M1)» quedó SUPERADA el 2026-09-09 por el ADR de sesiones — sus 12 tickets están descartados; qué queda vivo y qué ratificación falta
metadata:
  type: project
---

**Estado al 2026-09-09: superada.** El ADR «Sesiones — dos ejes» retira la sesión de visita del
modelo: prestar el móvil con sesión privada activa deja de ser un caso (el dueño cierra sesión —lo
local se borra, iCloud queda—, la otra persona entra con su cuenta en la nube, y el dueño restaura).
Los 12 tickets de la familia (los `secondary-*`, `welcome-*-secondary/visit`, `widget-snapshot-visitor-*`,
`prefs-domain-per-secondary-session`, `welcome-copy-blames-owner`) están en `tickets/discarded/` con el
motivo en su línea `Why:`. Ver [[rediseno-sesiones-dos-ejes]].

**Why:** el modelo nuevo hace imposible la ventana que motivaba toda la familia —el Welcome visible
con el corpus del dueño vivo— porque la salida de la sesión privada pasa a borrar lo local.

**How to apply:**
- **No reabrir ninguno de los 12 por su cuenta.** Si Jürgen NO ratifica la retirada de M1, se
  reabren todos juntos con la ratificación como motivo — nunca uno suelto.
- El código de M1 (`SecondarySessionStore`, `SessionDefaults`, `YalaModel-Secondary`, seams uitest)
  sigue en el árbol hasta `shell-derives-from-two-session-axes`; al tocarlo, no arreglarlo: retirarlo.
- **Lo único que sobrevive de aquí es el patrón**: el guard que falta suele estar **medio puesto**
  (mitad iKV protegida, mitad `.standard` cruda). Sigue en `docs/aprendizajes-tecnicos.md` y vale
  para cualquier frontera, no solo la de la visita.
