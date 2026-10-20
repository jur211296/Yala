# Revisión de Yala IA para 2.2 — octubre 2026

> Fecha: 2026-10-20. Árbol: `origin/2.2` + esta sesión. Card `tablero-revisar-a-fondo-como-usa-yala-la-ia-priv-u6iq`.
> Todo lo medido sale de un banco de 50 preguntas contra **staging** (nunca producción), dos pasadas antes y dos
> después, sobre la semilla `realista`. No cambia modelo, proveedor, cuota, precio ni la UI.

## Resumen

1. **Yala IA respondía mal el saldo**: con la semilla `realista` decía S/ 37.631 y el Panel S/ 71.569. Contaba solo
   los últimos 13 meses de movimientos y se dejaba fuera los saldos iniciales. Ahora dice lo mismo que el Panel.
2. **Ahora sabe más de lo que ya se le mandaba en resumen**: cada uno de los 12 meses anteriores, lo que va del año por
   categoría, los ingresos por categoría, todos los pagos programados y el tipo de cambio. Todo cabe en lo que dice el
   aviso de privacidad («un resumen de tus últimos 13 meses…»): no sale ningún dato de un tipo nuevo.
3. **El banco pasó de 50 a 97 respuestas buenas de 100** (dos pasadas de 50; las otras 3, a medias, ninguna mal). Lo que más mejoró: meses anteriores,
   saldos, «¿puedo gastar…?», divisas y preguntas de ingresos.
4. **Responde antes**: las preguntas claras ya no pasan por el clasificador (8 de 50 lo necesitan, antes 50). La mediana baja de 3,2–4,1 s a 1,9–2,5 s.
5. **Cuesta algo más por pregunta**: el contexto pasa de 8,2k a 12,8k tokens. Sin caché, unos 1,31 USD por cada
   1.000 preguntas frente a 0,93 (+41 %; con caché, mucho menos). Si Jürgen quiere recortarlo, tiene una card con
   opciones.

## Qué responde ahora mejor Yala IA

| La persona pregunta… | Antes | Ahora |
|---|---|---|
| «¿Cuánto dinero tengo?» | La mitad del saldo real | El saldo del Panel |
| «¿Cuánto gasté en mayo?», «¿qué mes gasté más?», «¿cuánto ahorré cada mes?» | «No tengo datos de mayo» | La cifra de cada mes de los últimos 12 |
| «Compara este mes con el mismo mes del año pasado» | «No tengo datos» | Octubre del año pasado entero, y lo dice |
| «¿Cuánto gasté en supermercado este año?», «¿cuánto me pagaron por freelance?» | «No tengo el desglose» | El total del año |
| «¿Puedo gastar 500 en unas zapatillas?», «¿me alcanza para el viaje?» | Rodeos, sin decir sí o no | Sí o no, con la cuenta hecha |
| «¿Cuánto puedo gastar por día hasta fin de mes?» | Una base inventada | Lo que queda de los presupuestos ÷ los días que quedan |
| «¿Cuánto valen en soles mis dólares?», «¿puedo pagar una cena de 200 dólares?» | «No tengo la tasa» | La conversión con el tipo de cambio de la app |
| «¿Qué suscripciones pago?» | Lista incompleta | Todas, con importe y próxima fecha |
| «¿Cuánto gasté ayer?» | Una cifra equivocada | La de ayer |
| «¿Cuál es la capital de Francia?», «¿Y con el de Hogar?» | A veces, los botones de «¿registrar o preguntar?» | Responde (o redirige a finanzas) |
| Un gasto de hoy leído de una foto o una nota de voz | No contaba hasta el mediodía | Cuenta desde por la mañana |
| Trato en es-ES, pt-BR y en-GB | «Informal you» | Tuteo o «você»; voseo en es-AR |

## 1. Mapa de los caminos de IA

Todas las llamadas salen por el gateway con su tarea (`X-Yala-Task`); el gateway elige proveedor y modelo
(`gateway/src/ai/routes.ts`). Todas son de OpenAI. **No hay IA en el teléfono**: grep de `FoundationModels`,
`SystemLanguageModel` y `LanguageModelSession` en `Yala/`, `YalaWidgets/` y `YalaShare/` da cero. «Privado» describe
dónde viven los datos, no dónde se piensa la respuesta.

