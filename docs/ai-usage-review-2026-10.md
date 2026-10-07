# Revisión del uso de IA en Yala — octubre 2026

> Fecha: 2026-10-07. Árbol medido: rama `encargo/2026-10-07-ai-usage-review-models-cost-and-answers`,
> base `5d72ab97d`. Investigación para 2.2: **no cambia modelo, proveedor, prompts ni parámetros**.
> No se hizo ninguna llamada de pago a las APIs: los tokens son **estimaciones desde el código** y se
> marcan como tales.

## Resumen en cinco líneas

1. Yala usa **un solo proveedor, OpenAI**, con tres modelos: `gpt-4.1-mini`, `gpt-4.1-nano` y
   `whisper-1`. Todo pasa por el gateway de Cloudflare, que pone la clave y la cuota.
2. La elección de modelo está **en el binario de la app**: cambiarla exige una release.
3. Nadie mide tokens ni coste por función. El gateway no lee `usage`. Es lo primero que conviene arreglar,
   porque todas las decisiones de coste dependen de ello.
4. La estructura de las respuestas es **mejorable**: un servicio (el parser de voz) no pide JSON y los
   otros piden «un JSON», no «este JSON». El SDK ya permite esquemas estrictos.
5. Hay bugs de idioma y de errores visibles para el usuario que se arreglan sin tocar el modelo.

> **Urgente, con fecha: OpenAI apaga `gpt-4.1-nano` el 23-oct-2026.** Lo usan la lectura de fotos, el
> clasificador del chat y las sugerencias. Sin cambios, ese día **el registro por imagen deja de funcionar
> en todas las versiones instaladas**. Solo el gateway llega a tiempo a todas. Ticket con opciones:
> `gpt-4-1-nano-shuts-down-on-october-23` — **decidir antes del 2026-10-20**.
> Fuente: https://developers.openai.com/api/docs/deprecations (consultada 2026-10-07).

## 1. Inventario

Todas las llamadas salen de la app con el SDK `MacPaw/OpenAI` 0.4.7 contra el gateway
(`ProxyClientFactory.makeOpenAI`, `Yala/App/Services/ProxyClientFactory.swift`), que reenvía a
`api.openai.com` (`gateway/src/proxy/openai.ts`). No hay funciones en la nube que llamen a la IA por su
cuenta: el gateway es un proxy de paso. Timeout del cliente: 20 s.

| # | Función para el usuario | Código | Modelo | Parámetros | Formato de respuesta | Cuota (`X-Yala-Category`) |
|---|---|---|---|---|---|---|
| 1 | **Chat Yala IA — preguntar** | `Yala/Services/ChatAssistantService.swift` (`runAskFlow`) | `gpt-4.1-mini` | temp 0.4, timeout 20 s, sin tope de salida | texto libre (markdown) | `chat` |
| 2 | Chat — **clasificar** la intención (cada mensaje) | `Yala/Services/Chat/ChatIntentClassifierService.swift` | `gpt-4.1-nano` | temp 0, timeout 8 s | `json_object` | `suggestions` |
| 3 | **Registrar por voz, por Siri y desde el chat** (texto → gastos) | `Yala/Services/TranscriptionParserService.swift` (`parseMultiple`) | `gpt-4.1-mini` | temp 0.1 | **ninguno** (JSON pedido por texto) | `voice` |
| 4 | **Transcribir voz** (hoja de voz y dictado del chat) | `Yala/Services/VoiceTranscriptionService.swift` | `whisper-1` | idioma ISO, m4a AAC 16 kHz mono | texto | `voice` |
| 5 | **Registrar por imagen** (foto, recibo, captura, PDF) | `Yala/App/Services/ImageVision/ImageVisionService.swift` | `gpt-4.1-nano` (visión) | JPEG 0.8 a resolución original, `detail: auto` | `json_object` | `vision` |
| 6 | **Insights** (hero + tarjetas) | `Yala/Services/InsightsLLMService.swift` (`generateInsights`) | `gpt-4.1-mini` | temp 0.4, caché en memoria 5 min | `json_object` | `insights` |
| 7 | Comentario del **flujo de caja** | ídem (`generateCashFlowInsight`) | `gpt-4.1-mini` | temp 0.4, caché en memoria 24 h | `json_object` | `insights` |
| 8 | Comentario de **desviaciones** del plan | ídem (`generateDeviationInsight`) | `gpt-4.1-mini` | temp 0.4, caché en memoria por día | `json_object` | `insights` |
| 9 | Comentario contextual | ídem (`generateContextualInsight`) | `gpt-4.1-mini` | — | `json_object` | `insights` — **sin llamadores: código muerto** |
| 10 | **Tendencias** (un bullet por gráfica) | `Yala/Services/TrendsAIService.swift` | `gpt-4.1-mini` | temp 0.4, caché en memoria 24 h | `json_object` | `insights` |
| 11 | **Sugerencias** del chat (chips) | `Yala/App/Services/ChatSuggestionsLLMService.swift` | `gpt-4.1-nano` | temp 0.7, caché diaria en `UserDefaults` | `json_object` | `suggestions` |
| 12 | Reescribir sugerencias que nombran cosas que el usuario no tiene | `Yala/App/Services/SuggestionsRewriterService.swift` | `gpt-4.1-mini` | temp 0.3, solo si hay inválidas | `json_object` | `suggestions` |

