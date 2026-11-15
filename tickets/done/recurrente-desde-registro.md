---
id: recurrente-desde-registro
status: done
priority: medium
area: "scheduled-payments, records, inbox"
created: 2026-11-15
updated: 2026-11-15
source: "encargo de Jürgen del 15-nov (ejemplo real: el correo de Cloudflare aprobado desde la Bandeja)"
---

# Crear un recurrente a partir de un registro

Un gasto que ya es recurrente (Cloudflare) llegaba a la Bandeja y se aprobaba, pero convertirlo en recurrente exigía
entrar a Editar o crear el pago de cero. Ahora hay tres entradas al mismo editor de recurrentes, prellenado con el
registro, y el registro queda como el primer pago (pagado) del recurrente sin duplicar el gasto.

## Qué hace

- **Registros**: «Hacer recurrente» en el menú del registro (pulsación larga / clic secundario) y «Recurrente» al pie
  del detalle, junto a Duplicar y Eliminar. VoiceOver lo lee «Hacer recurrente».
- **Bandeja**: «Guardar y hacer recurrente» bajo «Guardar» en la hoja del borrador. Aprueba por el camino de siempre y
  la hoja pasa al editor. No sale si el borrador ya viene de un recurrente, una suscripción o un grupo.
- **Planificación › Pagos**: «Desde un registro», junto a «Nuevo pago planificado», abre los registros de los últimos
  6 meses con buscador.
- **Sin duplicados**: con un recurrente parecido (misma moneda y tipo, monto ±15 %, mismo comercio; sin nombre, la misma
  subcategoría) se ofrece «Vincular a «…»» o «Crear otro recurrente».
- **Registros de grupo, transferencias, ajustes y los ya vinculados**: la acción no se ofrece.

Decisiones: `## Paso 0` del encargo (viaja en el PR). Código: `Yala/App/Logic/RecurringFromRecord/`,
`Yala/App/Views/Planning/PagosRecurrentes/RecurringFromRecordSheet.swift`.

## Pruebas

- Unit: `YalaTests/RecurrenteDesdeRegistro/RecurrenteDesdeRegistroTests.swift` (lógica, vínculo sobre almacén en disco
  y cableado de las tres entradas). Mutantes: quitar el salto de los vencimientos pasados y quitar el archivo del
  borrador cubierto tumban 3 casos.
- XCUITest: `YalaUITests/Flows/RecurrenteDesdeRegistroUITests.swift` (detalle, menú, Bandeja y Planificación).

Probado de punta a punta en el simulador (las cuatro entradas). El device-QA en el iPhone 14 queda como guion en el PR.
