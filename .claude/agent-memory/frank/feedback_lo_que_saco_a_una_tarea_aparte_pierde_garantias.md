---
name: lo-que-saco-a-una-tarea-aparte-pierde-garantias
description: Mover un `await` a un `Task {}` propio para poder cancelarlo por separado le quita las garantías del contenedor —cancelación heredada e identidad del handle— y las dos se pagan lejos del diff.
metadata:
  type: feedback
---

**Cuando saco una espera de su contenedor a una tarea propia, enumero qué le daba el contenedor
GRATIS y qué de eso deja de tener.** Un `Task {}` no estructurado **no hereda la cancelación** de
quien lo crea, y un handle guardado en un campo **no tiene identidad**: el que muere tarde pisa o
borra el del que nació detrás.

**Why:** el 2026-09-16, despertando el loop de Grupos
(`groups-loop-in-backoff-ignores-the-return-to-foreground`), saqué el `await sleeper(delay)` del
`loopTask` a un `napTask` propio para poder cortarlo al volver a primer plano sin matar el loop. El
cambio parecía aditivo. Se llevó por delante dos cosas que ya funcionaban:

1. **La cancelación.** `stopLoop()` —que llaman los cinco caminos de cierre de sesión— dejaba de
   cortar el sueño: el loop no miraba su propia cancelación hasta después de dormir, o sea hasta 5
   minutos. Lo cierra `withTaskCancellationHandler { await nap.value } onCancel: { nap.cancel() }`.
2. **La identidad del handle.** `stopLoop()` despublica el loop en el acto, pero el viejo sigue
   dentro de su request —lo que tarde la red— y al salir corre su `defer`. Entre medias nace otro
   loop, y el `defer` del viejo le borraba el handle: dos loops vivos, un `stopLoop` posterior
   cancelando `nil`, y un wake que dejaba su rastro en el log **sin cortar ningún sueño**. O sea, el
   bug que el ticket venía a arreglar, resucitado e invisible.

El segundo estaba también en el `defer { loopTask = nil }` **anterior a mi cambio**: heredé la forma
sin mirarla, y mi mecanismo nuevo la volvió dañina de una manera distinta.

**How to apply:**

- Antes de mover un `await` fuera de su tarea, escribe la lista: **cancelación, prioridad, contexto
  de actor, orden respecto a otros awaits, y quién publica y limpia el handle.** Cada línea es una
  garantía que hay que restituir a mano o declarar perdida.
- **Un campo que guarda una tarea o una generación lleva su prueba de identidad** al publicar y al
  limpiar (`if generacion == mía`, `if handle == el mío`). El patrón se reconoce por el `defer` que
  pone a `nil` un campo compartido: si entre el arranque y la muerte cabe otro arranque, ese `defer`
  es una bomba.
- **La regresión que introduce un cambio así va con test propio**, y el caso no es el del ticket: es
  «lo que ya funcionaba sigue funcionando» — aquí, `stopLoop` durante el sueño. Sin él nadie lo mira,
  porque el diff parece que solo añade.
- Y las tres lentes adversariales coincidieron en esto; el escenario completo —con su call-site real,
  el post-sign-in que corre justo tras cerrar sesión— lo construyó una. Ver
  [[review-adversarial-caza-lo-mio]] y [[mi-arreglo-rompe-la-premisa-de-otro-guard]].
