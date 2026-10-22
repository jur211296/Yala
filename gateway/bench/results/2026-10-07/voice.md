# voice.transcribe — banco del 2026-10-07

Precios comprobados el 2026-10-07. Generado por `npm run bench:voice -- --report`.

Error = WER (CER en ja y zh) contra la mejor referencia, tope 100 % por clip. Importes y comercio: en el texto transcrito (el importe vale en cifras o en letra tal como se dijo). Nota: resultado final tras la lectura de la app (núcleo = importe, signo y fecha; con comercio = además el comercio en la nota; estricta = además la divisa). Latencia: pasada en serie (`--latency`); con *, de la criba en paralelo (solo orienta).

## Resumen por motor (notas sintéticas: limpio + ruido 10 dB + ruido 5 dB)

| Motor | Clips | Error | Error limpio | Error 10 dB | Error 5 dB | Error habla real | Importes | Comercio | Notas leídas | Nota núcleo | Nota + comercio | Nota estricta | JSON de la app | Fallos | p50 / p95 s | USD/hora | Apagado |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `openai:whisper-1` | 422 | 9.0 % | 6.4 % | 9.4 % | 13.9 % | 5.8 % | 98.5 % | 74.7 % | 342/342 | 95.6 % | 73.7 % | 53.8 % | 100 % | 0 | 7.2 / 14.5* | 0.360 | 2027-02-26 |
| `openai:gpt-transcribe` | 248 | 7.2 % | 3.7 % | — | 10.7 % | 3.1 % | 97.3 % | 84.9 % | 168/168 | 91.7 % | 81.5 % | 57.7 % | 100 % | 0 | 4.6 / 5.6* | 0.270 | — |
| `openai:gpt-transcribe+kw` | 422 | 2.7 % | 1.3 % | 2.6 % | 5.7 % | 3.4 % | 98.4 % | 96.9 % | 342/342 | 94.2 % | 92.1 % | 67.3 % | 100 % | 0 | 4.7 / 6.2* | 0.270 | — |
| `openai:gpt-transcribe+kw+prompt` | 88 | 2.6 % | 1.2 % | 2.8 % | 5.4 % | — | 100.0 % | 94.9 % | 88/88 | 92.0 % | 86.4 % | 75.0 % | 100 % | 0 | 0.8 / 1.3* | 0.270 | — |
| `openai:gpt-transcribe:auto` | 84 | 3.9 % | 3.9 % | — | — | — | 100.0 % | 91.5 % | 84/84 | 95.2 % | 88.1 % | 63.1 % | 100 % | 0 | 4.4 / 4.7* | 0.270 | — |
| `openai:gpt-live-transcribe+kw` | 198 | 5.9 % | 1.6 % | — | 10.2 % | 2.8 % | 98.2 % | 90.8 % | 132/168 | 97.0 % | 93.9 % | 66.7 % | 100 % | 0 | 2.7 / 3.4* | 1.020 | — |
| `xai:grok-voice-transcribe-2.0` | 248 | 13.3 % | 8.7 % | — | 18.0 % | 8.5 % | 95.8 % | 82.7 % | 168/168 | 86.9 % | 73.8 % | 50.6 % | 100 % | 0 | 3.3 / 5.1* | 0.100 | — |
| `xai:grok-voice-transcribe-2.0+kw` | 422 | 9.8 % | 7.5 % | 9.9 % | 14.6 % | 8.1 % | 95.8 % | 93.8 % | 342/342 | 87.4 % | 82.5 % | 57.0 % | 100 % | 0 | 3.5 / 4.7* | 0.100 | — |
| `xai:grok-voice-transcribe-2.0+kw:vad0.1` | 164 | 15.2 % | — | — | 15.2 % | 5.7 % | 95.8 % | 89.4 % | 76/84 | 84.2 % | 81.6 % | 56.6 % | 100 % | 0 | 3.3 / 4.5* | 0.100 | — |
| `gemini:gemini-3.5-flash-lite+kw` | 422 | 7.5 % | 5.6 % | 7.2 % | 11.5 % | 7.5 % | 99.1 % | 96.2 % | 342/342 | 92.4 % | 90.1 % | 65.5 % | 100 % | 0 | 8.0 / 11.9* | 0.137 | — |
| `gemini:gemini-3.8-flash+kw` | 422 | 4.4 % | 4.0 % | 3.9 % | 5.9 % | 4.3 % | 99.9 % | 99.3 % | 315/342 | 100.0 % | 100.0 % | 70.5 % | 100 % | 0 | 12.1 / 19.9* | 0.310 | — |
| `apple:speech+kw` | 364 | 11.0 % | 7.0 % | 12.5 % | 17.8 % | 4.8 % | 92.2 % | 75.3 % | 294/294 | 87.4 % | 70.7 % | 47.6 % | 100 % | 0 | 0.1 / 0.1 | 0.000 | — |
| `apple:dictation+kw` | 422 | 16.8 % | 14.8 % | 14.4 % | 23.3 % | 10.7 % | 91.1 % | 78.5 % | 342/342 | 85.1 % | 71.9 % | 48.5 % | 99 % | 0 | 0.5 / 0.9 | 0.000 | — |
| `deepgram:nova-3+kw` | 422 | 9.4 % | 7.4 % | 9.0 % | 14.1 % | 6.8 % | 95.3 % | 85.1 % | 195/342 | 97.9 % | 93.3 % | 69.7 % | 100 % | 0 | 2.6 / 5.2* | 0.390 | — |
| `assemblyai:universal-3-5-pro+kw` | 422 | 4.4 % | 3.6 % | 3.8 % | 6.6 % | 4.4 % | 99.6 % | 97.2 % | 250/342 | 100.0 % | 98.0 % | 65.2 % | 100 % | 0 | 4.1 / 11.7* | 0.260 | — |
| `elevenlabs:scribe_v2+kw` | 422 | 3.7 % | 2.7 % | 3.3 % | 6.1 % | 2.7 % | 98.7 % | 98.3 % | 262/342 | 96.9 % | 96.9 % | 64.1 % | 100 % | 0 | 4.4 / 5.5* | 0.270 | — |

