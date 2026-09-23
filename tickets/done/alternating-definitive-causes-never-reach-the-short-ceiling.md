---
id: alternating-definitive-causes-never-reach-the-short-ceiling
status: done
priority: high
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-23
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

- [x] Decidido si se cierra o se acepta, con el porqué escrito.
- [x] Si se cierra: dos motivos definitivos alternándose alcanzan una salida antes de las 72 h.
- [x] Y un `localFailure` aislado tras horas de espera por red sigue SIN cobrar esas horas (el criterio del
      ticket que introdujo el reloj por causa).

## Relacionado

- `reverse-pre-mount-ceiling-charges-a-stall-to-whoever-stops-it-last` — el que introdujo el reloj por causa.
- `verify-reads-a-failed-local-fetch-as-an-empty-outbox` — el que hizo alcanzable el caso en la fase `drain`.

## Resolución (2026-09-23)

**Decidido: se cierra.** El techo corto existe porque 72 h delante de algo que esperar no arregla es demasiado, y este
caso las reintroducía por la puerta de al lado. Decisión de Frank en el encargo, sin preguntar (opción 2).

**Qué cambia para la persona.** Si al volver a iCloud la cuenta está suspendida y además el teléfono falla a ratos al
leer su base de datos, la vuelta sale a los 15 minutos acumulados, no a los tres días. Sale con el texto genérico
(«no llegó a completarse»), porque ninguno de los dos motivos llegó solo al plazo. Con un solo motivo sostenido todo
queda igual: a los 15 minutos, con su texto.

**Cómo.** Un tercer reloj en el journal, el de «cualquier motivo definitivo» (`reversePreMountDefinitiveAt` +
`reversePreMountDefinitiveAccruedSeconds`, schema 12). Es `CauseStallClock` con una sola clave para todo lo
definitivo: suma entre motivos distintos, se PAUSA con una observación sin motivo y se reinicia con el cambio de fase.
La máquina decide el corto contra él (el evento pasa a traer `definitiveStalledSeconds`). El reloj por causa se queda,
pero solo para elegir el copy: el texto específico sale si UN motivo solo llegó a los 900 s.

**Por qué no reintroduce lo que el reloj por causa cerró.** La red no trae motivo, así que pausa el reloj nuevo igual
que pausaba el de causa: las horas de red no las acumula nadie, y un `localFailure` aislado tras ellas empieza en
cero. Lo que sí suma es el tiempo bajo OTRO motivo definitivo, y es a propósito: los dos eran esperas que esperar no
arregla. Un hueco sin observaciones entre dos motivos definitivos cuenta, igual que ya contaba entre dos
observaciones del mismo motivo.

**El canario no cambia** (`cloudReversePreMountWaiting` sigue publicando el tramo de causa): es el que deja ver en la
flota la alternancia que preguntaba el punto 3.

**Dos consecuencias decididas, que la review sacó a la luz:**

- Un hueco SIN observaciones entre dos motivos distintos (un 403, la app cerrada veinte minutos, un fallo local al
  volver) cuenta y puede sacar de la vuelta en esa pasada. Es la regla que el reloj por causa ya aplicaba a un solo
  motivo. Fijado con `reversePreMountDefinitiveClock_anUnobservedGapBetweenTwoCauses_counts`.
- `accountUnavailable` y `refused` turnándose salen con el texto genérico aunque los dos digan lo mismo: la clave del
  reloj de causa es el `rawValue`. No miente; cambiarlo le cambiaría el significado al tramo del canario.

Y una fila de un build anterior (v11) parada a mitad de fase sale, como mucho, un plazo corto después de lo que habría
salido: trae el reloj de causa lleno y el nuevo vacío. Pasa una vez, al actualizar.

**Sin device-QA:** el escenario (dos motivos definitivos turnándose en la misma fase) no se puede montar en un iPhone
real a voluntad, y todo el cambio es lógica del runner y la máquina, cubierta por tests unitarios contra el store.
Por eso va a `done` y no a `qa`.

**Verificación:** 11 mutantes, todos muertos. Review de tres lentes (semántica del reloj, consumidores, regla y
tests): cazó el breadcrumb sin el reloj que decide, dos aserciones que no podían fallar, invariantes escritos sin la
excepción de las filas viejas, el round-trip del journal sin los campos nuevos y una memoria que invitaba a deshacer
el cambio. Todo arreglado.

**Tests:** `reversePreMountDefinitiveClock_alternatingCauses_leaveAtTheShortCeiling` (drenaje, 403 y fallo local
turnándose cada 30 s: 899 s holdea, 900 s sale con `preMountStalled`) y
`reversePreMountDefinitiveClock_networkHoursBetweenTwoCauses_areNotCharged` (10 min de 403, 3 h de red, y el fallo
local sale a los 5 min, no en el acto ni a los 15). Cuatro tests viejos adaptados; el que fijaba la salida a las
72 h con causas alternándose se sustituye por el primero.

**Encontrado por el camino:** el mismo agujero está en la subida del snapshot →
`snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling`. En la ida sin cifra se midió y no es
alcanzable de forma sostenida.
