---
id: 2026-11-25-ya-registrado-parte-descartar-con-texto-grande
status: backlog
priority: low
area: "bandeja, accesibilidad"
created: 2026-11-25
updated: 2026-11-25
source: "Pase de estrés del barrido antes de la build 9 de 2.3 (iPhone 14, texto al máximo)"
---

# Bandeja: con texto de accesibilidad, «Ya registrado» parte «Descartar» por sílabas

## Qué pasa

En la Bandeja, un pendiente que se parece a un registro guardado enseña «Ya registrado el 25 nov» con **Descartar** y
**Guardar igual** (lote 3 de la Bandeja sin duplicados, nuevo en la 2.3 (9)). Con el texto al máximo (AX5) los dos
botones van uno al lado del otro, cada uno con media fila, y «Descartar» sale como «Des- / cartar».

Medido en el iPhone 14 (iOS 27.2.1), Yala Dev de `origin/2.3` del 25-nov. A tamaño normal se ve bien.
Captura: `~/Claude/entregas/2026-11-25-barrido-y-testflight-2-3-build-9/evidencia/iphone14/11-ya-registrado-ax5.png`.

En la misma pantalla y tamaño también se parten «Pendien-tes» (chip del filtro), «Cate-goría» (cápsula «Falta») y
«STAR-BUCKS» (comercio): esos ya estaban en la 2.3 (8).

## Arreglo propuesto

`InboxAlreadyRecordedFooter.buttons` (`Yala/App/Views/Inbox/InboxDraftRowView.swift`): con
`dynamicTypeSize.isAccessibilitySize`, los dos botones en columna (`VStack(alignment: .leading)`) en vez de en fila.
Barato; no se hizo en el barrido porque el fichero estaba en el PR abierto del lote 4 de la Bandeja.
