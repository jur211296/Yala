Yala
# Análisis: tandas de UI en rojo y si esperar el CI mejoró algo
---
toca: docs/analisis/ci-ui-rojo-2026-11-25/,tickets/backlog/2026-11-25-analisis-tandas-ui-rojo-espera-ci.md,tickets/done/2026-11-25-analisis-tandas-ui-rojo-espera-ci.md
esfuerzo: high
cierre: cierra-sola
---

Jürgen preguntó el 25-nov a las 6:20 (hora de Lima): «Por qué seguimos teniendo tandas en rojo. Me preocupa esto porque cada sesión espera 45 minutos y parece que fuera en vano. Para eso mejor volvemos al auto-merge que nos hacía avanzar más rápido. ¿Podemos hacer un análisis de si ha mejorado algo con el cambio?». Con este análisis va a decidir si volvemos al auto-merge de antes.

Dato de partida: el último run de QA de 2.3 (https://github.com/jur211296/Yala/actions/runs/45535770873, HEAD 15f0146, 24-nov a las 21:50 Lima) quedó en verde, pero las tandas de UI 1, 4, 5, 7 y 13 de YalaUITests quedaron en rojo. Las tandas de UI son advisory (`continue-on-error`): no bloquean, pero las sesiones igual esperan el CI.

## Qué se pide
Es solo análisis: no cambias el flujo, los workflows ni el código.

1. **Cuándo cambió el flujo.** Encuentra desde qué fecha las sesiones esperan el CI o los gates de QA antes de cerrar o mergear, y qué había antes (auto-merge sin esperar). Busca en el repo (DECISIONS.md/ADR, `.github/workflows`, commits, CLAUDE.md) y, si hace falta, en el registro de casa (`~/Claude`). Cita la fuente de la fecha.
2. **Cada tanda roja.** Revisa con `gh` por lo menos los últimos 10 a 20 runs de QA de 2.3 (y los de las ramas de PR si sirven). Por cada tanda y por cada prueba que falla di si el fallo es real o flaky (intermitente: falla y pasa sin cambios de código). Di también la causa (timeout, arranque del simulador, datos o estado previo, selector o accesibilidad, orden entre pruebas) y el arreglo que propones. Arma una tabla de frecuencia: qué pruebas fallan más y en cuántos runs.
3. **Costo.** Calcula los minutos de espera de CI por sesión (desde que se abre el PR hasta que se cierra o mergea, o el tiempo que la sesión pasa esperando) y el total por día y por semana desde el cambio. Usa datos reales de `gh run list`/`gh pr list`, no supuestos.
4. **Beneficio antes y después del cambio.** Compara un periodo comparable antes y después: bugs que llegaron a TestFlight o a los barridos de QA, reverts, hotfixes, y PRs que el CI frenó con razón (fallos reales atrapados, separados de los rojos flaky o advisory). Si un dato no se puede medir, dilo y explica por qué.
5. **Recomendación** clara, con opciones y el costo y el riesgo de cada una. Como mínimo: volver al auto-merge sin esperar UI; dejar como gate solo build y unit; arreglar o poner en cuarentena las tandas flaky; correr la UI completa de noche (nightly) y no por PR; o una combinación. Di cuál recomiendas y por qué.
6. **Arreglos como cards.** Si propones arreglos de pruebas o del CI, no los hagas: déjalos como cards en 2.3 en el tablero (`tablero crear --proyecto Yala --version 2.3 ...`), una por arreglo, con la evidencia. Lista las cards en el entregable.
7. Ticket: crea `tickets/backlog/2026-11-25-analisis-tandas-ui-rojo-espera-ci.md` y, al cerrar, muévelo a `tickets/done/`.

Los datos crudos (CSV o JSON de runs, PRs y tiempos) quedan en `docs/analisis/ci-ui-rojo-2026-11-25/`.

## Qué NO hay que tocar
- Nada fuera de `toca:`. No toques `.github/workflows`, scripts de CI, código de la app, pruebas, `Yala/`, `YalaTests/`, `YalaUITests/`, `Yala/Resources` ni `tickets/` entero.
- No abras simulador ni compiles: todo sale de `gh`, logs y el repo.
- No re-ejecutes runs de CI para medir.

## Cómo se sabe que está bien
Jürgen puede decidir en un minuto: ve desde cuándo se espera, cuánto cuesta por semana, qué atrapó el CI de verdad, por qué fallan las tandas 1, 4, 5, 7 y 13 (real o flaky) y qué opción le recomiendas, con su costo.

## Cómo entregar
- **Entregable visual:** artifact público de Claude, fácil para decidir. Arriba la respuesta corta («¿sirvió esperar el CI?») y la recomendación. Después, gráficos de costo (minutos por día y por semana), el antes y después del beneficio, el mapa de tandas y pruebas rojas (real o flaky) y la tabla de opciones con su costo. Pon el link en «Qué salió». Nada de Markdown suelto como entregable.
- Si hay PR (solo docs), va contra 2.3, sin firma de IA. Deja el auto-merge activado y cierra; no esperes al CI.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones (resueltas en semi, sin consultar: todas menores y reversibles)

1. **Fecha del cambio:** se toma el commit de la decisión 125 de casa (19-nov 13:12 Lima) como frontera. Antes = 14 días previos; después = hasta el 25-nov 06:40. Se compara por día.
2. **Costo de la espera:** se mide en los transcripts reales de las sesiones de Yala de la Mini y la Max (llamadas a `esperar_merge.py`), no en supuestos; GitHub (auto-merge → merge recortado a 45 min) solo como contraste.
3. **Real o intermitente:** todas las pruebas corren cada noche; rojo varias noches seguidas o 3/3 intentos la primera noche tras cambios = real (las nuevas del 24-nov, «probable real» hasta la nocturna de hoy); rojo y verde sin cambios = intermitente; rescatada por reintento = intermitente.
4. **Cards:** una por arreglo, en 2.3, asignadas a Frank, `cierra-sola`. La decisión de volver al auto-merge no va como card: es de Jürgen y va en «Necesita de ti».
5. **`docs/TICKETS.md` no se toca:** no está en `toca:` y nada lo valida en CI.
6. **Decisiones de Jürgen pendientes:** las dos primeras son de otras sesiones (subida de la build 9 y el bug de D1, ya cerrado); la tercera es este análisis. `decisiones.py` no existe en la Max: se dice en el cierre.