## Nota por condición

| Motor | Núcleo limpio | Núcleo 10 dB | Núcleo 5 dB | Con comercio limpio | Con comercio 10 dB | Con comercio 5 dB |
|---|---|---|---|---|---|---|
| `openai:whisper-1` | 98.9 % | 97.6 % | 86.9 % | 78.7 % | 75.0 % | 61.9 % |
| `openai:gpt-transcribe` | 96.4 % | — | 86.9 % | 86.9 % | — | 76.2 % |
| `openai:gpt-transcribe+kw` | 97.7 % | 94.0 % | 86.9 % | 96.0 % | 91.7 % | 84.5 % |
| `openai:gpt-transcribe+kw+prompt` | 93.2 % | 90.9 % | 90.9 % | 88.6 % | 81.8 % | 86.4 % |
| `openai:gpt-transcribe:auto` | 95.2 % | — | — | 88.1 % | — | — |
| `openai:gpt-live-transcribe+kw` | 95.2 % | — | 100.0 % | 91.6 % | — | 98.0 % |
| `xai:grok-voice-transcribe-2.0` | 92.9 % | — | 81.0 % | 81.0 % | — | 66.7 % |
| `xai:grok-voice-transcribe-2.0+kw` | 92.0 % | 85.7 % | 79.8 % | 87.4 % | 79.8 % | 75.0 % |
| `xai:grok-voice-transcribe-2.0+kw:vad0.1` | — | — | 84.2 % | — | — | 81.6 % |
| `gemini:gemini-3.5-flash-lite+kw` | 95.4 % | 91.7 % | 86.9 % | 93.7 % | 90.5 % | 82.1 % |
| `gemini:gemini-3.8-flash+kw` | 100.0 % | 100.0 % | 100.0 % | 100.0 % | 100.0 % | 100.0 % |
| `apple:speech+kw` | 94.0 % | 81.9 % | 79.2 % | 78.7 % | 65.3 % | 59.7 % |
| `apple:dictation+kw` | 86.2 % | 91.7 % | 76.2 % | 75.9 % | 75.0 % | 60.7 % |
| `deepgram:nova-3+kw` | 97.1 % | 97.9 % | 100.0 % | 94.3 % | 89.4 % | 95.3 % |
| `assemblyai:universal-3-5-pro+kw` | 100.0 % | 100.0 % | 100.0 % | 97.6 % | 98.5 % | 98.3 % |
| `elevenlabs:scribe_v2+kw` | 96.4 % | 98.5 % | 96.6 % | 96.4 % | 98.5 % | 96.6 % |

## Nota núcleo por variante de idioma (sintéticas, todas las condiciones)

| Motor | es-PE | es-AR | es-ES | en-US | en-GB | pt-BR | pt-PT | fr-FR | de-DE | it-IT | nl-NL | pl-PL | ja-JP | zh-Hans |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `openai:whisper-1` | 97 % | 96 % | 96 % | 96 % | 100 % | 100 % | 67 % | 100 % | 100 % | 96 % | 96 % | 100 % | 100 % | 96 % |
| `openai:gpt-transcribe` | 100 % | 92 % | 92 % | 100 % | 100 % | 83 % | 50 % | 100 % | 100 % | 92 % | 92 % | 83 % | 100 % | 100 % |
| `openai:gpt-transcribe+kw` | 100 % | 92 % | 79 % | 100 % | 100 % | 92 % | 71 % | 100 % | 100 % | 96 % | 96 % | 92 % | 100 % | 100 % |
| `openai:gpt-transcribe+kw+prompt` | 100 % | — | 100 % | 100 % | 100 % | 50 % | 50 % | 100 % | 100 % | 100 % | 100 % | 75 % | — | — |
| `openai:gpt-transcribe:auto` | 83 % | 100 % | 100 % | 100 % | 100 % | 83 % | 83 % | 100 % | 100 % | 100 % | 100 % | 83 % | 100 % | 100 % |
| `openai:gpt-live-transcribe+kw` | 100 % | 100 % | 90 % | 100 % | 100 % | 88 % | 100 % | 100 % | 100 % | 100 % | 100 % | 78 % | 100 % | 100 % |
| `xai:grok-voice-transcribe-2.0` | 75 % | 92 % | 67 % | 67 % | 100 % | 83 % | 67 % | 100 % | 100 % | 92 % | 92 % | 92 % | 92 % | 100 % |
| `xai:grok-voice-transcribe-2.0+kw` | 77 % | 96 % | 67 % | 75 % | 100 % | 79 % | 71 % | 100 % | 100 % | 88 % | 96 % | 88 % | 92 % | 100 % |
| `xai:grok-voice-transcribe-2.0+kw:vad0.1` | 50 % | 80 % | 80 % | 67 % | 100 % | 100 % | 33 % | 100 % | 100 % | 80 % | 100 % | 80 % | 83 % | 100 % |
| `gemini:gemini-3.5-flash-lite+kw` | 90 % | 83 % | 92 % | 100 % | 100 % | 88 % | 67 % | 100 % | 100 % | 96 % | 92 % | 92 % | 96 % | 100 % |
| `gemini:gemini-3.8-flash+kw` | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % |
| `apple:speech+kw` | 87 % | 96 % | 83 % | 67 % | 100 % | 75 % | 71 % | 100 % | 100 % | 100 % | — | — | 71 % | 100 % |
| `apple:dictation+kw` | 90 % | 88 % | 71 % | 67 % | 96 % | 54 % | 46 % | 100 % | 100 % | 100 % | 96 % | 92 % | 92 % | 100 % |
| `deepgram:nova-3+kw` | 100 % | 100 % | 100 % | 100 % | 100 % | 67 % | 57 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % |
| `assemblyai:universal-3-5-pro+kw` | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % |
| `elevenlabs:scribe_v2+kw` | 100 % | 89 % | 91 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 80 % | 100 % | 100 % |

