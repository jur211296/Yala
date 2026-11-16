---
id: group-split-amount-field-keeps-the-old-value-and-drops-typed-digits
status: done
priority: medium
area: groups, expense-form
created: 2026-11-07
updated: 2026-11-10
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856
qa-status: passed
qa-date: 2026-11-10
qa-notes: device: reproducido con Device MCP en el iPhone 14 (1,200.00); fix verde en XCUITest
---

# Corregir un importe del reparto dejó «1,100.00» en vez de 150

Medido con toques sintéticos (XCUITest), **a confirmar con el dedo**: en «Nuevo gasto» → «Monto», los cuatro campos del
reparto llegan con «100.00». Tocar el de Ana, borrar seis veces y escribir «150» dejó **«1,100.00»**, y en Carla
«5,100.00» («Te pasaste por S/ 6,000.00»). El toque dejó el cursor delante del número, los borrados no hicieron nada y
los dígitos que pasaron de dos decimales se tiraron sin aviso (`AmountInputHelper.swift:22-27`). El campo no se selecciona
al tocarlo (`GroupSplitEditorCard.swift:340-352`).

Evidencia: capturas `64-reparto-monto`, `65-reparto-ana-150` y `66-reparto-carla-50` de la revisión.
Criterio: corregir un importe del reparto deja el número escrito. La alternativa B1 del problema 2 de la revisión (tocar
selecciona el importe entero) lo resolvería.

## Resuelto (2026-11-10, lote 01 de las mejoras necesarias 2.3)

Confirmado en el iPhone 14 con Device MCP (Yala Dev 2.2, grupo de 2, 400 → 200.00 cada uno): tocar a la izquierda del
número deja el cursor delante, los seis borrados no hacen nada y «150» acaba en **S/ 1,200.00**. Arreglo: al entrar en un
campo del reparto, el cursor va al final del número (`GroupSplitEditorCard`, `TextField(text:selection:)`). No se eligió
la alternativa B1 de la revisión (seleccionar el importe entero), que es de rediseño. Lo fija
`GroupSplitAmountFieldUITests` (sin el arreglo deja «150,100.00»). Evidencia: `~/Claude/entregas/2026-11-10-lote-2-3-grupos-cifras-planificacion/evidencia/antes-2-reparto-iphone14.mov`,
`~/Claude/entregas/2026-11-10-lote-2-3-grupos-cifras-planificacion/evidencia/antes-2-reparto-1200.png`, `~/Claude/entregas/2026-11-10-lote-2-3-grupos-cifras-planificacion/evidencia/despues-2-reparto-150.png`.
