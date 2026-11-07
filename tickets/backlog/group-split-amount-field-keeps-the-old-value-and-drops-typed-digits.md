---
id: group-split-amount-field-keeps-the-old-value-and-drops-typed-digits
status: backlog
priority: medium
area: groups, expense-form
created: 2026-11-07
updated: 2026-11-07
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856
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
