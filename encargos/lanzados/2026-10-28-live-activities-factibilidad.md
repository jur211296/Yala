# Live Activities · factibilidad ActivityKit y corte en tickets (2.4)

## Contexto
Card: tablero-live-activities-presencia-en-pantalla-de-hi45 (backlog, v2.4, assignee frank).
Jürgen 2026-10-28 dio el alcance de producto en el 1:1 con Frank. Quiere que Claude diga qué se puede / no se puede y si van 1 o N tickets. **Esta sesión NO implementa código de producto.** Solo investigación + propuesta de tickets. Ideas completas también en la nota de la card y en `~/Claude/tmp-frank/nota-live-activities-ideas-2026-10-28.md`.

## Que se pide
1. Leer la nota de la card (o el md de ideas) y el estado actual de notificaciones / Apple Pay / bandeja / pagos planificados / registro por voz en el repo (solo lo necesario: dónde viven hoy esos flujos).
2. Contrastar cada caso contra ActivityKit + Interactive Live Activities (iOS actual del proyecto / deployment target de Yala):
   - Post Apple Pay: LA ≤5 min con campos pendientes, tap → bandeja, ¿acciones inline (asignar cuenta/categoría, aprobar)?
   - Umbral presupuesto: LA con nombre + barra animada ≤5 min → luego push estática.
   - Pago planificado: ¿marcar / aprobar desde la LA?
   - Registro por voz: LA / Island desde Atajo, Control Center, Lock Screen y/o desde dentro de la app (onda fuera de la UI de Yala).
3. Por cada caso: **sí / parcial / no**, con motivo (API, UX Lock Screen/Island, App Store, duración, actualización en background, Interactive widgets limits).
4. Propuesta de corte: **un ticket** vs **varios** (títulos humanos, criterios de hecho, dependencias, orden sugerido). Versión 2.4 salvo que algo no quepa.
5. Actualizar la card hi45: nota con el informe corto, hechaCuando cumplido para la fase de alcance, y crear en tablero las cards hijas que propongas (assignee frank, v2.4, cierre `cierra-sola` salvo decisión vital). Mover hi45 a done si quedó solo como paraguas de alcance, o dejarla como épica con desbloqueos claros — elige lo más limpio y dilo en el cierre.
6. No tocar cola 2.2 ni abrir PRs de implementación. Si hace falta un doc corto en el repo (`docs/` o ADR), un PR solo de docs está bien.

## Que NO hay que tocar
- Código de producto / UI de la app más allá de leer.
- Cola S14…S29 ni TestFlight.
- No lanzar sims salvo que sea imprescindible para un smoke de ActivityKit (preferible no).

## Como se sabe que esta bien
- Informe por caso (sí/parcial/no + motivo).
- Lista de tickets propuestos (1 o N) con criterios.
- Card hi45 y cards nuevas al día en el tablero.
- Cierre con `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

- **Modo:** autónomo (sesión lanzada en bypass, cierra con `/cerrar-total`). Sin preguntas: no hay decisión de producto que la factibilidad no pueda dejar abierta en un ticket.
- **Ficheros:** `docs/live-activities-factibilidad.md` (informe), 5 tickets nuevos en `tickets/backlog/`, `docs/TICKETS.md` (índice). Nada de código.
- **Entrega:** diff entero en `docs/` + `tickets/` → sin nada que compilar; gate = validación del índice. PR de docs con auto-merge.
- **Corte:** cinco tickets (base + Apple Pay presencia · presupuesto · pago planificado · acciones inline Apple Pay · voz). Uno solo mezclaría un «sí/no» por medir (Apple Pay desde segundo plano) con riesgos que no deben frenar al resto.
- **Card hi45:** a `done` como paraguas de alcance; el trabajo vive en las cinco hijas (assignee frank, v2.4, `cierra-sola`). La 4 (acciones inline) va con prioridad baja porque depende de ver la 1 en uso.
- **Sin simulador ni iPhone:** todo sale de documentación y del repo; lo no medido queda marcado y asignado al ticket que lo mide.
- **Plan B por push del gateway** para pagos planificados: no se decide aquí; queda como pregunta dentro del ticket 3.
