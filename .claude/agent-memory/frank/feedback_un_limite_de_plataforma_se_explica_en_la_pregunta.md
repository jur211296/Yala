---
name: un-limite-de-plataforma-se-explica-en-la-pregunta
description: Si una opción de producto se apoya en un límite de plataforma, la pregunta explica el límite y ofrece la vía que lo levanta; el 16-sep Jürgen preguntó por qué Apple solo usa el Apple ID del teléfono y eligió levantarlo
metadata:
  type: feedback
---

**Cuando una recomendación acepta un límite de plataforma, dilo en la propia pregunta: qué impone la plataforma,
qué costaría levantarlo y cuál es la vía.** No lo presentes como un hecho del escenario.

**Why:** en `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (2026-09-16) propuse avisar de que «Usar
otra cuenta» con Apple vuelve a la misma cuenta, dando por hecho que Sign in with Apple nativo solo firma con el
Apple ID del dispositivo. Jürgen no eligió ninguna opción: preguntó por qué no se permite otro. Tras explicárselo
eligió «permitir otro Apple ID» con el inicio de sesión web, en ticket aparte, y la nota como puente. Encaja con
«implementar la versión robusta; residuales solo por límite de plataforma o ratificación explícita»: un límite de
plataforma que tiene salida no cuenta como límite.

**How to apply:** en la opción recomendada que dependa del límite, añade la alternativa que lo levanta con su coste
(aquí: Services ID, secreto JWT que caduca cada seis meses, la prueba del faro que se cae). Así la ronda se contesta
de una vez. Relacionado: [[cuando-la-app-pregunta-al-usuario]].
