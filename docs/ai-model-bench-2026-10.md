# Banco de modelos de IA — octubre 2026: las tres tareas de `gpt-4.1-nano`

> Fecha: 2026-10-07. Encargo `gpt-4-1-nano-shuts-down-on-october-23` (sesión 1 de
> `ai-model-choice-lives-in-the-app-binary`). Banco: `gateway/bench/` (cómo correrlo: su `README.md`). Datos crudos:
> `gateway/bench/results/2026-10-07/`. Precios comprobados ese día en las páginas oficiales (enlazadas en
> `gateway/bench/candidates.ts`). Gasto total del banco: ≈ 6 USD.

## Resultado

OpenAI apaga `gpt-4.1-nano` el 23-oct-2026. Sus tres tareas pasan a **`gpt-6-luna`** en el gateway, para todas las
versiones instaladas a la vez:

| Tarea | Antes | Ahora | Acierto antes → ahora | Coste por 1 000 llamadas | Latencia p95 (limpia) |
|---|---|---|---|---|---|
| Leer una foto (`photo.read`) | `gpt-4.1-nano`, `detail: auto` | `gpt-6-luna`, esfuerzo `low`, `detail: high` | **42 % → 96 %** | 0,71 → 0,53 USD | 6,7 s (corte de la app: 20 s) |
| Clasificar el mensaje del chat (`chat.intent`) | `gpt-4.1-nano`, temperatura 0 | `gpt-6-luna`, esfuerzo `none` | 97–98 % → **100 %** | 0,069 → 0,073 USD | 2,0 s (corte: 8 s) |
| Sugerencias del chat (`chat.suggestions`) | `gpt-4.1-nano`, temperatura 0,7 | `gpt-6-luna`, esfuerzo `none` | 97 % → **100 %** | 0,155 → 0,189 USD | 4,2 s (corte: 8 s) |

**Por qué `gpt-6-luna` en las tres:** es el modelo más barato que pasa el listón de cada tarea. Hay modelos que también
lo pasan, pero ninguno lo hace mejor en lo que importa. En la foto, los que sacan el 100 % estricto (Claude Haiku 4.5,
Grok, Gemini 3.8 Flash) solo ganan en la divisa de ¥ y zł, que el prompt de la app no enseña (ver «Lo que queda»), y
cuestan entre 6 y 10 veces más. Además, sin cabecera de tarea solo puede servir OpenAI: las versiones instaladas dicen en
sus permisos que la foto «se envía a OpenAI».

**Descartado a propósito:** `gpt-5.4-nano` (`detail: low`) sacó el 98 % en la foto, pero OpenAI lo apaga el 2027-04-01.
Elegirlo era volver a esta carrera en seis meses.

## Listón de cada tarea

Primero calidad medida, después precio (Jürgen, 2026-10-07). Un candidato pasa si cumple **todo**:

- **JSON que la app acepta al 100 %.** El criterio replica primero el parser de la app: si la app lo rechazaría, es fallo.
- **Acierto igual o mejor que `gpt-4.1-nano`, y además alto en absoluto.** En la foto, nano solo acierta el 42 %, así que
  «igual que nano» no basta. Listón de la foto: **100 % en lo grave** (importe con su signo, fecha y número de
  movimientos) y ≥ 95 % estricto (lo grave más la divisa). En el clasificador y las sugerencias: ≥ 99 %.
- **Latencia p95 por debajo del 75 % del corte de la app**: 6 s para el clasificador y las sugerencias (la app corta a los
  8 s, `timeoutSeconds = 8`) y 15 s para la foto (corta a los 20 s, y la foto tiene que subir antes).
- **Sin apagado anunciado** por el proveedor en los próximos 12 meses.

Entre los que pasan, gana el de menor coste por llamada.

## Cómo se midió

- **La misma petición que la app.** Prompts leídos del código Swift (`gateway/bench/lib/appRequests.ts`), la forma del
  SDK MacPaw y, en la foto, el JPEG con calidad 0,8. Pasa por los mismos adaptadores que usa el gateway.
