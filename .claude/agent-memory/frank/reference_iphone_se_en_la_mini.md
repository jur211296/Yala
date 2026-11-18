---
name: iphone-se-en-la-mini
description: El runtime iOS 27.2 admite iPhone SE (3.ª gen.); en la Mini no existe hasta crearlo, y un mismo .xctestrun sirve para antes/después en los dos devices
metadata:
  type: reference
---

En la Mini solo vive el iPhone 17 Pro. Un encargo que pide capturas en «iPhone SE» se resuelve creando el device:
`xcrun simctl create "iPhone SE (3rd generation)" com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation com.apple.CoreSimulator.SimRuntime.iOS-27-2` (medido 2026-11-18, UDID 691A1529…).

**Cómo se usó:** un `build-for-testing` a una derivedData propia, y `test-without-building -xctestrun … -destination id=<udid>` en cada device, con `sim-lock.sh` delante; el test adjunta capturas `keepAlways` y se sacan con `xcresulttool export attachments`. El «antes» = vista de `git show HEAD:` puesta en el árbol solo mientras compila.

**Trampa:** en el SE con AX3 el importe queda bajo la barra de «Guardar» y un arrastre desde él no desplaza; para la captura de abajo, arrastra desde otra cosa. Relacionado: [[antes-del-iphone-con-git-archive]].