| Camino | Qué ve la persona | Tarea → modelo (fila del gateway) | Qué datos recibe | Tokens (medido o estimado) | Dónde fallaba |
|---|---|---|---|---|---|
| **Chat · pregunta** (privado y nube) | Yala IA contesta | `chat.answer` → gpt-6-luna, sin razonar, 512 de salida | Reglas + JSON de la cuenta + turnos del día | **Medido**: 8,2k de entrada antes, 12,7k ahora; ~45 de salida | Saldos de 13 meses; sin meses anteriores, ingresos por categoría ni tasas (§2) |
| **Chat en la nube con el camino ampliado** | Igual | `chat.explore` (misma fila) + herramientas | Lo mismo + lo que pida | Flag a 0 en staging y producción: hoy responde como `chat.answer` | Fuera del banco (D2) |
| **Chat · clasificador** | Nada (decide pregunta / registrar / ambiguo) | `chat.intent` → gpt-6-luna | Solo el texto | ~0,7k; **1,4 s de media medidos** | Pagaba 1,4 s en cada pregunta; dos preguntas claras caían en «ambiguo» |
| **Chat · registrar** | Borradores en el chat | `chat.intent` + `text.parse` (gpt-6-luna, esfuerzo bajo, JSON estricto) | El texto, todas las subcategorías y las divisas de las cuentas | ~7,5k (estimado) | Ignoraba el modo «solo gastos» |
| **Chat · sugerencias** | Las tres preguntas del saludo | `chat.suggestions` (+ `chat.rewrite` si una nombra algo que no existe) | Agregados del mes | ~1,2k + ~1,1k | Idioma con el código a secas (sin medir el efecto) |
| **Chat · dictado** | Micrófono del chat | `voice.transcribe` (gpt-transcribe) | El audio | — | Va con el permiso del chat, que no menciona audio (ticket nuevo) |
| **Observaciones** | Tarjetas de Estadísticas › Observaciones | `insights.cards` → gpt-6-luna, esfuerzo bajo | Agregados del período **y la nota del gasto más alto** | 4,2–6,3k (estimado) | La nota contradice su propio comentario «nunca transacciones sueltas» (ticket nuevo) |
| **Flujo de caja y desviaciones** | Frase de las gráficas del flujo de caja | `insights.cashflow` / `insights.deviation` | Agregados del plan | ~1,1k cada una | No piden idioma (ticket existente); no miran Pro (ticket nuevo) |
| **Resumen con IA (Tendencias)** | Resumen de Tendencias | `trends.summary` → gpt-6.1-sol | Agregados por período | 2,4–4,5k | Idioma con el código a secas (ticket existente) |
| **Foto** | Leer un recibo o una captura | `photo.read` → gpt-6-luna | La imagen a 1536 px sin GPS, divisas | ~3,8k + imagen | — (banco de octubre: 96 %) |
| **Voz** | Hoja de voz | `voice.transcribe` + `text.parse` | Audio y hasta 80 términos | — | — (banco de octubre) |
| **Siri «Apuntar con Yala»** | Atajo de voz | `text.parse` desde el intent | El texto | ~7,5k | Pide el permiso de voz y foto; el chat registra con el del chat |
| Resto de intents de Siri y Atajos | Abrir la app o encolar | Ninguna | — | — | — |

## 2. El banco de preguntas

**Cómo se midió.** `YalaTests/AIBank/YalaIABankDumpTests` siembra `realista` en el simulador (iOS 27.0) y construye
cada petición con el código de la app: el mismo `FullFinancialContextBuilder` y el mismo prompt
(`ChatAssistantService.makeAskQuery`). `gateway/scripts/yala-ia-bank.ts` las manda a staging como el teléfono: primero
el clasificador, salvo que el teléfono ya haya decidido, y después la respuesta. Las cifras se corrigen contra las de
la app (`qa/ai-bank/results/2026-10-20/cifras-de-la-app.json`: saldo del Panel y gasto de cada mes con sus
calculadores). Preguntas en `qa/ai-bank/questions.json`; respuestas en la misma carpeta de resultados.

