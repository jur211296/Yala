---
name: vaciar-el-almacen-de-pruebas-del-iphone
description: El almacén de pruebas de Yala Dev en el iPhone 14 vive en el grupo de apps y sobrevive a desinstalar; con la semilla pesada, -uitest-reset tumba el arranque. Cómo vaciarlo desde la Mac.
metadata:
  type: reference
---

Medido el 2026-11-24 (barrido antes de la build 8, Max, iPhone 14 por cable, iOS 27.2.1):

- **`-uitest-reset` sobre un almacén con la semilla `pesado` pasa de los 20 s del arranque** y iOS mata Yala Dev
  (`0x8BADF00D`, `process-launch watchdog`), tres de tres. No es un bug de la app: es el gancho de pruebas.
- **Desinstalar no lo borra**: `YalaModel-UITest.store` vive en el grupo `group.com.jurgenschmidt.yala.dev`
  (`Library/Application Support/`), y el widget seguía enseñando las cifras viejas tras reinstalar.
- **Relanzar con `-uitest-seed pesado` sin reset tras desinstalar siembra ENCIMA** (la marca de «ya sembrado» se fue con
  `UserDefaults`): el saldo pasó de 265 mil a 650 mil en tres arranques, y mientras escribe el Panel no enseña el saldo
  grande.
- **Lo que funciona**: con la app cerrada, sobrescribir los tres ficheros con uno vacío:
  `xcrun devicectl device copy to --device <udid> --domain-type appGroupDataContainer --domain-identifier
  group.com.jurgenschmidt.yala.dev --source <fichero vacío> --destination "Library/Application Support/YalaModel-UITest.store"`
  (y `-wal`, `-shm`). El siguiente `-uitest-reset -uitest-seed realista` arranca en 8 s. `devicectl` no tiene `delete`;
  para ver qué hay, `devicectl device info files … --subdirectory "Library/Application Support"`.
- **`rotate` de Device MCP no gira el iPhone 14** si tiene el bloqueo de rotación o está de pie: lo girado se deja a los
  XCUITest de capturas.

Relacionado: [[conducir-el-iphone-real-con-device-mcp]], [[medir-release-en-el-iphone-con-semilla]].
