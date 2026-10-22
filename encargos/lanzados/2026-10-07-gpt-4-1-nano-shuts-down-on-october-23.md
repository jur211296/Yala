---
esfuerzo: high
---
# El gateway decide el modelo de cada tarea de IA (enrutado por tarea, con modelos elegidos por calidad medida) y ninguna llamada usa gpt-4.1-nano en producción antes del 20-oct

## Contexto
OpenAI apaga `gpt-4.1-nano` (y su snapshot `gpt-4.1-nano-2025-04-14`) el 23-oct-2026. Lo usan tres llamadas de la app: la lectura de fotos (`ImageVisionService`), el clasificador de intención del chat (`ChatIntentClassifierService`) y las sugerencias del chat (`ChatSuggestionsLLMService`). Sin cambio, ese día el registro por imagen deja de funcionar en todas las versiones instaladas, el chat clasifica con el regex de respaldo y las sugerencias caen a las fijas.

Hoy el modelo va dentro del binario de la app y el gateway (`gateway/`, Cloudflare Worker) lo reenvía sin mirarlo (`gateway/src/proxy/openai.ts`).

**Decisión de Jürgen (2026-10-07, 10:03 Lima), sustituye a la del 07:40:** nada de parche. Se hace ya la solución de largo plazo del ticket `ai-model-choice-lives-in-the-app-binary`, opción A: **el gateway es quien decide el modelo y sus parámetros para cada tarea**; la app solo dice qué tarea es. Sus palabras: «quiero ya la solución robusta y correcta a largo plazo, no parcheemos por parchar ni dejemos pendientes. Quiero eficiencia en tokens y en costos, pero asegurarnos de que la tarea se realiza bien; no usamos modelos que no vayan a hacer bien la tarea. Si debe ser un modelo mayor, no importa, a cambio de asegurar calidad.» No se vuelve a preguntar.

**Ampliación de Jürgen (2026-10-07, 10:05 Lima):** «ampliemos la comparación a todos los mercados y elijamos el mejor modelo para cada tarea, sea de quien sea. Y deberemos ir revisando cada cierto tiempo estos modelos para ver si debemos reajustarlos.» El gateway y el banco no pueden quedar atados a OpenAI.

Principio de elección de modelo (aplica a todo): **primero calidad medida, después precio.** Para cada tarea se elige el modelo más eficiente **que pase el listón de calidad** con pruebas propias; si ninguno barato lo pasa, uno mayor. Nunca se elige un modelo solo por precio ni por ser «el sustituto oficial».

Esta es la sesión 1 de dos. Esta sesión: el enrutado en el gateway (válido también para las versiones ya instaladas, que no mandan tarea), el banco de pruebas de calidad, la elección medida para las tres tareas de nano y el deploy. La sesión 2 (encargo aparte, después) hace que la app mande la tarea, mueve los parámetros al gateway y migra las otras tareas con el mismo banco. Diseña pensando en la sesión 2: que no haya que rehacer nada.

Ticket: `tickets/backlog/gpt-4-1-nano-shuts-down-on-october-23.md` y `tickets/backlog/ai-model-choice-lives-in-the-app-binary.md`. Informe: `docs/ai-usage-review-2026-10.md` (hallazgo H0 y tabla de precios). Llegaron con el PR #385; si al arrancar ese PR aún no está en `2.1`, léelos de su rama `encargo/2026-10-07-ai-usage-review-models-cost-and-answers` (`git show origin/<rama>:<ruta>`).

Card del tablero: `tablero-decidir-antes-del-20-oct-openai-apaga-gp-ss4b` (fecha límite 20-oct).

Para orientarte: `CLAUDE.md`, `gateway/README.md` (Deploy y «Pendiente del owner»), `gateway/wrangler.toml` (comentarios de deploy) y la memoria `.claude/agent-memory/frank/project_percent_eleccion_nube_alineado_con_prod.md` (precedente del último deploy de producción, 2026-09-10).