**Totales** (✓ responde bien y con la cifra correcta · ~ a medias · ✗ mal o «no tengo el dato» teniéndolo):

| | Antes (2 pasadas) | Después (2 pasadas) |
|---|---|---|
| ✓ | 50 de 100 | **97 de 100** |
| ~ | 13 | 3 |
| ✗ | 37 | 0 |
| Llamadas al clasificador | 50 por pasada | 8 por pasada |
| Tiempo hasta la respuesta, mediana (preguntas) | 3,2 s / 4,1 s | 1,9 s / 2,5 s |
| Tokens de entrada de `chat.answer` | 8.224 | 12.777 |
| Coste estimado por 1.000 preguntas, sin caché | ≈0,93 USD | ≈1,31 USD |

Coste: precios de `gpt-6-luna` (`docs/ai-cloud-vs-private-2026-10.md` §3): 0,10 USD por millón de tokens de entrada,
0,01 en caché, 0,50 de salida. `chat.answer` medido con los tokens que devolvió el servicio; el clasificador, estimado
(~0,7k tokens por llamada). Con la caché del servicio, dos preguntas seguidas de la misma persona pagan una décima
parte del contexto: en las pasadas medidas, 0,15–0,41 USD por 1.000.

**Por pregunta.** «Antes» y «después» resumen las dos pasadas. La respuesta literal de cada pasada está en
`qa/ai-bank/results/2026-10-20/`.

