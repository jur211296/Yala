---
id: ai-every-call-sends-its-task-and-passes-the-bench
status: qa
priority: high
area: ai, gateway, app, voice, image, quota
created: 2026-10-07
updated: 2026-10-08
qa-status: needs-testing
source: sesión 1 de ai-model-choice-lives-in-the-app-binary (encargo gpt-4-1-nano-shuts-down-on-october-23)
---

# La app dice qué tarea pide, y las 12 llamadas de IA pasan por el banco (sesión 2)

> **Encargo de la sesión 2**, escrito por la sesión 1 (2026-10-07). Cierra
> `ai-model-choice-lives-in-the-app-binary` del todo. Decisiones de Jürgen que lo gobiernan, todas del
> 2026-10-07 y sin volver a preguntar: el gateway decide modelo y parámetros por tarea (10:03, opción A);
> **primero calidad medida, después precio** («si debe ser un modelo mayor, no importa»); comparar con
> todo el mercado y revisar los modelos cada cierto tiempo (10:05); voz con el mejor motor del mercado
> (10:06); imagen «lo más óptimo» (10:16); cuota free de voz y foto como cupo de prueba (10:19, opción B).

## Lo que ya dejó la sesión 1

- **La tabla tarea → {proveedor, modelo, parámetros} vive en el gateway** (`gateway/src/ai/routes.ts`), con
  adaptadores de OpenAI, Gemini, Anthropic y Workers AI que devuelven siempre la forma de OpenAI.
- **Cabecera `X-Yala-Task`**, nombres en `gateway/src/ai/tasks.ts`. Sin cabecera, el gateway deduce la tarea
  (categoría + modelo + huella del prompt); las tres de `gpt-4.1-nano` ya salen con el modelo elegido por el
  banco. Las otras nueve salen **byte a byte** como antes (`passthrough`).
- **Banco** en `gateway/bench/` (README con el comando de la revisión periódica) y resultados en
  `docs/ai-model-bench-2026-10.md`.
- **La lectura de la nota de voz cuenta en el cubo `voice`** (antes caía en `chat`, que en free no existe:
  la prueba de voz free fallaba entera desde el 2026-06-15). Desde entonces cada nota gasta 2 usos de voz:
  el paso 5 lo corrige.

## Qué hay que hacer

1. **La app manda la tarea en las 12 llamadas.** `ProxyClientFactory.makeOpenAI(category:)` pasa a recibir
   también la tarea y la manda en `X-Yala-Task`. Nombres: los de `TASKS` (`photo.read`, `chat.intent`,
   `chat.suggestions`, `chat.answer`, `chat.rewrite`, `text.parse`, `voice.transcribe`, `insights.cards`,
   `insights.cashflow`, `insights.deviation`, `insights.contextual` —sin llamadores: decidir si se borra—,
   `trends.summary`). Test por servicio: la cabecera sale con su tarea. El gateway ya rechaza una tarea cuyo
   cubo no casa con `X-Yala-Category`; con la cabecera puesta, que el cubo **salga de la tarea** y no del
   cliente (cierra la mitad de `gateway-proxies-any-model-and-any-length`).
2. **Los parámetros dejan de vivir en la app.** Con cabecera, el gateway ya ignora el `model` del cuerpo y
   aplica los de la fila. Pasar las filas `passthrough` a `managed` cuando cada tarea tenga su banco (paso 3);
   hasta entonces, su fila managed reproduce los parámetros de hoy. La app puede seguir mandando un `model`
   (el SDK lo exige), pero ya no decide nada.
3. **Las 8 tareas de `gpt-4.1-mini` por el banco**, con el mismo principio y el mismo listón (igual o mejor
   que el modelo de hoy, JSON que la app acepta, dentro de su timeout): casos sin datos personales en los 10
   idiomas con variantes regionales, criterio explícito por tarea (replicar el parser de la app primero),
   candidatos de todo el mercado. Para el chat y los comentarios de Insights hace falta un criterio que no sea
   solo forma: fidelidad a los números del contexto (ningún número inventado) e idioma; si se usa un juez,
   que sea otro modelo y que se mida su acuerdo con una muestra puntuada a mano. Anotar por candidato lo que
   exigiría un segundo proveedor (ver el paso 7).
