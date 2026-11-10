---
name: medir-un-cuelgue-de-tipos-con-sample
description: Cómo medir en el simulador cuánto de abrir una pantalla se va en instanciar tipos por nombre (App Hang con TypeDecoder en Sentry), con sample y conteo inclusivo
metadata:
  type: reference
---

Un «App Hang» de Sentry con el hilo principal entero en `swift_getTypeByMangledName` → `TypeDecoder::decodeMangledType`
es el coste de descifrar un tipo de vista anidado la primera vez por proceso (YALA-IOS-G, Ajustes, 2026-11-09).

Medirlo en el simulador sin Instruments: los procesos del simulador son procesos del Mac.
1. Lanzar la app con `-uitest -uitest-skip-onboarding -uitest-seed minimal -uitest-reset` y esperar al botón.
2. `sample <pid> 3 1 -mayDie -file s.txt &` y tocar la entrada con `axe tap --id …` 0,3 s después.
3. Contar muestras INCLUSIVAS del hilo principal por patrón (sin contar anidados dos veces): un script que recorre el
   árbol del `Call graph` por la columna del número. Con muestreo a 1 ms, muestras ≈ ms.

Trampas medidas: con un `xcodebuild` en marcha el toque no llega y la muestra sale a 0 (y las que salen, infladas: 173
frente a ~92); repite con la Mac quieta. El `PERF ajustes` de `LoadTimeMarks` mide la pantalla entera y no aísla esto.
La cura fue `AnyView` en las funciones genéricas por las que pasa cada fila (~92 → ~40 ms).

Relacionado: [[sentry-tokens-y-api]].
