# Banco de voz — octubre 2026: qué motor transcribe las notas de Yala

> Fecha: 2026-10-07. Paso 4 de `tickets/backlog/ai-every-call-sends-its-task-and-passes-the-bench.md` (sesión 2 de
> `ai-model-choice-lives-in-the-app-binary`). Banco: `gateway/bench/voice/` (comando: `cd gateway && npm run
> bench:voice`). Casos: `gateway/bench/cases/voice/`. Datos crudos: `gateway/bench/results/2026-10-07/voice.*`.
> Precios comprobados ese día en las páginas oficiales (enlazadas en `gateway/bench/voice/run.ts`).
> Gasto total: ≈ 2,45 USD: OpenAI 1,39 (transcripción 0,83, lectura de la nota 0,54, TTS y pruebas de humo ~0,02; tope de Frank: 2), Gemini 0,28 (+ ~0,05 de TTS), Deepgram 0,25 (crédito de prueba de 200 USD), ElevenLabs 0,17 (horas incluidas en el plan Starter), AssemblyAI 0,16 (crédito de prueba de 50 USD), xAI 0,14, Apple 0.

## Resultado

**Gana OpenAI `gpt-transcribe` con `keywords`** (las subcategorías y los comercios de la persona) y su idioma en
`languages`. Es el motor que mejor transcribe de los 15 medidos, y además es el de OpenAI: **no hace falta un segundo
proveedor** para la voz, ni cambiar los textos de permisos.

| | `whisper-1` (hoy) | **`gpt-transcribe` + keywords** | ElevenLabs Scribe v2 | AssemblyAI Universal-3.5 Pro | Gemini 3.8 Flash | xAI Grok STT + keyterms |
|---|---|---|---|---|---|---|
| Error por palabra, notas (limpio · 10 dB · 5 dB) | 6,4 · 9,4 · 13,9 % | **1,3 · 2,6 · 5,7 %** | 2,7 · 3,3 · 6,1 % | 3,6 · 3,8 · 6,6 % | 4,0 · 3,9 · 5,9 % | 7,5 · 9,9 · 14,6 % |
| Error, habla real peruana (OpenSLR 73) · FLEURS 10 idiomas | 3,7 · 7,1 % | **2,0** · 4,1 % | **2,0 · 3,0 %** | 4,7 · 4,3 % | 3,8 · 4,6 % | 4,6 · 10,3 % |
| Comercio en el texto | 74,7 % | 96,9 % | 98,3 % | 97,2 % | 99,3 % | 93,8 % |
| Nota interpretada: núcleo · con comercio¹ | 95,6 · 73,7 % | 94,2 · **92,1 %** | 96,9 · 96,9 %² | 100 · 98,0 %² | 100 · 100 %² | 87,4 · 82,5 % |
| Latencia p50 / p95 | 7,2 / 14,5 s* | **0,8 / 1,2 s** (en serie, 88 llamadas) | 4,4 / 5,5 s* | 4,1 / 11,7 s* | 12,1 / **19,9 s*** | 3,5 / 4,7 s* |
| USD por hora de audio | 0,36 | 0,27 | 0,27 | 0,26 | 0,31 | 0,10 |
| Apagado anunciado | **2027-02-26** | — | — | — | — | — |

¹ Núcleo: importe, signo y fecha de cada movimiento, y el número exacto de movimientos, tras la lectura de la app.
Con comercio: además el comercio en la nota. ² Solo sobre las notas leídas (262, 250 y 315 de 342): las demás quedaron
sin leer al cerrar el banco (ver «Lo que no funcionó y lo que queda») y son justo las transcripciones que no coinciden con las de otro
motor, así que ese porcentaje está sesgado hacia arriba. * Latencia de la criba en paralelo: inflada, solo orienta.

**Por qué gana:** el menor error en limpio y con ruido de calle de los 15, empatado con ElevenLabs en el habla peruana
real, y +18 puntos de comercio bien escrito en la nota frente a `whisper-1` (92 % frente a 74 %). Es más barato que
`whisper-1` y, sin apagado anunciado, sustituye a `whisper-1`, que se apaga el 2027-02-26. ElevenLabs y AssemblyAI
quedan cerca, pero ninguno mejora la transcripción de `gpt-transcribe` y exigirían un segundo proveedor.

**Un matiz que decide un parámetro:** `gpt-transcribe` deja muchos importes **en letra** («cincuenta y seis veinte»,
«doce mil pesos») y la lectura de la app no entiende los decimales coloquiales en letra, así que su nota núcleo
queda 1,4 puntos por debajo de `whisper-1` (que siempre escribe cifras). Un `prompt` fijo que pide cifras lo recupera
en parte: en las 88 notas con decimales dichos en letra, núcleo 77 → **81** (`whisper-1`: 84), comercio 71 → 76
(`whisper-1`: 63), y las cifras en el texto pasan de 47 a 79 de 88, sin que el prompt se cuele en el texto (0 de 88).
Lo que queda de esa diferencia es de la lectura de la nota, no de la transcripción (ver «Lo que no funcionó y lo que queda»).

**Listón: ninguno lo pasa entero**, y conviene decirlo. `gpt-transcribe` con keywords cumple el error, la latencia,
el apagado y la cobertura, pero se queda por debajo de `whisper-1` en la nota núcleo en es-AR, es-ES, pt-BR y pl-PL
(1 a 4 notas de 24-30 en cada una) por los importes en letra, y en importes de pt-BR (88 %). ElevenLabs falla la nota
en es-AR, es-ES y pl-PL; AssemblyAI, el error en pt-PT (25 %); Gemini 3.8 Flash, la latencia (p95 19,9 s, el corte de
la app es 20 s); Apple `SpeechTranscriber`, la cobertura (sin neerlandés ni polaco).

