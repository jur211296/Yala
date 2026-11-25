---
name: medir-un-cambio-de-build-del-ci-en-local
description: Probar en la Mini un cambio del build del CI (caché, fechas, flags) con un worktree desechable y mirar en el binario que cada cambio llegó; el tiempo solo no prueba nada.
metadata:
  type: reference
---

Método (25-nov, encargo «UI nocturna y CI»): `git worktree add --detach` en el scratchpad, dos commits reales de 2.3, el mismo `xcodebuild build-for-testing` que el CI con `-derivedDataPath .ddp`, y tras CADA build `strings -a <app>/Yala.debug.dylib | grep` de un texto que el paso cambió (un `print` en `#if DEBUG`), más `strings` del `YalaTests` del `.xctest` para las pruebas.

**Why:** un build de 8 s «en verde» era un binario VIEJO (fechas de fichero más antiguas que el build anterior). Solo lo cazó el `strings`; el tiempo parecía un éxito. También: el pre-commit del repo rechaza commits en ese worktree, así que los cambios de prueba van sin commit (y el script debe comparar con el árbol de trabajo).

**How to apply:** antes de tocar caché, fechas o flags del job `build`, cualquier medida lleva su comprobación de binario. Cuidado con la caché de compilación (CAS): contenido ya compilado sale rápido aunque el arreglo no sirva, así que cada prueba usa un contenido nunca compilado. Borra el worktree al acabar: su `.ddp` ocupa ~21 GB.
