# Banco de chat y nota — 2026-10-07 (sesión 2, trabajador A)

> Paso 3 de `tickets/backlog/ai-every-call-sends-its-task-and-passes-the-bench.md` para las tres tareas que hoy usan
> `gpt-4.1-mini`: `text.parse`, `chat.answer` y `chat.rewrite`. Banco: `gateway/bench/` (README, sección del juez al
> final). Datos crudos: esta carpeta (pasada en serie de las finalistas) y `criba/` (todos los candidatos, con un
> subconjunto de casos). Precios comprobados ese día en las páginas oficiales (`gateway/bench/candidates.ts`).
> Gasto: ≈ 9,45 USD (OpenAI 1,31 · Gemini 3,79 · Anthropic 3,13 · xAI 0,91 · Workers AI 0,32; jueces, 4,40 del total).

## Resultado

Las tres tareas pasan a **`gpt-6-luna`**: mejoran o igualan a `gpt-4.1-mini`, cuestan entre 3,5 y 7 veces menos y
responden muy por debajo de su corte. Acierto y latencia salen de la pasada en serie completa (dos repeticiones).

| Tarea | Fila | Acierto (hoy → nuevo) | p95 (límite) | USD por 1 000 (hoy → nuevo) |
|---|---|---|---|---|
| `text.parse` | `gpt-6-luna`, esfuerzo `low`, texto, tope 1500 | 90,9 % → **97,7 %** (44 frases × 2) | 3,7 s (15 s) | 0,589 → **0,146** |
| `chat.answer` | `gpt-6-luna`, esfuerzo `none`, texto, tope 512 | 98,5 % → **100 %** (33 preguntas × 2) | 2,1 s (15 s) | 1,455 → **0,203** |
| `chat.rewrite` | `gpt-6-luna`, esfuerzo `none`, `json_object`, tope 300 | 100 % → **100 %** (14 × 2) | 2,1 s (6 s) | 0,198 → **0,056** |

- **Por qué:** es el más barato que pasa el listón en las tres. En `text.parse` el esfuerzo importa: sin razonar,
  `gpt-6-luna` se queda en 85,7 %.
- **Tope de salida:** la regla p99 × 2 daba 750 / 140 / 150 (p99: 373, 67 y 72 tokens, razonamiento incluido) y dejaba
  justos casos que el banco no tiene (notas de 5 movimientos, 10 frases a reescribir en alemán). La tabla usa el margen
  que propone el banco: 1500 / 512 / 300. Un JSON truncado hace que la app pierda la nota.
- **Desempate en `chat.answer`:** con esfuerzo `low` también saca el 100 % en la serie, por 0,208 USD frente a 0,203.
  Por la regla gana `none`.
- **Reserva de OpenAI:** no hace falta `LEGACY_OVERRIDES`, porque el ganador ya es de OpenAI. Si `gpt-6-luna` cayera, la
  siguiente que pasa es `gpt-5.6-luna` (`text.parse` low 97,7 %, 0,284; `chat.rewrite` none 100 %, 0,121); para
  `chat.answer`, `gpt-6-luna` low o mini (98,5 %).

## Listón

Un candidato pasa si cumple todo:

- **Lo que la app acepta, al 100 %:** el JSON de `text.parse` y `chat.rewrite` según su parser, replicado; en
  `chat.answer`, una respuesta no vacía.
- **Acierto igual o mejor que `gpt-4.1-mini` y ≥ 95 %:**
  - `text.parse`: un movimiento mal leído se cuela, pero el usuario ve el borrador antes de guardar. Mini saca 90,9 %.
  - `chat.answer`: la parte que no es determinista la decide un juez con un 96–100 % de acuerdo; pedir un 99 % sería
    exigirle más precisión de la que tiene.
  - `chat.rewrite`: mini saca el 100 %, así que «igual o mejor» ya exige el 100 %.
- **p95 por debajo del 75 % del corte:** 15 s en `text.parse` (hereda el `timeoutInterval` de 20 s) y en `chat.answer`
  (20 s); 6 s en `chat.rewrite` (8 s).
- **Sin apagado anunciado en 12 meses.**

Entre los que pasan, gana el más barato.

## Cómo se midió

- **Prompts:** se leen del Swift con `bench/lib/swift.ts`, y los tests lo fijan. Los parámetros son los de hoy y las
  llamadas pasan por los mismos adaptadores que el gateway.
- **`text.parse`:** recibe las 53 subcategorías de gasto y 9 de ingreso del seed con su nombre en el `.lproj` del usuario
  (`bench/lib/appCatalog.ts`), más subcategorías propias en tres casos.
- **`chat.answer`:** recibe el JSON de `FullFinancialContextBuilder`, replicado en `bench/lib/chatContext.ts`: 14 personas
  inventadas, una por locale, con un año de movimientos (~420–460) generado de forma determinista y agregado con las
  reglas del builder. El prompt de sistema mide unos 6.300 tokens.
- **`chat.rewrite`:** recibe exactamente las frases que el `isValid` replicado manda a reescribir; un test lo comprueba.
- **Casos**, en 14 locales: 44 frases dictadas (miles y decimales locales, «28万円», «一万二», divisas ajenas, «lucas»,
  fechas relativas, comercios locales, varias transacciones por frase); 33 preguntas (cuánto gasté, comparado con el mes
  pasado, presupuesto restante, comercio y día con más gasto, pagos fijos y pendientes, saldo, ahorro, seguimientos, sin
  datos y fuera de tema); 14 reescrituras.
