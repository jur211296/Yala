# La hoja «Unirme» debe aparecer siempre al abrir un invite (aunque ya tenga cuenta)

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, merge a 2.1 y /cerrar-total sin preguntar. Solo parar ante decisión/acceso real de Jürgen.

## Contexto
Ticket: `tickets/backlog/groups-invite-skips-unirme-sheet-if-onboarded.md` (high). Device QA TF 2.1 build 12: B = cuenta ya creada (onboarding hecho). Abre el enlace de invitación y **no** aparece `GroupInviteOnboardingView` / hoja «Unirme»: el alta al grupo ocurre sola, sin confirmar nombre ni grupo.

Veredicto del owner: **la hoja debe aparecer siempre** — primer plano, segundo plano o ya dentro de la app.

Re-medir coordenadas del ticket (pueden estar caducadas). Rama nace desde origin/2.1 (Casa #10). Secrets.xcconfig ya en worktree-enlaces.

PR #73 (borrar grupo → pop del detalle) ya está en 2.1; no lo reabras.

## Que se pide
1. Reproducir/medir por qué se salta la hoja cuando `hasCompletedOnboarding` es true.
2. Hacer que la hoja «Unirme» / onboarding de invite aparezca siempre al aceptar un enlace de invitación, también si la cuenta ya existe.
3. Alcance mínimo: no rediseñar onboarding general ni el flujo de install limpia salvo lo necesario para este skip.
4. Tests que fijen el comportamiento.
5. Ticket → qa/board según convención; PR a 2.1; merge cuando gate verde (UI advisory: contrastar con base 2.1); /cerrar-total.

## Que NO hay que tocar
- marketing/
- groups-pending-member (decisión de producto pendiente)
- kill-switch / reentry-killswitch
- groups-leave-rpc-error-10 (siguiente, no mezclar)
- No inventar causa del device más allá de lo medido

## Como se sabe que esta bien
- Con cuenta ya onboarded, abrir invite muestra la hoja y pide confirmación antes de unirse.
- Gate verde; PR mergeado; /cerrar-total con resumen en lenguaje de usuario.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) decisión de producto/acceso; (2) PR o preview listo; (3) terminaste y /cerrar-total — resumen de qué se hizo; (4) idle mid-ticket una vez. NO avises por test rojo a reclasificar, build a reintentar, ni ruido de setup cp/cd. URL/key solo en la Mini.