## Nota con comercio por variante de idioma

| Motor | es-PE | es-AR | es-ES | en-US | en-GB | pt-BR | pt-PT | fr-FR | de-DE | it-IT | nl-NL | pl-PL | ja-JP | zh-Hans |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `openai:whisper-1` | 53 % | 63 % | 92 % | 92 % | 79 % | 88 % | 42 % | 88 % | 83 % | 50 % | 92 % | 79 % | 88 % | 50 % |
| `openai:gpt-transcribe` | 67 % | 75 % | 92 % | 100 % | 83 % | 75 % | 33 % | 83 % | 100 % | 75 % | 92 % | 83 % | 92 % | 92 % |
| `openai:gpt-transcribe+kw` | 83 % | 92 % | 79 % | 100 % | 100 % | 92 % | 71 % | 100 % | 92 % | 96 % | 96 % | 92 % | 100 % | 100 % |
| `openai:gpt-transcribe+kw+prompt` | 50 % | — | 100 % | 100 % | 100 % | 50 % | 50 % | 100 % | 88 % | 100 % | 100 % | 75 % | — | — |
| `openai:gpt-transcribe:auto` | 67 % | 100 % | 100 % | 100 % | 83 % | 83 % | 67 % | 83 % | 100 % | 67 % | 100 % | 83 % | 100 % | 100 % |
| `openai:gpt-live-transcribe+kw` | 89 % | 100 % | 90 % | 100 % | 80 % | 88 % | 100 % | 100 % | 100 % | 100 % | 100 % | 67 % | 100 % | 100 % |
| `xai:grok-voice-transcribe-2.0` | 42 % | 67 % | 67 % | 50 % | 92 % | 75 % | 42 % | 83 % | 92 % | 67 % | 92 % | 75 % | 92 % | 100 % |
| `xai:grok-voice-transcribe-2.0+kw` | 60 % | 92 % | 67 % | 67 % | 100 % | 71 % | 58 % | 100 % | 96 % | 83 % | 92 % | 83 % | 92 % | 100 % |
| `xai:grok-voice-transcribe-2.0+kw:vad0.1` | 33 % | 80 % | 80 % | 50 % | 100 % | 100 % | 33 % | 100 % | 100 % | 80 % | 100 % | 80 % | 83 % | 100 % |
| `gemini:gemini-3.5-flash-lite+kw` | 83 % | 75 % | 92 % | 100 % | 96 % | 88 % | 67 % | 100 % | 96 % | 96 % | 92 % | 92 % | 96 % | 92 % |
| `gemini:gemini-3.8-flash+kw` | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % |
| `apple:speech+kw` | 53 % | 75 % | 83 % | 50 % | 58 % | 75 % | 42 % | 88 % | 92 % | 71 % | — | — | 67 % | 100 % |
| `apple:dictation+kw` | 40 % | 71 % | 71 % | 50 % | 67 % | 54 % | 33 % | 88 % | 92 % | 92 % | 96 % | 79 % | 88 % | 96 % |
| `deepgram:nova-3+kw` | 100 % | 88 % | 100 % | 87 % | 94 % | 67 % | 57 % | 100 % | 100 % | 100 % | 100 % | 100 % | 83 % | 100 % |
| `assemblyai:universal-3-5-pro+kw` | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 77 % | 100 % | 100 % |
| `elevenlabs:scribe_v2+kw` | 100 % | 89 % | 91 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 80 % | 100 % | 100 % |

## Nota estricta por variante de idioma (la divisa depende sobre todo del prompt de la app)

