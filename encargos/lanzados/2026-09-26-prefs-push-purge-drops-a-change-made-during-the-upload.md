# Si cambias una preferencia mientras se sube la anterior, el cambio nuevo ya no se pierde

## Contexto
Cola A autónoma (riesgo real: pérdida silenciosa de un cambio del usuario). Sale del cierre limpio de PR #271 (`prefs-outbox-reads-an-unreadable-file-as-corrupt-and-overwrites-it`): la review adversarial encontró que `PrefsOutbox.removeEntries(keys:)` borra por key sin comparar HLC; un `set()` durante el `await prefsClient.push` encola la misma key con HLC nuevo y la purga se la lleva. Ticket: `tickets/backlog/prefs-push-purge-drops-a-change-made-during-the-upload.md`. Rama base: `2.1`. Hora Lima ~22:43 (NOCTURNO 21:00–6:00): elige la opción robusta recomendada sin AskUserQuestion; si la decisión es demasiado grave para asumirla, aparca en ticket propio y sigue.

Hermano low (no tocar en este encargo salvo que el arreglo lo exija de verdad): `prefs-change-is-dropped-when-the-outbox-cannot-take-it` (cambio suelto cuando el outbox lanza).

## Que se pide
Arreglar el ticket de punta a punta en código + tests + board + PR a `2.1` + merge + `/cerrar-total`.

En lenguaje de usuario: cambias una preferencia, Yala la sube, y antes de que termine la vuelves a cambiar → el segundo cambio debe quedar en cola y subir en el ciclo siguiente; tus otros dispositivos no se quedan con el valor viejo.

Criterios del ticket:
- La purga tras el push solo retira una entry si su HLC es el que se subió; una más nueva se queda.
- Test con el `enqueue` intercalado entre la lectura y la purga, y control con la entry sin cambios.

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- El hermano low `prefs-change-is-dropped-when-the-outbox-cannot-take-it` salvo acoplamiento inevitable (si lo tocas, ticket/board al día)
- Prod Supabase; staging solo si el ticket lo exige de verdad
- No relanzar otros encargos ni pisar worktrees ajenos

## MODO AUTÓNOMO HASTA TERMINAR (norma Jürgen 2026-09-22, vigente)
La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo. Implementa, pasa gate, abre PR a `2.1`, mergea y cierra con `/cerrar-total` sin pedir OK para continuar. De noche no uses AskUserQuestion: opción robusta o aparca. Solo para si necesitas device/secrets/acceso que no tienes.

## Como se sabe que esta bien
- AC del ticket cumplidos con test que demuestra la carrera
- Board: ticket movido; hallazgos nuevos con ticket propio; `docs/TICKETS.md` al día
- PR mergeado a `2.1`
- `/cerrar-total` limpio (worktree/tmux)

## Paso 0

Decidido (nocturno, sin preguntas):

1. **La purga compara por HLC exacto, no por «más nuevo».** `removeEntries(pushed:)` recibe `key → hlc` de lo que se
   subió y solo retira la entry si su `hlc` es ese. Cada `enqueue` emite un HLC estrictamente mayor, así que la
   igualdad identifica la misma escritura; una distinta (más nueva, o de otra identidad tras un teardown) se queda.
2. **El HLC sale del wire que se envió**, no de la respuesta: `PushResult` no lo trae. Una key que el servidor devolviera
   sin haberla enviado no purga nada.
3. **La firma vieja `removeEntries(keys:)` desaparece**, no convive: dejarla sería dejar abierto el camino del bug.
4. **Fuera de alcance, con ticket propio:** el pull del mismo ciclo sigue aplicando el valor del servidor sobre una
   entry pendiente más nueva (el merge no mira el outbox). Tras este arreglo eso se ve como un parpadeo de un ciclo
   (el valor viejo, y el nuevo en cuanto sube), no como pérdida; también pasa sin carrera cuando el push falla
   transitorio. Es otro defecto, previo, y cambiar el merge es otra decisión.
5. **El hermano low** (`prefs-change-is-dropped-when-the-outbox-cannot-take-it`) no se toca: no hay acoplamiento.
6. Tests: unit de `PrefsOutbox` (entry reencolada no se purga + control sin cambios) y de `CloudSyncRuntime` con un
   stub de red que encola la misma key DURANTE el push (la carrera real, sin seam en producción) + control.
7. Review adversarial: sí (sync). Mutantes sobre la comparación.
