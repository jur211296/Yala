---
name: feedback-gateway-medido-va-a-produccion
description: Un arreglo del gateway que no cambia la respuesta y está medido, Jürgen lo quiere en producción desplegado por la sesión, no aparcado para él
metadata:
  type: feedback
---

El 2026-11-14 le ofrecí «staging yo, producción tú» para el gateway en paralelo (55 s → 16 s al entrar con la cuenta) y eligió
«staging y producción» por la sesión.

**Why:** el cambio era de rendimiento, con la misma respuesta, tests y mutante; aparcarlo dejaba a los usuarios esperando sin
motivo.

**How to apply:** con un cambio así, pregunta igual (es acceso a producción) pero ofrece desplegar los dos entornos; y despliega
sobre lo que YA corre en cada uno, no desde la rama: [[reference-desplegar-el-gateway-desde-la-mini]].
