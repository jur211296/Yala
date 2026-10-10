# Banco de modelos de IA — Claude Sonnet 5.5 y Haiku 5.5 en Insights y Tendencias

> Fecha: 2026-10-08. Encargo `banco-ia-sonnet-haiku-5-5-insights-tendencias` (card del tablero
> `tablero-banco-de-ia-medir-sonnet-5-5-y-haiku-5-5-asc1`). Sigue a `docs/ai-model-bench-2026-10.md` (sesión 2,
> PR #387). Datos crudos: `gateway/bench/results/2026-10-08-claude/`. Gasto: ≈ 1,84 USD, de los que 1,64 son de los
> créditos de Anthropic.

## Resultado

**Ninguno de los dos entra, ni como reemplazo ni como segundo proveedor.** Las filas de `gateway/src/ai/routes.ts` no
cambian y nada se enciende.

- **Tarjetas de Insights.** Ninguna variante de Claude pasa el listón. Sonnet 5.5 inventa ahorros y cuesta 35 veces más
  que `gpt-6-luna`. Haiku 5.5 sin razonar llega al 90,6 % sin cifras inventadas, pero en las 16 respuestas leídas a
  mano contradice los datos 3 veces, y el listón admite 1.
- **Tendencias.** Ningún Claude llega al 95 %: responden en español a quien usa la app en inglés o francés, o meten
  «Gasto» en una frase en alemán. El prompt de Tendencias pide el idioma solo con el código, el defecto que ya se
  arregló en Insights (ticket `trends-prompt-asks-the-language-by-bare-code`). Aun arreglado, Sonnet costaría 6,7 USD
  por 1 000 frente a 4,2 de `gpt-6.1-sol`, y el segundo proveedor preparado, Gemini 3.8 Flash, vuelve a ganar a los dos.
- **Los jueces del banco pasan a Sonnet 5.5**, como se pidió, con la excepción de que a Anthropic lo juzgan otros. En el
  chat es el mejor juez medido; en Insights no decide, igual que ninguno antes (ver «Los jueces»).

## `insights.cards` — 16 casos × 2 repeticiones, en serie

Listón: JSON 100 %, acierto ≥ 90 %, ninguna cifra inventada tras la revisión manual, como mucho 1 contradicción en las
16 respuestas de la repetición 0 y p95 < 15 s.

| Candidato | Acierto | Sin idioma | Inventadas | Contradicciones (16 leídas) | p95 | USD por 1 000 (lista) | Llamadas que cubren 1 000 USD de créditos |
|---|---|---|---|---|---|---|---|
| `gpt-6-luna` low (fila activa) | 96,9 % | 96,9 % | 1 | leída el 7-oct | 8,2 s | 0,435 | — |
| Sonnet 5.5 none | 93,8 % | 93,8 % | 2 | no se leyó | 9,0 s | 15,38 | 65 000 |
| Haiku 5.5 none | 90,6 % | 96,9 % | 0 | **3** | 5,5 s | 0,700 | 1,4 millones |
| Haiku 5.5 low | 84,4 % | 96,9 % | 1 | no se leyó | 6,1 s | 0,732 | 1,4 millones |
| Sonnet 5.5 low | 84,4 % | 93,8 % | 2 | no se leyó | 9,2 s | 15,66 | 64 000 |

- **Sonnet inventa ahorros.** «Cambiar dos visitas al restaurante libera unos 80–100 €» y «un abono en pausa ahorra hasta
  15 €» no salen de los datos: no hay número de visitas, y el abono medio cuesta 22,5 €. El criterio del 7-oct cuenta un
  ahorro estimado sin base como cifra inventada. Contados como consejo, Sonnet sin razonar llegaría al 100 %, pero a 35
  veces el precio de la fila activa.
- **Las contradicciones de Haiku sin razonar**: en c05 dice que el saldo (1 089 £) «casi cubre» el alquiler (1 050 £),
  que es menor; en c07, que 145 € es «casi lo mismo» que 90 € + 140 €; en c16, que el alquiler es «casi cuatro veces»
  los 210 $ de Salud, cuando es 6,2 veces. Una cuarta es dudosa: en c14 «已超出预算125%» se lee como «superó el
  presupuesto en un 125 %», y lo superó en un 25 %.
- **La fila activa también inventó una cifra hoy.** En c05, `gpt-6-luna` suma 1 023 £ donde la suma es 830 £. Es el
  mismo caso y el mismo tipo de error que su única contradicción del 7-oct (dio 1 050 £ donde eran 990 £): la fila
  tiene un punto débil en c05, no un fallo nuevo.

## `trends.summary` — 16 casos × 2 repeticiones, en serie

Listón: JSON 100 %, acierto ≥ 95 %, ninguna cifra inventada y p95 < 15 s.

| Candidato | Acierto | Sin idioma | Inventadas | p95 | USD por 1 000 (lista) | Llamadas que cubren 1 000 USD de créditos |
|---|---|---|---|---|---|---|
| Gemini 3.8 Flash low (preparado, apagado) | **100 %** | 100 % | 0 | 5,2 s | 1,533 | — |
| `gpt-6.1-sol` low (fila activa) | 96,9 % | 96,9 % | 0 | 8,6 s | 4,156 | — |
| Sonnet 5.5 low | 84,4 % | 96,9 % | 0 | 3,5 s | 6,774 | 148 000 |
| Sonnet 5.5 none | 81,3 % | 96,9 % | 0 | 3,6 s | 6,642 | 151 000 |
| Haiku 5.5 low | 71,9 % | 87,5 % | 0 | 7,3 s | 0,566 | 1,8 millones |
| Haiku 5.5 none | 53,1 % | 68,8 % | 0 | 2,8 s | 0,344 | 2,9 millones |

- **El idioma es lo que tumba a Claude.** Sonnet contesta entero en español a dos casos (`en-GB` y `fr`) y escribe «Dein
  Gasto», «Ingreso» o «aucun gasto» en otros. Haiku hace lo mismo en 7 a 9 de 32, y además se pasa de los 132
  caracteres por viñeta. OpenAI y Gemini no tropiezan con el mismo prompt.
- **Sin el idioma, Sonnet pasaría** (96,9 %) y es rápido (p95 3,5 s), pero a precio de lista cuesta un 63 % más
  que `gpt-6.1-sol` y 4,4 veces Gemini.
- **El fallo de `gpt-6.1-sol`** es de forma: en t11 omite la viñeta de la gráfica de tendencia.

## El precio con créditos

Los 1 000 USD de créditos de Claude Startups dejan el coste efectivo de Anthropic en 0 hasta agotarse o hasta vencer a
los 6 meses de reclamarlos. Eso no cambia la recomendación por dos razones:

1. **Ninguna variante pasa el listón**, y el banco decide primero por calidad.
2. **Los créditos caducan.** Una fila elegida por ser gratis durante 6 meses vuelve al precio de lista después, y en las
   dos tareas ese precio es mayor que el de la fila activa (Sonnet) o su calidad menor (Haiku).

El mejor uso de esos créditos que ha salido de aquí son **los jueces del banco**: pagan las revisiones trimestrales sin
tocar el saldo prepago de OpenAI, que es el mismo de producción.

## Los jueces

Desde hoy **Claude Sonnet 5.5 juzga a todos los proveedores menos a Anthropic**. A los candidatos de Anthropic los
juzgan Gemini 3.8 Flash en `chat.answer`, y Gemini y Grok 4.3 en Insights y Tendencias. Nadie juzga a su propio
proveedor. El código: `JUDGES` en `gateway/bench/lib/insightsJudge.ts` y el orden recomendado en
`gateway/bench/README.md`. Se queda así para la revisión trimestral.

Acuerdo con las muestras puntuadas a mano:

| Tarea | Juez | Respuestas | Acuerdo | κ de Cohen | ¿Decide? |
|---|---|---|---|---|---|
| `chat.answer` (medido el 7-oct) | Sonnet 5.5 | 24 | 100 % | 1,00 | sí |
| `chat.answer` (medido el 7-oct) | Gemini 3.8 Flash | 25 | 96 % | 0,83 | sí |
| Insights y Tendencias (medido hoy) | Sonnet 5.5 | 29 | 55 % | 0,23 | no |
| Insights y Tendencias (7-oct) | Gemini 3.8 Flash | 34 | 85 % | 0,37 | no |
| Insights y Tendencias (7-oct) | Grok 4.3 | 38 | 76 % | 0,38 | no |

- **En Insights, Sonnet es más estricto que la nota a mano**, no más descuidado. Sus 13 desacuerdos suspenden
  respuestas que la muestra aprobó, y 8 son por dos cosas: comparar el periodo en curso con uno completo (5), y leer
  `monthsPositive` como meses de flujo positivo (3). Las dos son defectos del prompt que el informe del 7-oct anotó como
  problemas de la app y no del modelo.
- **En Insights no decide ningún juez**, como antes: hace falta κ ≥ 0,6 y 85 % de acuerdo. Deciden el criterio
  determinista y la lectura a mano.
- **Coste del juicio**: 0,0045 USD por respuesta con Sonnet (29 juicios, 0,13 USD).

### Cambio del mismo día: en Insights juzga Gemini solo

Pedido por Jürgen el 2026-10-08, tras ver la tabla de arriba. **En `insights.cards`, `insights.cashflow` e
`insights.deviation` decide Gemini 3.8 Flash solo**, y Sonnet cuando el candidato es de Google: nadie juzga a su propio
proveedor. `trends.summary` y `chat.answer` siguen como arriba.

Poner a Gemini primero no bastaba: el banco junta a los dos primeros jueces de otro proveedor y exige que aprueben los
dos. Esa pareja era Gemini + Sonnet en cualquier orden, así que ningún veredicto cambiaba. Por eso en Insights decide uno.

Recalculado sobre los juicios ya pagados del 7-oct (`--agreement --date 2026-10-07`), sin llamadas nuevas:

| Veredicto del banco | Respuestas | Acuerdo | κ de Cohen |
|---|---|---|---|
| Insights, pareja (antes) | 30 | 67 % | 0,33 |
| Insights, Gemini solo (ahora) | 30 | 87 % | 0,52 |
| Las cuatro tareas juntas, antes → ahora | 40 | 63 % → 78 % | 0,30 → 0,39 |

Sigue sin decidir: κ 0,52 no llega al 0,6 del listón. Pero ahora mide lo que mide la nota a mano, y cuesta un juicio por
respuesta en vez de dos.

### 2026-10-10: en Tendencias también juzga Gemini solo

**En `trends.summary` decide Gemini 3.8 Flash solo**, y Grok 4.3 cuando el candidato es de Google. Antes decidía la
pareja que abría Sonnet. Nadie juzga a su propio proveedor. Insights y `chat.answer` no cambian, y tampoco el modelo que
sirve Tendencias en la app.

La muestra a mano de Tendencias tenía 10 respuestas. Se amplió a 40: 30 más del 7-oct, puntuadas antes de lanzar ningún
juez sobre ellas (`scored: 2026-10-10` en `insights.hand-scores.json`). Una respuesta entera en otro idioma que el del
usuario cuenta como no útil. Luego juzgaron los cuatro jueces (`--judges all --max-usd 1`).

| Juez en Tendencias | Respuestas | Acuerdo | κ de Cohen | Aprueba malas | Suspende buenas |
|---|---|---|---|---|---|
| Gemini 3.8 Flash | 33 | 79 % | 0,46 | 6 | 1 |
| Grok 4.3 | 37 | 78 % | 0,48 | 5 | 3 |
| gpt-oss-120b | 34 | 74 % | 0,27 | 8 | 1 |
| Sonnet 5.5 | 27 | 44 % | 0,14 | 0 | 15 |
| **Banco antes** (pareja que abre Sonnet) | 40 | 57 % | 0,23 | | |
| **Banco ahora** (Gemini solo, Grok de relevo) | 40 | 80 % | 0,48 | | |

- **Sonnet suspende 15 respuestas buenas y no aprueba ninguna mala.** Es más estricto que la nota a mano, como en
  Insights, y en la pareja su «no» decidía siempre.
- **Gemini y Grok empatan** (una respuesta de diferencia). Abre Gemini porque coincide algo más y es el mismo juez de
  Insights. Además cuesta menos (0,0011 frente a 0,0014 USD por juicio) y tarda 2,4 s de mediana frente a 32 s.
- **Sigue sin decidir**: κ 0,48 no llega al 0,6 del listón.
- **Gasto de API de la medición**: 0,16 USD (98 juicios).

## Qué se midió, y cómo

- **Los mismos casos y el mismo listón que el banco vigente**: 16 casos por tarea en 14 locales, el cuerpo exacto de la
  app con los prompts leídos del Swift de hoy y el mismo criterio (`gateway/bench/lib/insightsGrading.ts`).
- **El listón de Insights ya no era el 90,6 % del encargo.** Tras el arreglo del idioma del 7-oct por la noche
  (`results/2026-10-07-idioma/`), `gpt-6-luna` low sacaba el 100 %. Por eso las filas activas se midieron otra vez en
  la misma pasada, con el mismo prompt y la misma red.
- **Variantes de Claude**: Sonnet 5.5 sin razonar (`thinking: between_tools`) y con esfuerzo `low`; Haiku 5.5 sin
  razonar (`thinking: disabled`) y con esfuerzo `low`. Precios de `gateway/bench/candidates.ts`, que coinciden con la tabla oficial: Sonnet
  2/10 USD y Haiku 0,10/0,50 USD por millón de tokens de entrada y salida.
- **Todo en serie** (`--reps 2 --concurrency 1`, con el candado de latencia): las 352 llamadas valen para la latencia.
  Ningún error de transporte.
- **Revisión manual de cifras**: las 69 que el verificador marcó, leídas contra los datos del caso
  (`insights.flagged-review.json`): 49 derivadas, 13 consejos y 7 inventadas.

## Lo que no se midió

- La lectura a mano de Sonnet y de las filas activas: Sonnet ya no pasaba por las cifras inventadas, y las filas activas
  se leyeron el 7-oct.
- El juez sobre las respuestas de hoy: en Insights no decide, así que solo habría gastado créditos.
- Flujo de caja y desviaciones: el encargo pide tarjetas y Tendencias.
- Tendencias con el prompt de idioma arreglado: es un cambio de la app, fuera del encargo.
- La latencia sobre red móvil: el banco mide desde la Mini.