## Listón

Primero calidad medida, después precio (Jürgen, 2026-10-07). Un motor pasa si cumple **todo**:

1. **Error en limpio ≤ 15 % (WER) en CADA una de las 14 variantes**, y ≤ 10 % de error por carácter (CER) en japonés
   y chino.
2. **Importes en el texto ≥ 90 % en cada variante** (todas las condiciones). El importe vale en cifras o escrito en
   letra tal como se dijo: mide si el motor OYÓ el importe. Si la lectura de la app lo entiende después lo mide el
   punto 3 (en letra falla con los decimales coloquiales: ver «Lo que no funcionó y lo que queda»).
3. **Nota interpretada (núcleo) ≥ la de `whisper-1` en CADA variante.** Es lo que la persona ve: importe, signo
   (gasto o ingreso) y fecha correctos y el número exacto de movimientos, después de pasar la transcripción por la
   lectura de la app. Con 24-30 notas por variante, una nota son 3-4 puntos: el empate cuenta como pasar.
4. **Latencia p95 ≤ 15 s** (75 % del corte de 20 s que la app pone a cada petición, `ProxyClientFactory`), medida en
   serie.
5. **Sin apagado anunciado antes del 2027-10-07** (12 meses).
6. **Los 14 idiomas y variantes**: un motor que no cubre alguno queda fuera, aunque gane en los demás.

Entre los que pasan, gana el de mejor nota interpretada; el error por palabra desempata, y el precio solo después.

## Cómo se midió

### Corpus (`gateway/bench/cases/voice/`, sin datos personales)

- **84 notas de finanzas sintéticas**, 6 por variante: es-PE, es-AR, es-ES, en-US, en-GB, pt-BR, pt-PT, fr-FR,
  de-DE, it-IT, nl-NL, pl-PL, ja-JP y zh-Hans. Son frases como las que dicta la gente: importes con decimales y
  miles, divisas («soles», «quid», «złotych», «円», «元»…), fechas relativas («ayer», «el lunes», «anteayer»),
  comercios locales (Plaza Vea, Wong, Rappi, Tottus, Coto, PedidosYa, Mercadona, El Corte Inglés, Trader Joe's,
  Tesco, Pão de Açúcar, Continente, Carrefour, Rewe, Esselunga, Albert Heijn, Biedronka, Żabka, ローソン, 出前館,
  美团, 盒马…), ingresos y notas con dos movimientos. Manifiesto: `notes.json` (por nota: texto dicho, referencia
  en cifras y grafías alternativas, movimientos esperados con signo, fecha, divisa y comercio, y cómo se dijo cada
  importe).
- **Dos motores de TTS para no sesgar**, y el manifiesto `clips.json` dice cuál generó cada clip: voces de macOS
  (`say`, Apple) y Gemini TTS (`gemini-3.8-flash-lite-tts`, Google, con voces regionales: acento argentino para
  es-AR). Para es-PE, además, `gpt-4o-mini-tts` de OpenAI con instrucciones de acento limeño (6 clips): ninguna voz
  de Apple ni de Google es peruana. 174 clips limpios, AAC .m4a mono a 16 kHz (lo que graba la app), 3,3 MB en el
  repo.
- **Ruido de calle** (`voice/corpus.py noise`, reproducible con semilla): tráfico (ruido marrón con pasadas de
  coches), ruido rosa y murmullo de cuatro voces del corpus invertidas, con 0,6 s de calle antes y después de hablar.
  Se mezcla a **10 dB y 5 dB de SNR** sobre la potencia de los tramos con voz. Una versión ruidosa por nota y SNR
  (168 clips), de su clip `say` o `gemini` alterno. No va en el repo: se regenera desde los limpios.
- **Habla humana real** (`real.json`; el audio lo baja `corpus.py real` a `gateway/bench/.cache/voice/real/`, no
  va en el repo):
  - **OpenSLR 73** (Google, CC BY-SA 4.0): 30 clips de español **peruano** leídos por 30 hablantes distintos (15
    mujeres, 15 hombres), sacados del zip remoto de 900 MB por rangos HTTP.
  - **FLEURS** (Google, CC BY 4.0): 5 clips por idioma de los 10, del principio de `dev.tar.gz` en streaming.
  - No son notas de finanzas: miden el error por palabra con voces de verdad, no la nota interpretada.

### Motores (`gateway/bench/voice/engines.ts`, cada uno con la petición de su doc oficial del día)

| Motor | Petición | Pistas | Precio (2026-10-07) | Apagado |
|---|---|---|---|---|
| OpenAI `whisper-1` | REST `/v1/audio/transcriptions` | `language` (lo de hoy en la app) | 0,006 USD/min | **2027-02-26** |
| OpenAI `gpt-transcribe` | REST, `languages[]` | sin y con `keywords[]`; sin `languages` (auto); con `keywords[]` y un `prompt` que pide cifras | 0,0045 USD/min | — |
| OpenAI `gpt-live-transcribe` | Realtime (WebSocket), PCM 24 kHz | `languages` + `keywords` | 0,017 USD/min | — |
| xAI `grok-voice-transcribe-2.0` | REST `POST /v1/stt` | `language`, `format=true`; sin y con `keyterm` | 0,10 USD/h | — |
| Google `gemini-3.5-flash-lite` | `generateContent` con el audio | idioma y palabras en el prompt | 0,30 / 2,50 USD por 1M tokens | — |
| Google `gemini-3.8-flash` | ídem, razonamiento `low` | ídem | 0,75 / 3,75 USD por 1M (×2 desde el 2027-01-01) | — |
| Apple `SpeechTranscriber` | `SpeechAnalyzer`, en el dispositivo | `contextualStrings` | 0 | — |
| Apple `DictationTranscriber` | `SpeechAnalyzer`, en el dispositivo | `contextualStrings` | 0 | — |
| Deepgram `nova-3` | REST `/v1/listen` | `language`, `keyterm`, `smart_format` | 0,0052 + 0,0013 (keyterm) USD/min | — |
| AssemblyAI `universal-3-5-pro` | REST upload + transcript | `language_code`, `keyterms_prompt` | 0,21 + 0,05 USD/h | — |
| ElevenLabs `scribe_v2` | REST `/v1/speech-to-text` | `language_code`, `keyterms` | 0,22 + 0,05 USD/h | — |