- **Casos sin datos personales** (`gateway/bench/cases/`):
  - Clasificador: 115 frases en 12 locales (es-PE, es-ES, en, pt-BR, pt-PT, fr, de, it, nl, pl, ja, zh-Hans), con
    jerga y montos locales.
  - Sugerencias: 16 contextos de usuario en 12 idiomas.
  - Foto: 26 imágenes. Doce son ejemplos que enseña la app (recibos, alertas bancarias y listas de movimientos, en seis
    idiomas). Catorce son capturas generadas con datos ficticios: notificaciones de bancos peruanos con fechas
    relativas, un extracto de 20 filas, un extracto de tarjeta en USD, una boleta de 29 líneas fotografiada, tickets
    alemán y polaco fotografiados con poca luz, avisos en japonés y chino, modo oscuro, un ingreso y una captura que no
    es financiera.
- **Dos pasadas.** Primero un cribado de todos los candidatos, a resolución original. Después, para las finalistas, una
  segunda pasada **en serie** (una llamada cada vez) que da la latencia limpia y una repetición para medir la variación.
  Las latencias marcadas con * vienen del cribado en paralelo, con la subida de las fotos saturando la conexión de
  casa: sirven para ordenar, no como medida.
- **Candidatos.**
  - OpenAI: `gpt-4.1-nano` (línea base), `gpt-4.1-mini`, `gpt-6-luna`, `gpt-5.6-luna`, `gpt-5.4-mini`, `gpt-5.4-nano` y
    `gpt-5.6-terra`. Los de razonamiento, con esfuerzo `none` y `low`.
  - Google: Gemini 3.5 Flash-Lite, 3.1 Flash-Lite y 3.8 Flash.
  - Anthropic: Claude Haiku 4.5 y Claude Sonnet 5.5.
  - xAI: Grok 4.20 sin razonamiento y Grok 4.3.
  - Modelos abiertos alojados en Cloudflare Workers AI: Llama 4 Scout, Mistral Small 3.1 y gpt-oss-20b.

¹ **Núcleo (solo foto):** importe con su signo, fecha y número de movimientos; la divisa no cuenta.
² **Errores:** fallos de transporte (429, 5xx) que siguieron fallando al reanudar. Cuentan como fallo.
³ **p50 / p95:** latencia de la pasada en serie. Con *, del cribado en paralelo.

## Leer una foto (`photo.read`)

Todos a resolución original (lo que hoy manda la app). La tabla completa, con todas las resoluciones, está en
`gateway/bench/results/2026-10-07/photo.read.md`.

