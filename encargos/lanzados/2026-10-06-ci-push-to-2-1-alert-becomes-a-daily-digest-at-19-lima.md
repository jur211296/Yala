# El aviso de push a 2.1 deja de salir en cada push y pasa a un solo resumen diario a las 19:00 Lima

## Contexto
Hoy `.github/workflows/avisar-grok-push-principal.yml` manda un aviso a la routine «Avisos CI Yala» (webhook, secrets `GROK_WEBHOOK_URL` / `GROK_WEBHOOK_SENDER_KEY`, entrega vía `.github/actions/avisar` con respaldo a issue `aviso-ci`) en CADA push a `2.1`. Con la cola autónoma eso es un aviso por merge y por push de docs: ruido. Dan lo propuso y Jürgen dio el OK el 2026-10-06: un solo resumen diario. Tarjeta del tablero `tablero-ci-el-aviso-de-push-a-2-1-pasa-a-un-resu-0h7s`.

## Qué se pide
- Cambiar ese workflow para que deje de dispararse en cada push y corra una vez al día a las 19:00 Lima (`cron: "0 0 * * *"` en UTC), más `workflow_dispatch` para poder probarlo a mano.
- El resumen cubre las últimas 24 h de `2.1`: PRs mergeados (número, título humano) y commits directos que no vinieron de un PR (primera línea, autor), con link al compare. Si no hubo nada, NO envía nada (ni aviso vacío).
- Mantener la misma entrega: `.github/actions/avisar`, los mismos secrets, el respaldo a issue si el webhook no responde, y la protección contra inyección (texto de commits por `env:`/`jq --arg`, nunca `${{ }}` dentro de `run:`).
- Actualizar el comentario de cabecera del workflow y cualquier doc del repo que describa el aviso por push (CLAUDE.md / docs de CI) para que diga la verdad nueva.
- Probarlo de verdad: un `workflow_dispatch` desde la rama del PR (o el equivalente que funcione) que llegue al webhook, y el caso «nada en 24 h» que no envía. Deja en el PR qué corrida lo prueba.
- Abre PR a `2.1` con auto-merge, y cierra tú sola con `/cerrar-total` cuando el PR quede en cola (autónomo de punta a punta, sin esperar a Jürgen).

## Qué NO hay que tocar
- `qa.yml`, `nocturna-vigilante.yml` ni `ping-avisador.yml`: los avisos de CI en rojo siguen saliendo al momento.
- No rehacer ni cambiar los secrets ni la routine de Grok.
- Nada de app iOS: no hace falta build ni simulador. No arranques ningún simulador.

## Gate tras el CI del PR anterior
La sesión arranca ya, sobre `origin/2.1`. No se espera a que el PR anterior (#373, también toca CI pero en `qa.yml`) entre, y no se parte de su rama. Justo antes de abrir el PR, mirar si #373 sigue en CI. Si sigue, esperar a que entre y rebasar una sola vez. Si `2.1` no se movió, seguir de frente. Si ese CI falla, no esperar: rebasar con lo que haya y seguir.

## Cómo se sabe que está bien
- Un push a `2.1` ya no genera aviso.
- Una corrida programada/manual con actividad en 24 h manda un resumen legible con los PRs y commits; sin actividad, no manda nada.
- El respaldo a issue sigue funcionando si el webhook falla.
- PR abierto con auto-merge a `2.1`, tarjeta 0h7s actualizada, Mini limpia y sesión cerrada con `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Ficheros: solo `.github/workflows/avisar-grok-push-principal.yml` (nombre de fichero intacto: lo citan la action, el ping y tickets).

1. **Ventana del cron**: tramo FIJO `[00:00 UTC de ayer, 00:00 UTC de hoy)`, no «24 h antes de arrancar». El cron llega a retrasarse horas (4 h 35 min el 2026-09-08); así un run tardío cubre lo mismo y dos días no se pisan ni dejan hueco. A mano (`workflow_dispatch`), la ventana acaba ahora y dura `horas` (input, default 24).
2. **PRs**: `gh pr list --state merged --base 2.1 --search merged:INI..FIN` + filtro exacto por `mergedAt`. Título del PR, no el del commit de merge.
3. **Commits directos**: `git log --first-parent --no-merges origin/2.1` en la ventana, descartando los que sean `mergeCommit` de un PR (squash/rebase). Autor = `%an`.
4. **Compare**: desde el último commit de primer padre anterior a la ventana hasta la punta.
5. **Vacío**: el paso de envío no corre (`if: hay == 'true'`); deja un `::notice`.
6. **Tope**: 30 PRs y 30 commits, con «…y N más».
7. **Prueba del caso vacío**: dispatch con `horas` pequeño (p. ej. 0/1) en un tramo sin actividad.
8. **Comentario del `ping-avisador.yml`** que dice que este workflow avisa en cada push: queda desfasado pero el encargo prohíbe tocar ese fichero → se anota en el PR, no se toca.
9. **Prueba desde la rama**: `workflow_dispatch` con `--ref` de la rama; si GitHub lo rechaza por no estar el trigger en `2.1`, commit temporal con `push` a la rama y se retira antes del PR.