## Que se pide
0. Antes de nada: el PR #385 (rama `encargo/2026-10-07-ai-usage-review-models-cost-and-answers`) tiene los checks en verde pero no se mergea porque choca con `2.1` solo en `docs/TICKETS.md`. Trae `2.1` a esa rama, resuelve el índice conservando las entradas de los dos lados, haz push y deja que el auto-merge lo meta. No toques nada más de ese PR.
1. Inventario: lista las 12 llamadas de IA de la app (8 con `gpt-4.1-mini`, 3 con `gpt-4.1-nano`, 1 con `whisper-1`): servicio, categoría del gateway, modelo, parámetros (temperatura, formato de respuesta, esfuerzo, topes) y forma del cuerpo. De ahí sale el nombre canónico de cada tarea (p. ej. `photo.read`, `chat.intent`, `chat.suggestions`…), que usará la cabecera de la sesión 2.
2. Enrutado en el gateway: una tabla única tarea → {proveedor, modelo, parámetros}, fácil de cambiar y con tests. El gateway habla con cada proveedor mediante un adaptador (formato de entrada y de salida, imagen, JSON estricto, errores y reintentos) y siempre devuelve a la app la misma forma de respuesta que hoy, así cambiar de proveedor nunca exige release. En esta sesión, como mínimo, el adaptador de OpenAI ya pasa por esa interfaz, más el de cualquier proveedor que gane una de las tres tareas. Reglas:
   - Si llega cabecera de tarea (la mandará la app desde la sesión 2; define ya su nombre y formato), manda la tabla.
   - Si no llega (todas las versiones instaladas hoy), el gateway deduce la tarea a partir de la categoría, el modelo pedido y la forma del cuerpo. Las tres tareas de nano tienen que quedar bien identificadas y enrutadas; si dos no se pueden distinguir con certeza, documenta por qué y aplica la elección segura para ambas.
   - Un modelo pedido que no esté en la tabla ni sea deducible no se reenvía a ciegas: decide y documenta el comportamiento (rechazo claro o tarea por defecto de la categoría).
   - El gateway registra en los logs, por petición, la tarea resuelta y el modelo usado (sin contenido del usuario), para poder verificarlo con `wrangler tail`.
