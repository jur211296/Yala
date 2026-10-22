---
name: el-tablero-antes-que-el-bug
description: Jürgen elige sanear el tablero antes que atacar un bug de producción, y quiere el bloque entero en un commit, no troceado
metadata:
  type: feedback
---

Ofrecí cuatro arranques —tres defectos vivos y «limpiar los ocho tickets fantasma»— y eligió
**la limpieza**, teniendo delante un bug de producción que bloquea al usuario. Después, con el
alcance ya crecido a 18 ficheros, le ofrecí trocearlo en cuatro y eligió **el plan entero, un
commit**.

**Why:** un backlog en el que no se puede confiar contamina toda decisión posterior — priorizar
sobre tickets que mienten es peor que no priorizar. Y cuando el cambio es solo documentación,
partirlo en commits pequeños no compra seguridad: compra ruido. Su elección se validó sola:
los ocho «fantasmas» resultaron ser siete vivos y cuatro defectos que no existían escritos en
ninguna parte.

**How to apply:** cuando el tablero y el código compitan por la misma sesión, ofrece el tablero
como opción real y no como trámite previo. Y en cambios de solo documentación, propón el bloque
completo por defecto; reserva el troceo para lo que toca código. Dos avisos que salieron de
esta sesión:

- **No cierres un ticket por lectura.** Un ticket en `tickets/qa/` espera *verificación*, no
  arreglo; código correcto no lo cierra. Antes de archivar nada, pon escépticos a demostrar
  que el defecto **sigue vivo**, con la carga de la prueba sobre el cierre.
- **Un residual que solo vive dentro de un ticket que archivas, se pierde.** Ábrele ticket
  propio *antes* de mover el padre, en el mismo commit.

Relacionado: [[decisiones-que-esperan-a-jurgen]], [[creo-que-no-es-aprobacion]].

## Corolario (2026-09-04): acumula trabajo y prueba en bloque, no sobre la marcha

Le ofrecí preparar la tanda de QA —dos tickets nuevos sin montaje en el guion— en vez de abrir otro
ticket, con el argumento de que desbloquearía SU trabajo. Respondió: **«No podré hacer QA aún,
prefiero avanzar tickets y después probar todo».**

**Why:** su disponibilidad para el device-QA no va al ritmo de la sesión. Dos teléfonos y una tanda
son un bloque de tiempo suyo que no se parte en trozos, así que dejarle cosas en `qa/` no le
desbloquea nada hoy — sólo le llena la cola. Lo que sí le sirve es que la cola crezca con trabajo
terminado y verificable.

**How to apply:**
- **No frenes por acumulación.** Que `qa/` crezca no es deuda que haya que pagar antes de seguir; es
  el estado normal entre sus tandas. Ofrecer «preparo la tanda» como alternativa a avanzar es
  ofrecerle trabajo que hoy no puede usar.
- **Sí sigue valiendo dejar cada ticket listo para probarse**: montaje escrito, qué mirar, qué sería
  un fallo. Lo que no vale es parar el avance para organizarlo.
- Y como el device-QA llega tarde, **el peso de la verificación cae en los tests**: cuando el ticket
  admita «device o repro», construye el repro. Un ticket que sólo se puede cerrar con dos teléfonos
  se queda parado semanas.
