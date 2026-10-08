---
id: ai-model-choice-lives-in-the-app-binary
status: backlog
priority: high
area: ai, gateway
created: 2026-10-07
updated: 2026-10-07
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H15)
---

# El modelo de IA está escrito en la app: cambiarlo exige una release

> **Grupo: para Jürgen.** Arquitectura del contrato app ↔ gateway. Decide cómo se harán todos los
> cambios de modelo futuros.

## Qué pasa

Cada servicio escribe su modelo (`.gpt4_1_mini` en 8 sitios, `.gpt4_1_nano` en 3, `.whisper_1` en 1) y
el gateway lo reenvía sin mirar. Consecuencias:

- Cambiar de modelo exige release, y las versiones viejas siguen con el viejo. El apagado de
  `gpt-4.1-nano` el 23-oct (`gpt-4-1-nano-shuts-down-on-october-23`) es el primer caso real.
- No se puede probar un modelo nuevo con un % de usuarios.
- El sitio natural para partir la IA por modo nube o privado (card de 2.2) es el gateway, y hoy no
  decide nada.

## Opciones

| | Qué se hace | A favor | En contra |
|---|---|---|---|
| **A** | El gateway elige el modelo **por categoría** (`X-Yala-Category`) y por tarea, e ignora el que mande la app | Un cambio de modelo es un deploy del Worker. Sirve para A/B y para modo nube/privado | Hay que añadir una cabecera de **tarea** (la categoría `suggestions` hoy mezcla clasificador, sugerencias y reescritor; `insights` mezcla cinco). Parámetros que dependen del modelo (`reasoning_effort`, `temperature`) también pasan al gateway |
| **B** | La app sigue mandando el modelo, pero el gateway tiene una **tabla de sustitución** (modelo pedido → modelo usado) | Cambio mínimo y compatible con todas las versiones. Resuelve los apagados | No permite elegir distinto por tarea si dos tareas comparten modelo |
| **C** | Dejarlo como está | Nada que hacer | Cada apagado de OpenAI es una carrera contra App Review |

## Recomendación

**B ya** (es lo que pide el apagado del 23-oct y se hace en un día), **A en 2.2** junto con la card de
partir la IA por modo. B absorbe `gateway-proxies-any-model-and-any-length`.

## Hecho cuando

- Opción B: tabla en el gateway con tests; la app actual funciona sin cambios.
- Opción A: además, cabecera de tarea en la app y la elección de modelo documentada en el gateway.

## Decisión de Jürgen (2026-10-07, 10:03 Lima): opción A ya, calidad primero

> «Quiero ya la solución robusta y correcta a largo plazo, no parcheemos por parchar ni dejemos pendientes… no usamos
> modelos que no vayan a hacer bien la tarea. Si debe ser un modelo mayor, no importa, a cambio de asegurar calidad.»
> Y a las 10:05: «ampliemos la comparación a todos los mercados y elijamos el mejor modelo para cada tarea, sea de quien
> sea. Y deberemos ir revisando cada cierto tiempo estos modelos.»

**Sesión 1, hecha (2026-10-07):**

- Tabla tarea → {proveedor, modelo, parámetros} en el gateway (`gateway/src/ai/routes.ts`).
- Cabecera `X-Yala-Task`, y deducción de la tarea para las versiones que no la mandan.
- Adaptadores de OpenAI, Gemini, Anthropic, xAI y Workers AI.
- Banco de calidad (`gateway/bench/`).
- Las tres tareas de `gpt-4.1-nano` pasan a `gpt-6-luna`.
- Decisión registrada en `docs/DECISIONS.md` (2026-10-07).

**Sesión 2, pendiente:** `ai-every-call-sends-its-task-and-passes-the-bench`. La app manda la cabecera en las 12 llamadas,
los parámetros salen de la app, y las demás tareas, la voz y la cuota free pasan por el banco. Este ticket se cierra
cuando se cierre aquél.