**Llamadas por acción del usuario** (medido en el flujo del código):

- Una pregunta del chat = **2 llamadas**: clasificador (nano) + respuesta (mini). Si la intención es
  «registrar», la segunda es el parser (mini) en vez de la respuesta.
- Una nota de voz = **2 llamadas**: `whisper-1` + parser (mini). Las dos cuentan en la cuota `voice`.
- Una foto = 1 llamada (nano con visión). Varias fotos = una por foto.
- Abrir el chat = 0, 1 o 2 llamadas para las sugerencias, una vez al día.

**Cuotas del gateway** (`gateway/src/policy.ts`): Pro — chat 75/día, visión 50, voz 100, insights 60,
sugerencias 300. Free — solo visión 5/día y voz 5/día; el resto exige Pro.

**Tamaño estimado de los prompts** (caracteres de código medidos; tokens estimados a ≈3,7 caracteres
por token en español, **no medidos**):

| Prompt | Caracteres | Tokens (estimado) | Qué más va en la petición |
|---|---|---|---|
| Chat, parte fija | ≈5 600 | ≈1 500 | + JSON financiero completo + **todos** los turnos anteriores |
| Parser | ≈4 700 | ≈1 300 | + fecha + lista de subcategorías del usuario |
| Clasificador | ≈2 300 | ≈600 | + el mensaje |
| Imagen | ≈1 800 | ≈500 | + la imagen |
| Insights | ≈3 300 | ≈900 | + JSON agregado del período |

El JSON financiero del chat tiene topes (10 categorías, 20 comercios, 10 etiquetas, hasta 10 gastos por
subcategoría en 10 subcategorías), pero **su tamaño real no está medido**: depende de los datos del
usuario. Por orden de magnitud, varios miles de tokens por pregunta.

## 2. Revisión contra la documentación oficial

Todas las fuentes se consultaron el **2026-10-07**. Lo que ninguna fuente dice aparece como «no
confirmado». Las cifras de coste por acción son **cálculos propios** sobre esos precios y sobre tokens
estimados.

### Estado de los modelos que usamos

| Modelo | Estado | Sustituto recomendado | Fuente |
|---|---|---|---|
| `gpt-4.1-nano` | **Se apaga el 2026-10-23** (anuncio del 2026-04-22) | `gpt-5.6-luna` | https://developers.openai.com/api/docs/deprecations |
| `gpt-4.1-mini` | Vigente, sin fecha de apagado. Su ficha recomienda «GPT-5 Mini for more complex tasks» | — | https://developers.openai.com/api/docs/models/gpt-4.1-mini |
| `whisper-1` | **Se apaga el 2027-02-26** | `gpt-transcribe` o `gpt-live-transcribe` | https://developers.openai.com/api/docs/deprecations |
| Chat Completions (`/v1/chat/completions`) | Sigue soportado; Responses es lo recomendado para proyectos nuevos. Sin aviso de retirada | — | https://developers.openai.com/api/docs/guides/migrate-to-responses |

