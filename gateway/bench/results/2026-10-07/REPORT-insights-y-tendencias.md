# Insights y Tendencias — banco del 2026-10-07 (sesión 2, trabajador B)

Cuatro llamadas que hoy usan `gpt-4.1-mini`: `insights.cards`, `insights.cashflow`, `insights.deviation` y
`trends.summary`. `insights.contextual` no entra: no tiene llamadores y se borra. Gasto ≈ 3,23 USD (OpenAI 1,62 ·
Anthropic 0,88 · Gemini 0,39 · xAI 0,25 · Workers AI 0,07).

## Resultado

| Tarea | Fila activa | Acierto (mini → nuevo) | p95 | USD por 1 000 (mini → nuevo) |
|---|---|---|---|---|
| `insights.cards` | `gpt-6-luna`, esfuerzo `low`, `json_object`, tope 2020 | 56,3 % → **90,6 %** | 9,4 s | 1,369 → **0,482** |
| `insights.cashflow` | `gpt-6-luna`, `none`, `json_object`, tope 256 | 21,4 % → **25,0 %** (100 % sin contar el idioma) | 2,1 s | 0,194 → **0,052** |
| `insights.deviation` | `gpt-6-luna`, `none`, `json_object`, tope 256 | 21,4 % → **21,4 %** (100 % sin contar el idioma) | 2,8 s | 0,166 → **0,048** |
| `trends.summary` | `gpt-6.1-sol`, `low`, `json_object`, tope 1020 | 68,8 % → **100 %** | 9,8 s | 0,601 → 4,490 |

- **Tendencias la gana Gemini 3.8 Flash** (100 %, p95 4,2 s, 1,47 USD por 1 000), que no se puede encender sin lo que
  pide el paso 7. Queda preparado y apagado (`PREPARED_ROUTES` en `gateway/src/ai/routes.ts`) y sirve la mejor de
  OpenAI: primero calidad, aunque cueste más. La app guarda el resumen 24 h, así que el volumen es bajo.
- **Flujo de caja y desviaciones** fallan en el idioma con todos los modelos: el prompt de la app no lo pide. Ticket
  `insights-cashflow-and-deviation-prompts-do-not-ask-for-the-language`.
- **Topes:** p99 × 2 en tarjetas (1009 → 2020) y Tendencias (510 → 1020), con el razonamiento contado; 256 en flujo de
  caja y desviaciones (p99 51 y 56), con margen.

## Qué se midió

- **El cuerpo exacto de la app.** Prompts leídos del Swift y payloads replicados de sus builders (JSONSerialization
  compacto con la barra escapada, `sortedKeys` en Tendencias). Lo fija `test/ai.bench.insights.test.ts`.
- **60 casos sin datos personales en 14 locales:** 16 de tarjetas, 14 de flujo de caja, 14 de desviaciones y 16 de
  Tendencias (semana y año, filtros, compartidos, pocos datos, anterior en 0, balance negativo, sin histórico).
- **Dos pasadas:** criba con `--reps 1` y un subconjunto de casos; finalistas con todos los casos, `--reps 2
  --concurrency 1` y el candado de latencia.

## Criterio

1. El parser de la app: `hero` obligatorio; de 3 a 6 tarjetas; `null` solo donde la app lo admite; Tendencias corta a
   4 viñetas.
2. **Ninguna cifra inventada.** Cada número se compara con los datos y sus derivados (diferencias, porcentajes, partes
   del total, ×7/28/30/31 de los promedios, ×12 de los mensuales), en todos los formatos regionales y multiplicadores
   (mil, k, Tsd., 万, Mio.). Toda cifra que el verificador marca se revisa a mano (`insights.flagged-review.json`, 41).
3. **El idioma del usuario**, sin vocabulario del prompt español colado («Dein Gasto», «ingressos»).
4. **Lo que exige la pantalla:** iconos SF Symbols de iOS ≤ 26, la divisa delante, una cifra por viñeta, largos máximos
   (180 caracteres por comentario, 132 por viñeta) y gráficas que existen.
5. **Juez de otro proveedor**, que no decide (ver abajo).

## El juez no decide

40 respuestas puntuadas leyendo cada una, antes de lanzar ningún juez (pasan 33). Un juez decide si κ ≥ 0,6 y el
acuerdo ≥ 85 %, y ninguno llega:

| Juez | Acuerdo | κ |
|---|---|---|
| Gemini 3.8 Flash | 85 % | 0,37 |
| Grok 4.3 | 76 % | 0,38 |
| gpt-oss-120b | 62 % | −0,19 |
| Los dos primeros juntos | 73 % | 0,32 |

Fallan en lo sutil: el 24 % del ingreso, «casi el doble» dicho de 2,5 veces, comparar con el mes en curso. En su
lugar: revisión manual de las cifras marcadas y lectura completa de la repetición 0 de las candidatas principales.

## Listón

- JSON aceptado al 100 %.
- Acierto ≥ `gpt-4.1-mini` y alto en absoluto, con 0 cifras inventadas: Insights ≥ 90 % y como mucho 1 contradicción en
  las 16 leídas; Tendencias ≥ 95 %.
- p95 en serie < 15 s (75 % del corte de 20 s).
- Entre los que pasan, el más barato.

## Por qué cada fila

