# CI: la suite completa de UI en 2.1 no corre en su horario y el watchdog la relanza cada pocas horas

## Contexto
Tarjeta del tablero `tablero-ci-la-suite-completa-de-ui-en-2-1-no-cor-wjij` (Frank, medium). Visto del 2026-10-01 al 2026-10-05: 5 veces en 5 días, 3 el 5-oct (~02:54, 13:30 y 22:25 Lima). El watchdog de cobertura detecta más de 26 h sin la suite completa de UI en `2.1` y la lanza él (última: run 37408856675).
Síntomas:
1. El schedule de GitHub Actions de la suite UI no corre en su ventana.
2. Las corridas que lanza el watchdog no cuentan como corrida: vuelve a dispararse a las pocas horas.
3. Hipótesis SIN verificar: el run 37408856675 está pegado al push de PR #368 (run 37408856692); quizá el watchdog se dispara con cada push.
Ya hay un ticket que puede ser el mismo problema: `tickets/backlog/cobertura-ui-diaria-cuelga-del-push.md`. Léelo primero; si es este, trabaja sobre él y muévelo como toque.
Los rojos advisory de YalaUITests tras #362/#363 ya se avisaron a Jürgen; no son parte de esto.
Acaba de entrar en cola de merge el PR #375 (solo cambia `.github/workflows/avisar-grok-push-principal.yml`: el aviso por push pasa a un resumen diario a las 19:00 Lima). No depende de este encargo, pero tenlo en cuenta si algo del watchdog o la suite UI colgaba de ese workflow.

## Qué se pide
Encontrar por qué la suite completa de UI no corre en su horario y por qué el watchdog no reconoce las corridas que él mismo lanza (cron, filtro de evento/rama/workflow con el que busca la última corrida, triggers). Dejarlo robusto, con la mejor práctica aunque tome más tiempo: que la suite corra una vez al día en su ventana y que el watchdog solo actúe cuando de verdad falte una corrida completa. Probarlo de verdad (workflow_dispatch / corridas reales), no solo leyendo YAML. PR a `2.1` con auto-merge.

## Qué NO hay que tocar
- No cambies el contenido de los tests de UI ni el producto.
- No toques `.github/workflows/avisar-grok-push-principal.yml` (PR #375) ni `ping-avisador.yml`.
- No hace falta simulador local para esto. Si llegaras a necesitar build o simulador, pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador, boot de 1 solo simulador, tests, apagar y limpiar ese simulador. Nunca solapar swift-frontend + SpringBoard + app + UITests.

## Gate después del CI del PR anterior
La sesión arranca ya, sobre `origin/2.1`. No se espera a que el PR anterior entre, y no se parte de la rama en auto-merge. Justo antes del gate, mirar si el PR anterior (#375) sigue en CI. Si sigue, esperar a que entre y rebasar una sola vez, con el simulador apagado. Si `2.1` no se movió, seguir de frente. Si ese CI falla, no esperar: rebasar con lo que haya y seguir. El build y el simulador van después de ese rebase, una sola vez.

## DerivedData y cachés
Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Cómo se sabe que está bien
- Causa raíz explicada con evidencia (runs, eventos, filtros), no hipótesis.
- PR abierto a `2.1` con auto-merge, con las pruebas reales en el cuerpo.
- Si algo necesita a Jürgen (secrets, settings del repo), queda en «Necesita de ti».
- Cierra con `/cerrar-total` autónomo: deja la Mini limpia (sin simuladores, sin DerivedData de la sesión, worktree retirado si ya no hace falta).

## Paso 0

Medido antes de decidir (2026-10-06):

- **El schedule de `qa.yml` sí corre**: 29 de 29 días desde el 8-sep, con 3,9–8,9 h de retraso sobre
  las 08:17 UTC. El síntoma 1 no existe tal cual: es lectura del síntoma 2.
- **Los 22 disparos del vigilante desde el 8-sep fueron falsos**: en todos había una corrida de UI
  en las 26 h previas. Causa: `GET /actions/workflows/qa.yml/runs?event=…&branch=…` devuelve
  subconjuntos distintos llamada a llamada (vigilantes a un minuto: 0/0 y luego 1/2). Reproducido
  en local hoy: 0 schedule y 2 dispatch, y un minuto después 29 y 24.
- Hipótesis 3 del encargo: cierta pero no es la causa — el vigilante corre en cada push por diseño;
  cada push es una tirada más del dado de la API.

Decisiones (auto-contestadas, MODO AUTÓNOMO):

1. **Lectura**: unión de fuentes (filtro por evento + listado sin filtro paginado) y de 3 rondas;
   una lectura sin ninguna fuente válida es «no sé», no «no hay».
2. **Cuándo actuar**: ventana diaria anclada al cron de `qa.yml` (leído del propio fichero) y plazo
   de 12 h (máx. retraso medido 8,9 h). Antes del plazo, el vigilante espera; nunca lanza.
3. **Disparadores**: push se queda (red si el cron muere) y el cron del vigilante pasa a después del
   plazo (20:47 y 23:47 UTC).
4. **Verificación del dispatch**: por el `workflow_run_id` que devuelve la API, con respaldo de lectura.
5. Se incluye `vigilante-calla-si-no-puede-comprobar-la-nocturna`: es el mismo paso que reescribo.
6. Inputs de prueba: `ahora` (ensayo, nunca dispara) y `forzar` (dispara de verdad, sin aviso).
7. `cobertura-ui-diaria-cuelga-del-push` → `discarded` por su propio criterio (≥10/14: son 29/29).
   `vigilante-margen-menor-que-el-retraso-real-del-cron` → `done` con este PR.