Docs consultadas el 2026-10-07: developers.openai.com/api/docs/guides/speech-to-text,
…/guides/realtime-transcription, …/deprecations y …/pricing; docs.x.ai/developers/model-capabilities/audio/speech-to-text
y …/pricing; ai.google.dev/gemini-api/docs/audio y …/pricing; developers.deepgram.com/reference/speech-to-text/listen-pre-recorded
y deepgram.com/pricing; assemblyai.com/docs/api-reference/transcripts/submit y assemblyai.com/pricing;
elevenlabs.io/docs/api-reference/speech-to-text/convert y elevenlabs.io/pricing/api.

- **Las pistas** son las de la persona: las subcategorías semilla de la app en su idioma (leídas de
  `CategorySeed.swift`, `L10n.swift` y `Localizable.strings`: unos 60 nombres) y 10 comercios frecuentes: 70
  palabras por idioma. Los comercios
  de las notas 1-4 de cada variante están en la lista y los de las notas 5-6 no, para medir también el comercio que
  la persona aún no tiene en su memoria.
- **`gpt-live-transcribe` no se puede usar por REST**: `/v1/audio/transcriptions` lo rechaza (`invalid_parameter`,
  medido). Solo por Realtime.
- **Por coste**, las variantes de control (`gpt-transcribe` sin keywords, xAI sin keyterms y `gpt-live-transcribe`)
  midieron un subconjunto: limpio `say`, ruido 5 dB y habla real (el streaming, solo la peruana).

### Métricas (`gateway/bench/voice/metrics.ts` y `parse.ts`)

- **Error por palabra (WER; CER en ja y zh)** contra la mejor de las referencias de la nota: en cifras, con otras
  grafías naturales o tal como se dijo (en letra). Normalización: NFKC, minúsculas, fuera los símbolos de divisa,
  cada número en cifras a una forma canónica (sin separador de miles y con punto decimal: «25,50», «25.50» y «25.5»
  son la misma palabra; un separador seguido de tres cifras es de miles), toda la puntuación a espacio (también
  apóstrofos y guiones) y las tildes se conservan. «Veinticinco con cincuenta» no penaliza si la transcripción entera
  va en letra. Cada clip se topa en 100 %.
- **Importes en el texto**: cada importe esperado aparece en cifras (también «23 pounds 40», «45 mil», «28万»,
  «三十二点八») o escrito en letra tal como se dijo.
- **Comercio en el texto**: el nombre o una grafía del manifiesto («PlazaVea», «Lidlu», «Żabce»…).
- **Nota interpretada**: la transcripción pasa por la lectura de la app, **igual que hoy**:
  `TranscriptionParserService.parseMultiple`, con su prompt leído del Swift (`lib/swift.ts`), `gpt-4.1-mini`,
  temperatura 0,1, el cuerpo del SDK MacPaw, la fecha de hoy fija (2026-10-07) y las subcategorías semilla en el
  idioma de la persona. Después, la decodificación de la app (`parseMultipleResponse`): si la app la rechazaría, es
  fallo. Acierta si salen **exactamente** los movimientos esperados:
  - **Núcleo:** importe, signo y fecha (la fecha nula cuenta como hoy, que es lo que guarda la app).
  - **Con comercio:** además, el comercio en la nota, que es donde la app lo enseña.
  - **Estricta:** además, la divisa. **No separa motores**: el prompt de la lectura solo enseña seis divisas (USD,
    EUR, PEN, MXN, COP, BRL), y con libras, pesos argentinos, złotych, yenes o yuanes devuelve `null` o una
    equivocada (ver «Lo que queda»).
  - La lectura se cachea por transcripción (sin mayúsculas ni puntuación de frase): dos motores que oyen lo mismo
    reciben la misma lectura.
- **Latencia**: pasada aparte **en serie** (una llamada cada vez, con el candado `gateway/bench/.latency-lock`
  compartido con el banco de texto), dos clips por variante (la nota 02 limpia y la nota 05 a 5 dB) y dos
  repeticiones. La de la criba en paralelo solo orienta. Apple se mide en esta Mac (M-series, macOS 27.0.1), que es
  una aproximación del iPhone, no el iPhone.

## Tablas

Completas en `gateway/bench/results/2026-10-07/voice.md` (por motor × idioma × condición, sesgo del TTS, habla real y
listón con las variantes que fallan). Aquí, las que deciden.

### Resumen (notas sintéticas: limpio + 10 dB + 5 dB; habla real aparte)

