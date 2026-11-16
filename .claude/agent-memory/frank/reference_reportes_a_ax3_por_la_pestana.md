---
name: reportes-a-ax3-por-la-pestana
description: con texto de accesibilidad las tarjetas de Reportes en «Más» no se alcanzan en XCUITest; se entra configurando Reportes como pestaña
metadata:
  type: reference
---

A AX3 (`UICTContentSizeCategoryAccessibilityXL`) `app.openReport("flujoDeCaja")` falla con «No está la tarjeta en
Más»: la tarjeta queda bajo la rejilla y los arrastres sintéticos no la materializan. Lo que funcionó (10-nov, lote 05):
lanzar con `-tabBarConfiguration` `#""{\"activeTabs\":[\"panel\",\"statistics\",\"reports\"]}""#`, `selectTab(.reports)`
y, si el chip `report_chip_flujoDeCaja` asoma por la derecha, `swipeLeft()` sobre `report_chip_comparativa`.
Molde en `LargeTextSecondaryScreensUITests`. La Comparativa a AX3 con semilla `realista` colgó una consulta de
XCUITest («Timed out while evaluating UI query») una vez; al repetir, ver [[un-timeout-tapa-el-rojo-de-detras]].

Y `axe` no ve Ajustes (es hoja): sus marcos se miden desde el propio XCUITest con `print`, ver [[axe-no-ve-las-hojas]].
