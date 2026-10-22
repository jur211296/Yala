# Banco de IA: Gemini como juez principal en Insights

## Contexto
En el banco del PR #407 los jueces pasaron a Sonnet 5.5. En Insights, Sonnet coincide con la nota a mano solo ~55 %, contra ~85 % de Gemini 3.8 Flash. Jürgen pidió (2026-10-08) poner a Gemini primero **solo en Insights**; el resto de tareas sigue con Sonnet. PR #407 ya está mergeado a 2.1. Card: `tablero-banco-de-ia-gemini-como-juez-principal-e-xkmy` (ya en in progress).

## Que se pide
1. En `gateway/bench` (o donde viva `JUDGES`), para las tareas `insights.*` poner Gemini primero como juez.
2. Regla: nadie juzga a su propio proveedor (si el candidato es Gemini, el juez no puede ser Gemini).
3. El resto de tareas del banco dejan a Sonnet como están tras #407.
4. Correr el banco / tests que cubran JUDGES de Insights y dejar evidencia en el PR.
5. Nota corta en `docs/ai-model-bench-2026-10*.md` (o el doc del banco que ya exista) explicando el cambio y el porqué.
6. Al terminar: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, actualizar card, limpiar worktree/tmux; sin simulador).

## Que NO hay que tocar
- No cambiar el modelo que sirve Insights/Tendencias en producción (solo el orden de jueces del banco).
- No tocar jueces de otras tareas fuera de `insights.*`.
- No pedir créditos ni claves nuevas: usa las del banco que ya hay.
- No abrir simulador ni tocar iOS.
- DerivedData/cachés de XcodeBuildMCP de worktrees muertos: borrar solo si tocas build iOS (aquí no aplica).

## Como se sabe que esta bien
- PR a 2.1 con JUDGES de Insights en Gemini primero y la regla anti-auto-juicio.
- Banco/tests de esa parte en verde.
- Doc del banco actualizado.
- `/cerrar-total` hecho.

## Paso 0

Medido antes de decidir: `JUDGES` vive en `gateway/bench/lib/insightsJudge.ts` y es **una sola lista para cuatro
tareas**: las tres `insights.*` y `trends.summary`. El 55 % / 85 % del doc del banco se midió sobre las cuatro juntas.

1. **Alcance: solo `insights.cards`, `insights.cashflow` e `insights.deviation`.** `trends.summary` sigue con Sonnet
   primero. Asumido: el encargo dice «solo en Insights» y «no tocar jueces fuera de `insights.*`»; se toma literal.
   Se deja anotado como hallazgo que la medida no separaba Tendencias.
2. **Orden en `insights.*`: Gemini 3.8 Flash, Sonnet 5.5, Grok 4.3, gpt-oss-120b.** Cada respuesta la miran los dos
   primeros de otro proveedor: a Gemini lo juzgan Sonnet y Grok; a Anthropic, Gemini y Grok (como ya era).
3. **Cómo:** `judgesFor(proveedor, tarea)` con la tarea obligatoria, para que ningún llamador caiga en silencio al orden
   por defecto. Los tres llamadores (`--agreement`, el juicio y el informe) ya tienen la tarea a mano.
4. **Evidencia sin gastar créditos:** tests de vitest y `--agreement` sobre los juicios ya pagados del 2026-10-07, que
   recalcula el par con el orden nuevo. No se lanza el juez de pago: en Insights no decide ninguno.
5. **Doc:** nota en `docs/ai-model-bench-2026-10-claude.md` (sección «Los jueces») y `gateway/bench/README.md`.
6. Sin iOS ni simulador: el gate de `Yala/` no aplica; el CI de `gateway` y los tests locales son la red.

**Revisado tras medir (preguntado a Jürgen, 20:03):** solo el orden no cambiaba ningún veredicto, porque el banco junta a
los dos primeros jueces y la pareja seguía siendo Gemini + Sonnet. Jürgen eligió **«Gemini juzga solo»** en `insights.*`
(Sonnet cuando el candidato es Gemini). Acuerdo del banco en Insights: 67 % → 87 % (κ 0,33 → 0,52).