3. Banco de pruebas de calidad en el repo (dónde y cómo, decides tú; que lo pueda reusar la sesión 2 para todas las tareas): casos reales por tarea (fotos de recibos, capturas de notificaciones bancarias y extractos para `photo`; frases de chat en los 10 idiomas de la app (es, en, pt, fr, de, it, nl, pl, ja, zh-Hans, con variantes regionales como es-PE, es-ES, pt-BR y pt-PT) para el clasificador y las sugerencias), sin datos personales, con criterio de acierto explícito por tarea, y un script que corre cada modelo candidato y saca acierto, latencia, tokens y coste por caso. Si para llamar a OpenAI desde el banco necesitas una clave y no la encuentras en el vault del proyecto en 1Password, pregunta con AskUserQuestion; no la saques de los secrets del Worker.
4. Elección medida para las tres tareas de nano, **con candidatos de todo el mercado**: de OpenAI al menos `gpt-4.1-nano` (línea base de hoy, mientras exista), `gpt-4.1-mini`, `gpt-5.6-luna`, `gpt-6-luna`, `gpt-5.4-mini` y `gpt-5.6-terra`; de Google (familia Gemini Flash / Flash-Lite actual), de Anthropic (Haiku actual y uno mayor) y, si alguno es razonable de servir, modelos abiertos alojados (p. ej. Workers AI u otro proveedor). Comprueba versiones y precios vigentes en las páginas oficiales el día que corras el banco. Para los de razonamiento, prueba el esfuerzo bajo y ninguno. Si para un proveedor no hay clave en el vault del proyecto en 1Password, pregunta con AskUserQuestion qué hacer (crear cuenta y clave o saltarlo) en lugar de descartarlo en silencio. Listón: igual o mejor que nano hoy en acierto, sin romper el formato JSON, y dentro del tiempo límite de la app (20 s). Elige por tarea el más eficiente que pase, sea del proveedor que sea. Si gana uno que no es OpenAI, revisa antes qué exige: privacidad (dónde procesa, si retiene o entrena con los datos), texto de consentimiento de la app y política de privacidad web (que hoy pueden nombrar solo a OpenAI), clave, cuotas y DPA. Si eso no llega antes del 20-oct, deja en producción el mejor de OpenAI que pase el listón y deja escrito el cambio de proveedor como paso concreto del ticket de la sesión 2 (no como pendiente sin dueño). **Imagen (decisión de Jürgen, 2026-10-07, 10:16 Lima): «lo más óptimo».** La resolución y el `detail` que se mandan son parte de la elección de cada modelo, no un ajuste aparte: en el banco, cada candidato de foto se prueba también con distintas resoluciones (reducida en el lado mayor al máximo útil de ese modelo) y con detalle bajo y alto, usando fotos reales (recibos largos, capturas de notificaciones bancarias, extractos con muchas filas). Gana la combinación más eficiente que pase el listón, y esa resolución y ese detalle quedan en la tabla del gateway. El reescalado en la app a ese máximo (para ahorrar datos y evitar el límite de 20 s) va como paso concreto en el ticket de la sesión 2, sin enviar nunca más píxeles de los que el modelo elegido aprovecha. Deja los resultados en `docs/` (tabla por tarea y candidato, con proveedor, acierto, latencia, tokens y coste) y la elección con su porqué.
5. Tests del gateway (vitest): enrutado con y sin cabecera, deducción de las tres tareas de nano con cuerpos reales (imagen incluida), modelo desconocido, parámetros que salen según la tabla, y un control que salga rojo con el código viejo. `npm test` y `npm run typecheck` en `gateway/` verdes; resultado en el PR.
6. PR a `2.1` con auto-merge. El deploy sale de `2.1` ya mergeado.
7. Antes de desplegar, compara lo desplegado con `2.1`. El último deploy de producción y de staging es del 2026-09-10 ~06:43 Lima (prod version `034e1074`). Desde entonces hay en `2.1` seis commits que tocan `gateway/src` o `wrangler.toml` y que viajarán con este deploy: `fdfbb5e5f`, `783a4ec9b` (quita `secondarySessionRolloutPercent` de `/config` y del `.toml`), `647c16e1e` (killSwitch), `03a6217c1`, `028c5e3df`, `42c056399` (los cuatro de `sync/account.ts`). Lístalos en el PR con una línea de producto cada uno.