- **Tarjetas.** `gpt-6-luna` low es la más barata que pasa. Fuera: `gpt-6-luna` none (2 contradicciones),
  `gpt-6.1-sol` (93,8 %, pero p95 15,9 s; alternativa de calidad si la app sube el corte a 25 s), Gemini 3.1 Flash-Lite
  (96,9 %, pero inventa una cifra y dos causas). La única contradicción de luna low: en c05 da 1 050 donde la suma es 990.
- **Flujo de caja y desviaciones.** Todos aciertan el 100 % sin contar el idioma; luna none iguala o supera a mini y
  cuesta 3-4 veces menos. Sus 28 respuestas, leídas a mano: ninguna contradice los datos.
- **Tendencias.** Solo Gemini 3.8 Flash y `gpt-6.1-sol` sacan el 100 %, sin contradicciones en las 16 leídas.

## Finalistas (acierto con la revisión manual; p95 de la pasada en serie)

### insights.cards (32 llamadas)

| Candidato | Acierto | Sin idioma | Inventadas | p95 | USD por 1 000 |
|---|---|---|---|---|---|
| gemini-3.1-flash-lite | 96,9 % | 96,9 % | 1 | 3,5 s | 1,223 |
| gpt-6.1-sol low | 93,8 % | 100 % | 0 | 15,9 s | 8,649 |
| **gpt-6-luna low** | **90,6 %** | 96,9 % | 0 | 9,4 s | 0,482 |
| gpt-6-luna none | 90,6 % | 93,8 % | 0 | 7,0 s | 0,422 |
| gpt-5.6-luna low | 87,5 % | 96,9 % | 0 | 9,4 s | 1,192 |
| gemini-3.8-flash low | 78,1 % | 81,3 % | 0 | 7,4 s | 3,376 |
| claude-haiku-5-5 none | 71,9 % | 93,8 % | 0 | 6,6 s | 0,691 |
| gpt-4.1-mini | 56,3 % | 100 % | 0 | 6,4 s | 1,369 |

### insights.cashflow (28 llamadas; todas al 100 % sin idioma)

| Candidato | Acierto | p95 | USD por 1 000 |
|---|---|---|---|
| llama-4-scout | 57,1 % | 1,7 s | 0,115 |
| gemini-3.1-flash-lite | 46,4 % | 1,1 s | 0,147 |
| **gpt-6-luna none** | **25,0 %** | 2,1 s | 0,052 |
| claude-haiku-5-5 none | 25,0 % | 1,8 s | 0,109 |
| gpt-4.1-mini | 21,4 % | 1,2 s | 0,194 |

### insights.deviation (28 llamadas; ~100 % sin idioma)

| Candidato | Acierto | p95 | USD por 1 000 |
|---|---|---|---|
| claude-haiku-5-5 low | 32,1 % | 1,5 s | 0,103 |
| llama-4-scout | 28,6 % | 1,8 s | 0,104 |
| **gpt-6-luna none** | **21,4 %** | 2,8 s | 0,048 |
| gemini-3.1-flash-lite | 21,4 % | 1,2 s | 0,121 |
| gpt-4.1-mini | 21,4 % | 1,1 s | 0,166 |

### trends.summary (32 llamadas)

| Candidato | Acierto | Inventadas | p95 | USD por 1 000 |
|---|---|---|---|---|
| gemini-3.8-flash low | 100 % | 0 | 4,2 s | 1,473 |
| **gpt-6.1-sol low** | **100 %** | 0 | 9,8 s | 4,490 |
| gemini-3.1-flash-lite | 96,9 % | 1 | 1,7 s | 0,607 |
| gpt-5.6-luna low | 87,5 % | 0 | 6,5 s | 0,612 |
| claude-haiku-5-5 low | 84,4 % | 0 | 7,9 s | 0,664 |
| gpt-6-luna none | 68,8 % | 0 | 2,9 s | 0,163 |
| gpt-4.1-mini | 68,8 % | 1 | 2,3 s | 0,601 |

## Lo que encontró el banco en la app

1. **Los prompts de flujo de caja y desviaciones no mandan el idioma**: casi todos los modelos contestan en español a
   quien no lo habla.
2. **`monthsPositive` y `monthsNegative` cuentan el saldo acumulado**, y los modelos lo leen como flujo.
3. **La etiqueta «Sept 26» / «9月 26» se lee como el día 26.**
4. **El enfoque de Tendencias menciona «cards» y «hero»**, que no existen en esa pantalla.
5. **El vocabulario del prompt español se cuela en otros idiomas**: «Dein Gasto», «gasto oscylował», «ingressos».

## Encender un proveedor que no es OpenAI

Gemini (Tendencias): textos de permisos y consentimiento en 16 idiomas, política de privacidad web publicada, nivel de
pago (no entrena con los datos; DPA y retención), `GEMINI_API_KEY` como secret del Worker, cuotas (hubo 429 y 503),
precio que se dobla el 2027-01-01 (~2,95 USD por 1 000, aún por debajo de `gpt-6.1-sol`) y comprobar su apagado en 12
meses. Después, `gpt-6.1-sol` pasa a `LEGACY_OVERRIDES`. Anthropic, Workers AI y xAI: ninguna fila los elige.

## Lo que no se midió

Latencia sobre red móvil; los nombres de mes y día de iOS (el banco usa `Intl`); el orden de claves aleatorio de la app;
juez sobre las finalistas (no fiable y ~5 USD); Sonnet como juez; la lectura a mano solo cubre la repetición 0;
`gpt-6-astra`, solo en la criba.
