---
id: alternating-definitive-causes-never-reach-the-short-ceiling
status: backlog
priority: high
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-22
source: "review adversarial de `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (2026-09-22), lente de consumidores"
---

# Con dos motivos definitivos alternándose, la vuelta a iCloud espera tres días en vez de quince minutos

## El problema, en lenguaje de usuario

La vuelta a iCloud promete salir en **15 minutos** cuando el motivo es de los que no se arreglan esperando. Si
se dan **dos** de esos motivos a la vez y van turnándose, ese plazo **no vence nunca**: cada vez que el motivo
cambia, el reloj corto empieza de cero. La salida acaba llegando por el plazo largo, **72 horas**.

Ejemplo concreto: cuenta suspendida por impago (403) **más** un teléfono cuyo store falla a ratos. Cada pasada
alterna `accountUnavailable` y `localFailure`, el reloj corto se re-sella en cada observación, y la persona
espera tres días en la barra al 30 % en vez de los quince minutos que el techo corto le prometió.

## Por qué pasa (medido el 2026-09-22 en este árbol)

El reloj por CAUSA que introdujo `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` tiene la
regla «**causa distinta ⇒ lo acumulado del motivo anterior se tira**»
(`MigrationRunner.reversePreMountCauseClock`), y es la regla correcta para su problema: sin ella, un fallo de
una vez cobraba las horas que la espera llevaba por otra cosa.

Su efecto colateral está **admitido por escrito** en el docblock de la máquina
(`MigrationStateMachine.swift:750-756`): dos motivos alternándose reinician el corto para siempre. La regla de
área lo dice desde el otro lado —«sin el reloj de fase, dos motivos definitivos alternándose reinician el corto
en cada observación y la espera vuelve a no tener techo»—, o sea que lo que hoy responde a este caso es el
plazo LARGO, y eso es deliberado.

**Lo que cambió el 2026-09-22 es cuántas fases pueden caer ahí.** Hasta
`verify-reads-a-failed-local-fetch-as-an-empty-outbox`, `reverseDrainAll` tenía **un solo** blocker posible (el
403 del push, `MigrationWorkExecutor.swift:1046`); ahora tiene dos, porque el `fetch` del outbox que lanza sale
como `.blocked(.localFailure)`. `reverseVerify` ya tenía tres y por tanto ya era alcanzable ahí.

## Qué habría que decidir

1. **¿Es aceptable?** El argumento a favor de dejarlo: el reloj de FASE existe justo para que la espera tenga
   techo pase lo que pase, y 72 h es ese techo. El argumento en contra: el techo corto se creó porque 72 h
   delante de algo definitivo es demasiado, y este caso lo reintroduce por la puerta de al lado.
2. **Si se cierra, ¿cómo?** Un tercer reloj («tiempo parado bajo CUALQUIER motivo definitivo», que no se
   reinicia al cambiar de causa) parece lo mínimo, pero hay que comprobar que no reintroduce lo que el reloj
   por causa cerró: un `localFailure` de una vez tras horas de espera por RED no debe cobrar esas horas.
3. **¿Qué frecuencia real tiene?** Nadie lo ha medido. El canario `cloudReversePreMountWaiting` publica
   `<fase>|<tramo de fase>|<tramo de causa>|<causa>`, así que la flota podría contestarlo: un teléfono con el
   tramo de fase creciendo y el de causa siempre en `lt_15m` es exactamente este caso.

## Criterios de aceptación

- [ ] Decidido si se cierra o se acepta, con el porqué escrito.
- [ ] Si se cierra: dos motivos definitivos alternándose alcanzan una salida antes de las 72 h.
- [ ] Y un `localFailure` aislado tras horas de espera por red sigue SIN cobrar esas horas (el criterio del
      ticket que introdujo el reloj por causa).

## Relacionado

- `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` — el que introdujo el reloj por causa.
- `verify-reads-a-failed-local-fetch-as-an-empty-outbox` — el que hizo alcanzable el caso en la fase `drain`.