| Motor | es-PE | es-AR | es-ES | en-US | en-GB | pt-BR | pt-PT | fr-FR | de-DE | it-IT | nl-NL | pl-PL | ja-JP | zh-Hans |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `openai:whisper-1` | 53 % | 13 % | 92 % | 92 % | 8 % | 88 % | 42 % | 88 % | 83 % | 50 % | 88 % | 17 % | 25 % | 17 % |
| `openai:gpt-transcribe` | 67 % | 0 % | 92 % | 100 % | 8 % | 75 % | 33 % | 83 % | 100 % | 75 % | 92 % | 25 % | 17 % | 42 % |
| `openai:gpt-transcribe+kw` | 83 % | 0 % | 79 % | 100 % | 17 % | 92 % | 71 % | 100 % | 92 % | 96 % | 96 % | 29 % | 33 % | 50 % |
| `openai:gpt-transcribe+kw+prompt` | 50 % | — | 100 % | 100 % | 17 % | 50 % | 50 % | 100 % | 88 % | 100 % | 100 % | 75 % | — | — |
| `openai:gpt-transcribe:auto` | 67 % | 0 % | 100 % | 100 % | 17 % | 83 % | 67 % | 83 % | 100 % | 67 % | 100 % | 17 % | 33 % | 50 % |
| `openai:gpt-live-transcribe+kw` | 89 % | 0 % | 90 % | 100 % | 20 % | 88 % | 100 % | 100 % | 100 % | 100 % | 100 % | 11 % | 0 % | 36 % |
| `xai:grok-voice-transcribe-2.0` | 42 % | 0 % | 67 % | 50 % | 0 % | 75 % | 42 % | 83 % | 92 % | 67 % | 92 % | 25 % | 33 % | 42 % |
| `xai:grok-voice-transcribe-2.0+kw` | 60 % | 17 % | 67 % | 67 % | 0 % | 71 % | 58 % | 100 % | 96 % | 83 % | 92 % | 25 % | 29 % | 33 % |
| `xai:grok-voice-transcribe-2.0+kw:vad0.1` | 33 % | 20 % | 80 % | 50 % | 0 % | 100 % | 33 % | 100 % | 100 % | 80 % | 100 % | 20 % | 33 % | 33 % |
| `gemini:gemini-3.5-flash-lite+kw` | 83 % | 4 % | 92 % | 100 % | 8 % | 88 % | 67 % | 100 % | 96 % | 88 % | 92 % | 33 % | 29 % | 33 % |
| `gemini:gemini-3.8-flash+kw` | 100 % | 0 % | 100 % | 100 % | 0 % | 100 % | 100 % | 100 % | 100 % | 95 % | 100 % | 38 % | 30 % | 33 % |
| `apple:speech+kw` | 53 % | 0 % | 67 % | 50 % | 0 % | 75 % | 33 % | 88 % | 92 % | 71 % | — | — | 25 % | 17 % |
| `apple:dictation+kw` | 40 % | 0 % | 71 % | 42 % | 0 % | 54 % | 33 % | 88 % | 92 % | 92 % | 96 % | 25 % | 33 % | 17 % |
| `deepgram:nova-3+kw` | 100 % | 0 % | 100 % | 87 % | 0 % | 67 % | 57 % | 100 % | 100 % | 100 % | 100 % | 0 % | 28 % | 60 % |
| `assemblyai:universal-3-5-pro+kw` | 100 % | 5 % | 91 % | 100 % | 0 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 18 % | 22 % | 52 % |
| `elevenlabs:scribe_v2+kw` | 100 % | 5 % | 91 % | 100 % | 0 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 20 % | 0 % | 48 % |

## Error en limpio por variante de idioma (WER; CER en ja y zh)

