---
name: poblacion-cero-del-eje-de-vaciado
description: "PR #166 — el hueco del eje de vaciado remoto en altas solo-grupos anteriores al 10-sep se cerró MIDIENDO población cero, no con código; qué lo reabriría y qué números quedan como referencia del parque"
metadata:
  type: project
---

**El último residual del eje de sesión quedó cerrado el 2026-09-14 (PR #166) sin tocar el predicado.**
El hueco es real —un alta solo-grupos anterior al 2026-09-10 no tiene `groupsOnlyNeutralMountKey`, el
backfill le escribe `hasPrivateSession = true` y ese teléfono obedecería la señal de vaciado remoto—,
pero no alcanza a nadie.

**Why:** Jürgen zanjó el fork del ticket en mitad de la sesión: «población cero, sin predicado nuevo en
el receptor ni señal inventada». Las alternativas derivaban el eje de una AUSENCIA, que falla ABIERTO.
Método y fuentes: [[la-poblacion-de-un-bug-se-mide-antes-de-arreglarlo]].

**Los números del parque, que sirven para otros tickets** (medidos el 2026-09-14 y con fecha de
caducidad propia — vuelve a medirlos, no los cites):

- App Store pública: **2.0.4**. Ni 2.0.5 ni 2.1 han salido de TestFlight.
- TestFlight: **3 testers** (2 instalados, 1 invitado sin instalar); uno concentra ~2470 sesiones.
- Telemetría de producción, 90 días: **5 altas personales**, 1 migración a la nube, **0 altas
  solo-grupos** (ni organizador ni invitación).
- Backend de Grupos en producción: **0 identidades**, 0 perfiles, 0 grupos, 0 miembros.
- Ningún build distribuido trae `PrivateSessionMark` compilado: build 13 = commit del 9-sep, el eje
  llegó el 12-sep.

**How to apply:**

- Si aparece un ticket que dice «esta población de usuarios está afectada», **empieza por los números
  de arriba re-medidos**: con un parque así, muchos residuales se cierran midiendo en vez de
  arreglándose. No al revés — no los uses para minimizar un bug que sí tiene camino en producción.
- **Qué reabre este cierre:** una tercera alta solo-grupos que no escriba el eje en el acto o no arme
  el mount neutro. Lo vigila
  `PrivateSessionMarkWiringTests.bothGroupsOnlySignUpsWriteTheAxisAndArmTheNeutralMount`, con censo de
  armadores (3). Si ese test se pone rojo, el ticket vuelve a estar vivo.
- El PR arregló además un **rojo heredado de `2.1`**: el censo de lecturas de `confirmedPrivateSession`
  decía 6 y eran 7 desde el PR #164. El patrón por si vuelve: cada vez que este eje gobierna algo
  asíncrono se lee en los **dos** extremos de la espera, así que un consumidor nuevo casi siempre
  aporta dos lecturas, no una.
- **El árbol principal `~/Yala` quedó 12 commits por detrás de `origin/2.1`** al cerrar: tenía cambios
  sin commitear de otra sesión de Frank en `.claude/agent-memory/`, así que el `pull --ff-only` abortó
  y no se tocó. El ESTADO se escribió desde el worktree empujando directo a `2.1` (permitido: diff
  entero en `docs/`).