| Candidato | Proveedor | Esfuerzo | Detalle | Lado mayor | Llamadas | Acierto | Núcleo¹ | JSON aceptado | Errores² | p50 / p95 ms³ | Tokens entrada / salida | USD por 1 000 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `mistral-small-3.1` | workersai | — | auto | original | 26 | 100.0 % | 100 % | 100 % | 0 | 19127 / 49504* | 2727 / 252 | 1.097 |
| `gemini-3.8-flash` | gemini | low | high | original | 26 | 100.0 % | 100 % | 100 % | 0 | 7805 / 16652* | 2205 / 367 | 3.029 |
| `claude-haiku-4-5` | anthropic | none | auto | original | 26 | 100.0 % | 100 % | 100 % | 0 | 5047 / 9636* | 2995 / 223 | 4.111 |
| `grok-4.3` | xai | — | high | original | 26 | 100.0 % | 100 % | 100 % | 0 | 9823 / 16793* | 3580 / 213 | 5.007 |
| `grok-4.20-non-reasoning` | xai | — | high | original | 26 | 100.0 % | 100 % | 100 % | 0 | 3679 / 11063* | 3570 / 264 | 5.122 |
| `claude-sonnet-5-5` | anthropic | none | auto | original | 26 | 100.0 % | 100 % | 100 % | 0 | 7378 / 12998* | 5877 / 270 | 14.455 |
| `gpt-5.4-nano` | openai | none | low | original | 52 | 98.1 % | 100 % | 100 % | 0 | 2186 / 6049 | 3360 / 269 | 0.845 |
| `gpt-6-luna` | openai | low | high | original | 52 | 96.2 % | 100 % | 100 % | 0 | 3109 / 6729 | 3834 / 283 | 0.525 |
| `gpt-5.6-luna` | openai | none | high | original | 52 | 96.2 % | 100 % | 100 % | 0 | 2500 / 10154 | 3321 / 223 | 0.931 |
| `gemini-3.1-flash-lite` | gemini | — | high | original | 26 | 96.2 % | 100 % | 100 % | 0 | 25839 / 84136* | 2205 / 304 | 1.007 |
| `gemini-3.5-flash-lite` | gemini | low | high | original | 26 | 96.2 % | 100 % | 100 % | 0 | 14424 / 28995* | 2205 / 323 | 1.469 |
| `gemini-3.5-flash-lite` | gemini | none | high | original | 26 | 96.2 % | 100 % | 100 % | 0 | 9140 / 17629* | 2205 / 323 | 1.469 |
| `gpt-4.1-mini` | openai | — | high | original | 26 | 96.2 % | 96 % | 100 % | 0 | 9207 / 19400* | 4199 / 250 | 2.079 |
| `gpt-4.1-mini` | openai | — | low | original | 26 | 96.2 % | 96 % | 100 % | 0 | 7879 / 16988* | 4199 / 257 | 2.090 |
| `gpt-5.4-mini` | openai | low | high | original | 26 | 96.2 % | 100 % | 100 % | 0 | 5177 / 10792* | 3321 / 322 | 3.937 |
| `gpt-5.4-nano` | openai | none | high | original | 52 | 92.3 % | 98 % | 100 % | 0 | 2245 / 7382 | 3321 / 267 | 0.998 |
| `gpt-5.6-luna` | openai | low | high | original | 26 | 92.3 % | 100 % | 100 % | 0 | 7580 / 18266* | 3321 / 289 | 1.011 |
| `llama-4-scout` | workersai | — | auto | original | 26 | 92.3 % | 92 % | 100 % | 0 | 12485 / 51578* | 3212 / 218 | 1.052 |
| `gpt-5.4-mini` | openai | none | high | original | 26 | 92.3 % | 100 % | 100 % | 0 | 5065 / 8582* | 3321 / 202 | 3.401 |
| `gpt-5.6-terra` | openai | none | high | original | 26 | 92.3 % | 100 % | 100 % | 0 | 6518 / 11203* | 3321 / 175 | 8.746 |
| `gpt-5.6-terra` | openai | low | high | original | 26 | 92.3 % | 100 % | 100 % | 0 | 6570 / 12156* | 3321 / 184 | 8.854 |
| `claude-sonnet-5-5` | anthropic | low | auto | original | 26 | 92.3 % | 100 % | 100 % | 0 | 6444 / 11371* | 5878 / 270 | 14.453 |
| `gpt-6-luna` | openai | none | high | original | 52 | 90.4 % | 100 % | 100 % | 0 | 2916 / 5768 | 3834 / 249 | 0.508 |
| `gpt-5.4-nano` | openai | low | low | original | 26 | 88.5 % | 100 % | 100 % | 0 | 7283 / 20619* | 3360 / 366 | 1.130 |
| `gpt-5.4-nano` | openai | low | high | original | 26 | 84.6 % | 96 % | 100 % | 0 | 8131 / 18457* | 3321 / 345 | 1.095 |
| `gpt-5.6-luna` | openai | low | low | original | 26 | 69.2 % | 69 % | 100 % | 0 | 14697 / 25390* | 1126 / 428 | 0.739 |
| `gpt-6-luna` | openai | low | low | original | 26 | 53.8 % | 65 % | 100 % | 0 | 16000 / 24626* | 1126 / 398 | 0.312 |
| `gpt-5.6-luna` | openai | none | low | original | 26 | 46.2 % | 54 % | 100 % | 0 | 9370 / 19848* | 1126 / 212 | 0.479 |
| `gpt-6-luna` | openai | none | low | original | 26 | 42.3 % | 58 % | 100 % | 0 | 8268 / 17988* | 1126 / 202 | 0.214 |
| `gpt-4.1-nano` | openai | — | auto | original | 26 | 42.3 % | 77 % | 100 % | 0 | 6184 / 18105* | 5876 / 297 | 0.706 |

**Lo que se ve:**

- **nano falla sobre todo la divisa.** Devuelve `S/` en vez de `PEN`, así que la app no casa la cuenta. En los recibos
  además pierde el total. Su 77 % de núcleo es el techo de lo que hoy reciben los usuarios.
