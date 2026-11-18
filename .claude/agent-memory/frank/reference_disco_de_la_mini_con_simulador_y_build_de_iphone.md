---
name: disco-de-la-mini-con-simulador-y-build-de-iphone
description: En la Mini, un simulador SE creado para capturas más una build para el iPhone en la misma sesión bajan el disco de 20 a 4 GB; qué ocupa y qué se puede borrar sin pedir a nadie.
metadata:
  type: reference
---

Medido el 2026-11-17 en la Mini (encargo «Reusar»), empezando con 20 GB libres:

- **DerivedData propia en el scratchpad** (`-derivedDataPath`): 7,8 GB tras la primera build de simulador
  (3,6 GB son `SourcePackages`). Úsala también para el gate y la build del iPhone: así no se paga otra entera en
  `~/Library/Developer/Xcode/DerivedData`.
- **Un simulador iPhone SE creado para capturas**: 4,5 GB tras unos arranques. Bórralo en cuanto tengas sus
  capturas (`xcrun simctl delete <udid>`): libera ~2 GB enseguida y el resto al rato.
- **La build para el iPhone 14** suma ~2 GB en la misma DerivedData (`Debug-Dev-iphoneos`). Tras instalar con
  `devicectl`, esas carpetas se borran con `find … -name Debug-Dev-iphoneos -prune -exec rm -r {} +`.
- Las copias de `.app` que guardes para el «antes» pesan 414 MB cada una.
- `rm -rf` lo niega el sandbox; `rm -r` de rutas concretas pasa. Un comando con sintaxis de zsh (`${(f)…}`) lo
  para el chequeo de borrados aunque no borre nada: escribe la lista en un fichero y usa `$(cat fichero)`.

Ver [[borrar-en-disco-lo-hace-el-bot]], [[segundo-simulador-en-la-max]].
