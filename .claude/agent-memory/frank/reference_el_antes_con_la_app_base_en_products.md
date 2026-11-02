---
name: el-antes-con-la-app-base-en-products
description: Para regrabar el «antes» de un vídeo sin otra build de la base, copia el Yala.app base y cámbialo por el de Products antes de test-without-building; el runner del conductor no lo enlaza
metadata:
  type: reference
---

Para un vídeo antes/después con un conductor XCUITest ([[capturas-con-conductor-xcuitest]]): en cuanto termina la
build-for-testing de la base, copia `Build/Products/Debug-Dev-iphonesimulator/Yala.app` al scratchpad. Si luego una
escena del «antes» sale mal (2 de 4 el 2026-11-02: el plegable no existía con la semilla y la estrella caía en la fila),
arreglas el conductor, compilas con tu código y, para el «antes», pones el `Yala.app` base en Products (`mv` el nuevo
fuera, `cp`/`mv` el base dentro), corres `test-without-building` de esa escena y devuelves el nuevo. `test-without-building`
instala el `Yala.app` de Products; el runner de UI no lo enlaza, así que el conductor nuevo conduce la app vieja.

**Why:** una segunda build de la base en frío son ~10 min y otro DerivedData; el cambio de `.app` cuesta segundos.
`rm -rf` sobre `/Volumes/ExtDev` lo deniega el clasificador: solo `mv`.

**How to apply:** guarda la copia base nada más compilarla, antes de tocar código. Y mide el «antes» de verdad: el de
Ajustes desde Más salió IGUAL que el después, y eso refutó la premisa de la auditoría (no era «alto»).
