---
name: yala-dev-es-debug-dev
description: El scheme Yala Dev compila Debug-Dev; con configuration Debug (XcodeBuildMCP o xcodebuild -configuration Debug) sale la app de producción sin DEV_BUILD
metadata:
  type: reference
---

El scheme `Yala Dev` usa `Debug-Dev` (y `Release-Dev`). Si en `session_set_defaults` pones `configuration: Debug`,
XcodeBuildMCP la impone: sale `com.jurgenschmidt.yala` sin `DEV_BUILD`, los seeds `-uitest-seed` no siembran lo
esperado y el canal de Grupos no nace encendido. Costó un build de 5 min el 2026-10-21. Pon `Debug-Dev` o no pongas
configuración. Relacionado: [[deriveddata-en-extdev]], [[spm-sin-red-en-el-sandbox]].

**También con `xcodebuild` a mano (2026-10-25, lote 12.3):** `-scheme "Yala Dev" -configuration Debug` deja los productos
en `Debug-iphonesimulator/` con la app de producción; Grupos no abre «Saldar» y un XCUITest de grupos cae sin pista.
Sin `-configuration` sale `Debug-Dev-iphonesimulator/`. Mira la carpeta de `Build/Products` antes de fiarte de un build.
Costó dos builds completos de 20 min con `-jobs 2`.
