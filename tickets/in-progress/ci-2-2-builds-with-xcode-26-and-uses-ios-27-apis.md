---
id: ci-2-2-builds-with-xcode-26-and-uses-ios-27-apis
status: in-progress
priority: high
area: "ci, testing"
created: 2026-10-18
updated: 2026-10-18
source: rojo del CI en el merge del PR #552 a 2.2 (run 39185367867)
---

# El CI de 2.2 compila con Xcode 26.6 y 2.2 ya usa APIs de iOS 27

## Qué pasó

Desde el merge del PR #552 (Siri e IA de iOS 27) en `2.2`, el job `tests` muere en
**Build for testing** y no corre ningún test:

```
Yala/App/Intents/SiriQueryIntents.swift:195:28: error: value of type
'some AssistantSchemas.SystemIntent' has no member 'open'
```

El job corría en `macos-26` con `setup-xcode latest-stable`, que el 18-oct es Xcode 26.6 (SDK
iOS 26.5). La release de 2.2 se compila con Xcode 27.1 en la Mini.

## Medido

- La imagen `macos-26` (20261013) solo trae Xcode 26.0.1–26.6.
- GitHub ofrece la imagen `xcode-27` (preview, macOS 27; actions/runner-images#14404) con
  Xcode 27.0 (default), **27.1 build 27A9275** —el mismo de la Mini— y 27.2 beta. Su único
  runtime es iOS 27.0 y no trae iPhone 17 Pro.

## Arreglo

En `2.2`, los jobs `tests` y `ui` de `qa.yml` pasan a `runs-on: xcode-27` y eligen Xcode 27.1
con `qa/scripts/ci-xcode.sh`, que falla si el build no es 27A9275. El simulador sigue siendo un
iPhone 17 Pro, que `ci-simulador.sh` crea en iOS 27.0. `2.1` no se toca: sigue en `macos-26`.

Descartado: guards `#if compiler(>=6.4)` alrededor de las APIs de iOS 27. Dejarían sin compilar
en el CI justo el código nuevo de 2.2.

## Riesgo que queda

La imagen `xcode-27` está en preview: GitHub avisa de colas mientras equilibra capacidad. Si
una corrida se queda esperando runner, es eso y no el código.
