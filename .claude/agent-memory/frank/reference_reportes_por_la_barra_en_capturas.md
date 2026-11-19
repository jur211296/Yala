---
name: reportes-por-la-barra-en-capturas
description: En capturas con XCUITest en el SE o con letra de accesibilidad, Reportes no se alcanza por «Más»; ponlo en la barra con -tabBarConfiguration y toca report_chip_<id>
metadata:
  type: reference
---

`app.openReport(id)` pasa por la tarjeta de «Más», y en el SE o con texto de accesibilidad esa tarjeta no entra en el
árbol (la `LazyVGrid` de `testing.md`): el caso cae con «No está la tarjeta … en Más». Lo que funcionó el 2026-11-18 en
las capturas del detalle de línea del flujo de caja: lanzar con
`-tabBarConfiguration "{\"activeTabs\":[\"panel\",\"statistics\",\"reports\"]}"`, `app.selectTab(.reports)` y tocar
`report_chip_flujoDeCaja`. Molde: `YalaUITests/FlujoDetalleLinea/FlujoDetalleLineaCapturasUITests.swift`.

**Why:** costó dos corridas perdidas (AX y SE) con el presupuesto de 30 min de interfaz.

**How to apply:** en un conductor de capturas que vaya a correr en varios tamaños, usa la barra desde el principio.
Relacionado: [[el-antes-con-la-app-base-en-products]], [[capturas-se-letra-grande-en-la-mini]].