| Motor | es-PE | es-AR | es-ES | en-US | en-GB | pt-BR | pt-PT | fr-FR | de-DE | it-IT | nl-NL | pl-PL | ja-JP | zh-Hans |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `openai:whisper-1` | 5 % | 17 % | 3 % | 6 % | 4 % | 5 % | 18 % | 4 % | 3 % | 7 % | 1 % | 11 % | 1 % | 4 % |
| `openai:gpt-transcribe` | 4 % | 10 % | 2 % | 8 % | 1 % | 2 % | 10 % | 6 % | 0 % | 6 % | 0 % | 4 % | 0 % | 0 % |
| `openai:gpt-transcribe+kw` | 1 % | 7 % | 1 % | 2 % | 1 % | 2 % | 2 % | 0 % | 0 % | 1 % | 0 % | 2 % | 0 % | 0 % |
| `openai:gpt-transcribe+kw+prompt` | 4 % | — | 0 % | 0 % | 1 % | 0 % | 0 % | 1 % | 0 % | 3 % | 0 % | 5 % | — | — |
| `openai:gpt-transcribe:auto` | 6 % | 10 % | 2 % | 8 % | 1 % | 6 % | 7 % | 6 % | 0 % | 9 % | 0 % | 0 % | 0 % | 0 % |
| `openai:gpt-live-transcribe+kw` | 1 % | 0 % | 1 % | 0 % | 4 % | 6 % | 0 % | 0 % | 0 % | 0 % | 2 % | 4 % | 3 % | 1 % |
| `xai:grok-voice-transcribe-2.0` | 17 % | 19 % | 17 % | 14 % | 7 % | 9 % | 18 % | 8 % | 3 % | 6 % | 0 % | 2 % | 2 % | 1 % |
| `xai:grok-voice-transcribe-2.0+kw` | 14 % | 13 % | 16 % | 8 % | 7 % | 5 % | 16 % | 2 % | 5 % | 2 % | 2 % | 2 % | 9 % | 1 % |
| `xai:grok-voice-transcribe-2.0+kw:vad0.1` | — | — | — | — | — | — | — | — | — | — | — | — | — | — |
| `gemini:gemini-3.5-flash-lite+kw` | 2 % | 3 % | 11 % | 2 % | 2 % | 6 % | 16 % | 3 % | 10 % | 10 % | 11 % | 3 % | 1 % | 1 % |
| `gemini:gemini-3.8-flash+kw` | 1 % | 0 % | 11 % | 0 % | 0 % | 3 % | 11 % | 2 % | 9 % | 9 % | 10 % | 2 % | 0 % | 0 % |
| `apple:speech+kw` | 5 % | 4 % | 15 % | 7 % | 11 % | 5 % | 10 % | 6 % | 4 % | 13 % | — | — | 1 % | 4 % |
| `apple:dictation+kw` | 8 % | 6 % | 19 % | 10 % | 6 % | 43 % | 42 % | 6 % | 11 % | 10 % | 20 % | 9 % | 9 % | 9 % |
| `deepgram:nova-3+kw` | 1 % | 6 % | 7 % | 4 % | 1 % | 19 % | 19 % | 4 % | 1 % | 9 % | 2 % | 28 % | 0 % | 6 % |
| `assemblyai:universal-3-5-pro+kw` | 0 % | 3 % | 0 % | 2 % | 1 % | 3 % | 25 % | 2 % | 10 % | 0 % | 0 % | 6 % | 2 % | 0 % |
| `elevenlabs:scribe_v2+kw` | 1 % | 7 % | 4 % | 2 % | 2 % | 0 % | 2 % | 0 % | 1 % | 9 % | 10 % | 0 % | 3 % | 0 % |

## Error con ruido a 5 dB por variante de idioma

| Motor | es-PE | es-AR | es-ES | en-US | en-GB | pt-BR | pt-PT | fr-FR | de-DE | it-IT | nl-NL | pl-PL | ja-JP | zh-Hans |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `openai:whisper-1` | 11 % | 26 % | 6 % | 11 % | 8 % | 18 % | 52 % | 6 % | 3 % | 22 % | 8 % | 11 % | 4 % | 8 % |
| `openai:gpt-transcribe` | 6 % | 21 % | 4 % | 8 % | 3 % | 23 % | 50 % | 3 % | 0 % | 13 % | 6 % | 7 % | 2 % | 1 % |
| `openai:gpt-transcribe+kw` | 2 % | 12 % | 7 % | 6 % | 1 % | 7 % | 30 % | 0 % | 1 % | 4 % | 3 % | 3 % | 3 % | 0 % |
| `openai:gpt-transcribe+kw+prompt` | 8 % | — | 9 % | 0 % | 0 % | 18 % | 19 % | 0 % | 0 % | 11 % | 0 % | 0 % | — | — |
| `openai:gpt-transcribe:auto` | — | — | — | — | — | — | — | — | — | — | — | — | — | — |
| `openai:gpt-live-transcribe+kw` | 13 % | 9 % | 7 % | 8 % | 6 % | 20 % | 44 % | 3 % | 1 % | 5 % | 9 % | 9 % | 8 % | 1 % |
| `xai:grok-voice-transcribe-2.0` | 33 % | 34 % | 22 % | 19 % | 6 % | 27 % | 60 % | 4 % | 14 % | 9 % | 10 % | 8 % | 5 % | 2 % |
| `xai:grok-voice-transcribe-2.0+kw` | 29 % | 24 % | 19 % | 19 % | 10 % | 19 % | 54 % | 0 % | 11 % | 10 % | 1 % | 6 % | 2 % | 1 % |
| `xai:grok-voice-transcribe-2.0+kw:vad0.1` | 29 % | 24 % | 20 % | 19 % | 7 % | 21 % | 63 % | 0 % | 8 % | 9 % | 1 % | 8 % | 2 % | 1 % |
| `gemini:gemini-3.5-flash-lite+kw` | 5 % | 11 % | 11 % | 7 % | 2 % | 16 % | 59 % | 2 % | 9 % | 12 % | 12 % | 13 % | 1 % | 1 % |
| `gemini:gemini-3.8-flash+kw` | 3 % | 2 % | 10 % | 3 % | 2 % | 5 % | 23 % | 2 % | 9 % | 9 % | 8 % | 5 % | 2 % | 0 % |
| `apple:speech+kw` | 17 % | 19 % | 19 % | 16 % | 14 % | 29 % | 42 % | 7 % | 7 % | 28 % | — | — | 9 % | 7 % |
| `apple:dictation+kw` | 20 % | 38 % | 31 % | 17 % | 27 % | 37 % | 61 % | 4 % | 16 % | 21 % | 12 % | 26 % | 9 % | 9 % |
| `deepgram:nova-3+kw` | 14 % | 13 % | 9 % | 9 % | 2 % | 43 % | 39 % | 9 % | 4 % | 11 % | 9 % | 30 % | 2 % | 1 % |
| `assemblyai:universal-3-5-pro+kw` | 4 % | 0 % | 0 % | 4 % | 2 % | 10 % | 43 % | 2 % | 6 % | 7 % | 1 % | 13 % | 0 % | 0 % |
| `elevenlabs:scribe_v2+kw` | 7 % | 6 % | 1 % | 5 % | 8 % | 6 % | 30 % | 2 % | 0 % | 9 % | 8 % | 0 % | 3 % | 0 % |