| Motor | Clips | Error | Limpio | 10 dB | 5 dB | Habla real | Importes | Comercio | Notas leídas | Núcleo | Con comercio | Estricta | p50 / p95 s | USD/h |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `openai:whisper-1` | 422 | 9,0 % | 6,4 % | 9,4 % | 13,9 % | 5,8 % | 98,5 % | 74,7 % | 342/342 | 95,6 % | 73,7 % | 53,8 % | 7,2 / 14,5* | 0,36 |
| `openai:gpt-transcribe` (sin keywords)³ | 248 | 7,2 % | 3,7 % | — | 10,7 % | 3,1 % | 97,3 % | 84,9 % | 168/168 | 91,7 % | 81,5 % | 57,7 % | 4,6 / 5,6* | 0,27 |
| **`openai:gpt-transcribe+kw`** | 422 | **2,7 %** | **1,3 %** | **2,6 %** | **5,7 %** | 3,4 % | 98,4 % | 96,9 % | 342/342 | 94,2 % | 92,1 % | 67,3 % | 4,7 / 6,2* | 0,27 |
| `openai:gpt-transcribe+kw+prompt`⁴ | 88 | — | — | — | — | — | — | — | 88/88 | 92,0 % | 86,4 % | — | **0,8 / 1,2** | 0,27 |
| `openai:gpt-transcribe:auto` (sin `languages`)³ | 84 | 3,9 % | 3,9 % | — | — | — | 100 % | 91,5 % | 84/84 | 95,2 % | 88,1 % | 63,1 % | 4,4 / 4,7* | 0,27 |
| `openai:gpt-live-transcribe+kw`³ | 198 | 5,9 % | 1,6 % | — | 10,2 % | 2,8 % | 98,2 % | 90,8 % | 132/168 | 97,0 % | 93,9 % | 66,7 % | 2,7 / 3,4* | 1,02 |
| `xai:grok-voice-transcribe-2.0`³ | 248 | 13,3 % | 8,7 % | — | 18,0 % | 8,5 % | 95,8 % | 82,7 % | 168/168 | 86,9 % | 73,8 % | 50,6 % | 3,3 / 5,1* | 0,10 |
| `xai:grok-voice-transcribe-2.0+kw` | 422 | 9,8 % | 7,5 % | 9,9 % | 14,6 % | 8,1 % | 95,8 % | 93,8 % | 342/342 | 87,4 % | 82,5 % | 57,0 % | 3,5 / 4,7* | 0,10 |
| `gemini:gemini-3.5-flash-lite+kw` | 422 | 7,5 % | 5,6 % | 7,2 % | 11,5 % | 7,5 % | 99,1 % | 96,2 % | 342/342 | 92,4 % | 90,1 % | 65,5 % | 8,0 / 11,9* | 0,14 |
| `gemini:gemini-3.8-flash+kw` | 422 | 4,4 % | 4,0 % | 3,9 % | 5,9 % | 4,3 % | 99,9 % | 99,3 % | 315/342 | 100 %² | 100 %² | 70,5 % | 12,1 / 19,9* | 0,31 |
| `apple:speech+kw` (en la Mac) | 364 | 11,0 % | 7,0 % | 12,5 % | 17,8 % | 4,8 % | 92,2 % | 75,3 % | 294/294 | 87,4 % | 70,7 % | 47,6 % | **0,1 / 0,1** | 0 |
| `apple:dictation+kw` (en la Mac) | 422 | 16,8 % | 14,8 % | 14,4 % | 23,3 % | 10,7 % | 91,1 % | 78,5 % | 342/342 | 85,1 % | 71,9 % | 48,5 % | 0,5 / 0,9 | 0 |
| `deepgram:nova-3+kw` | 422 | 9,4 % | 7,4 % | 9,0 % | 14,1 % | 6,8 % | 95,3 % | 85,1 % | 195/342 | 97,9 %² | 93,3 %² | 69,7 % | 2,6 / 5,2* | 0,39 |
| `assemblyai:universal-3-5-pro+kw` | 422 | 4,4 % | 3,6 % | 3,8 % | 6,6 % | 4,4 % | 99,6 % | 97,2 % | 250/342 | 100 %² | 98,0 %² | 65,2 % | 4,1 / 11,7* | 0,26 |
| `elevenlabs:scribe_v2+kw` | 422 | 3,7 % | 2,7 % | 3,3 % | 6,1 % | 2,7 % | 98,7 % | 98,3 % | 262/342 | 96,9 %² | 96,9 %² | 64,1 % | 4,4 / 5,5* | 0,27 |

³ Variante de control: solo limpio `say`, 5 dB y habla real (el streaming, solo la peruana). ⁴ Solo las 22 notas con
decimales dichos en letra, en limpio (`say` y `gemini`) y con ruido; latencia en serie de esas 88 llamadas. La
estricta (con divisa) no separa motores: ver «Lo que queda».

### Mismos clips para todos (limpio `say` · 5 dB · habla peruana real · FLEURS)

| Motor | Limpio `say` | 5 dB | Peruano real | FLEURS (10 idiomas) |
|---|---|---|---|---|
| `whisper-1` | 6,7 % | 13,9 % | 3,7 % | 7,1 % |
| `gpt-transcribe` sin keywords | 3,7 % | 10,7 % | 2,0 % | 3,8 % |
| **`gpt-transcribe` + keywords** | **1,4 %** | **5,7 %** | **2,0 %** | 4,1 % |
| `gpt-transcribe` sin `languages` | 3,9 % | — | — | — |
| `gpt-live-transcribe` + keywords | 1,6 % | 10,2 % | 2,8 % | — |
| xAI | 8,7 % | 18,0 % | 4,6 % | 10,9 % |
| xAI + keyterms | 7,4 % | 14,6 % | 4,6 % | 10,3 % |
| Gemini 3.8 Flash | 4,2 % | 5,9 % | 3,8 % | 4,6 % |
| ElevenLabs Scribe v2 | 2,1 % | 6,1 % | **2,0 %** | **3,0 %** |
| AssemblyAI Universal-3.5 Pro | 2,9 % | 6,6 % | 4,7 % | 4,3 % |
| Deepgram Nova-3 | 8,7 % | 14,1 % | 4,5 % | 8,2 % |