**OK de Jürgen (2026-10-07, 08:06 Lima): desplegar `2.1` entero, con los seis commits.** Verifica primero en staging que los seis no rompen nada: `/config` sin `secondarySessionRolloutPercent`, el killSwitch de Grupos y el sync de cuenta. Si algo falla en staging, para antes de producción y avisa. No se vuelve a preguntar.
8. Deploy a staging con `npm run deploy:staging` y verificar ahí, con `wrangler tail`, que las tres tareas se resuelven bien y salen con el modelo elegido y responden bien (foto, clasificación, sugerencias), y que las otras 9 llamadas siguen igual que hoy.
9. Deploy a producción con `npm run deploy:production` y verificar: `/healthz`, que no sale ninguna llamada a `gpt-4.1-nano`, y que foto, clasificador y sugerencias responden con el modelo elegido. Anota en el PR la version ID anterior y la nueva (la anterior es el rollback: `wrangler rollback`). Si la comprobación con la app de la tienda necesita teléfono, deja un guion corto de device-QA en `tickets/qa/` para Jürgen.
10. Encargo de la sesión 2: escribe en `tickets/backlog/` el ticket de la sesión 2 con todo lo que falte para cerrar `ai-model-choice-lives-in-the-app-binary` del todo: la app manda la cabecera de tarea en las 12 llamadas, los parámetros dejan de vivir en la app, y las 8 tareas de `gpt-4.1-mini` pasan por el banco con el mismo principio (candidatos de OpenAI y, si el banco lo justifica, de otros proveedores, anotando lo que exigiría un segundo proveedor: claves, cuotas, privacidad, texto de consentimiento). Añade además que el banco se pueda volver a correr con un solo comando para la revisión periódica de modelos que pidió Jürgen (documenta cómo en `docs/`). **Voz (decisión de Jürgen, 2026-10-07, 10:06 Lima):** «la mejor opción que haya en el mercado, esta funcionalidad es clave, no vayamos por el más barato así nomás». Para la transcripción manda la calidad medida, no el precio: el ticket de la sesión 2 tiene que comparar los mejores motores de voz del mercado, en la nube y en el iPhone (OpenAI `gpt-transcribe` con palabras clave, los de Google, Deepgram, AssemblyAI, ElevenLabs, el SpeechAnalyzer de Apple y otros que haya ese día), con audios reales en los 10 idiomas de la app (es, en, pt, fr, de, it, nl, pl, ja, zh-Hans, con variantes regionales como es-PE, es-ES, pt-BR y pt-PT): acento peruano, ruido de calle, montos, fechas y nombres de comercios. Se mide el error por palabra, el acierto en montos y comercios, y el resultado final de la nota ya interpretada; la latencia cuenta, y el coste solo desempata. Hueco detectado el 7-oct a corregir en la sesión 2: el selector de idioma de voz solo ofrece Sistema, español e inglés (`VoiceLanguage` en `VoiceTranscriptionService.swift`), y «Sistema» toma el idioma del iPhone (`Locale.preferredLanguages`), no el que el usuario eligió en la app; además, un idioma no reconocido cae a inglés. La voz debe seguir el idioma de la app y cubrir los 10. `gpt-4o-mini-transcribe` queda descartado (se apaga el mismo día que `whisper-1`). **Cuota free (decisión de Jürgen, 2026-10-07, 10:19 Lima, opción B):** una nota de voz = 1 uso (transcribir e interpretar la misma nota cuentan juntos), y la cuota free de voz y de foto deja de ser diaria y pasa a ser un cupo de prueba de 5 notas y 5 fotos en total por dispositivo, sin reinicio diario. Voz y foto siguen siendo Pro fuera de la prueba de «Configura tu Yala». Va en la sesión 2 (gateway y app), con tests de que la 5.ª nota completa funciona y la 6.ª se rechaza con el mensaje claro de pasarse a Pro. Enlaza ahí los tickets `ai-text-model-generation-upgrade`, `voice-transcription-model-choice`, `image-reading-sends-the-full-resolution-photo`, `free-voice-quota-counts-each-dictation-twice` y `gateway-proxies-any-model-and-any-length`, que se resuelven con el mismo banco.
11. Tickets: anota la decisión de Jürgen (10:03, opción A ya, calidad primero) en el ticket de nano y en `ai-model-choice-lives-in-the-app-binary`, muévelos según las convenciones del repo y actualiza `docs/TICKETS.md`.
12. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-decidir-antes-del-20-oct-openai-apaga-gp-ss4b` a «done» si producción quedó verificada, o a «in qa» asignada a jurgen si queda device-QA, con `tablero mover <id> --a "<estado>" --agente frank` (y `tablero asignar` si toca).

## Que NO hay que tocar
- El código Swift de la app: en esta sesión no se compila iOS ni se arranca simulador (la cabecera desde la app es la sesión 2).
- El modelo y los parámetros de las otras 9 llamadas: deben salir exactamente como hoy, aunque ya pasen por la tabla.
- Los percents y demás vars de `wrangler.toml`, las migraciones D1 y los secrets del Worker.
- Nunca `wrangler deploy` a pelo: siempre los scripts de npm (su `predeploy` copia los manifests que git ignora).
- No despliegues a producción nada más que este cambio y los seis commits listados.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml`, `avisar-grok-push-principal.yml`, marketing/ y Web/.