- **`detail: low` es inservible en la familia 5.6/6** (512 × 512 px): baja del 96 % al 54 %. La fila usa `high`.
- **Los fallos que quedan en los buenos son de divisa en ¥ y zł** (`s07`, `s08`, `s09`): el modelo devuelve `null`
  porque el prompt solo enseña $, €, S/ y £.

### Resolución: el `maxEdge` para la sesión 2

| Modelo | Lado mayor | Llamadas | Acierto | Fallos | Tokens de entrada | USD por 1 000 |
|---|---|---|---|---|---|---|
| `gpt-5.6-luna` | original | 78 | 94.9 % | s07-card-ja, s08-payment-zh | 3321 | 0.958 |
| `gpt-5.6-luna` | 2048 | 52 | 90.4 % | app-list-en, s07-card-ja, s08-payment-zh | 3321 | 0.948 |
| `gpt-5.6-luna` | 1536 | 78 | 94.9 % | s07-card-ja, s09-receipt-pl | 2377 | 0.767 |
| `gpt-5.6-luna` | 1024 | 52 | 94.2 % | s07-card-ja, s08-payment-zh | 1583 | 0.635 |
| `gpt-5.6-luna` | 768 | 52 | 88.5 % | s02-statement, s07-card-ja, s08-payment-zh, s04-long-receipt | 1331 | 0.597 |
| `gpt-6-luna` | original | 52 | 96.2 % | s07-card-ja, s08-payment-zh | 3834 | 0.525 |
| `gpt-6-luna` | 2048 | 26 | 92.3 % | s07-card-ja, s08-payment-zh | 3321 | 0.462 |
| `gpt-6-luna` | 1536 | 52 | 94.2 % | s08-payment-zh, s07-card-ja | 2377 | 0.379 |
| `gpt-6-luna` | 1024 | 26 | 92.3 % | s08-payment-zh, s09-receipt-pl | 1583 | 0.309 |
| `gpt-6-luna` | 768 | 26 | 88.5 % | s07-card-ja, s08-payment-zh, s09-receipt-pl | 1331 | 0.296 |

La calidad es plana de 1024 px al original, y a 768 px empieza a perder el extracto y la boleta larga. Hay que cuidar la
sobrelectura de esta tabla: con 26 casos, un caso son 4 puntos, y los fallos de 1024 y 1536 son los mismos de divisa que
a resolución original. **`maxEdge = 1536`** deja margen para fotos reales de papel térmico gastado, que el banco
representa poco, con un 38 % menos de tokens que la original. La app reducirá la foto en la sesión 2. Hasta entonces la
foto llega entera y `gpt-6-luna` la reduce por su cuenta.

## Clasificar el mensaje del chat (`chat.intent`)

