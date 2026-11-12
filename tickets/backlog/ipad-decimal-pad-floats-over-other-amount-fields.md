---
id: ipad-decimal-pad-floats-over-other-amount-fields
status: backlog
priority: medium
area: ipad, formularios
created: 2026-11-11
updated: 2026-11-11
source: hallazgo de la sesión «Lote 2.3 · barra sobre el teclado» (decisión 68 de la revisión 2.3), medido en el simulador
---

# En el iPad, los demás campos de importe pueden abrir el teclado numérico flotante encima del formulario

En el iPad Air 11 (iOS 27.2, simulador), un `TextField` con `.keyboardType(.decimalPad)` abre un teclado numérico en un
globo flotante encima del contenido, además del teclado acoplado. En Nuevo registro tapaba la descripción y la pregunta
del importe (decisión 68 de la revisión 2.3). Pasar la hoja a tamaño de página no lo quita; lo quita el teclado de
números y signos, que sale solo acoplado. En el iPad Pro 13 no salía, ni antes del cambio.

La sesión lo arregló solo en los cuatro campos de Nuevo registro (importe, los dos importes de la transferencia y la
tasa), con `View.amountKeyboard()` (`Yala/App/Views/Transactions/Components/AmountKeyboard.swift`). Quedan 25 ficheros
con `.decimalPad` sin medir en el iPad: el formulario de cuenta y sus líneas, el borrador del chat, filtros de exportar,
el editor de favoritos, Grupos (gasto, saldo inicial, presupuesto, reparto, liquidación, líneas), Bandeja, onboarding,
presupuestos, pagos planificados, edición en lote, flujo de caja (cinco hojas) y las calculadoras de saldo y de reparto.

## Qué haría falta

1. Medir en el iPad Air 11 cuáles abren el flotante encima de algo que importa (el caso de
   `KeyboardSaveBar23UITests.test_iPad_amountKeyboardIsDockedNotFloatingOverTheSheet` se puede copiar: cuenta teclas
   «1» por encima del teclado acoplado).
2. Donde salga, pasar el campo a `.amountKeyboard()`, comprobando antes que filtra lo que se escribe (con el teclado
   de signos se puede escribir un «+» o una letra).