### Precios (USD por 1M tokens, tarifa estándar)

Fuente: https://developers.openai.com/api/docs/pricing (la URL antigua de `platform.openai.com` redirige
ahí).

| Modelo | Entrada | Entrada en caché | Salida | Nota |
|---|---|---|---|---|
| `gpt-4.1-mini` | 0,40 | 0,10 | 1,60 | hoy |
| `gpt-4.1-nano` | 0,10 | 0,025 | 0,40 | hoy; se apaga el 23-oct |
| `gpt-4o-mini` | 0,15 | 0,075 | 0,60 | sin aviso de retirada |
| `gpt-5-mini` | 0,25 | 0,025 | 2,00 | el snapshot `-2025-08-07` se apaga el 2026-12-11 |
| `gpt-5-nano` | 0,05 | 0,005 | 0,40 | el snapshot `-2025-08-07` se apaga el 2026-12-11 |
| `gpt-5.4-mini` | 0,75 | 0,075 | 4,50 | vigente |
| `gpt-5.4-nano` | 0,20 | 0,02 | 1,25 | se apaga el 2027-04-01 |
| `gpt-5.6-luna` | 0,20 | 0,02 | 1,20 | equivale al nivel nano; razona por defecto (`medium`) |
| `gpt-5.6-terra` | 2,00 | 0,20 | 12,00 | equivale al nivel mini |
| `gpt-6-luna` | 0,10 | 0,01 | 0,50 | «most efficient model for focused, high-volume tasks» |

Desde la generación 5.6, **escribir** en la caché de prompts cuesta 1,25× la entrada (en 4.1 no se cobra).
Batch y Flex cuestan la mitad, pero no sirven para respuestas en vivo.

