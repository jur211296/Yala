---
id: voice-transcription-model-choice
status: backlog
priority: medium
area: voice, ai, cost
created: 2026-10-07
updated: 2026-10-07
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H17)
---

# `whisper-1` se apaga el 26-feb-2027: elegir con qué se transcribe la voz

> **Grupo: para Jürgen.** Cambio de modelo y, en la opción C, de proveedor (a Apple, en el iPhone).

## Qué pasa

La hoja de voz y el dictado del chat transcriben con `whisper-1`
(`VoiceTranscriptionService.swift:118`). OpenAI lo apaga el **2027-02-26** y recomienda `gpt-transcribe`
o `gpt-live-transcribe` (https://developers.openai.com/api/docs/deprecations, consultada 2026-10-07).
Hay margen, pero cae dentro del ciclo de 2.2, y el modelo va dentro del binario
(`ai-model-choice-lives-in-the-app-binary`).

## Lo confirmado en fuente (2026-10-07)

| Modelo | $/minuto | Estado | Nota |
|---|---|---|---|
| `whisper-1` (hoy) | 0,006 | se apaga 2027-02-26 | `prompt` de hasta 224 tokens, `language` singular |
| `gpt-4o-mini-transcribe` | 0,003 | se apaga 2027-02-26 | — |
| `gpt-transcribe` | 0,0045 | vigente, el recomendado | acepta `prompt`, `keywords` y `languages` (plural; no mandar también `language`) |

Fuentes: https://developers.openai.com/api/docs/pricing y
https://developers.openai.com/api/docs/guides/speech-to-text. Límite de archivo: 25 MB; `m4a` admitido.

Apple: `SpeechAnalyzer` + `SpeechTranscriber` (framework Speech), **iOS 26.0+**, con modelos que se
descargan con `AssetInventory` y comprobación de idioma con `SpeechTranscriber.supportedLocale`
(https://developer.apple.com/documentation/speech/speechanalyzer, consultada 2026-10-07). Que sea
**gratis y 100 % en el dispositivo** es lo esperable pero la página no lo dice textualmente: no
confirmado.

## Opciones

| | Qué se hace | A favor | En contra | Coste |
|---|---|---|---|---|
| **A** | `gpt-transcribe` con `keywords` = subcategorías y comercios del usuario | El recomendado por OpenAI. Las palabras clave ayudan con nombres propios («Plaza Vea», «Rappi»). −25 % frente a hoy (0,0045 frente a 0,006) | Hay que probar calidad en es/en/fr/de/it/pt | ≈$0,00075 por nota de 10 s |
| **B** | `gpt-4o-mini-transcribe` | El más barato (−50 %) | Se apaga el mismo día que `whisper-1`: solo aplaza el problema | ≈$0,0005 por nota de 10 s |
| **C** | Transcripción en el iPhone con `SpeechTranscriber` | Sin red para transcribir, sin coste por minuto, encaja con el **modo privado**. Libera cuota `voice` (hoy cada nota gasta 2; ver `free-voice-quota-counts-each-dictation-twice`) | Descarga de modelo la primera vez; calidad y cobertura de idiomas sin medir; más código en la app | 0 por minuto (no confirmado) |

## Recomendación

**A como camino principal en 2.2**, porque es el reemplazo oficial y no cambia la arquitectura. Evaluar
**C** dentro de la card de partir la IA por modo (modo privado), con una prueba de calidad en los seis
idiomas antes de decidir. B no se recomienda.

## 2026-10-07: va a la sesión 2

Decisión de Jürgen (10:06): «la mejor opción que haya en el mercado… no vayamos por el más barato así nomás». La
comparación (incluido xAI, que Jürgen nota mejor en el dictado de Grok) y el arreglo del selector de idioma de voz son el
paso 4 de `ai-every-call-sends-its-task-and-passes-the-bench`.

## Hecho cuando

- Decisión anotada aquí.
- Si A: la app (o el gateway) deja de pedir `whisper-1` antes del 2027-02-26, con test de la petición.
