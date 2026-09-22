---
id: restore-retry-reopens-the-session-window-every-90-seconds
status: backlog
priority: medium
area: "icloud, restore, sesiones"
created: 2026-09-21
source: "lente 2 de la review adversarial de `restore-session-window-has-no-reachable-ceiling`, 2026-09-21"
---

# «Volver a buscar» reabre la ventana de sesión cada 90 s, y es más barato que la puerta

## El problema, en lenguaje de usuario

No hay síntoma para el dueño legítimo. Quien tiene en la mano un teléfono con los datos de otra
persona puede mantener abierta la ventana que permite entrar en la cuenta sin aviso **con UN toque
cada minuto y medio**, sin pasar por ninguna puerta y sin que haga falta que baje nada.

## Medido (2026-09-21)

Es el camino más barato de los que quedan, y lo destapó la review del ticket del techo mientras medía
otro. La población es la que **no tiene ningún `.importEvent` en el proceso**: el teléfono cuyo corpus
ajeno ya se importó en un arranque anterior.

1. Entrar a Restaurar → `restoreStartedAt = T1`. `isRestoringNow` da `true` durante los **60 s de
   gracia** de `ICloudRestoreInProgressLogic` (sin actividad observada, la ventana vive hasta ahí).
2. La espera agota su tope de 90 s sin un solo evento.
3. `closesTheSessionWindow(settled: false, hasObservedImportActivity: false)` da `true` ⇒
   `noteRestoreFinished` apaga la ventana y suelta el dueño.
4. Un toque en «Reintentar» del estado terminal → `restoreStartedAt = T2 ≈ T1 + 91` ⇒ **otros 60 s de
   gracia**.

⇒ guard abierto ~60 s de cada ~91, indefinidamente, **un toque por vuelta**. Ni el aparcado de la
puerta de descarte interviene (el apagado del paso 3 lo consume) ni hace falta descarga viva.

**Esto no es una regresión: es el precio declarado de la gracia.** El apagado del paso 3 existe a
propósito —es la PRECISIÓN que cierra la ventana del usuario realmente nuevo antes de los 60 s— y el
estreno del paso 4 es lo único que hace útil la señal. Lo que nadie había medido es lo que cuesta
ponerlos en ciclo.

## Lo que haría falta

Las dos piezas están documentadas y ninguna es obviamente la que sobra:

- **La gracia de 60 s** existe porque al principio `hasObservedImportActivity` también es `false`:
  apagar ahí le devolvería el bloqueo al dueño legítimo que sí está restaurando y solo espera al
  primer evento. Acortarla muerde a esa población.
- **El estreno tras un final** es la puerta grande de la señal y tiene que seguir abierta.

Un camino posible, sin diseñar: que un estreno que sigue a un `noteRestoreFinished` **sin un solo
import observado** herede la gracia en vez de estrenarla —o sea, que la gracia se cuente una vez por
proceso y no una por entrada—. Hay que medir antes a quién deja fuera: el que enciende iCloud y
reintenta con razón entra por ahí.

## Criterios de aceptación

- [ ] El ciclo reintentar-reintentar deja de mantener el guard abierto de forma continua, **o** está
      escrito por qué se acepta.
- [ ] El dueño legítimo que reintenta con razón sigue teniendo su ventana completa.
- [ ] Un test que recorra el ciclo con el reloj, midiendo el veredicto del guard y no el campo.

## Relación con otros tickets

- `restore-session-window-has-no-reachable-ceiling` — de donde sale; cerró el ciclo de la puerta de
  descarte, que cuesta 3 toques y 600 s de espera. Éste cuesta 1 toque y 91 s.
- `leaving-and-reentering-restore-renews-the-hard-cap` — cerró el ciclo de salir-y-volver.