4. **Voz: el mejor motor del mercado, por calidad medida** (el coste solo desempata). Comparar en la nube y en
   el iPhone: OpenAI `gpt-transcribe` con `keywords`, **xAI** (STT por REST a 0,10 USD/h y en streaming por
   `wss://api.x.ai/v1/stt`; Jürgen nota que el dictado de Grok le funciona mejor que el de Yala, 2026-10-07),
   los de Google, Deepgram, AssemblyAI, ElevenLabs, el `SpeechAnalyzer`/`SpeechTranscriber` de Apple y los que
   haya ese día. **`gpt-4o-mini-transcribe` queda
   descartado** (se apaga con `whisper-1`, el 2027-02-26). Audios reales en los 10 idiomas (es, en, pt, fr,
   de, it, nl, pl, ja, zh-Hans) con variantes (es-PE, es-ES, pt-BR, pt-PT): acento peruano, ruido de calle,
   montos, fechas y nombres de comercios. Medir error por palabra, acierto en montos y comercios, y el
   resultado final de la nota ya interpretada (transcripción + `text.parse`); la latencia cuenta.
   **Hueco a corregir en la misma sesión:** el selector de idioma de voz solo ofrece Sistema, español e
   inglés (`VoiceLanguage` en `VoiceTranscriptionService.swift`), «Sistema» toma el idioma del iPhone
   (`Locale.preferredLanguages`) y no el que el usuario eligió en la app, y un idioma no reconocido cae a
   inglés. La voz sigue el idioma de la app y cubre los 10.
5. **Cuota free de voz y foto: cupo de prueba** (opción B de Jürgen). Una nota de voz = 1 uso (transcribir e
   interpretar la misma nota cuentan juntos), y la cuota free deja de ser diaria: 5 notas y 5 fotos **en
   total por dispositivo**, sin reinicio. Fuera de la prueba de «Configura tu Yala», voz y foto siguen siendo
   Pro. Gateway (`policy.ts`, `rate_limiter.ts`: un contador sin ventana por device) y app (mensaje claro de
   pasarse a Pro). Tests: la 5.ª nota completa funciona y la 6.ª se rechaza con ese mensaje; lo mismo con
   las fotos. Cierra `free-voice-quota-counts-each-dictation-twice` (su premisa cambió el 2026-10-07: antes
   la segunda llamada caía en el cubo `chat`; ahora gasta del de voz).
6. **Imagen: la app reduce la foto al máximo útil del modelo elegido**, nunca más píxeles de los que el modelo
   aprovecha: el `maxEdge` de la fila `photo.read`, **1536 px** según el banco del 7-oct (y su `detail`, que el gateway
   ya aplica). Antes de bajar del valor medido, volver a medir con fotos reales gastadas.
6 bis. **Divisas que el prompt de la foto no enseña.** Es lo único que separa a `gpt-6-luna` del 100 % en la foto
   (`docs/ai-model-bench-2026-10.md`). El prompt de `ImageVisionService` solo da reglas para $, €, S/ y £, y Yala está en
   japonés, chino, polaco y portugués de Brasil: con ¥, zł o R$ el modelo devuelve `null`. Añadir los símbolos de las
   divisas de los 10 idiomas (¥ según el contexto: JPY o CNY) y volver a correr `npm run bench -- --task photo.read`.
   Va de la mano de `vision-reads-every-dollar-sign-as-usd`. Ahorra datos y
   aleja el timeout de 20 s. Si la fila cambia de modelo, el `maxEdge` viaja con ella: la app lo lee del
   gateway (p. ej. en `/config`) o lo fija la release que cambie de modelo. Cierra
   `image-reading-sends-the-full-resolution-photo`.
7. **Segundo proveedor, si el banco lo justifica en alguna tarea** (ver el informe de la sesión 1): solo para
   peticiones **con** cabecera, de una versión cuyo texto lo cuente. Requisitos antes de encenderlo:
   - texto de consentimiento y de permisos de la app (hoy dicen «se envía a OpenAI» en
     `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSMicrophoneUsageDescription` y
     `aiConsent.*`, en todos los idiomas);
   - política de privacidad web (`Web/privacy_content.md` nombra solo a OpenAI);
   - DPA y retención del proveedor (Gemini: solo el nivel **de pago** no entrena con los datos);
   - su clave como secret del Worker (`GEMINI_API_KEY` / `ANTHROPIC_API_KEY`, ya declaradas en `env.ts`);
   - cuotas y límites del proveedor para el tráfico de Yala;
   - `LEGACY_OVERRIDES` con el mejor de OpenAI para esa tarea: las versiones instaladas prometen OpenAI, y
     `routeFor` se niega a servirles otro proveedor (test en `ai.routing.test.ts`).

   **Anthropic medido el 2026-10-08 y descartado** (`docs/ai-model-bench-2026-10-claude.md`): ni Sonnet 5.5 ni Haiku
   5.5 pasan el listón en tarjetas de Insights ni en Tendencias. El candidato de este paso sigue siendo Gemini 3.8
   Flash en Tendencias (100 %, p95 5,2 s, 1,53 USD por 1 000 frente a 96,9 % y 4,16 de `gpt-6.1-sol`).