Transcripción (misma fuente y https://developers.openai.com/api/docs/guides/speech-to-text):
`whisper-1` $0,006/min · `gpt-4o-mini-transcribe` $0,003/min (se apaga con `whisper-1`) ·
`gpt-transcribe` $0,0045/min (recomendado; acepta `prompt`, `keywords` y `languages`). Límite: 25 MB.

### Salida estructurada

- `json_schema` con `strict: true` garantiza la **forma**; `json_object` solo garantiza JSON válido. La
  guía recomienda «always using Structured Outputs instead of JSON mode when possible».
  `gpt-4.1-mini` y `gpt-4.1-nano` lo soportan; la generación 5.6 y `gpt-6-luna`, también.
  https://developers.openai.com/api/docs/guides/structured-outputs
- En modo estricto todos los campos son obligatorios; un opcional se declara como unión con `null`.
- El SDK de la app (MacPaw/OpenAI **0.4.7**) ya tiene `ResponseFormat.jsonSchema` con `strict`,
  `maxCompletionTokens` y `reasoningEffort`. No tiene `prompt_cache_key`. Comprobado en
  `Sources/OpenAI/Public/Models/ChatQuery.swift` del tag 0.4.7 en GitHub.

### Caché de prompts

- Automática. Pide el contenido fijo **al principio** y lo variable al final.
- El mínimo de 1 024 tokens está documentado **solo para 5.6 y posteriores**; para 4.1 la guía dice que
  «varies by request settings». El «1 024» de 4.1 queda **no confirmado**.
  https://developers.openai.com/api/docs/guides/prompt-caching

### Visión

- Tokens = parches de 32×32 px × multiplicador del modelo: `gpt-4.1-nano` ×2,46, `gpt-4.1-mini` ×1,62,
  familia 5.x ×1,2. En `gpt-4.1-mini`, `low`/`high`/`auto` usan el mismo tamaño (2 048 px, 6 144 parches).
  En `gpt-5.6-luna`, `low` reduce a 512×512. Los límites de `gpt-4.1-nano` ya no se publican.
  https://developers.openai.com/api/docs/guides/images-vision

### Buenas prácticas de prompts (y cómo estamos)

Fuentes: https://developers.openai.com/cookbook/examples/gpt4-1_prompting_guide y
https://developers.openai.com/api/docs/guides/prompt-engineering

| Práctica | Yala hoy |
|---|---|
| Orden identidad → instrucciones → ejemplos → contexto, contexto variable al final | El chat lo cumple. Parser e imagen meten la fecha del día en medio de las reglas |
| GPT-4.1 sigue las instrucciones al pie de la letra; si dos chocan, gana la **última** | El parser se contradice (fecha nula frente a «hoy») → `voice-parser-sends-no-json-mode` |
| Pedir que varíe las frases de ejemplo o las repetirá | El chat tiene cuatro respuestas de ejemplo literales; no medido si las repite |
| Fijar snapshots en producción | Se usan alias (`gpt-4.1-mini`), no snapshots |
| Structured Outputs en vez de modo JSON | Ninguna llamada lo usa → H5 y H6 |

### Apple Foundation Models (en el iPhone)

iOS 26+, generación guiada con `@Generable` (salida que no puede romper el esquema) y herramientas.
Ventana de **4 096 tokens** por sesión según la nota técnica TN3193; requiere un iPhone con Apple
Intelligence (15 Pro o posterior). Español incluido. Que sea gratis **no consta** textualmente.
https://developer.apple.com/documentation/foundationmodels

## 3. Hallazgos

Cada hallazgo tiene ticket. Los «autónomos» se pueden lanzar sin Jürgen; los «para Jürgen» cambian
modelo, proveedor o coste.

### Lo que el usuario ya nota

| # | Hallazgo | Evidencia | Ticket |
|---|---|---|---|
| H1 | Insights sale en el idioma de la **región**, no en el de la app; flujo de caja y desviaciones no reciben idioma | `InsightsViewModel.swift:286` usa `Locale.current`; los prompts de `generateCashFlowInsight`/`generateDeviationInsight` no lo mencionan | `ai-comments-ignore-the-app-language` (autónomo) |
| H2 | La tarjeta de error de Insights enseña el error técnico **en inglés** («Network error: …»), y la cuota agotada sale como error de red | `InsightsViewModel.swift:261` → `localizedDescription`; literales en `InsightsLLMService.swift:38-48` | `ai-insights-error-card-shows-raw-english-errors` (autónomo) |
| H3 | Volver a Insights en <5 s da «rate limited» aunque la respuesta está en caché | orden intervalo → caché en `InsightsLLMService`; Tendencias lo hace bien | `insights-rate-limit-runs-before-the-cache` (autónomo) |
| H4 | Una foto con «$» se registra en **USD** aunque el usuario sea de México, Colombia, Chile o Argentina | `ImageVisionService.swift:103` | `vision-reads-every-dollar-sign-as-usd` (autónomo) |
| H10 | El dictado del chat ignora el idioma de voz elegido; la hoja de voz no filtra las «alucinaciones» de `whisper-1` con silencio | `ChatAssistantViewModel.swift:459` usa `.system`; el filtro solo está en el chat | `voice-language-and-silence-handling-differ-between-chat-and-sheet` (autónomo) |
| H13 | El plan free da 5 usos de voz al día, pero **cada nota de voz gasta 2** (transcribir + leer): en la práctica son 2 notas | `TranscriptionParserService` y `VoiceTranscriptionService` piden ambos `category: .voice` | `free-voice-quota-counts-each-dictation-twice` (Jürgen) |

### Estructura de las respuestas

| # | Hallazgo | Evidencia | Ticket |
|---|---|---|---|
| H5 | El parser de voz/chat/Siri **no pide modo JSON** y su prompt se contradice (fecha nula vs. «hoy»; ejemplo con una subcategoría que puede no existir) | `TranscriptionParserService.swift` ≈262-269 | `voice-parser-sends-no-json-mode` (autónomo) |
| H6 | Los otros nueve usos piden `json_object`: JSON válido, forma no garantizada. Los huecos se tapan con defaults silenciosos; el icono de Insights es un SF Symbol libre que puede pintarse vacío | `grep responseFormat: .jsonObject` | `ai-responses-use-json-object-not-a-strict-schema` (autónomo) |
| H7 | Ninguna llamada pone tope a la salida (`max_completion_tokens`) | 0 resultados en `Yala/` | `ai-calls-have-no-output-token-cap` (autónomo) |
| H11 | Si el contexto del chat no se codifica, el modelo recibe `{}` y contesta que no hay datos | `FullFinancialContext.swift:43`, `try?` | `chat-context-encoding-failure-is-silent` (autónomo) |

Lo que está bien y conviene no romper: el chat fija el idioma con `AppLocale` y explica por qué; el
system prompt del chat pone la parte fija **delante** de los datos (para la caché de prompts); el
clasificador cae a un regex si la red falla; Tendencias tiene el orden correcto caché → intervalo →
cliente y una caché de 24 h por contenido; las sugerencias se cachean por día **e idioma**.

### Eficiencia y coste

| # | Hallazgo | Evidencia | Ticket |
|---|---|---|---|
| H8 | Cada pregunta del chat reenvía **todos** los turnos anteriores, aunque el prompt pide ignorar los que no vienen al caso | `ChatAssistantService.buildMessages` | `chat-sends-every-past-turn-to-the-model` (autónomo) |
| H9 | No se mide `usage`: no hay coste por función ni % de caché | `gateway/src/proxy/openai.ts` reenvía sin leer | `gateway-does-not-record-ai-token-usage` (autónomo) |
| H12 | El gateway reenvía cualquier modelo y cualquier longitud; la categoría de cuota la elige el cliente | `proxy()` y `categoryFrom` | `gateway-proxies-any-model-and-any-length` (autónomo) |
| H14 | La foto viaja a **resolución original** (JPEG 0.8, `detail: auto`). Pesa megas, alarga la subida contra un timeout de 20 s y maximiza los tokens de imagen | `ImageVisionService.swift:151-160` | `image-reading-sends-the-full-resolution-photo` (Jürgen) |
| H15 | El modelo está escrito en la app: cambiarlo exige release y no permite probar dos modelos a la vez | `model: .gpt4_1_mini` en 8 sitios, `.gpt4_1_nano` en 3 | `ai-model-choice-lives-in-the-app-binary` (Jürgen) |
| H0 | **`gpt-4.1-nano` se apaga el 2026-10-23** y lo usan foto, clasificador y sugerencias | ver §2 | `gpt-4-1-nano-shuts-down-on-october-23` (Jürgen) |
| H16 | La familia `gpt-4.1` ya no es la última de OpenAI | ver §2 | `ai-text-model-generation-upgrade` (Jürgen) |
| H17 | `whisper-1` es el modelo de transcripción más antiguo de OpenAI | ver §2 | `voice-transcription-model-choice` (Jürgen) |

Caché de prompts: el chat la favorece (fijo delante). El parser y la imagen meten la fecha del día **antes**
de las reglas fijas, así que su prefijo común es corto; con prompts de ≈1 300 y ≈500 tokens, el parser
podría cachear y la imagen no llega al mínimo. Las cachés propias de Insights son **en memoria**: se
pierden al cerrar la app, así que el comentario de flujo de caja «de 24 h» se vuelve a pedir en cada
arranque en frío.

### Código muerto o desfasado

- `InsightsLLMService.generateContextualInsight` no tiene llamadores.
- `Yala/App/Services/ImageOCR/` (OCR local con el framework Vision de Apple) no tiene llamadores fuera de
  su carpeta, aunque la cabecera de `ImageVisionService` dice que es su respaldo.
- Comentarios que dicen «GPT-4o Vision» donde el modelo es `gpt-4.1-nano`.
- Errores con el texto «OpenAI API key not configured», de cuando la clave vivía en la app.

No se abre ticket para esto: es limpieza sin efecto para el usuario, y la opción C de
`image-reading-sends-the-full-resolution-photo` decide si el OCR local vuelve a usarse o se borra.

## 4. Oportunidades, por impacto

1. **Que la foto no deje de funcionar el 23-oct.** El gateway sustituye `gpt-4.1-nano` para todas las
   versiones → `gpt-4-1-nano-shuts-down-on-october-23` (Jürgen, urgente).
2. **Medir antes de optimizar.** `usage` por categoría en el gateway →
   `gateway-does-not-record-ai-token-usage` (autónomo). Sin esto, todo lo de coste es estimación.
3. **El modelo, en el gateway.** Cambiar de modelo sin release, probar con un % y partir por modo →
   `ai-model-choice-lives-in-the-app-binary` (Jürgen).
4. **Arreglar lo que el usuario ya ve**: idioma de Insights y flujo de caja, errores en inglés, «$» como
   USD, dictado del chat con otro idioma → cuatro tickets autónomos.
5. **Respuestas con esquema estricto** y tope de salida: menos errores de lectura y peor caso acotado →
   tres tickets autónomos.
6. **Generación nueva de modelos**: hasta ≈−75 % por token con `gpt-6-luna` frente a `gpt-4.1-mini`,
   pendiente de una comparación de calidad → `ai-text-model-generation-upgrade` (Jürgen).
7. **Menos tokens por pregunta del chat**: solo los últimos turnos → autónomo.
8. **Transcripción**: `whisper-1` se apaga en febrero; `gpt-transcribe` cuesta un 25 % menos y acepta
   palabras clave → `voice-transcription-model-choice` (Jürgen).
9. **Fotos más ligeras** (menos fallos por timeout; ahorro de tokens según el modelo) →
   `image-reading-sends-the-full-resolution-photo` (Jürgen).
10. **Cuota de voz free coherente** → `free-voice-quota-counts-each-dictation-twice` (Jürgen).

## 5. Alternativas

Coste por acción = cálculo propio con los precios de §2 y los tokens estimados de §1. **No medido.**

| Tarea | Hoy | Alternativa | Coste hoy (≈) | Coste alternativa (≈) | A favor | En contra |
|---|---|---|---|---|---|---|
| Pregunta del chat (≈6 500 entrada, ≈150 salida, supuesto) | `gpt-4.1-mini` | `gpt-6-luna` (`reasoning: none`) | $0,003 | $0,0007 | −75 %; el más nuevo | Comparar calidad en español con datos reales |
| | | `gpt-5.6-luna` | | $0,0015 | Sustituto oficial de nano | Más caro que `gpt-6-luna` |
| | | Claude Haiku 4.5 | | $0,007 | Esquema JSON soportado | ≈2,4× más caro; segundo proveedor |
| | | Gemini 3.1 Flash-Lite | | $0,0019 | Esquema JSON soportado | Segundo proveedor (consentimiento, claves) |
| | | Apple Foundation Models | | 0 (no confirmado) | Sin red; encaja con modo privado | 4 096 tokens no caben el JSON del chat; solo iPhone 15 Pro+ |
| Clasificar intención (≈700 / 20) | `gpt-4.1-nano` (se apaga) | `gpt-4.1-mini` | $0,00008 | $0,0003 | Comportamiento conocido | ×4 |
| | | `gpt-6-luna` | | $0,00008 | Mismo coste que hoy | Modelo nuevo |
| | | Apple Foundation Models | | 0 | Tarea pequeña, cabe; sin red | Solo con Apple Intelligence; el regex queda de respaldo |
| Foto (≈5 000 tokens de imagen en mini) | `gpt-4.1-nano` (se apaga) | `gpt-4.1-mini` | ≈$0,0008 (nano, límites no publicados) | ≈$0,0024 | Seguro y conocido | ≈×3 |
| | | `gpt-5.6-luna` `high` / `low` | | ≈$0,0008 / ≈$0,0003 | Más barato | `low` puede leer peor recibos largos |
| Nota de voz de 10 s | `whisper-1` + `gpt-4.1-mini` | `gpt-transcribe` + parser actual | $0,001 + $0,0008 | $0,00075 + $0,0008 | −25 % en audio; `keywords` | Probar calidad en seis idiomas |
| | | `SpeechTranscriber` en el iPhone + parser | | 0 + $0,0008 | Sin coste de audio; modo privado | Descarga de modelo; calidad sin medir |
| Insights (≈2 400 / 500) | `gpt-4.1-mini` | `gpt-6-luna` | $0,0018 | $0,0005 | −70 % | Comparar calidad |

**Conclusión sobre «¿es el mejor modelo sin gastar de más?»**: `gpt-4.1-mini` es correcto en calidad
para estas tareas y no tiene fecha de apagado, pero ya no es el más barato de su nivel: `gpt-6-luna` es
≈4× más barato por token. `gpt-4.1-nano` **deja de ser una opción el 23-oct**. Antes de mover nada más
hay que medir el consumo real y comparar calidad con un juego de pruebas propio.

## 6. Insumo para «Partir la IA según modo nube o privado» (2.2)

Card `tablero-partir-la-ia-segun-modo-nube-o-privado-0y9k`. Nada de esto se implementa aquí.

- **Hoy el modo no cambia nada de la IA.** En modo privado, el chat manda igualmente el JSON financiero
  completo a OpenAI vía el gateway; Insights y Tendencias mandan agregados. «Privado» se refiere a dónde
  viven los datos, no a la IA. La sesión de partir debería decidir si eso se cuenta así al usuario.
- **El chat de hoy es «todo en el prompt»** (Opción B, sin herramientas) con topes fijos (top 10/20).
  Para «en nube se puede explorar mucho más», la vía natural es que el modelo **pida** datos (function
  calling contra las tablas del usuario en Supabase, desde el gateway) en vez de recibir un resumen
  recortado. Eso cambia la arquitectura del chat y el coste por pregunta: decisión de Jürgen.
- **Para el modo privado** existe una opción sin red: Apple Foundation Models en el dispositivo (§2).
  Contexto pequeño y solo con Apple Intelligence, así que encaja en tareas acotadas (clasificador,
  sugerencias, comentarios de una frase), no en el chat con todo el JSON.
- **El gateway ya sabe quién es quién.** Mover la elección de modelo al gateway
  (`ai-model-choice-lives-in-the-app-binary`) es también el sitio donde partir por modo sin release.
- **Mide antes de ampliar.** Ampliar el contexto en nube multiplica tokens de entrada; sin
  `gateway-does-not-record-ai-token-usage` no habrá forma de saber cuánto.
- Las cuotas del gateway (`policy.ts`) son por tier, no por modo. Si en nube se explora más, puede hacer
  falta una cuota distinta.

## 7. Tickets creados

**Autónomos** (bugs y mejoras acotadas; no cambian modelo ni proveedor):

| Ticket | Prioridad |
|---|---|
| `ai-comments-ignore-the-app-language` | medium |
| `ai-insights-error-card-shows-raw-english-errors` | medium |
| `vision-reads-every-dollar-sign-as-usd` | medium |
| `voice-parser-sends-no-json-mode` | medium |
| `gateway-does-not-record-ai-token-usage` | medium |
| `insights-rate-limit-runs-before-the-cache` | low |
| `ai-responses-use-json-object-not-a-strict-schema` | low |
| `ai-calls-have-no-output-token-cap` | low |
| `chat-sends-every-past-turn-to-the-model` | low |
| `voice-language-and-silence-handling-differ-between-chat-and-sheet` | low |
| `chat-context-encoding-failure-is-silent` | low |
| `gateway-proxies-any-model-and-any-length` | low |

**Para Jürgen** (modelo, proveedor o coste; cada uno con opciones A/B/C y recomendación):

| Ticket | Qué decide |
|---|---|
| `gpt-4-1-nano-shuts-down-on-october-23` | **Urgente, antes del 2026-10-20**: qué sustituye a `gpt-4.1-nano` |
| `ai-model-choice-lives-in-the-app-binary` | Si el modelo se elige en el gateway |
| `ai-text-model-generation-upgrade` | Si se sale de `gpt-4.1-mini/nano` y hacia qué |
| `voice-transcription-model-choice` | `whisper-1`, sucesor de OpenAI o transcripción en el iPhone |
| `image-reading-sends-the-full-resolution-photo` | Resolución y detalle de la foto, u OCR local |
| `free-voice-quota-counts-each-dictation-twice` | Cuánta voz da el plan free |
