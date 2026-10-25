---
name: montar-el-simulador-del-duo
description: Una sesión del iPhone Duo en la Mini empieza bajando el runtime 27.1 (7,85 GB, ~45 min), que solo admite el Duo; el iPhone 17 Pro vuelve en 27.0. Device Hub abre con un aviso de PosterBoard que hay que cerrar.
metadata:
  type: reference
---

Medido el 2026-10-24 (Xcode 27.1, sesión «Duo cerrado · opción 2»):

- **Al cerrar una sesión Duo se borra también el runtime 27.1**, así que la siguiente arranca sin él:
  `xcodebuild -downloadPlatform iOS` lo trae (7,85 GB, unos 45 min). Lánzalo en segundo plano lo primero y compila la
  base mientras baja.
- **El runtime 27.1 solo admite el Duo**: `simctl create … iPhone-17-Pro … iOS-27-1` da `Incompatible device`. El
  iPhone 17 Pro va en 27.0, y ahí todo lo que vaya con `#available(iOS 27.1, *)` es un no-op: la comparación al píxel
  en el iPhone demuestra que no cambia nada, no que el código nuevo funcione en un iPhone con 27.1.
- **Device Hub abre a veces con «PosterBoard se cerró inesperadamente»** encima: «Ignorar» (clic en 911,376 con la
  ventana donde abre) y elegir el Duo en la lista (540,262). Los botones de postura quedan donde dice `duo/comun.sh`.
- **Los scripts de la ficha son bash**: `source comun.sh` desde zsh falla con `bad substitution`. Un envoltorio
  `bash -c` (o un script con `#!/usr/bin/env bash` que los cargue y haga `eval "$1"`) sirve para conducir el Duo.

Relacionado: [[deriveddata-en-extdev]], [[spm-sin-red-en-el-sandbox]].
