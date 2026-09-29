---
name: el-modificador-nuevo-quita-la-tolerancia
description: Cambiar cómo se monta algo (quitar → ocultar) quita una tolerancia del sistema que el estado viejo usaba sin saberlo; el gate entero lo cazó, las capturas no.
metadata:
  type: feedback
---

Al pasar la `TabView` de «quitar las pestañas que no tocan» a «montarlas todas con `.hidden(_:)`» (paso 5 del carril
adaptativo, 2026-09-29), la app pasó a ABORTAR en la entrada por invitación: la selección se quedaba en Panel con la
shell de solo grupos, y UIKit no tolera una pestaña oculta seleccionada. Con la pestaña quitada, la `TabView` lo
toleraba en silencio, y ese estado raro llevaba meses ahí sin que nadie lo supiera.

**Why:** las capturas antes/después, los tests de navegación nuevos y el diff píxel a píxel en iPhone salieron
perfectos. Lo cazó el lote 3 del gate (`GroupInviteOnboardingUITests`), un área que no tocaba a propósito, y solo
porque se corrieron las 49 suites de las áreas que casan con `ContentView.swift`. El crash salía como un rojo normal
(«no apareció el banner»); el `.ips` del xcresult era lo que decía «SIGABRT en `_UITabModel _setSelectedItem`».

**How to apply:** cuando cambio el MECANISMO con el que el sistema recibe un estado (quitar vs ocultar, `if` vs
`opacity`, `ForEach` vs `.hidden`), pregunto qué estados raros toleraba el mecanismo viejo —selección apuntando a algo
ausente, índices fuera de rango— y busco quién los produce (`grep` de escritores directos). Y ante un rojo de XCUITest
en un área ajena: primero `xcresulttool export attachments` y mirar si hay un `.ips`. Relacionado:
[[mi-arreglo-quita-la-salida-que-habia]], [[el-arbol-base-contesta-si-es-mio]].
