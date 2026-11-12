# Registro por voz: onda y texto en vivo

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `registro-voz-onda-texto` · Sesión cola **S21** · al cerrar → **S22**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/registro-voz-onda-texto-vivo-tjws.md`

Léelo y ejecútalo tal cual (contexto, qué se pide, qué NO tocar, cómo se sabe que está bien). Este wrapper solo fija el hueco en la cola automática S0–S29.

## Qué NO tocar
Lo que diga el brief per-card. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief per-card + PR a 2.2 cuando aplique.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué reconocedor da el texto en vivo?** → `SpeechAnalyzer` + `SpeechTranscriber` de iOS 26, con resultados volátiles.
Por qué: corre siempre en el dispositivo y su API no pide el permiso «Reconocimiento de voz» (medido en el `.swiftinterface` del SDK 27.1: no hay autorización en el módulo), así que no hay diálogo nuevo ni `NSSpeechRecognitionUsageDescription`. Alternativa descartada: `SFSpeechRecognizer` con `requiresOnDeviceRecognition`, que exige el permiso extra y su texto en 16 idiomas.

**D2 · ¿Cómo se alimenta sin tocar el audio que va a la IA?** → un `AVAudioEngine` aparte con un tap en la entrada, en paralelo; `AudioRecorderService` (AVAudioRecorder, ajustes y fichero) no cambia ni una línea.
Por qué: el criterio es «el audio a la IA idéntico», y lo más seguro es no tocar el grabador. Alternativa descartada: pasar la grabación a un tap y escribir el fichero a mano, que cambia el formato que llega al gateway.

**D3 · ¿Qué pasa si el idioma no está en el teléfono, el modelo no está descargado o el motor no arranca?** → solo se ve la onda; si el modelo está «soportado» pero sin bajar, se pide su descarga en segundo plano para la próxima vez.
Por qué: el texto es decorativo; la grabación nunca depende de él. Alternativa descartada: esperar a la descarga dentro de la grabación.

**D4 · ¿Idioma del reconocedor?** → el mismo del registro por voz (`appPreferences.voiceLanguage.isoCode`).

**D5 · Alcance** → solo el registro por voz (`VoiceRecordingView`). El dictado de Yala IA se queda con el orbe (asumido en la card).

**D6 · Textos nuevos** → uno: la etiqueta de accesibilidad de la frase en vivo, en los 16 locales. La onda va oculta a VoiceOver como el orbe; «Escuchando…», la pista, Cancelar y Listo no cambian.

**D7 · Test** → seam `-uitest-voice-live` (junto a `-uitest-voice-result`): frase fija que aparece palabra a palabra y nivel simulado; XCUITest comprueba onda y frase. Unit de la lógica pura. El texto real y el audio idéntico con el reconocedor escuchando van a device-QA (el simulador no trae los modelos).

**D8 · Reducir movimiento** → la onda se queda quieta (rayas de silencio) y el texto sigue apareciendo, como decía la propuesta A.