| Candidato | Proveedor | Esfuerzo | Llamadas | Acierto | JSON aceptado | Errores² | p50 / p95 ms³ | Tokens entrada / salida | USD por 1 000 |
|---|---|---|---|---|---|---|---|---|---|
| `gpt-6-luna` | openai | none | 144 | 100.0 % | 100 % | 0 | 1222 / 1983 | 647 / 17 | 0.073 |
| `gpt-6-luna` | openai | low | 115 | 100.0 % | 100 % | 0 | 9285 / 14552* | 647 / 44 | 0.087 |
| `gpt-5.6-luna` | openai | none | 144 | 100.0 % | 100 % | 0 | 1192 / 1502 | 647 / 17 | 0.150 |
| `gpt-5.6-luna` | openai | low | 115 | 100.0 % | 100 % | 0 | 6517 / 8068* | 647 / 17 | 0.150 |
| `gpt-5.4-nano` | openai | low | 115 | 100.0 % | 100 % | 0 | 5471 / 7080* | 647 / 22 | 0.157 |
| `gpt-oss-20b` | workersai | low | 115 | 100.0 % | 100 % | 0 | 3764 / 5898* | 710 / 53 | 0.158 |
| `llama-4-scout` | workersai | — | 115 | 100.0 % | 100 % | 0 | 3219 / 3843* | 640 / 15 | 0.185 |
| `gemini-3.1-flash-lite` | gemini | — | 115 | 100.0 % | 100 % | 0 | 61229 / 131642* | 690 / 21 | 0.204 |
| `gemini-3.5-flash-lite` | gemini | low | 144 | 100.0 % | 100 % | 0 | 845 / 1108 | 690 / 21 | 0.260 |
| `gemini-3.5-flash-lite` | gemini | none | 144 | 100.0 % | 100 % | 0 | 851 / 1213 | 690 / 21 | 0.260 |
| `gpt-4.1-mini` | openai | — | 144 | 100.0 % | 100 % | 0 | 703 / 902 | 648 / 11 | 0.277 |
| `gpt-5.4-mini` | openai | low | 115 | 100.0 % | 100 % | 0 | 5362 / 8087* | 647 / 38 | 0.657 |
| `gemini-3.8-flash` | gemini | low | 115 | 100.0 % | 100 % | 0 | 5975 / 9459* | 690 / 63 | 0.752 |
| `claude-haiku-4-5` | anthropic | none | 144 | 100.0 % | 100 % | 0 | 849 / 1218 | 959 / 14 | 1.029 |
| `grok-4.3` | xai | — | 115 | 100.0 % | 100 % | 0 | 8264 / 11071* | 856 / 17 | 1.112 |
| `gpt-5.6-terra` | openai | low | 115 | 100.0 % | 100 % | 0 | 6753 / 8164* | 647 / 17 | 1.500 |
| `claude-sonnet-5-5` | anthropic | none | 115 | 100.0 % | 100 % | 0 | 4517 / 5740* | 1296 / 18 | 2.772 |
| `claude-sonnet-5-5` | anthropic | low | 115 | 100.0 % | 100 % | 0 | 4738 / 8196* | 1297 / 19 | 2.784 |
| `gpt-5.4-nano` | openai | none | 144 | 99.3 % | 100 % | 0 | 854 / 1104 | 647 / 18 | 0.152 |
| `gpt-5.4-mini` | openai | none | 115 | 99.1 % | 100 % | 0 | 4620 / 5577* | 647 / 17 | 0.563 |
| `grok-4.20-non-reasoning` | xai | — | 115 | 99.1 % | 100 % | 0 | 2701 / 4388* | 848 / 18 | 1.105 |
| `gpt-5.6-terra` | openai | none | 115 | 99.1 % | 99 % | 1 | 7850 / 8733* | 647 / 17 | 1.500 |
| `gpt-4.1-nano` | openai | — | 144 | 97.9 % | 100 % | 0 | 722 / 1003 | 648 / 11 | 0.069 |
| `mistral-small-3.1` | workersai | — | 115 | 94.8 % | 100 % | 0 | 4128 / 7941* | 709 / 17 | 0.258 |

## Sugerencias del chat (`chat.suggestions`)

Criterio: el parser de la app las acepta, hay al menos 8 válidas, al menos el 90 % están en el idioma pedido y al menos
la mitad nombra un dato del usuario.

