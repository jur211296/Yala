---
name: una-funcion-que-sale-de-yala-dev-hereda-lo-solo-dev
description: Al sacar una función de Yala Dev a la app de producción, busca todo lo que solo tiene Dev (claves del Info.plist por configuración, #if DEV_BUILD): Face ID cerraba la app (22-nov)
metadata:
  type: feedback
---

«Navegadores conectados» salía de Yala Dev cambiando una URL, y el cambio parecía de una línea. La pista estaba en el
`coverage` del índice: `NSFaceIDUsageDescription` solo en Debug-Dev y Release-Dev. «Vincular un navegador» pide Face ID
(`LAContext`), y sin la clave iOS cierra la app. Ni el build ni los XCUITest lo ven: corren con Yala Dev.

**Why:** lo que se gatea por scheme no vive solo en Swift; también en `project.pbxproj` (`INFOPLIST_KEY_*`,
entitlements) por configuración.

**How to apply:** antes de abrir una función de Dev a producción, `grep -n` de sus permisos en el pbxproj por las cuatro
configuraciones de la app y `plutil -p` del `.app` del scheme `Yala`. Fíjalo con un test que lea el pbxproj.