Las keywords bajan el error de `gpt-transcribe` a la mitad en las notas (3,7 → 1,4 % limpio, 10,7 → 5,7 % a 5 dB) y no
cambian el habla real, que no habla de finanzas: no estorban.

### Por variante de idioma (los principales)

Error en limpio (WER; CER en ja y zh):

| Motor | es-PE | es-AR | es-ES | en-US | en-GB | pt-BR | pt-PT | fr | de | it | nl | pl | ja | zh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `whisper-1` | 5 % | 17 % | 3 % | 6 % | 4 % | 5 % | 18 % | 4 % | 3 % | 7 % | 1 % | 11 % | 1 % | 4 % |
| **`gpt-transcribe` + kw** | 1 % | 7 % | 1 % | 2 % | 1 % | 2 % | 2 % | 0 % | 0 % | 1 % | 0 % | 2 % | 0 % | 0 % |
| ElevenLabs | 1 % | 7 % | 4 % | 2 % | 2 % | 0 % | 2 % | 0 % | 1 % | 9 % | 10 % | 0 % | 3 % | 0 % |
| AssemblyAI | 0 % | 3 % | 0 % | 2 % | 1 % | 3 % | 25 % | 2 % | 10 % | 0 % | 0 % | 6 % | 2 % | 0 % |
| Gemini 3.8 Flash | 1 % | 0 % | 11 % | 0 % | 0 % | 3 % | 11 % | 2 % | 9 % | 9 % | 10 % | 2 % | 0 % | 0 % |
| xAI + keyterms | 14 % | 13 % | 16 % | 8 % | 7 % | 5 % | 16 % | 2 % | 5 % | 2 % | 2 % | 2 % | 9 % | 1 % |
| Deepgram | 1 % | 6 % | 7 % | 4 % | 1 % | 19 % | 19 % | 4 % | 1 % | 9 % | 2 % | 28 % | 0 % | 6 % |
| Apple `SpeechTranscriber` | 5 % | 4 % | 15 % | 7 % | 11 % | 5 % | 10 % | 6 % | 4 % | 13 % | — | — | 1 % | 4 % |
| Apple `DictationTranscriber` | 8 % | 6 % | 19 % | 10 % | 6 % | 43 % | 42 % | 6 % | 11 % | 10 % | 20 % | 9 % | 9 % | 9 % |

Error con ruido de calle a 5 dB:

| Motor | es-PE | es-AR | es-ES | en-US | en-GB | pt-BR | pt-PT | fr | de | it | nl | pl | ja | zh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `whisper-1` | 11 % | 26 % | 6 % | 11 % | 8 % | 18 % | 52 % | 6 % | 3 % | 22 % | 8 % | 11 % | 4 % | 8 % |
| **`gpt-transcribe` + kw** | 2 % | 12 % | 7 % | 6 % | 1 % | 7 % | 30 % | 0 % | 1 % | 4 % | 3 % | 3 % | 3 % | 0 % |
| ElevenLabs | 7 % | 6 % | 1 % | 5 % | 8 % | 6 % | 30 % | 2 % | 0 % | 9 % | 8 % | 0 % | 3 % | 0 % |
| AssemblyAI | 4 % | 0 % | 0 % | 4 % | 2 % | 10 % | 43 % | 2 % | 6 % | 7 % | 1 % | 13 % | 0 % | 0 % |
| Gemini 3.8 Flash | 3 % | 2 % | 10 % | 3 % | 2 % | 5 % | 23 % | 2 % | 9 % | 9 % | 8 % | 5 % | 2 % | 0 % |
| xAI + keyterms | 29 % | 24 % | 19 % | 19 % | 10 % | 19 % | 54 % | 0 % | 11 % | 10 % | 1 % | 6 % | 2 % | 1 % |

pt-PT a 5 dB es el caso más duro para todos: la voz de macOS de portugués europeo (Joana) es la más pobre del corpus.

Nota núcleo (todas las condiciones; 24-30 notas por variante, una nota son 3-4 puntos):

| Motor | es-PE | es-AR | es-ES | en-US | en-GB | pt-BR | pt-PT | fr | de | it | nl | pl | ja | zh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `whisper-1` | 97 % | 96 % | 96 % | 96 % | 100 % | 100 % | 67 % | 100 % | 100 % | 96 % | 96 % | 100 % | 100 % | 96 % |
| **`gpt-transcribe` + kw** | 100 % | 92 % | 79 % | 100 % | 100 % | 92 % | 71 % | 100 % | 100 % | 96 % | 96 % | 92 % | 100 % | 100 % |

Nota con comercio (lo que la persona ve escrito en la nota):

| Motor | es-PE | es-AR | es-ES | en-US | en-GB | pt-BR | pt-PT | fr | de | it | nl | pl | ja | zh |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `whisper-1` | 53 % | 63 % | 92 % | 92 % | 79 % | 88 % | 42 % | 88 % | 83 % | 50 % | 92 % | 79 % | 88 % | 50 % |
| **`gpt-transcribe` + kw** | 83 % | 92 % | 79 % | 100 % | 100 % | 92 % | 71 % | 100 % | 92 % | 96 % | 96 % | 92 % | 100 % | 100 % |