Gate tras el CI de los PR anteriores: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR anterior (el de `ipad-drop-unreadable-file-fails-silently`) y el #385 siguen en CI. Si siguen, espera a que entren y rebasa una sola vez. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue.

Mini limpia al cerrar: sin simuladores encendidos, sin worktree ni cachés de esta sesión tras el merge, sin borrar nada de otra sesión viva.

## Como se sabe que esta bien
- La tabla tarea → modelo vive en el gateway, con cabecera definida y deducción para versiones instaladas; tests verdes con control rojo.
- Banco de pruebas en el repo y resultados por tarea y candidato en `docs/`; las tres tareas de nano usan el modelo más eficiente que pasa el listón de calidad.
- Staging y producción desplegados desde `2.1` con los scripts de npm, con version IDs antes y después en el PR; en producción no sale ninguna llamada a `gpt-4.1-nano`.
- Ticket de la sesión 2 escrito y enlazado; tickets y `docs/TICKETS.md` al día; card movida; Mini limpia.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> Jürgen contestó en sesión (10:3x Lima) solo lo de las claves: OpenAI, Gemini y Anthropic las deja él en `~/Secrets/yala-ai-bench/`.

**D1 · Cabecera de tarea** → `X-Yala-Task: <tarea>`, nombres `area.accion` en minúscula (`photo.read`, `chat.intent`, `chat.suggestions`…). Una tarea por cabecera manda la tabla entera (proveedor, modelo, parámetros); el `model` del cuerpo se ignora.
Por qué: la app deja de saber de modelos. Descartado: reutilizar `X-Yala-Category` (mezcla tareas: `suggestions` lleva tres, `insights` cinco).

**D2 · Cabecera desconocida o incoherente** → valor desconocido: se ignora y se deduce (log `header_unknown`); tarea conocida cuya categoría no casa con `X-Yala-Category`: 400.
Por qué: un rollback del gateway no debe tumbar a una app más nueva, y la categoría de cuota no se puede usar para colar una tarea cara bajo un cubo barato.

**D3 · Deducción sin cabecera (todas las versiones instaladas)** → ruta + categoría + modelo + huella del prompt de sistema. `photo.read` = categoría `vision`; `chat.intent` y `chat.suggestions` = `suggestions` + nano, separados por el inicio del prompt de sistema (sin cambios desde que existen, abril de 2026; el gateway es de junio). Sin huella: temperatura 0 → `chat.intent`, si no → `chat.suggestions` (log `heuristic`).
Por qué: las tres se distinguen con certeza; la heurística solo cubre un cuerpo que no salió de la app.

**D4 · Las llamadas que no son nano** → `gpt-4.1-mini` y `whisper-1` sin cabecera salen **byte a byte** como hoy (se reenvían los bytes recibidos); la tarea se deduce solo para el log, y si no hay huella queda `<categoria>.legacy`.
Por qué: el encargo exige que salgan exactamente igual.

**D5 · Modelo fuera de la tabla** → 400 con error en formato OpenAI (`model_not_allowed`). Ninguna versión con gateway manda otro modelo que `gpt-4.1-mini`, `gpt-4.1-nano` o `whisper-1`.
Por qué: reenviar a ciegas deja usar el gateway como proxy gratis de cualquier modelo (`gateway-proxies-any-model-and-any-length`).

