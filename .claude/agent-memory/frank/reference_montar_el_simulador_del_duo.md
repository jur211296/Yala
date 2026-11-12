---
name: montar-el-simulador-del-duo
description: Con Xcode 27.2 el Duo vive en un runtime propio (iOS-27-2-iPhone19-4) que no se deja instalado; se baja con -downloadPlatform iOS. Device Hub abre con un aviso de PosterBoard que hay que cerrar.
metadata:
  type: reference
---

Medido el 2026-11-02 al pasar a Xcode 27.2 (antes, 2026-10-24 con 27.1):

- **`xcodebuild -downloadPlatform iOS` baja DOS runtimes 27.2**: el general (`iOS-27-2`, iPhone 17 Pro, iPad…) y uno
  que solo admite el Duo (`iOS-27-2-iPhone19-4`). En la Mini se deja solo el general (decisión de Jürgen: «descarga los
  que necesites nomas»); el del Duo se borra (`simctl runtime delete <id>`) y se vuelve a bajar para una sesión Duo.
  Lánzalo en segundo plano lo primero y compila la base mientras baja.
- **El iPhone 17 Pro ya corre en 27.2**, así que lo que va con `#available(iOS 27.1, *)` sí se ejecuta en el iPhone.
  Con 27.1 era al revés: el 17 Pro iba en 27.0 y esa rama era un no-op en el simulador.
- **Device Hub abre a veces con «PosterBoard se cerró inesperadamente»** encima: «Ignorar» (clic en 911,376 con la
  ventana donde abre) y elegir el Duo en la lista (540,262). Los botones de postura quedan donde dice `duo/comun.sh`.
- **Los scripts de la ficha son bash**: `source comun.sh` desde zsh falla con `bad substitution`. Un envoltorio
  `bash -c` (o un script con `#!/usr/bin/env bash` que los cargue y haga `eval "$1"`) sirve para conducir el Duo.

Relacionado: [[deriveddata-en-extdev]], [[spm-sin-red-en-el-sandbox]].
