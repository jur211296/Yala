---
name: eje1-marca-sesion-privada
description: PR #150 (paso 12, PR-A) — el eje 1 ya tiene fuente propia; eran 9 constructores y no 6, el barrido de M1 es el PR-B, y el device-QA NO es simulable
metadata:
  type: project
---

**El paso 12 del rediseño de sesiones sale partido en dos, y el PR-A (#150, 2026-09-12) es el que lo
desbloquea:** `PrivateSessionMark` le da fuente propia al eje 1 («¿hay sesión privada en este
teléfono?»), que hasta ahora se derivaba del flag que el propio ticket borra.

**Why:** sin esto el paso 12 no era ejecutable. Nueve decisiones de producto —qué se borra al cerrar
sesión, si «Vaciar datos» avisa a los demás dispositivos del Apple ID, qué dice «Tu cuenta de Yala»,
si al eliminar la cuenta de grupos sobrevive lo personal— colgaban de `!isGroupInviteMode`.

**How to apply:**

- **El eje eran NUEVE constructores, no los 6 del encargo.** Los otros tres son las funciones de
  `DestructiveScopeLogic` que recibían el mismo eje bajo el nombre viejo (`wipeOperation`,
  `wipeSignalsAppleIDDevices`, `wipeLanding`). Jürgen aprobó incluirlas el 12-sep: el criterio fue
  que dejarlas partía el eje en dos nombres justo antes del barrido.
- **Lo que el PR-B hereda, ya medido — no lo redescubras:** `CloudIdentityRoutingLogic.deviceState`
  (`:257-265`) es una SEGUNDA fuente del mismo eje, derivada de `onboardingMode` y cableada en
  `ContentView`; `ProfileView.isExportEnabled` se queda en el flag a propósito (su eje es «qué
  exportar», no «hay vida personal»); y el flag y la marca DIVERGEN en el vaciado remoto, que se
  cierra solo cuando el flag muera.
- **El device-QA NO es simulable y es de Jürgen:** el simulador no tiene sesión de nube, y las dos
  celdas que importan —cerrar sesión en «equipo» (privada + grupos) y eliminar la cuenta de grupos
  sin sesión privada— piden dos dispositivos del mismo Apple ID.
- **Dos decisiones suyas del 12-sep que mandan sobre el ticket escrito:** la marca es POSITIVA con
  backfill de un arranque (un gate derivado de una ausencia falla abierto), y es estrictamente LOCAL
  — no la escribe el merge del iCloud-KV, aunque su semilla legacy sí pueda venir de ahí porque el
  parque no tiene otra fuente.

**Lo que la review adversarial cazó, y que no está en git porque nunca llegó a commit:** seis
defectos míos, de los cuales los dos caros fueron el prefijo de la clave envenenando el simulador
([[feedback_el_prefijo_que_elegi_tiene_dos_efectos]]) y el backfill resucitando la marca que el
cierre acababa de borrar ([[feedback_el_default_seguro_no_es_el_mismo_para_todos]]).

Relacionado: [[project_paso12_dominio_preferencias]] (el tercio mecánico, PR #149) ·
[[project_rediseno_sesiones_dos_ejes]]