| # | Pregunta | Antes | Después | Nota |
|---|---|---|---|---|
| S01 | ¿Cuánto dinero tengo en total? | ✗ ✗ S/ 37.631 | ✓ ✓ S/ 71.568,75 | El bug de los 13 meses: faltaban los saldos iniciales |
| S02 | ¿Cuánto tengo en mi cuenta de ahorros? | ✗ ✗ US$ 16.404 | ✓ ✓ US$ 29.025 ≈ S/ 103.039 | Además dice cuánto es en soles |
| S03 | ¿Cuánto tengo en dólares? | ✗ ✗ | ✓ ✓ | Igual que S02 |
| S04 | What's my total balance right now? | ✗ ✗ | ✓ ✓ | Igual que S01, en inglés |
| S05 | ¿Mi saldo subió o bajó este mes? | ~ ✗ «bajó S/ 3.723» | ✓ ✓ subió S/ 1.188 | Regla nueva: el `balance` de un período es lo que subió o bajó |
| G01 | ¿Cuánto llevo gastado este mes? | ✓ ✓ | ✓ ✓ | — |
| G02 | ¿En qué categoría gasto más este mes? | ✗ ✗ Alimentación | ✓ ✓ Hogar | `categories` ya venía ordenado; ahora el prompt lo dice |
| G03 | ¿Cuánto gasté en Uber este mes? | ✓ ✓ («UBER») | ✓ ✓ («Uber») | Los comercios vienen en mayúsculas; ahora los escribe bien |
| G04 | ¿Cuánto gasté en comida el mes pasado? | ✓ ✓ | ✓ ✓ | — |
| G05 | ¿Cuánto gasté en supermercado en lo que va del año? | ✗ ✗ | ✓ ✓ S/ 19.553 | `total_current_year` por categoría y subcategoría |
| G06 | Quanto gastei com restaurantes este mês? | ✓ ✓ | ✓ ✓ | — |
| G07 | ¿Cuál fue mi gasto más grande este mes? | ✓ ✓ | ✓ ✓ | — |
| G08 | ¿Cuánto gasté ayer? | ✗ ✗ S/ 291 | ✓ ✓ S/ 443 | `periods.yesterday`; antes sumaba a ojo |
| G09 | ¿Cuánto gasté la semana pasada? | ✓ ✓ | ✓ ✓ | — |
| C01 | ¿Estoy gastando más o menos que el mes pasado? | ✓ ✓ | ✓ ~ | Una pasada redondeó a 15,3 % en vez de 15,4 % |
| C02 | Compara lo de este mes con el mismo mes del año pasado | ✗ ✗ | ✓ ✓ | `periods.same_month_last_year`; con el dato solo en la lista, el modelo decía que no lo tenía |
| C03 | ¿Cuánto gasté en mayo? | ✗ ✗ | ✓ ✓ S/ 8.319 | `monthly_history` |
| C04 | ¿En qué mes del último año gasté más? | ✗ ✗ | ✓ ✓ dic. 2025, S/ 9.901 | `monthly_history_summary`: leyendo las 12 filas se saltaba diciembre |
| C05 | ¿Cuánto gasté en total el año pasado? | ✗ ✗ S/ 7.915 | ✓ ✓ S/ 26.596 (oct–dic) | Dice que solo tiene tres meses de 2025 |
| C06 | ¿Cuánto ahorré cada mes en los últimos 6 meses? | ~ ~ (3–4 meses) | ✓ ✓ | — |
| C07 | How does my transport spending compare to three months ago? | ~ ~ (usaba agosto) | ✓ ✓ julio, S/ 517 | `metadata.period_months` dice qué mes es cada período |
| C08 | ¿Cuánto gasté en restaurantes en julio? | ✗ ✗ | ✓ ✓ S/ 982 | Subcategorías de cada mes |
| I01 | ¿Cuánto gané este mes? | ✓ ✓ | ✓ ✓ | Ahora dice de qué |
| I02 | ¿Cuánto me pagaron por freelance este año? | ✗ ✗ | ✓ ✓ S/ 30.214 | `income_categories` |
| I03 | ¿Cuál es mi tasa de ahorro este año? | ✓ ✓ | ✓ ✓ | — |
| P01 | ¿Cómo voy con mis presupuestos? | ✓ ✓ | ✓ ✓ | — |
| P02 | ¿Me queda presupuesto para salir a comer? | ✓ ✓ | ✓ ✓ | Una versión intermedia lo confundía con la suma de todos; corregido con el nombre del campo |
| P03 | ¿Qué presupuesto está más en riesgo? | ✓ ✓ | ✓ ✓ | — |
| P04 | Am I over budget on anything? | ✓ ✓ | ✓ ✓ | Regla: un presupuesto se nombra por su nombre |
| R01 | ¿Qué pagos tengo pendientes en los próximos días? | ✓ ✓ | ✓ ✓ | — |
| R02 | ¿Cuánto pago al mes en suscripciones? | ✓ ✓ | ✓ ✓ | — |
| R03 | ¿Cuándo me toca pagar el alquiler? | ✓ ✓ | ✓ ✓ | — |
| R04 | Quais assinaturas eu pago todo mês? | ~ ✓ | ✓ ✓ | `recurring.active` |
| X01 | ¿Puedo gastar 500 soles en unas zapatillas este mes? | ✗ ~ | ✓ ✓ | Sí, con la cuenta hecha sobre el saldo y los pagos de este mes. Sin «¿?» caía en «¿registrar o preguntar?» (medido en el simulador): ahora es pregunta siempre |
| X02 | ¿Me alcanza para un viaje de 3000 soles el próximo mes? | ✗ ✗ | ✓ ~ | Una pasada empieza con «No» y acaba en «sí cabe» |
| X03 | Can I afford a 200 dollar dinner this week? | ✗ ✗ «no exchange rate» | ✓ ✓ ≈ S/ 710 | `fx_rates`. Una versión intermedia restaba del saldo lo ya gastado; la regla lo prohíbe |
| X04 | ¿Cuánto puedo gastar por día hasta fin de mes? | ~ ~ | ✓ ✓ S/ 155 al día | `month_outlook`: sumaba mal cuatro presupuestos |
| M01 | ¿Cuánto vale en soles lo que tengo en dólares? | ✗ ✗ | ✓ ✓ | `balance_in_main_currency` |
| M02 | ¿Cuánto me ingresó en dólares este mes? | ~ ~ | ~ ✓ | Este mes no hubo ingresos en dólares: una pasada lo dice, la otra no lo puede afirmar |
| GR01 | ¿Cuánto me deben en mis grupos? | ~ ~ | ✓ ✓ | Ya no dice que el total «incluye grupos» sin haber grupos. Grupos como contenedor tiene su sesión |
| GR02 | ¿Cuánto gasté en el viaje con mis amigos? | ✓ ✓ | ✓ ✓ | Dice que no lo puede identificar y ofrece la etiqueta |
| N01 | Gasté 45 soles en el cine | ✓ ✓ registrar | ✓ ✓ | Con cifra: sigue yendo al clasificador |
| N02 | Anota 120 de supermercado y 30 de taxi | ✓ ✓ | ✓ ✓ | — |
| N03 | I spent 12 dollars on coffee | ✓ ✓ | ✓ ✓ | — |
| N04 | Paguei 80 reais de gasolina | ✓ ✓ | ✓ ✓ | — |
| N05 | Me pagaron 1500 por un proyecto | ✓ ✓ | ✓ ✓ | Con «solo gastos», el borrador nace como gasto |
| T01 | (Restaurantes este mes) → ¿Y el mes pasado? | ✓ ✓ | ✓ ✓ | — |
| T02 | (Presupuesto de Movilidad) → ¿Y con el de Hogar? | ✓ ✗ ambiguo | ✓ ✓ | El clasificador no ve la conversación: 0,72–0,76 de confianza, al filo del umbral |
| O01 | ¿Cuál es la capital de Francia? | ✗ ✗ ambiguo | ✓ ✓ | Ahora redirige a finanzas, como pide el prompt |
| O02 | ¿Cuánto gasté en enero de 2023? | ✓ ✓ | ✓ ✓ | Dice desde qué mes tiene datos |

