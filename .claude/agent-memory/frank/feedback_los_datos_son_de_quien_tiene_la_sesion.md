---
name: los-datos-son-de-quien-tiene-la-sesion
description: Apagar una defensa porque «los datos ya son de su dueño» exige que el dueño esté delante — con la sesión caída, el corpus es de nadie y entra otro
metadata:
  type: feedback
---

Si abro una puerta con el argumento «lo que hay en el store es de la cuenta X, no hay a quién proteger», el término
tiene que exigir que **X esté presente** (sesión viva), no solo que el modo diga X.

**Why:** 2026-09-29, puerta del invitado. Metí `storageMode == .cloud` para que el corpus no la despertara. La lente de
datos cruzados midió que con la sesión caducada la invitación pedía entrar, el alta de grupos no pasa por el guard
cross-cuenta, y otra persona se unía sobre el corpus de la cuenta cerrada: sus gastos caían ahí y subían al volver la
dueña. Mis tests fingían el provider y no lo veían. Relacionado: [[review-adversarial-caza-lo-mio]],
[[el-predicado-que-amplio-cortocircuita]].

**How to apply:** al relajar una defensa por propiedad de los datos, pregunta «¿y si nadie tiene esa cuenta abierta?».
Y el test del caso negativo, con el provider de PRODUCCIÓN capturado antes de que el entorno lo sustituya: si no, un
mutante que quite la mitad nueva solo lo caza un scan.
