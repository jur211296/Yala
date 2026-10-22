# Banco de IA: medir Sonnet 5.5 y Haiku 5.5 en Insights y Tendencias, y pasar jueces a Sonnet

## Contexto
Jürgen tiene 1.000 USD en créditos de la API de Anthropic (Claude Startups; vencen a los 6 meses tras reclamarlos en Claude Console). Card del tablero: «Banco de IA: medir Sonnet 5.5 y Haiku 5.5 en Insights y Tendencias, y jueces a Sonnet, con los créditos de Claude» (tablero-banco-de-ia-medir-sonnet-5-5-y-haiku-5-5-asc1), lista para lanzar, desbloqueada al cerrar cloud-tx-epoch-orphan-relations.

En el banco del 7-oct (PR #387), Sonnet 5.5 y Haiku ya empatan al 100 % donde gpt-6-luna también saca 100 % (foto, clasificador, sugerencias), pero más lentos y caros. Lo que no llega al 100 % es Insights (gpt-6-luna 90,6 %) y Tendencias (gpt-6.1-sol 100 % a 4,49 USD/1.000; Gemini 3.8 Flash gana pero está apagado), y ahí Sonnet no se midió como candidato.

Clave Anthropic ya en la Mini: ~/Secrets/yala-ai-bench/anthropic.key (también disponible como secreto del bot YALA_ANTHROPIC_BENCH_KEY). Rama base: origin/2.1. Enlace: https://github.com/jur211296/Yala/pull/387

## Que se pide
1. Correr `npm run bench` con claude-sonnet-5-5 y claude-haiku-5-5 (effort none y low) en insights.cards y trends.summary, mismos casos y listón que el banco vigente.
2. Informe en docs/ con tabla comparada: calidad, p95 y costo por 1.000 a precio de lista y con créditos Anthropic; recomendación clara (¿entra alguno como segundo proveedor / reemplazo en Insights o Tendencias?).
3. Pasar los jueces del banco a Sonnet 5.5 (salvo cuando el juzgado es Anthropic: nadie juzga a su propio proveedor) y dejarlo así para la revisión trimestral.
4. Si alguno gana con evidencia, actualizar el ticket del paso 7 (segundo proveedor) según corresponda.
5. Al terminar: `/cerrar-total` autónomo (PR a 2.1 en auto-merge si hay cambios; card a in qa o done según criterio; Mini limpia).

## Que NO hay que tocar
- No encender rutas en producción ni cambiar el proveedor por defecto de Insights/Tendencias en prod.
- No gastar créditos fuera del banco (solo insights.cards y trends.summary + cambio de jueces).
- No reabrir el trabajo de cloud-tx-epoch-orphan-relations ni depender del merge del PR #406.
- No tocar secretos fuera de ~/Secrets/yala-ai-bench/; no escribir claves en el repo.

## Como se sabe que esta bien
- Informe en docs/ con tabla y recomendación mergeable a 2.1.
- Jueces del banco apuntan a Sonnet 5.5 con la excepción Anthropic→Anthropic documentada.
- Bench corrido con evidencia (salida / artefactos) para sonnet-5-5 y haiku-5-5 en Insights y Tendencias (none y low).
- Cierre con `/cerrar-total`.

## Paso 0

Decidido sin nadie delante (sesión autónoma). Lo asumido va marcado.

1. **El listón de Insights ya no es 90,6 %.** Medido: tras el fix de idioma del 7-oct por la noche (`be06b429e`,
   `results/2026-10-07-idioma/`), `gpt-6-luna` low saca **100 %** en tarjetas. El prompt de Tendencias no cambió, así
   que su listón sigue: `gpt-6.1-sol` low 100 % a 4,49 USD por 1 000.
2. **Mismos casos y listón que el banco vigente**: los 16 casos de cada tarea, `--reps 2 --concurrency 1` (la pasada en
   serie, la única que vale para la latencia), JSON 100 %, 0 cifras inventadas tras revisión manual, ≤ 1 contradicción
   en las 16 respuestas de la repetición 0 leídas a mano, Insights ≥ 90 % y Tendencias ≥ 95 %, p95 en serie < 15 s.
3. **Carpeta propia**: `gateway/bench/results/2026-10-08-claude/`. No se escribe en las del 7-oct salvo el acuerdo del
   juez (abajo), que vive junto a su muestra a mano.
4. **Asumido: los titulares se vuelven a medir en la misma pasada** (`gpt-6-luna` low en tarjetas, `gpt-6.1-sol` low y
   Gemini 3.8 Flash low en Tendencias). Mismo prompt, misma red, misma hora: la comparación es justa. Cuesta < 0,5 USD.
5. **Variantes Anthropic**: Sonnet 5.5 `none` (`between_tools`) y `low`; Haiku 5.5 `none` (`thinking: disabled`) y
   `low`. 4 variantes × 16 casos × 2 repeticiones × 2 tareas = 256 llamadas.
6. **Coste con créditos**: el informe da el precio de lista y cuántas llamadas cubren los 1 000 USD de créditos (coste
   efectivo 0 hasta agotarlos o hasta que venzan a los 6 meses).
7. **Jueces**: en `insightsJudge.ts` Sonnet 5.5 (low, sin temperatura) pasa a ser el primero; cada respuesta la miran
   los dos primeros de otro proveedor, así que a Anthropic lo juzgan Gemini y Grok. Antes de fiarse, se mide su acuerdo
   con las 40 respuestas puntuadas a mano del 7-oct (`insights.hand-scores.json`). En `chat.answer` el orden recomendado
   pasa a Sonnet primero (ya medido: 100 %, κ 1,00) y Gemini juzga a Anthropic. El juez sigue sin decidir en Insights
   si no llega a κ ≥ 0,6 y 85 %.
8. **Nada se enciende**: ni `routes.ts` ni `PREPARED_ROUTES` cambian. Si alguien gana, se actualiza el paso 7 del ticket
   `ai-every-call-sends-its-task-and-passes-the-bench`.
9. **Sin código de la app**: el diff cae en `gateway/bench/`, `docs/`, `tickets/` y `encargos/`. `gateway/` sí compila
   (typecheck + vitest), así que va por PR con su CI.
