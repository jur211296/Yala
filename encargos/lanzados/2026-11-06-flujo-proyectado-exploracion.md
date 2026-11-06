# Flujo proyectado · exploración en Tendencias y Panel (con WidgetKit)
toca: Tendencias, Panel, Flujo de caja, WidgetKit / widgets

Rama base: origin/2.3. Sesión de exploración: lista todas las dudas con `preguntar-bot` (opciones claras) y NO implementa hasta tener respuestas. Un solo cierre. Máquina: la libre. Cierre autónomo. Termina con `/cerrar-total`. Commits y PR sin firma de IA (si solo hay docs/preguntas, PR de docs o cierre sin código).

## Contexto
Jürgen (6-nov) quiere «Flujo proyectado» en Tendencias y Panel para 2.3: un control «Ver proyectado» que muestre una continuación punteada del gráfico diario, estimada a partir de pagos planificados y estimaciones base de gasto (puede basarse en flujo de caja). Debe incluir WidgetKit. Card: «Flujo proyectado en Tendencias y Panel».

## Qué se pide
1. Recorrer Tendencias, Panel, flujo de caja y widgets actuales; anotar cómo encajaría el proyectado.
2. Listar TODAS las dudas de producto y técnica con `preguntar-bot` (2–3 opciones cada una): de dónde sale la estimación base, horizonte (7/14/30 días), qué pasa con meses sin presupuesto, monedas, privacidad en widgets, etc.
3. Proponer un plan corto de implementación (pantallas + WidgetKit) sin escribir el feature todavía.
4. Dejar la card con nota del plan y de las preguntas abiertas.

## Qué NO hay que tocar
marketing/. No implementes el feature en esta sesión. No asumas respuestas de producto.

## Cómo se sabe que está bien
Quedó el inventario de dudas preguntadas al bot, el plan escrito y la card actualizada. Gate verde si hubo diff. `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR. Las decisiones de PRODUCTO no están aquí: el encargo prohíbe asumirlas y van a Jürgen por el bot (13 preguntas, 2026-11-06 11:15).

**D1 · ¿Sobre qué base se trabaja?** → `origin/2.3`; la rama nació de `2.2` y se movió a `2.3` antes de tocar nada.
Por qué: el encargo dice «Rama base: origin/2.3» y la card es de la versión 2.3. Alternativa descartada: quedarse en 2.2 (el PR caería en otra versión).

**D2 · ¿Dónde queda escrito el plan y las preguntas?** → un ticket nuevo `tickets/backlog/flujo-proyectado-en-tendencias-y-panel.md` (+ su fila en `docs/TICKETS.md`) y una nota en la card del tablero.
Por qué: el ticket es la superficie del «qué y por qué» mientras el trabajo vive (CLAUDE.md). Alternativa descartada: un acta en `docs/sessions/` (tercera superficie que envejece).

**D3 · ¿Cómo se entrega?** → PR de solo docs contra `2.3`, en cola de auto-merge, sin firma de IA.
Por qué: worktree + modo autónomo; el encargo pide «PR de docs» si no hay código. Alternativa descartada: commit directo a la rama base (la regla de docs directos habla de `2.2`, y esta base es `2.3`).

**D4 · ¿Se cierra sin las respuestas?** → no: se espera la respuesta del bot avanzando con lo demás, y las respuestas se apuntan en el ticket y la card antes de `/cerrar-total`.
Por qué: regla dura «No cierres incompleto». Alternativa descartada: cerrar con las preguntas abiertas.

**D5 · ¿Se toca código o se sacan capturas?** → no. Solo documentación; sin cambio visible no hay evidencia de antes y después.
Por qué: el encargo prohíbe implementar en esta sesión.