### Sesgo del TTS

Ningún motor sale favorecido por el TTS de su propio proveedor: `gpt-transcribe` + kw tiene 1,4 % con las voces de
Apple, 1,3 % con las de Google y 1,3 % con las 6 de OpenAI; Gemini 3.8 Flash, 4,2 % con Apple y 4,0 % con Google; Apple
`SpeechTranscriber`, 7,1 % con las dos. Las voces de Apple son las más difíciles para casi todos (Dictation: 20,8 % con
Apple y 9,5 % con Google).

## Lo que observamos de cada motor

- **OpenAI `gpt-transcribe` (+ keywords).** El mejor transcribiendo, en los 14 idiomas y con ruido. Las keywords le
  enseñan los comercios («Tottus», «PedidosYa», «Thuisbezorgd»): comercio en el texto 85 → 97 %. Deja importes en
  letra en español, portugués, polaco e inglés: «Cargué en Azta en YPF por doce mil pesos y gasté ochocientos» (su
  peor caso: «nafta» → «Azta» en es-AR). Por REST con m4a; `languages` y `keywords` como campos repetidos
  (`languages[]`, `keywords[]`); contesta `{text, languages, usage}` y cobra por segundos de audio. Sin `languages`
  (detección automática) el error sube poco (3,7 → 3,9 % en limpio) pero no hay por qué arriesgarlo: el idioma lo
  sabe la app.
- **OpenAI `gpt-live-transcribe`.** Solo por Realtime (WebSocket, PCM a 24 kHz): `/v1/audio/transcriptions` lo rechaza
  (`invalid_parameter`, medido). En limpio igual que `gpt-transcribe` (1,6 %), con ruido peor (10,2 % frente a
  5,7 %) y 3,8 veces más caro. Interesa solo si la app transcribiera mientras graba (el texto llega ~2,8 s después de
  soltar el audio entero, medido con una nota de 4 s).
- **OpenAI `whisper-1`.** Lo de hoy. Siempre escribe cifras, lo que ayuda a la lectura, pero alucina con ruido
  («Gastei 42 euros no Uber e não ganhei nada, porém violei a minha irmã») y escribe mal los comercios. Se apaga el
  2027-02-26, igual que `gpt-4o-transcribe` y `gpt-4o-mini-transcribe`.
- **ElevenLabs Scribe v2.** El segundo, muy cerca: el mejor en habla real (FLEURS 3,0 %, inglés real 3 %). Peor caso:
  neerlandés (10 %) e italiano (9 %) en limpio. También deja algunos importes en letra.
- **AssemblyAI Universal-3.5 Pro.** Muy bueno salvo en portugués europeo (25 % en limpio, 43 % a 5 dB) y alemán (10 %).
  Es asíncrono (subir, pedir y sondear): p95 de la criba 11,7 s.
- **Google Gemini 3.8 Flash.** El más robusto al ruido junto a `gpt-transcribe` (5,9 % a 5 dB), pero lento (p95 19,9 s
  en la criba: al borde del corte de 20 s) y, al ser un modelo general, reformula («12 €» por «doce euros»: 9-11 % de
  error en es-ES, de, it y nl). No admite razonamiento `minimal` (400, medido): va con `low`. Gemini 3.5 Flash-Lite,
  más rápido y barato, se cae con ruido (portugués europeo a 5 dB: 59 %).
- **xAI (`grok-voice-transcribe-2.0`).** Lo que Jürgen nota en el dictado de Grok **no se reproduce con la API de STT
  de xAI** en estas notas: 7,5 % de error en limpio y 14,6 % a 5 dB con keyterms, el peor en la nota interpretada de
  los de nube (87 %). Con `format=true` escribe importes raros en español y portugués («Ayer gasté 25 con S/50»,
  «le yapeé S/15»), y con el umbral de voz por defecto (`vad_threshold` 0,5) **devuelve texto vacío** con audio bajo
  (3 de 5 clips de FLEURS en inglés); con 0,1 lo transcribe (inglés real: 62 → 25 %), pero no mejora con ruido. Es el
  más barato (0,10 USD/h) y rápido.
- **Deepgram Nova-3.** Flojo en portugués (19 % en limpio: «pano de açúcar») y polaco (28 %), y mezcla cifras y
  caracteres en chino («一百9十九»).
- **Apple `SpeechTranscriber`** (el modelo nuevo de iOS/macOS 26+, en el dispositivo). Gratis e instantáneo (0,1 s en la
  Mac), 7,0 % en limpio y muy bueno en habla real (4,8 %), pero se cae con ruido (17,8 % a 5 dB) y **no tiene
  neerlandés ni polaco** (`SpeechTranscriber.supportedLocales` en macOS 27.0.1, medido), ni es-PE ni es-AR (se usa
  es-MX).
- **Apple `DictationTranscriber`** (el dictado de siempre). Cubre los 10 idiomas, pero es el peor: 14,8 % en limpio,
  42-43 % en portugués y algunas transcripciones vacías.

## Qué exigiría encender un proveedor que no es OpenAI

Las versiones instaladas dicen en sus permisos que el audio «se envía a OpenAI para transcripción»
(`NSMicrophoneUsageDescription`, en los 10 idiomas) y la política de privacidad web (`Web/privacy_content.md`) solo
nombra a OpenAI. Para cualquier otro proveedor, antes de encenderlo:

| | Texto de permisos y consentimiento | Política de privacidad | DPA y retención (lo comprobado el 2026-10-07) | Clave | Cuotas |
|---|---|---|---|---|---|
| **ElevenLabs** | Cambiar `NSMicrophoneUsageDescription` y `aiConsent.*` en los 10 idiomas, en una versión nueva; solo esa versión puede recibirlo (cabecera `X-Yala-Task` + `LEGACY_OVERRIDES` con OpenAI para las instaladas) | Nombrar a ElevenLabs como encargado | DPA publicado (elevenlabs.io/dpa, 8-abr-2026). **Fuera de Enterprise, el audio puede usarse para entrenar** salvo que se desactive en la cuenta; la retención cero (`enable_logging=false`) es solo Enterprise | `ELEVENLABS_API_KEY` nueva en `env.ts` + `wrangler secret put` | Plan Starter: 27 h de STT al mes incluidas; con tráfico real, plan superior |
| **AssemblyAI** | Ídem | Ídem | En planes de pago entra **por defecto** en la mejora de modelos (opt-out en la consola, solo hacia delante); transcripciones 30 días por defecto (TTL configurable); servidores UE sin entrenamiento | `ASSEMBLYAI_API_KEY` nueva | Asíncrono: subir + sondear (2 llamadas más por nota) |
| **Google (Gemini)** | Ídem | Ídem | Solo el nivel **de pago** no entrena con los datos | `GEMINI_API_KEY` (ya declarada) | 429/503 frecuentes medidos el 7-oct (también en el banco de texto) |
| **xAI** | Ídem | Ídem | Guarda peticiones 30 días para auditoría y no entrena sin permiso; retención cero solo Enterprise (docs.x.ai/developers/faq/security) | `XAI_API_KEY` nueva | 10 peticiones/s en REST |
| **Deepgram** | Ídem | Ídem | Programa de mejora de modelos por defecto; `mip_opt_out=true` por petición lo excluye **y quita el 50 % de descuento** | `DEEPGRAM_API_KEY` nueva | — |
| **Apple (en el dispositivo)** | El audio no sale del iPhone: el texto de permisos dejaría de mencionar a OpenAI para la transcripción (la lectura de la nota sigue yendo a OpenAI) | Ídem | No aplica para el audio | — | — |

En todos: el adaptador nuevo en `gateway/src/ai/providers/` (multipart o JSON, según el proveedor) y su test, y un
banco que vuelva a pasar con la clave de producción antes de encenderlo.

## Si ganara Apple en el dispositivo

No gana, pero esto es lo que cambiaría si se quisiera usar (por ejemplo, como respaldo sin red):

- **Idiomas:** `SpeechTranscriber` no cubre neerlandés ni polaco; `DictationTranscriber` sí, con mucha peor calidad.
  Haría falta un modelo por idioma y la regla de cuál usar, con `SpeechTranscriber.supportedLocales` como fuente.
- **Descarga del modelo:** `AssetInventory.assetInstallationRequest(supporting:)` + `downloadAndInstall()` la primera
  vez (en la Mac, unos segundos por idioma). **Una app solo puede tener 5 idiomas reservados**: pasado ese número,
  `SFSpeechErrorDomain` 11, «Too many allocated locales, 5 maximum» (medido). Hay que soltar los que no se usan
  (`AssetInventory.release(reservedLocale:)`) y reservar el de la persona (`reserve(locale:)`).
- **Sin el modelo** (sin red la primera vez, o un idioma sin modelo): no hay transcripción; la app tendría que caer a
  la nube o pedir que se descargue.
- **Detalles medidos:** `DictationTranscriber` con `.shortDictation` entrega el último resultado sin marcarlo como final
  (hay que quedarse con el último provisional o usar `.longDictation`). Las palabras del contexto van como
  `AnalysisContext.contextualStrings`. En la Mac no pidió permiso de reconocimiento de voz; en el iPhone no se midió.
- **Privacidad:** el audio no saldría del teléfono; la lectura de la nota seguiría yendo a OpenAI.
- La latencia es la de esta Mac (M-series), una aproximación del iPhone, no una medida en él.

## La fila `voice.transcribe` del gateway

**Para producción hoy** (OpenAI, que es lo que prometen los permisos de las versiones instaladas), y es también el
ganador por calidad:

```ts
"voice.transcribe": {
  mode: "managed",
  provider: "openai",
  model: "gpt-transcribe",
  params: {
    languageField: "languages",   // languages[] = [idioma de la app]; nunca `language` a la vez (lo rechaza)
    maxKeywords: 100,             // medido con 70: 10 comercios + ~60 subcategorías
    prompt: "Personal finance voice note. Write every amount with digits, for example 12.50, 56.20 or 1,250.",
  },
}
```

- **Idioma:** `languages[]` con el ISO 639-1 que manda la app (`VoiceLanguage.isoCode`, que ya sigue al idioma de
  Yala): `es`, `en`, `pt`, `fr`, `de`, `it`, `nl`, `pl`, `ja`, `zh`. Un solo idioma: `languages` sustituye a `language`
  en `gpt-transcribe` y mandar los dos tumba la petición. `zh` funciona tal cual (medido en los 30 clips de chino).
- **Keywords:** de la app, porque el gateway no conoce los datos de la persona: los nombres de sus subcategorías
  visibles (gasto e ingreso, lo que ya junta `fetchSubcategoryNames()` en `VoiceRecordingView`) y sus comercios más
  usados (`MerchantMemory`), **primero los comercios** por si se recorta. Uno por entrada, sin `<`, `>` ni saltos de
  línea (OpenAI rechaza la petición entera si alguno los trae).