## Importes en el texto por variante de idioma (sintéticas, todas las condiciones)

| Motor | es-PE | es-AR | es-ES | en-US | en-GB | pt-BR | pt-PT | fr-FR | de-DE | it-IT | nl-NL | pl-PL | ja-JP | zh-Hans |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `openai:whisper-1` | 100 % | 100 % | 100 % | 98 % | 100 % | 100 % | 85 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 96 % |
| `openai:gpt-transcribe` | 100 % | 100 % | 92 % | 100 % | 100 % | 83 % | 88 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % |
| `openai:gpt-transcribe+kw` | 100 % | 100 % | 96 % | 100 % | 100 % | 88 % | 96 % | 100 % | 100 % | 98 % | 100 % | 100 % | 100 % | 100 % |
| `openai:gpt-transcribe+kw+prompt` | 100 % | — | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | — | — |
| `openai:gpt-transcribe:auto` | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % |
| `openai:gpt-live-transcribe+kw` | 96 % | 100 % | 100 % | 100 % | 100 % | 92 % | 88 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % |
| `xai:grok-voice-transcribe-2.0` | 100 % | 83 % | 100 % | 67 % | 92 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % |
| `xai:grok-voice-transcribe-2.0+kw` | 100 % | 83 % | 100 % | 75 % | 92 % | 96 % | 98 % | 100 % | 100 % | 100 % | 100 % | 100 % | 96 % | 100 % |
| `xai:grok-voice-transcribe-2.0+kw:vad0.1` | 100 % | 83 % | 100 % | 67 % | 92 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % |
| `gemini:gemini-3.5-flash-lite+kw` | 100 % | 100 % | 100 % | 100 % | 100 % | 98 % | 94 % | 100 % | 100 % | 96 % | 100 % | 100 % | 100 % | 100 % |
| `gemini:gemini-3.8-flash+kw` | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 98 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % |
| `apple:speech+kw` | 95 % | 100 % | 92 % | 67 % | 100 % | 92 % | 85 % | 100 % | 100 % | 100 % | — | — | 75 % | 100 % |
| `apple:dictation+kw` | 100 % | 96 % | 88 % | 67 % | 96 % | 75 % | 60 % | 100 % | 100 % | 100 % | 100 % | 96 % | 96 % | 100 % |
| `deepgram:nova-3+kw` | 100 % | 100 % | 100 % | 96 % | 100 % | 100 % | 100 % | 100 % | 100 % | 92 % | 100 % | 83 % | 100 % | 63 % |
| `assemblyai:universal-3-5-pro+kw` | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 94 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % | 100 % |
| `elevenlabs:scribe_v2+kw` | 98 % | 100 % | 100 % | 98 % | 100 % | 100 % | 94 % | 96 % | 100 % | 100 % | 100 % | 100 % | 96 % | 100 % |

## Sesgo del TTS: error y nota núcleo en limpio, por motor que generó el audio

| Motor | Error `say` (Apple) | Error `gemini` (Google) | Error `openai` (solo es-PE) | Nota `say` | Nota `gemini` | Nota `openai` |
|---|---|---|---|---|---|---|
| `openai:whisper-1` | 6.7 % | 6.3 % | 3.7 % | 99 % | 99 % | 100 % |
| `openai:gpt-transcribe` | 3.7 % | — | — | 96 % | — | — |
| `openai:gpt-transcribe+kw` | 1.4 % | 1.3 % | 1.3 % | 96 % | 99 % | 100 % |
| `openai:gpt-transcribe+kw+prompt` | 1.1 % | 1.2 % | — | 91 % | 95 % | — |
| `openai:gpt-transcribe:auto` | 3.9 % | — | — | 95 % | — | — |
| `openai:gpt-live-transcribe+kw` | 1.6 % | — | — | 95 % | — | — |
| `xai:grok-voice-transcribe-2.0` | 8.7 % | — | — | 93 % | — | — |
| `xai:grok-voice-transcribe-2.0+kw` | 7.4 % | 7.1 % | 13.2 % | 92 % | 93 % | 83 % |
| `xai:grok-voice-transcribe-2.0+kw:vad0.1` | — | — | — | — | — | — |
| `gemini:gemini-3.5-flash-lite+kw` | 5.4 % | 6.0 % | 3.4 % | 96 % | 95 % | 83 % |
| `gemini:gemini-3.8-flash+kw` | 4.2 % | 4.0 % | 0.0 % | 100 % | 100 % | 100 % |
| `apple:speech+kw` | 7.1 % | 7.1 % | 4.4 % | 92 % | 96 % | 100 % |
| `apple:dictation+kw` | 20.8 % | 9.5 % | 4.6 % | 77 % | 94 % | 100 % |
| `deepgram:nova-3+kw` | 8.7 % | 6.6 % | 0.0 % | 98 % | 96 % | 100 % |
| `assemblyai:universal-3-5-pro+kw` | 2.9 % | 4.6 % | 0.0 % | 100 % | 100 % | 100 % |
| `elevenlabs:scribe_v2+kw` | 2.1 % | 3.6 % | 0.0 % | 96 % | 97 % | 100 % |

