---
id: gpt-4-1-nano-shuts-down-on-october-23
status: backlog
priority: very-high
area: ai, gateway, image, chat
created: 2026-10-07
updated: 2026-10-07
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H0)
---

# OpenAI apaga `gpt-4.1-nano` el 23-oct-2026, y la lectura de fotos depende de él

> **Grupo: para Jürgen.** Cambio de modelo con fecha. **Decidir antes del 2026-10-20** para tener
> margen de probar en staging y desplegar el gateway antes del 23.

## Qué le pasa al usuario si no se hace nada

A partir del **23 de octubre de 2026**, en **todas las versiones instaladas** de Yala:

- **Registrar por imagen deja de funcionar.** Cada foto falla y la hoja dice «inténtalo otra vez».
- El chat sigue respondiendo, pero clasifica la intención con el regex de respaldo, que solo entiende
  español e inglés. Un «gasté 50 en mercado» en francés se trata como pregunta.
- Las sugerencias del chat caen a las fijas por reglas.

Los tres efectos están **inferidos de los caminos de error del código**, no observados: el modelo
todavía responde hoy.

## Lo medido (2026-10-07)

- Fuente: https://developers.openai.com/api/docs/deprecations (consultada 2026-10-07), sección
  «2026-04-22: Legacy GPT model snapshots»: *shutdown* **October 23, 2026**, `gpt-4.1-nano` |
  `gpt-4.1-nano-2025-04-14`, sustituto recomendado **`gpt-5.6-luna`**. La página dice que el modelo
  «will no longer be accessible».
- Usan `.gpt4_1_nano`: `ImageVisionService.swift:169`, `ChatIntentClassifierService.swift:89`,
  `ChatSuggestionsLLMService.swift:149`.
- El modelo va **dentro del binario** y el gateway lo reenvía sin mirar
  (`gateway/src/proxy/openai.ts`). Una release nueva **no salva** a quien no actualice: solo el gateway
  llega a todas las versiones a la vez.

## Opciones

| | Qué se hace | A favor | En contra | Coste (estimado) |
|---|---|---|---|---|
| **A** | El gateway reescribe `gpt-4.1-nano` → **`gpt-4.1-mini`** en `/v1/chat/completions` | Misma familia y mismos parámetros (temperatura, `json_object`, visión). Riesgo mínimo. Llega a todas las versiones. `gpt-4.1-mini` no tiene fecha de retirada | ×4 el precio por token en estas tres llamadas (0,40/1,60 frente a 0,10/0,40 por 1M) | Una foto: ≈5 000 tokens de imagen ×1,62 en mini → ≈$0,002 (cálculo propio desde la guía de visión). Clasificador: ≈700 tokens → ≈$0,0003 |
| **B** | El gateway reescribe → **`gpt-5.6-luna`** con `reasoning_effort: "none"` | Es el sustituto oficial. Más barato que mini (0,20/1,20) y menos tokens por imagen (×1,2) | Es un modelo de razonamiento (por defecto `medium`): hay que forzar `none` o sube la latencia contra los 8 s del clasificador. La página **no dice** si acepta `temperature`; hay que probarlo en staging. Comportamiento no comparado con el actual | Foto 1536×2048 en `high`: 3 000 tokens → ≈$0,0006 |
| **C** | Solo una release de la app con otro modelo | Sin tocar el gateway | **No llega a tiempo** (revisión de App Store) y no cubre a quien no actualice | — |

## Recomendación

**A ahora, B después.** A es el puente seguro antes del 23. La migración a la generación nueva se decide
con datos en `ai-text-model-generation-upgrade`, ya con el consumo medido
(`gateway-does-not-record-ai-token-usage`). Si Jürgen prefiere ir directo a B, que sea con una prueba en
staging de las tres llamadas antes del 20.

En cualquier caso, la siguiente release debería dejar de mandar `gpt-4.1-nano` o, mejor, dejar de mandar
modelo (`ai-model-choice-lives-in-the-app-binary`).

## Hecho cuando

- Test del gateway: una petición con `gpt-4.1-nano` sale hacia OpenAI con el modelo elegido y el resto
  del cuerpo intacto (imagen incluida).
- Staging: foto, clasificación y sugerencias funcionan con el build de la tienda **sin recompilar**.
- Producción desplegada antes del 2026-10-23.

## Decisión de Jürgen (2026-10-07, 10:03 Lima) y lo hecho

> «Quiero ya la solución robusta y correcta a largo plazo, no parcheemos por parchar ni dejemos pendientes. Quiero
> eficiencia en tokens y en costos, pero asegurarnos de que la tarea se realiza bien; no usamos modelos que no vayan a
> hacer bien la tarea. Si debe ser un modelo mayor, no importa, a cambio de asegurar calidad.»

No se tomó ni la A ni la B de arriba. Se hizo la opción A de `ai-model-choice-lives-in-the-app-binary`: el **gateway
decide el modelo por tarea** y las tres tareas de nano se eligieron con un banco de calidad, comparando con todo el
mercado (ampliación de las 10:05).

- **Elegido: `gpt-6-luna` en las tres.** La foto pasa del 42 % al 96 % de acierto (100 % en importe, fecha y número de
  movimientos) y cuesta menos que nano. El clasificador y las sugerencias quedan al 100 %. Detalle y porqué en
  `docs/ai-model-bench-2026-10.md`.
- **Llega a todas las versiones instaladas sin release:** sin cabecera, el gateway deduce la tarea por la huella del prompt.
- La opción A de este ticket (`gpt-4.1-mini`) habría acertado el 96 % en la foto a 4 veces el coste de `gpt-6-luna`.