| Candidato | Proveedor | Esfuerzo | Llamadas | Acierto | JSON aceptado | Errores² | p50 / p95 ms³ | Tokens entrada / salida | USD por 1 000 |
|---|---|---|---|---|---|---|---|---|---|
| `gpt-6-luna` | openai | none | 32 | 100.0 % | 100 % | 0 | 3501 / 4191 | 375 / 303 | 0.189 |
| `gpt-6-luna` | openai | low | 16 | 100.0 % | 100 % | 0 | 24337 / 28579* | 375 / 362 | 0.219 |
| `mistral-small-3.1` | workersai | — | 16 | 100.0 % | 100 % | 0 | 33580 / 36062* | 403 / 307 | 0.312 |
| `gpt-5.6-luna` | openai | none | 32 | 100.0 % | 100 % | 0 | 2868 / 3494 | 375 / 236 | 0.359 |
| `gpt-5.6-luna` | openai | low | 16 | 100.0 % | 100 % | 0 | 22824 / 25845* | 375 / 348 | 0.493 |
| `gemini-3.1-flash-lite` | gemini | — | 16 | 100.0 % | 100 % | 0 | 35328 / 135668* | 397 / 322 | 0.583 |
| `gemini-3.5-flash-lite` | gemini | low | 16 | 100.0 % | 100 % | 0 | 7643 / 24136* | 397 / 346 | 0.985 |
| `gemini-3.5-flash-lite` | gemini | none | 16 | 100.0 % | 100 % | 0 | 17417 / 22398* | 397 / 363 | 1.028 |
| `gpt-5.4-mini` | openai | none | 16 | 100.0 % | 100 % | 0 | 14757 / 24362* | 375 / 286 | 1.569 |
| `gpt-5.4-mini` | openai | low | 16 | 100.0 % | 100 % | 0 | 16540 / 20087* | 375 / 386 | 2.019 |
| `gpt-5.6-terra` | openai | low | 16 | 100.0 % | 100 % | 0 | 22011 / 24074* | 375 / 232 | 3.528 |
| `gpt-5.6-terra` | openai | none | 16 | 100.0 % | 100 % | 0 | 22158 / 23754* | 375 / 234 | 3.555 |
| `claude-sonnet-5-5` | anthropic | low | 16 | 100.0 % | 100 % | 0 | 13350 / 14665* | 929 / 430 | 6.158 |
| `claude-sonnet-5-5` | anthropic | none | 16 | 100.0 % | 100 % | 0 | 13511 / 17052* | 928 / 437 | 6.229 |
| `gpt-4.1-nano` | openai | — | 32 | 96.9 % | 100 % | 0 | 3165 / 4917 | 376 / 293 | 0.155 |
| `gpt-4.1-mini` | openai | — | 32 | 96.9 % | 100 % | 0 | 3431 / 6416 | 376 / 303 | 0.635 |
| `claude-haiku-4-5` | anthropic | none | 32 | 96.9 % | 100 % | 0 | 3119 / 6300 | 682 / 303 | 2.199 |
| `llama-4-scout` | workersai | — | 16 | 93.8 % | 100 % | 0 | 30347 / 39561* | 381 / 272 | 0.334 |
| `gpt-5.4-nano` | openai | none | 16 | 93.8 % | 100 % | 0 | 18011 / 24923* | 375 / 318 | 0.472 |
| `gpt-5.4-nano` | openai | low | 16 | 93.8 % | 100 % | 0 | 17599 / 18359* | 375 / 325 | 0.481 |
| `grok-4.20-non-reasoning` | xai | — | 16 | 93.8 % | 100 % | 0 | 10012 / 11206* | 570 / 298 | 1.456 |
| `gemini-3.8-flash` | gemini | low | 16 | 93.8 % | 100 % | 0 | 13010 / 14269* | 397 / 366 | 1.668 |
| `grok-4.3` | xai | — | 16 | 81.2 % | 100 % | 0 | 28751 / 34148* | 578 / 268 | 1.391 |
| `gpt-oss-20b` | workersai | low | 16 | 68.8 % | 100 % | 0 | 18298 / 27973* | 438 / 338 | 0.189 |

## Lo que observamos de cada proveedor

- **Gemini:** el nivel gratuito agota la cuota en minutos (429) y da 503 «alta demanda» incluso en el de pago. Sin
  facturación, Google usa las peticiones para entrenar. Gemini 3.8 Flash saca el 100 % en la foto, a 3 USD por 1.000.
- **Anthropic:** Claude Haiku 4.5 saca el 100 % en la foto y en el clasificador, a 4,1 y 1,0 USD por 1.000. No tiene modo
  «JSON libre», así que se le pasa el esquema (`output_config.format`).
- **xAI (Grok):** el 100 % en la foto con las dos versiones, a unos 5 USD por 1.000. En las sugerencias, por debajo (81–94 %).
- **Workers AI:** Mistral Small 3.1 saca el 100 % en la foto, pero con p95 de 50 s. Los modelos abiertos alojados quedan
  lejos en latencia.

## Lo que queda (sesión 2: `ai-every-call-sends-its-task-and-passes-the-bench`)

- **Divisas fuera del prompt.** El prompt de la foto solo enseña $, €, S/ y £, y Yala está en japonés, chino, polaco y
  portugués de Brasil. Enseñar ¥ (JPY o CNY según el contexto), R$, zł y el resto de símbolos de los 10 idiomas, y volver
  a medir: es lo que separa a `gpt-6-luna` del 100 %.
- **Reducir la foto en la app** a 1536 px (`maxEdge` de la fila).
- **Segundo proveedor:** hoy no se justifica. Lo que ganan es la divisa del punto anterior, a 6–10 veces el coste. Si
  tras arreglar el prompt sigue habiendo diferencia, su lista de requisitos está en el ticket de la sesión 2.
- **Revisión periódica:** `cd gateway && npm run bench -- --task all` (ver `gateway/bench/README.md`).
