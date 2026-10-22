---
name: el-tope-del-test-de-cancelacion-es-propio
description: Un test de cancelación no puede apoyarse en el tope del SUT — el mutante que deja la espera sin resolver lo hace COLGAR, no fallar
metadata:
  type: feedback
---

Un test que prueba «cancelar corta la espera» **lleva tope PROPIO**, no el `timeout:` del SUT.

**Why:** el 2026-09-21 escribí los cuatro casos de `forceFetchAndWait` apoyándome en que, si el arreglo
regresaba, la espera se resolvería por su propio tope y el caso fallaría por duración. Razoné bien el
caso feliz y mal el que importa: el mutante que rompe la mitad que cobra el valor pendiente deja la caja
resuelta **con la continuation dentro**, así que ni el tope ni la notificación vuelven a tocarla — la
espera no termina **nunca** y el test se suspende para siempre. Lo destapó el propio mutante, no el
razonamiento. Y era literalmente el AC nº4 del ticket que estaba implementando («un test que CUELGUE en
vez de fallar es un rojo mal leído»), incumplido por mí en el mismo commit que lo citaba.

**How to apply:** cuando el SUT sea una espera y el escenario sea cancelarla o abortarla, el tope va
FUERA: la espera corre en un `Task` suelto que deja su resultado en una caja actor-aislada, y el caso
sondea esa caja con su propio reloj. Sin valor al tope ⇒ `#expect` falla. Con Swift Testing, `.timeLimit`
en la `@Suite` cubre lo mismo con una línea cuando el caso hace `await withCheckedContinuation` directo —
y ahí es donde suele vivir el modo de fallo, así que no basta con ponérselo al consumidor.

Corolario que se paga solo: **prueba el mutante ANTES de dar el test por bueno**. El razonamiento sobre
«qué pasa si esto regresa» acierta el caso obvio y falla el peor.

Relacionado: [[el-tramo-sin-acotar-lo-cumple-el-vecino]], [[el-mutante-que-sobrevive-puede-sobrar]].