## Habla humana real (OpenSLR 73 = es-PE; FLEURS = el resto): error por idioma

| Motor | es-PE | es-419 | en-US | pt-BR | fr-FR | de-DE | it-IT | nl-NL | pl-PL | ja-JP | zh-Hans |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `openai:whisper-1` | 4 % | 3 % | 16 % | 12 % | 7 % | 3 % | 1 % | 5 % | 6 % | 3 % | 16 % |
| `openai:gpt-transcribe` | 2 % | 3 % | 9 % | 5 % | 3 % | 0 % | 2 % | 2 % | 2 % | 5 % | 6 % |
| `openai:gpt-transcribe+kw` | 2 % | 3 % | 9 % | 5 % | 5 % | 0 % | 2 % | 3 % | 4 % | 5 % | 7 % |
| `openai:gpt-live-transcribe+kw` | 3 % | — | — | — | — | — | — | — | — | — | — |
| `xai:grok-voice-transcribe-2.0` | 5 % | 2 % | 62 % | 10 % | 11 % | 3 % | 3 % | 7 % | 6 % | 0 % | 5 % |
| `xai:grok-voice-transcribe-2.0+kw` | 5 % | 2 % | 62 % | 7 % | 12 % | 5 % | 2 % | 5 % | 1 % | 0 % | 5 % |
| `xai:grok-voice-transcribe-2.0+kw:vad0.1` | 5 % | 2 % | 25 % | 8 % | 10 % | 5 % | 2 % | 5 % | 0 % | 0 % | 5 % |
| `gemini:gemini-3.5-flash-lite+kw` | 6 % | 4 % | 23 % | 15 % | 7 % | 2 % | 3 % | 5 % | 11 % | 6 % | 10 % |
| `gemini:gemini-3.8-flash+kw` | 4 % | 4 % | 22 % | 7 % | 4 % | 2 % | 1 % | 1 % | 2 % | 2 % | 0 % |
| `apple:speech+kw` | 2 % | 2 % | 14 % | 17 % | 7 % | 4 % | 1 % | — | — | 5 % | 6 % |
| `apple:dictation+kw` | 4 % | 4 % | 22 % | 29 % | 20 % | 7 % | 4 % | 22 % | 14 % | 12 % | 14 % |
| `deepgram:nova-3+kw` | 4 % | 3 % | 17 % | 17 % | 10 % | 4 % | 5 % | 6 % | 11 % | 5 % | 5 % |
| `assemblyai:universal-3-5-pro+kw` | 5 % | 3 % | 7 % | 10 % | 2 % | 2 % | 4 % | 4 % | 6 % | 3 % | 1 % |
| `elevenlabs:scribe_v2+kw` | 2 % | 3 % | 3 % | 8 % | 2 % | 1 % | 1 % | 5 % | 1 % | 5 % | 1 % |

## Listón

Pasa si cumple TODO: (1) error en limpio ≤ 15 % (CER ≤ 10 % en ja/zh) en CADA variante; (2) importes en el texto ≥ 90 % en cada variante; (3) nota núcleo ≥ la de `whisper-1` en CADA variante; (4) latencia p95 ≤ 15 s; (5) sin apagado anunciado antes del 2027-10-07; (6) cubre las 14 variantes.