- **Prompt:** el fijo de la fila, no el de la app. Pide cifras para que la lectura de la nota no tropiece con los
  decimales en letra. Medido solo en las 88 notas con decimales dichos en letra (limpio y ruido): no se cuela en el
  texto y sube la nota núcleo de 77 a 81.
- **Versiones instaladas** (mandan `whisper-1` y `language`, sin keywords): la misma fila les sirve sin release, y ya
  salen mejor que con `whisper-1` (sin keywords: 3,7 % de error frente a 6,7 % en limpio, 10,7 % frente a 13,9 % a 5 dB,
  2,0 % frente a 3,7 % en habla peruana real, y comercio 85 % frente a 75 %). Además `whisper-1` se apaga el
  2027-02-26.
- **Corte:** con 20 s sobra: p95 de 1,2 s en serie (88 llamadas), 6,2 s en la criba en paralelo.
- **Coste:** 0,0045 USD/min (0,27 USD/h), un 25 % menos que `whisper-1`; la respuesta trae `usage.seconds`.

**Sobre el adaptador de Frank (`gateway/src/ai/providers/transcription.ts`):** con `languages[]` desde el `language`
de la app y `keywords[]` desde el `prompt` de la app basta para el ganador, con dos cosas: (1) el `prompt` fijo de la
fila (ya lo admite `p.prompt`); (2) `maxKeywords` ≥ 70, que es con lo que se midió. Un detalle: `keywordsFrom` también
parte por comas; ningún nombre semilla de los 10 idiomas lleva coma (comprobado), pero uno que ponga la persona sí
podría partirse en dos.

## Lo que no funcionó y lo que queda

- **No se leyeron todas las notas.** Al cerrar quedaban 269 transcripciones sin pasar por la lectura (de ElevenLabs,
  AssemblyAI, Deepgram, Gemini 3.8 Flash, `gpt-live-transcribe` y la variante de xAI con umbral bajo): otro banco tenía
  el candado de latencia y Frank pidió cerrar sin esperar. La nota de esos motores está calculada sobre las leídas y
  sesgada hacia arriba (las no leídas son las transcripciones que no coinciden con las de ningún otro motor). La de
  `whisper-1` y `gpt-transcribe`, que deciden la fila, está completa. Para completarla: `npm run bench:voice -- --only
  none` (unos 0,15 USD de OpenAI).
- **La latencia en serie con candado no se midió.** Las cifras con * son de la criba en paralelo. La de `gpt-transcribe`
  (p50 0,8 s, p95 1,2 s) es de una tanda en serie de 88 llamadas, sin candado propio. La de Apple es local, en serie.
- **Infringí el candado de latencia una vez**: la primera tanda de lecturas (gpt-4.1-mini, 8 a la vez) corrió unos 11
  minutos con el candado del trabajador A puesto, antes de que el banco de voz lo mirara. Desde entonces el banco espera
  antes de cada llamada mientras haya un candado ajeno; las 88 llamadas en serie del prompt de cifras se lanzaron con
  `--no-lock-wait` tras el mensaje de Frank.
- **La lectura de la nota es lo que más falla ya, no la transcripción.** Con `gpt-transcribe` el texto sale casi
  perfecto (1,3 % de error en limpio) y aun así la nota falla en:
  - **Importes en letra coloquiales**: «cincuenta y seis veinte», «dwadzieścia dziewięć pięćdziesiąt», «28 euros e 30»
    (este último lo parte en dos movimientos). La lectura de la app no los entiende; `whisper-1` los escribe en cifras.
  - **Divisas**: el prompt de `TranscriptionParserService` solo enseña seis (USD, EUR, PEN, MXN, COP, BRL). Con libras
    devuelve `null`, con «pesos» en Argentina **MXN**, con złotych y yuanes `null`, y con yenes a veces **PEN**: una nota
    japonesa de 860 円 sale en soles. Por eso la nota estricta se queda entre el 48 y el 71 % con todos los motores. Es el mismo hueco
    que el de la foto (`vision-reads-every-dollar-sign-as-usd`) y su arreglo va en la tarea `text.parse`.
  - La latencia de la lectura (`gpt-4.1-mini`) en la criba fue de 15,8 s de mediana con 8 a la vez; en serie no se
    midió. Con la transcripción en 1-2 s y el corte de 20 s por petición, conviene vigilarla en la tarea `text.parse`.
- **xAI con audio bajo**: si algún día se usa, `vad_threshold` 0,1 o subir la ganancia antes de mandar.
- **El corpus sintético** (voces de máquina, ruido simulado) no sustituye a notas reales de la persona: el habla real
  (OpenSLR 73 y FLEURS) no son notas de finanzas. Antes de cerrar la decisión del todo, unas cuantas notas reales
  grabadas en la calle con el iPhone, anonimizadas.

## Revisión periódica

```bash
python3 -I gateway/bench/voice/corpus.py all      # una vez: audio sintético, ruido y habla real
cd gateway && npm run bench:voice                  # criba de todos los motores con clave (reanudable)
npm run bench:voice -- --latency --only openai:gpt-transcribe+kw,elevenlabs --parse-latency   # latencia, en serie
npm run bench:voice -- --report                    # rehace voice.md desde los .jsonl
```

Antes de una revisión: precios y modelos del día en `VARIANTS` (`voice/run.ts`), y un tope de OpenAI con
`--openai-cap` (USD; por defecto 1,85) que corta transcripciones y lecturas al llegar. Claves en
`~/Secrets/yala-ai-bench/{openai,xai,gemini,deepgram,assemblyai,elevenlabs}.key`; sin clave, el motor se salta.
