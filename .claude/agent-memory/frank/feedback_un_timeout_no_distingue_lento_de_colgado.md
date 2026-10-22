---
name: un-timeout-no-distingue-lento-de-colgado
description: Duraciones clavadas en el límite del timeout parecen la firma de un cuelgue y son solo el timeout cortando — súbelo antes de escribir la hipótesis. Refutó un ticket entero el 2026-09-10.
metadata:
  type: feedback
---

**Un test que falla por timeout con duraciones clavadas en el límite (5010 / 5012 / 5010 ms) NO prueba
que se cuelgue. Prueba que tarda más que el límite. Súbelo y vuelve a medir ANTES de escribir la
hipótesis.**

**Why:** el ticket `account-goldens-freeze-read-test-times-out` razonaba —bien— que «el número clavado en
el límite dice que el test no tarda: se cuelga; un test lento daría duraciones dispersas», y de ahí
concluía «subir el timeout NO es el arreglo». Sobre esa conclusión llevaba una semana sin tocarse. El
2026-09-10 lo corrí con `--testTimeout=60000` y **pasó en verde en 9,3 s**: no había ningún `await`
muerto, iba un 86 % por encima de su presupuesto. La agrupación en 5010-5012 ms es el timeout disparando
con precisión — **cualquier** test que tarde más da ese mismo número.

**How to apply:**

- Ante un rojo por timeout, la primera medición cuesta un flag: `--testTimeout` (vitest) o el parámetro
  `{ timeout: }` del `it`. Si pasa, es lento; si sigue rojo con 10× el presupuesto, ahí sí sospecha.
- La agrupación estrecha de duraciones **sí** es señal de «presupuesto agotándose siempre en el mismo
  punto» y no de una race — eso era correcto en ese ticket. Lo que no se sigue es que el presupuesto se
  agote por un cuelgue en vez de por lentitud.
- **Subir el timeout puede ser el arreglo legítimo**, y no hacerlo tiene un coste que se olvida: mientras
  el test está rojo, **el invariante que protege no lo comprueba nadie**. Aquí era «el freeze no bloquea
  las lecturas», del que depende que la reversa pueda releer.
- Y separa las dos preguntas: «¿sube el timeout?» (decisión de Jürgen) y «¿por qué tarda 9 s?» (el trabajo
  real; aquí apunta al corpus de staging que solo crece, `corpus-de-test-de-staging-crece-sin-limite`).

Relacionado: [[dos-corridas-un-simulador]] (el otro rojo que no es del test: ahí la firma es
`Failing tests:` **sin** línea de fallo) · [[rojo-conocido-no-exime-de-bisecar]] ·
[[la-premisa-del-encargo-tambien-se-mide]]
