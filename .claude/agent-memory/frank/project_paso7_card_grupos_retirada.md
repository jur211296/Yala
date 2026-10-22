---
name: paso7-card-grupos-retirada
description: Paso 7 del rediseño (PR #136) — la card «Grupos» del propósito y la puerta B enteras fuera; «Vengo por un grupo» es la ÚNICA entrada a la rama del organizador, y una red nueva lo fija (saltará a propósito si el paso 10 añade otra).
metadata:
  type: project
---

**El paso 7 del rediseño de sesiones está en el PR #136 (2026-09-10)**: el onboarding personal ofrece dos
propósitos y a solo-grupos solo se entra por «Vengo por un grupo». El ticket se decía «pequeño», y no lo
era: la card cedía a la MISMA cadena de alta que el Welcome (la «puerta B»), así que borrar el caso sin
ramas muertas se llevó el payload en memoria, `Entry.onboardingCard` y la divisa explícita del alta.

**Why:** la decisión de Jürgen era «borrar el caso del enum del todo, no dejar ramas muertas ni un caso
deprecated». `Entry.onboardingCard` habría sido exactamente ese caso deprecated.

**How to apply:**

- **`GroupsGateWiringTests.organizerBranchHasOneEntry` exige que `groupsOrganizerFlowActive = true`
  aparezca en UN solo sitio** (`startGroupsOrganizerBranch`). Si el paso 10 (asociar grupos desde la
  pestaña, [I] → [G]) reutiliza esta cadena, ese test se pondrá rojo **a propósito**: es una entrada nueva
  que el ADR sí autoriza. Hay que ampliarlo conscientemente, no «arreglarlo».
- Sin device-QA: el ticket fue directo a `done`.
- Quedaron en ticket, no olvidados: `flows-atlas-predates-session-redesign` (el Atlas de flujos sigue
  enseñando la card; espera una decisión de Jürgen) y, en el ticket 12, el guard M1 de
  `advanceGroupsOrganizerFlow`, que ya solo es defensa en profundidad.
- La review adversarial (una lente) no encontró nada roto en la puerta A y sí siete defectos del cambio.
  La lección de método está en [[la-asercion-que-no-puede-fallar]] (octavo eslabón: el dominio que
  encoge).

Relacionado: [[rediseno-sesiones-dos-ejes]].