## 3. Qué se cambió

**Contexto (`FullFinancialContextBuilder`).**
- Los saldos salen del libro entero y con el corte de hoy, como el Panel (`AccountBalanceCalculator`,
  `LiveBalanceCalculator`). Las estadísticas siguen siendo de los últimos 13 meses.
- «Hoy» termina al final del día, no en este instante: la foto y la voz fechan a las 12:00.
- Nuevo, todo agregado y dentro de los 13 meses: `monthly_history` (12 meses cerrados: ingresos, gastos, neto y lo
  que más pesó), `monthly_history_summary` (mes más caro y más barato, medias y totales por año),
  `income_categories`, `total_current_year` por categoría, `recurring.active`, `periods.yesterday`,
  `periods.same_month_last_year`, `month_outlook`, `metadata.period_months`, `fx_rates` y
  `balance_in_main_currency`.
- Un contexto que no se puede preparar ya no llega al modelo como `{}`: el chat enseña su error de siempre y no
  gasta la llamada.

**Prompt (`ChatAssistantService`).** Reglas para meses anteriores, hoy y ayer, ingresos, otra divisa, «¿subió o bajó
mi saldo?», «¿puedo gastar…?» y nombres de comercios y presupuestos. El trato sale del idioma base (voseo en es-AR).

**Ruta.** Una pregunta que se reconoce en el teléfono no pasa por el clasificador: sin cifras ni verbo de apuntar,
con signo de pregunta o con un interrogativo que no puede abrir un registro. Contra las 115 frases del banco de
`chat.intent` (12 idiomas) no contradice ninguna y se ahorra el clasificador en 43 de las 48 preguntas. «¿Puedo gastar…?» y
«¿me alcanza…?» son pregunta aunque traigan cifra, y el clasificador tiene ejemplos de ellas: con el prompt nuevo acierta
120 de 120 contra staging (las 115 y cinco nuevas).

**Registrar.** Con «solo gastos», el borrador del chat nace como gasto, como en Siri, el Atajo y Apple Pay.

**Lo que no se tocó:** modelo, proveedor, parámetros de las filas del gateway, cuotas, precios, textos visibles, el
flag de `chat.explore` y lo que manda el resto de caminos. Ningún despliegue.

## 3 bis. Barrido en el simulador

Yala Dev contra staging, iPhone 17 Pro con iOS 27.0, semilla `realista`. Capturas en
`~/Claude/entregas/Yala-2026-10-20-revision-ia-yala-2-2/capturas/`.