| Motor | (1) error | (2) importes | (3) nota ≥ whisper-1 | (4) p95 | (5) apagado | (6) cobertura | Pasa |
|---|---|---|---|---|---|---|---|
| `openai:whisper-1` | ✗ es-AR 17 %, pt-PT 18 % | ✗ pt-PT 85 % | ✓ | ✓ 14.5* | ✗ 2027-02-26 | ✓ | no |
| `openai:gpt-transcribe` | ✓ | ✗ pt-BR 83 %, pt-PT 88 % | ✗ es-AR 92 %<96 %, es-ES 92 %<96 %, pt-BR 83 %<100 %, pt-PT 50 %<67 %, it-IT 92 %<96 %, nl-NL 92 %<96 %, pl-PL 83 %<100 % | ✓ 5.6* | ✓ | ✓ | no |
| `openai:gpt-transcribe+kw` | ✓ | ✗ pt-BR 88 % | ✗ es-AR 92 %<96 %, es-ES 79 %<96 %, pt-BR 92 %<100 %, pl-PL 92 %<100 % | ✓ 6.2* | ✓ | ✓ | no |
| `openai:gpt-transcribe+kw+prompt` | ✓ | ✓ | ✗ pt-BR 50 %<100 %, pt-PT 50 %<67 %, pl-PL 75 %<100 % | ✓ 1.3* | ✓ | ✗ 11/14 | no |
| `openai:gpt-transcribe:auto` | ✓ | ✓ | ✗ es-PE 83 %<97 %, pt-BR 83 %<100 %, pl-PL 83 %<100 % | ✓ 4.7* | ✓ | ✓ | no |
| `openai:gpt-live-transcribe+kw` | ✓ | ✗ pt-PT 88 % | ✗ es-ES 90 %<96 %, pt-BR 88 %<100 %, pl-PL 78 %<100 % | ✓ 3.4* | ✓ | ✓ | no |
| `xai:grok-voice-transcribe-2.0` | ✗ es-PE 17 %, es-AR 19 %, es-ES 17 %, pt-PT 18 % | ✗ es-AR 83 %, en-US 67 % | ✗ es-PE 75 %<97 %, es-AR 92 %<96 %, es-ES 67 %<96 %, en-US 67 %<96 %, pt-BR 83 %<100 %, it-IT 92 %<96 %, nl-NL 92 %<96 %, pl-PL 92 %<100 %, ja-JP 92 %<100 % | ✓ 5.1* | ✓ | ✓ | no |
| `xai:grok-voice-transcribe-2.0+kw` | ✗ es-ES 16 %, pt-PT 16 % | ✗ es-AR 83 %, en-US 75 % | ✗ es-PE 77 %<97 %, es-ES 67 %<96 %, en-US 75 %<96 %, pt-BR 79 %<100 %, it-IT 88 %<96 %, pl-PL 88 %<100 %, ja-JP 92 %<100 % | ✓ 4.7* | ✓ | ✓ | no |
| `xai:grok-voice-transcribe-2.0+kw:vad0.1` | ✓ | ✗ es-AR 83 %, en-US 67 % | ✗ es-PE 50 %<97 %, es-AR 80 %<96 %, es-ES 80 %<96 %, en-US 67 %<96 %, pt-PT 33 %<67 %, it-IT 80 %<96 %, pl-PL 80 %<100 %, ja-JP 83 %<100 % | ✓ 4.5* | ✓ | ✓ | no |
| `gemini:gemini-3.5-flash-lite+kw` | ✗ pt-PT 16 % | ✓ | ✗ es-PE 90 %<97 %, es-AR 83 %<96 %, es-ES 92 %<96 %, pt-BR 88 %<100 %, nl-NL 92 %<96 %, pl-PL 92 %<100 %, ja-JP 96 %<100 % | ✓ 11.9* | ✓ | ✓ | no |
| `gemini:gemini-3.8-flash+kw` | ✓ | ✓ | ✓ | ✗ 19.9* | ✓ | ✓ | no |
| `apple:speech+kw` | ✓ | ✗ en-US 67 %, pt-PT 85 %, ja-JP 75 % | ✗ es-PE 87 %<97 %, es-ES 83 %<96 %, en-US 67 %<96 %, pt-BR 75 %<100 %, ja-JP 71 %<100 % | ✓ 0.1 | ✓ | ✗ 12/14 | no |
| `apple:dictation+kw` | ✗ es-ES 19 %, pt-BR 43 %, pt-PT 42 %, nl-NL 20 % | ✗ es-ES 88 %, en-US 67 %, pt-BR 75 %, pt-PT 60 % | ✗ es-PE 90 %<97 %, es-AR 88 %<96 %, es-ES 71 %<96 %, en-US 67 %<96 %, en-GB 96 %<100 %, pt-BR 54 %<100 %, pt-PT 46 %<67 %, pl-PL 92 %<100 %, ja-JP 92 %<100 % | ✓ 0.9 | ✓ | ✓ | no |
| `deepgram:nova-3+kw` | ✗ pt-BR 19 %, pt-PT 19 %, pl-PL 28 % | ✗ pl-PL 83 %, zh-Hans 63 % | ✗ pt-BR 67 %<100 %, pt-PT 57 %<67 % | ✓ 5.2* | ✓ | ✓ | no |
| `assemblyai:universal-3-5-pro+kw` | ✗ pt-PT 25 % | ✓ | ✓ | ✓ 11.7* | ✓ | ✓ | no |
| `elevenlabs:scribe_v2+kw` | ✓ | ✓ | ✗ es-AR 89 %<96 %, es-ES 91 %<96 %, pl-PL 80 %<100 % | ✓ 5.5* | ✓ | ✓ | no |

## Latencia en serie (pasada `--latency`: nota 02 limpia y nota 05 a 5 dB de cada variante, 2 repeticiones)

| Motor | Llamadas | p50 s | p95 s | máx s | Tras la voz p50 / p95 s (streaming) |
|---|---|---|---|---|---|
| `apple:speech+kw` | 48 | 0.1 | 0.1 | 0.2 | — |
| `apple:dictation+kw` | 56 | 0.5 | 0.9 | 1.2 | — |

## Gasto

- apple: 1070 llamadas, 0.000 USD
- xai: 834 llamadas, 0.136 USD
- openai: 1462 llamadas, 0.826 USD
- gemini: 844 llamadas, 0.282 USD
- deepgram: 422 llamadas, 0.246 USD
- assemblyai: 422 llamadas, 0.164 USD
- elevenlabs: 422 llamadas, 0.170 USD
- openai (lectura de la nota): 949 llamadas, 0.541 USD
- OpenAI total (con el TTS de es-PE, ~0.02 USD): 1.387 USD
