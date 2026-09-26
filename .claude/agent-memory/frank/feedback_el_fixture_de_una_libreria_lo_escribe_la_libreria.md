---
name: el-fixture-de-una-libreria-lo-escribe-la-libreria
description: un fixture de lo que una librería GUARDA se genera con la librería; copiar el JSON de su respuesta de red dio un rojo en mi propio test (26-sep)
metadata:
  type: feedback
---

Cuando un test necesita «lo que el SDK deja en su almacén», el fixture lo escribe el SDK (cliente real con almacén en
memoria), no un literal copiado de otra suite.

**Why:** el 26-sep copié el JSON de sesión de `SupabaseSessionRenewalContractTests` —es la RESPUESTA del servidor, snake_case y
fechas ISO— para el testigo `sessionIsGone`. El SDK guarda con `JSONEncoder()` por defecto (camelCase, fechas como número), así
que el fixture no decodificaba y mi propio test salió rojo en la suite completa. Lo cazaron también dos lentes. El docblock del
fixture afirmaba lo contrario («tal como la guarda el SDK»): lo escribí sin medirlo.

**How to apply:** si el dato viene de una librería, genera el fixture pasándolo por ella (`AuthClient` + almacén en memoria,
molde de `GroupsDetachSessionSurvivesTests.witness_sessionStoredByTheSDK_isAlive`). Relacionado: [[el-fixture-hereda-la-anatomia-de-produccion]], [[mi-docblock-tambien-es-una-premisa]].
