# Registrar decisiones Jürgen 5-nov (deploys, 80 %, Lola, hooks)
toca: `tickets/`, `docs/`

Rama base: 2.3. Un solo PR chico (docs/tickets/tablero). Sin simulador.

## Contexto
Jürgen contestó el resumen de las 6:00. El registro vivo está en `~/Claude/entregas/Yala--decisiones-2026-11-05/decisiones.md`. Hay que dejarlo en el repo (tickets/qa o docs) y alinear cards.

## Qué se pide
1. Leer ese md de entregas (cópialo al worktree si hace falta).
2. Actualizar o crear notas en tickets/cards tocadas: umbral 80 % + palabra «en el límite»; OKs de deploy (sin desplegar tú); Gmail 613 ya en 2.3 draft.
3. Card de «en el límite» sin palabra: mover o anotar decisión = **sí poner la palabra**; implementación puede ser card nueva cierra-sola en 2.2 o 2.3 según encaje (pregunta al bot si duda de versión).
4. No desplegar Workers ni tocar App Store Connect.

## Hecha cuando
- PR con el registro durable + cards al día.
- `/cerrar-total`.

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Rama base.** El worktree nació de `2.2`; el encargo pide `2.3`. → Rama reiniciada sobre `origin/2.3` (sin commits propios que perder). PR a `2.3`.
2. **Dónde va el registro durable.** Las cards ya citan «docs/DECISIONS.md, entrada del 5-nov», que no existe en ninguna rama. → Se escribe esa entrada; no se crea fichero aparte. No hay fichero de ticket para estas cards (viven solo en el tablero).
3. **Cards.** Medido: las de 80 %, «en el límite», deploys, Gmail y Sentry ya llevan la nota del 5-nov. → No se reescriben. Solo falta el candado de commits: nota en la card del hook de los worktrees.
4. **«En el límite».** Ya en backlog, versión 2.3, decidida «sí» y con siguiente paso. → Se queda en backlog; se le añade enlace al PR de este registro. Sin card nueva (sería duplicada). Versión 2.3 la fijó el bot dueño; no hace falta preguntar.
5. **Lola / App Store.** Fuera de territorio. → Se menciona en una línea, sin tocar `marketing/`.
6. **Gate.** Diff solo en `docs/` → va sin compilar; sin simulador.