**D6 · Proveedor en producción sin cabecera = solo OpenAI** → las versiones instaladas dicen en el permiso de cámara/fotos, en el consentimiento y en la política web que «la foto se envía a OpenAI». Un proveedor distinto solo puede servir peticiones **con cabecera** de una versión cuyo texto lo cuente. Un ganador que no sea OpenAI va a la sesión 2 como paso concreto.
Por qué: el gateway no puede cambiar el texto que ya leyó el usuario. Además, su clave sería un secret nuevo del Worker, fuera de lo que esta sesión puede tocar.

**D7 · Imagen** → la tabla lleva `detail` (el gateway lo aplica ya) y `maxEdge` (contrato para el reescalado en la app, sesión 2). El gateway no reescala: no hay librería de imagen en el Worker y el binding de Images es un servicio nuevo de pago.

**D8 · Banco** → `gateway/bench/`, en TypeScript, y **llama a través de los mismos adaptadores del gateway**: lo que se mide es lo que se despliega. Casos y criterio por tarea en `gateway/bench/cases/`; resultados crudos en `gateway/bench/results/`; informe en `docs/`.
Por qué: un banco con su propio cliente HTTP mide otra petición.

**D9 · Casos de foto sin datos personales** → recibos reales con licencia libre (Wikimedia Commons / CORD), los recibos de ejemplo de la app y capturas de notificaciones y extractos renderizadas con datos ficticios (una captura es un render: no hay «foto real» de una captura). Fotos reales de Jürgen, anonimizadas, quedan como paso de la sesión 2.

**D10 · Listón** → acierto ≥ el de `gpt-4.1-nano` en el mismo banco, 100 % de JSON válido para el parser de la app y latencia p95 ≤ 5 s para clasificador y sugerencias (la app corta a los **8 s**, no a los 20) y ≤ 12 s para la foto (corta a 20 s y hay que subir la imagen). Entre los que pasan, gana el de menor coste por llamada.
Por qué: el clasificador y las sugerencias tienen su propio timeout de 8 s en el código (`timeoutSeconds = 8`).

**D11 · Reintentos** → el adaptador los soporta (`retries` por ruta, solo en red/429/5xx); en la tabla quedan a 0.
Por qué: con 8 s de presupuesto, un reintento convierte un error rápido en un timeout.

**D12 · Log por petición** → una línea JSON `ai_route` con tarea, cómo se resolvió, proveedor, modelo, estado, ms y tokens de `usage`. Sin contenido.

**D13 · PR #385** → el merge de `2.1` traía Swift ya verificado en `2.1` (diff de `.swift` contra `2.1` vacío); se commiteó con `--no-verify` tras pasar a mano el `commit-msg`. El sello del gate no aplicaba: el PR no toca Swift.

**D14 · La lectura de la nota de voz contaba en el cubo `chat`** (hallazgo, medido en código; el tail de producción de 2,5 min no tuvo tráfico) → **se arregla hoy**, decisión de Jürgen (11:2x Lima, AskUserQuestion): `voice` entra en las categorías de `/v1/chat/completions`. Antes, un usuario free recibía 403 «requiere Pro» al interpretar cada nota de voz desde el 2026-06-15; un Pro gastaba esa lectura del cupo de chat. La cuota nueva (una nota = un uso, cupo de 5) sigue en la sesión 2.

**D15 · Typecheck del gateway** → se arregla porque el encargo exige `npm run typecheck` verde y en `2.1` ya daba 6 errores en tests (sin tipos de Node). Dos tsconfig: `src/` solo con tipos de Workers; `test/` y `bench/` aparte con un `test/node-shim.d.ts` mínimo. Sin `@types/node`: metería `process`/`Buffer` en el ámbito del Worker, que es lo que el ticket `gateway-typecheck-roto-y-fuera-del-ci` pedía evitar.

**D16 · Gasto del banco** → Jürgen eligió OpenAI Build con 20 USD («usuarios súper bajos»). El banco va en dos pasadas (cribado a resolución original y barrido de resolución y detalle solo para quien pasa) y para si el gasto se acerca a 10 USD.
