---
name: mover-un-paso-detras-de-un-await
description: Mover un paso síncrono detrás de un await de red deja correr ANTES a quien arranca en paralelo (otra Task del main actor), no solo al import del espejo
metadata:
  type: feedback
---

Mover un paso síncrono detrás de un `await` de red se paga con lo que otro `Task` hace en ese hueco. Y el
otro no siempre es el que el comentario del código tiene en mente.

El 2026-09-25 moví la restauración de identidades del reconcile de `done` detrás de la pregunta del lease.
Mi argumento: «el espejo está apagado, no llega ningún import». Era verdad, pero el runtime de sync arranca
en OTRO `Task` del arranque, con el reconcile todavía pendiente. `canRunDomain` no mira los pendientes, y la
regla del repo decía lo contrario: «un pendiente en `done` lo bloquea». Resultado: su pull llegaba antes que
mi restauración, creaba un born-remote y la fila ya no se restauraba. La lente de orden lo midió.

**Why:** el comentario de un invariante nombra al competidor que el autor tenía en mente. Los demás no salen,
y una regla que dice «X está parado» es una afirmación que se mide.

**How to apply:** antes de añadir un `await` delante de algo que lee o escribe estado compartido, lista
QUIÉN puede correr en ese hueco:
- los `Task` hermanos del arranque (`AppBootstrapper` lanza varios en paralelo);
- las cadencias del runtime;
- los observers.
Y mide cada gate que se supone que los para. Relacionado: [[lo-que-saco-a-una-tarea-aparte-pierde-garantias]] y
[[la-premisa-del-encargo-tambien-se-mide]].