- **Dos pasadas:** criba en paralelo con un subconjunto (14 / 12 / 14) y todos los candidatos, y pasada completa de las
  finalistas con `--reps 2 --concurrency 1` bajo el candado; la latencia sale solo de ahí.

## Criterios

- **`text.parse`:** primero lo que hace la app (`parseMultipleResponse` con `JSONDecoder` estricto y el filtro del chat:
  importe > 0 y < 1e6). Después, cada movimiento esperado se empareja por importe, tipo, fecha efectiva, divisa efectiva y
  subcategoría resuelta con `DraftBuilder.matchSubcategoryByHint`. No puede sobrar ninguno. El comercio y las etiquetas se
  miden aparte.
- **`chat.answer`:** (a) fidelidad: toda cifra sale del contexto, exacta, redondeada o truncada, o de una operación
  documentada; (b) idioma; (c) responde: aparece alguna cifra o nombre esperado. Lo demás lo decide el juez.
- **`chat.rewrite`:** primero `parseRewritten`; tantas frases como se pidieron, cada una ≤ 80 caracteres, en el idioma
  pedido y sin el nombre inventado; al menos la mitad con un nombre real del usuario.

## El juez de `chat.answer`

La muestra son 36 respuestas que pasaban el criterio determinista, **puntuadas por Frank leyendo cada respuesta** antes de
ver a ningún juez: 31 bien y 5 mal (`criba/chat.answer.handscore.json`, con el porqué de cada nota).

| Juez | Acuerdo con la muestra | κ de Cohen |
|---|---|---|
| Gemini 3.8 Flash | 96 % (24/25) | 0,83 |
| Claude Sonnet 5.5 | 100 % (24/24) | 1,00 |
| Claude Haiku 5.5 | 83 % | 0,52 (descartado) |

Gemini juzga a todos menos a Google, y a Google lo juzga Sonnet: nadie juzga a su propio proveedor.

## Finalistas (pasada en serie)

| Tarea | Candidato | Acierto | p95 | USD por 1 000 |
|---|---|---|---|---|
| `text.parse` | grok-4.20 sin razonar | 100 % | 6,2 s | 3,10 |
| | gpt-6-luna low | 97,7 % | 3,7 s | 0,146 |
| | gpt-5.6-luna low | 97,7 % | 3,3 s | 0,284 |
| | claude-haiku-5-5 sin razonar | 95,5 % | 1,5 s | 0,392 |
| | gemini-3.1-flash-lite | 93,2 % | 1,6 s | 0,819 |
| | gpt-4.1-mini (hoy) | 90,9 % | 3,2 s | 0,589 |
| `chat.answer` | gpt-6-luna none | 100 % | 2,1 s | 0,203 |
| | gpt-6-luna low | 100 % | 2,2 s | 0,208 |
| | gpt-oss-120b (Workers AI) | 100 % | 5,0 s | 2,33 |
| | gpt-4.1-mini (hoy) | 98,5 % | 1,6 s | 1,455 |
| | claude-haiku-5-5 low | 90,9 % | 3,7 s | 1,12 |
| `chat.rewrite` | gpt-6-luna, haiku-5-5, gpt-5.6-luna, llama-4-scout, gemini-3.1-flash-lite, mini, grok-4.20 | 100 % todos | ≤ 2,1 s | 0,056 – 0,766 |

Grok 4.20 saca el 100 % en `text.parse`, a 21 veces el coste y fuera de OpenAI (paso 7: no se puede encender hoy).

## Lo que se ve

- **Jerga regional:** «18 lucas» en Lima se lee como 18 000 (en Perú una luca es un sol).
- **Divisas que el prompt de `text.parse` no enseña** (solo seis): «Franken» sale EUR y los «pesos» argentinos, MXN o PEN.
- **La trampa del mes en curso** en `chat.answer`: el contexto no trae «el mes pasado hasta hoy», y comparar con el mes a
  medias es la mayor fuente de respuestas equivocadas.
- **Los modelos flojos copian el ejemplo español del prompt** con usuarios ingleses; `gpt-6-luna` nunca.

## Qué exigiría encender otro proveedor (paso 7)

Los textos de `aiConsent.*` y de los permisos, `Web/privacy_content.md` publicada, contrato y retención (Gemini solo de
pago), la clave como secret del Worker (`ANTHROPIC_API_KEY`, `GEMINI_API_KEY` y `XAI_API_KEY` ya están en `env.ts`;
Workers AI no tiene binding), cuotas (xAI dio 429 «at capacity»; el prepago de Anthropic se agotó durante el banco) y su
`LEGACY_OVERRIDES` con la fila de OpenAI.

## Lo que no se midió

- `gpt-5.5` y `gpt-6-astra` (no hacían falta: los más baratos pasan), Gemini 3.1 Pro (preview), y DeepSeek V4 Flash y
  Gemma 4 26B de Workers AI (devuelven vacío tras agotar el tope razonando).
- `chat.answer`: tonos y enfoques distintos del de por defecto, la sección `anomalies`, varias divisas, más de un turno
  previo y contextos de más de ~17 000 caracteres.
- `text.parse`: notas de más de 2 movimientos y errores de transcripción reales (eso es del banco de voz).
- La latencia desde un iPhone en Lima: el banco mide desde este Mac. El acuerdo del juez está medido con 36 respuestas.