8. **Revisión periódica de modelos.** El comando ya existe (`npm run bench -- --task all`, en
   `gateway/bench/README.md`). Falta decidir la cadencia y quién la dispara (propuesta: trimestral, y
   siempre que OpenAI anuncie un apagado en https://developers.openai.com/api/docs/deprecations).
9. **Cuenta de OpenAI con el correo de Yala** (petición de Jürgen del 2026-10-07). Ya existe la organización
   con 20 USD en el plan Build. Pasos: crear el proyecto `yala-gateway` y su clave; `npx wrangler secret put
   OPENAI_API_KEY` en staging, probar foto/clasificador/sugerencias; después `--env production` y vigilar con
   `wrangler tail`; revocar la clave vieja a los pocos días. Antes, comprobar en *Settings › Limits* que los
   límites del nivel de la cuenta cubren el tráfico.

## Tickets que se resuelven con esto

`ai-model-choice-lives-in-the-app-binary` · `ai-text-model-generation-upgrade` ·
`voice-transcription-model-choice` · `image-reading-sends-the-full-resolution-photo` ·
`free-voice-quota-counts-each-dictation-twice` · `gateway-proxies-any-model-and-any-length` (el modelo ya
está cerrado; falta la longitud y la categoría por tarea).

## Hecho cuando

- Las 12 llamadas mandan `X-Yala-Task` y el gateway decide modelo y parámetros de todas.
- Cada tarea tiene casos, criterio y resultado en `docs/`, y su fila sale del banco.
- La voz sigue el idioma de la app en los 10 idiomas, con el motor elegido por calidad medida.
- La cuota free es un cupo de 5 notas y 5 fotos por dispositivo, con sus tests.
- La foto viaja reducida al `maxEdge` de su fila.

## Hecho (sesión 2, 2026-10-07)

- **Las 12 llamadas por la tabla.** La app manda `X-Yala-Task` en las 11 que quedan (`ProxyTask`; `insights.contextual` se
  retiró: su llamador se fue el 2026-04-12). Con cabecera el cubo sale de la tarea. Las versiones instaladas se enrutan
  por deducción a las mismas filas.
- **Filas del banco** (`gateway/src/ai/routes.ts`, informes en `docs/ai-model-bench-2026-10.md`,
  `docs/ai-voice-bench-2026-10.md` y `gateway/bench/results/2026-10-07/REPORT-*.md`): chat, reescritura y lectura de la
  nota a `gpt-6-luna`; la voz a `gpt-transcribe` con los términos del usuario; Insights a `gpt-6-luna` y Tendencias a
  `gpt-6.1-sol`. Todo sigue en OpenAI: Gemini 3.8 Flash empata en Tendencias a un tercio del precio y queda preparado y
  apagado (`PREPARED_ROUTES`) hasta cumplir el paso 7.
- **Cupo de prueba**: 5 notas y 5 fotos en total por instalación, una nota = un uso, el fallo del proveedor devuelve el
  uso, y la app enseña «Ya usaste tus notas/fotos de prueba» con «Ver Yala Pro». Verificado en producción con un
  dispositivo ficticio: la 6.ª nota y la 6.ª foto dan 403 `yala_trial_exhausted`.
- **Voz**: «Idioma de la app» (sigue al de Yala) y los 10 idiomas; nada cae a inglés.
- **Foto**: sube reducida al `maxEdge` de su fila (1536 px, publicado en `/config`); el prompt enseña ¥, R$, zł y CHF, y
  el «$» lo decide la divisa principal. En el banco, del 94,2 % al 100 %.
- **Cuenta de OpenAI de Yala**: el gateway de staging y el de producción usan claves de cuenta de servicio de la
  organización de Yala (proyectos propio de staging y «Yala - Production»).

## Device-QA (iPhone, con el build que lleve esta sesión)

Lo del gateway ya está en producción y no necesita build: las versiones instaladas ya leen fotos, notas y chat con los
modelos nuevos. Lo que sí necesita el build nuevo:

1. **Selector de voz.** Ajustes › Personalización › Idioma de voz. Esperado: «Idioma de la app» marcado y los 10
   idiomas con su nombre (Español, English, Português, Français, Deutsch, Italiano, Nederlands, Polski, 日本語, 中文).
2. **Nota con un comercio tuyo.** Con «Idioma de la app», dicta «Ayer 25 soles con 50 en <un comercio que uses mucho>».
   Esperado: importe 25,50 y el comercio bien escrito en el borrador.
3. **Dictar en otro idioma.** Elige English en el selector y dicta «Coffee 4.50 at Starbucks». Esperado: borrador de
   4,50. Vuelve a «Idioma de la app».
4. **Foto de un recibo real.** Esperado: lee el total en unos segundos (la foto sube reducida).
5. **«$» a secas** (`vision-reads-every-dollar-sign-as-usd`). Con la divisa principal en PEN, foto de un ticket que diga
   solo «$ 25.00». Esperado: el borrador sale sin divisa decidida (la eliges tú), no en USD.
6. Avísame cuando lo pruebes y miro `wrangler tail`: cada llamada debe salir con `how: "header"`.

El cupo de prueba agotado no se puede ver con una cuenta Pro: está verificado en producción y por XCUITest
(`VoiceEntryReviewUITests` / `ImageEntryReviewUITests#test_trialUsedUp_saysSo_andOffersPro`).
