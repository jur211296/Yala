---
name: fundir-una-entrada-nueva-hereda-sus-excepciones
description: Meter una señal nueva con un `||` en el parámetro de una puerta le regala los atajos de la vieja; la marca del claim se saltaba la red de «Empezar desde cero» igual que el sello.
metadata:
  type: feedback
---

Cuando una señal nueva debe relajar una puerta «igual que» otra que ya existe, **no la fundas en el parámetro de la
vieja** (`claimed = sello || marca`). Ese parámetro no solo abre: suele venir con atajos que la vieja se ganó y la nueva
no, y el `||` se los hereda sin que nadie lo decida.

**Why:** el 2026-09-22 añadí la marca del claim sin respuesta a `claimedForMigrationHere`, en el controller. En la puerta
(`StorageMigrationIdentityGateLogic.check`) esa rama va ANTES del chequeo de «Empezar desde cero»: el sello se salta esa
red a sabiendas (residual escrito). Con el `||`, la marca también se la saltaba, y con la sesión de la persona anterior
el reclaim del mismo líder habría subido las finanzas de la nueva a su cuenta. Lo cazaron dos lentes por separado. El
arreglo fue un parámetro PROPIO en la lógica pura (`hasUnansweredMigrationClaim`), con su tabla de tests y sin el atajo.

**How to apply:** si la señal nueva «vale como» otra, pásala aparte hasta la lógica pura y decide allí, caso por caso,
qué excepciones hereda. Y mira dónde está la rama de la vieja respecto a las demás redes: si va antes, todo lo que entre
por ella se las salta. Relacionado: [[feedback_un_verbo_nuevo_hereda_las_prohibiciones_del_viejo]] (el mismo error, visto
desde los tests) y [[feedback_el_molde_no_traslada_sus_precondiciones]].
