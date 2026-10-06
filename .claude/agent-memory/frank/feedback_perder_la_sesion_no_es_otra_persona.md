---
name: perder-la-sesion-no-es-otra-persona
description: Una marca de «misma persona» atada a la sesión se invalida por la PRESENCIA de otra cuenta, no por la ausencia de la propia
metadata:
  type: feedback
---

Al atar una marca de «esto es de quien está delante» a una sesión, **solo la invalida OTRA cuenta abierta**; quedarse
sin sesión no prueba que haya otra persona.

**Why:** el 2026-10-06 (`groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start`) até la marca de los
grupos que conserva el aviso tardío a «la misma sesión o ninguna, igual que al escribirla». Dos lentes de la review
midieron que el guard cross-cuenta del Welcome hace `signOut()` de la sesión que la propia persona acaba de abrir, y
una sesión caducada también se va: la marca caía y volvía el handover que existía para evitar. Mi docblock decía
«equivocarse hacia "no vale" es barato: preguntar de más»; lo que se pregunta ahí es un borrado con sello irreversible.

**How to apply:** antes de elegir la condición de validez, enumera quién retira la sesión además del cambio de persona
(guards que cierran, caducidad, SDK). Si la ausencia tiene causas legítimas de la misma persona, valida por
«ninguna u otra igual a la mía». Y cuando escribas «el lado barato», mira QUÉ ofrece ese lado. Relacionado:
[[los-datos-son-de-quien-tiene-la-sesion]] (la cara opuesta: abrir una puerta exige al dueño presente),
[[una-marca-que-abre-una-entrada-se-ata-a-quien-la-gano]].