| Paso | Esperado | Salió |
|---|---|---|
| Panel › Tendencias › Saldo | La cifra del saldo de hoy | S/ 71.568,75 (`01-panel-saldo.png`) |
| Yala IA: «Cuánto dinero tengo en total» | La misma cifra | S/ 71.568,75 (`03-saldo.png`) |
| «Cuánto gasté en mayo» | Gasto de mayo de 2026 | S/ 8.319, ingresos y neto (`04-…png`) |
| «Puedo gastar 500 soles en unas zapatillas este mes», sin signos | Respuesta con la cuenta hecha | Antes del último cambio, «¿registrar o preguntar?» (`04`, `05`); después, «Sí, con cuidado» con los S/ 280 de este mes (`06-…png`) |

El borrador con «solo gastos», la fecha del mediodía y el contexto que no se puede preparar no se condujeron a mano:
los fija un test cada uno. Los saldos y el mediodía, además, con su mutante: devolviendo la ventana de 13 meses o el
corte por instante, el test cae. Nada queda para el iPhone de Jürgen: el contexto se
arma en el teléfono igual en producción, y el resto de lo que cambia vive en el texto que va al gateway.

## 4. Lo que queda para Jürgen

| Card | Qué decide | Recomendación |
|---|---|---|
| Coste del contexto nuevo de Yala IA | Dejarlo como está, recortar la historia a 6 meses o quitarla | A, dejarlo: +0,4 USD por cada 1.000 preguntas sin caché y casi todo el salto de calidad |
| El micrófono del chat manda audio con el permiso del chat | Si el permiso del chat cubre el audio o se pide el de voz | Pedir el de voz y foto, como Siri |
| IA en el teléfono para el modo privado | Si se prueba Apple Foundation Models para el clasificador y las sugerencias | Un spike medido con este mismo banco antes de decidir |

La card de los turnos (`…n6t8`) sigue en backlog: su triage dice que falta decidir N.

## 5. Encontrado y no tocado

Cada uno tiene ticket en `tickets/backlog/` y card:
- `chat-microphone-sends-audio-with-the-chat-consent` (privacidad, decisión arriba).
- `insights-cards-send-the-note-of-the-largest-expense`: Observaciones manda la nota libre del gasto más alto.
- `cashflow-ai-comment-does-not-check-pro`: la frase del flujo de caja llama al gateway sin mirar Pro.
- `panel-balance-curve-parity-test-depends-on-the-day` (arreglado aquí, en el test): `PanelBalanceFigureCurveParityTests` salía rojo hoy, también
  aislado y también sobre `origin/2.2` limpio (medido): la semilla redondea la tasa a dos decimales y la del día 1 era la
  de hoy. El control ahora pide que algún punto la distinga.
- `chat-suggestions-show-merchants-in-capitals`: las sugerencias del saludo dicen «SUPERMERCADO y MERCADO».
- `account-card-reports-cashflow-carousel-uitest-is-flaky`: el carrusel del flujo de caja por tarjeta falló 2 de 7 veces
  en el gate (5 de 5 verde sobre `origin/2.2`, 3 de 3 verde al repetir aquí).

## 6. Cómo repetir el banco

```bash
# 1. Volcar las peticiones (simulador iOS 27.0, scheme Yala Dev)
TEST_RUNNER_YALA_AI_BANK_DIR=/ruta/salida bash qa/scripts/sim-lock.sh -- xcodebuild test -project Yala.xcodeproj \
  -scheme "Yala Dev" -destination 'platform=iOS Simulator,id=<udid>' -only-testing:YalaTests/YalaIABankDumpTests
# 2. Mandarlas a staging
cd gateway && npx vite-node scripts/yala-ia-bank.ts -- --dir /ruta/salida \
  --base https://yala-gateway-staging.misty-surf-6866.workers.dev \
  --dev-secret-file ~/Secrets/yala-gateway/staging-dev-shared-secret
```

Cada pasada cuesta menos de 0,10 USD (medido: 50 preguntas de unos 12.700 tokens) y la paga la clave de OpenAI del gateway de staging.
