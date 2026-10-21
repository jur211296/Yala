---
name: yala-dev-es-debug-dev
description: Con XcodeBuildMCP, `configuration: Debug` sobre el scheme «Yala Dev» compila el bundle de producción sin DEV_BUILD; la buena es Debug-Dev
metadata:
  type: reference
---

El scheme `Yala Dev` usa `Debug-Dev` (y `Release-Dev`). Si en `session_set_defaults` pones `configuration: Debug`,
XcodeBuildMCP la impone: sale `com.jurgenschmidt.yala` sin `DEV_BUILD`, los seeds `-uitest-seed` no siembran lo
esperado y el canal de Grupos no nace encendido. Costó un build de 5 min el 2026-10-21. Pon `Debug-Dev` o no pongas
configuración. Relacionado: [[deriveddata-en-extdev]], [[spm-sin-red-en-el-sandbox]].
