---
id: convert-personal-expense-to-group-from-the-editor
status: done
priority: high
area: "grupos, registros"
created: 2026-11-09
updated: 2026-11-09
source: "pedido de Jürgen del 2026-11-07 (card del tablero «2.3 · Pasar una transacción personal a un grupo desde Editar en Registros»)"
---

# Convertir a gasto compartido desde Editar de un registro

## Qué cambia para la persona

Al editar un gasto personal guardado aparece «Convertir a gasto compartido». Se elige el grupo (si hay más de uno), se
revisa el gasto con el importe, la moneda, la fecha, la cuenta y «pagado por ti» fijos —son los del registro— y se
reparte. Al guardar, el editor se cierra con el aviso «Ahora es un gasto de «grupo»» y «Ver».

## Cómo funciona

El registro no se copia: pasa a ser la pata real del gasto que se crea, como el enlace «¿Ya lo apuntaste?» de la Bandeja
(L13-15). El puente lo conserva (cuenta, nota, etiquetas, necesidad y categoría intactas) y solo añade el «Préstamo a
grupos» de lo que te deben. Un solo guardado; si algo falla antes, `rollback()` deja todo como estaba (medido con un
guardado que falla).

## Decisiones

- Solo gastos personales (Jürgen, 2026-11-07). Fuera ingresos, transferencias, ajustes, lo que ya es de un grupo, cuenta
  archivada o de otra moneda que el registro, sesión sin finanzas personales.
- «Mi parte» se bloquea con explicación: su importe es solo tu parte y el puente lo reescribiría al total.
- Con cambios sin guardar en el editor se bloquea con explicación.
- Desde la conversión el registro ES el gasto del grupo: si el grupo lo borra, le cambia la moneda o el pagador, el
  registro sigue al gasto (lo dice la revisión). Es la semántica de L13-15.

## Hallazgos con ticket propio

- `deleting-a-scheduled-payment-deletes-group-legs-without-unbridging`
- `group-system-category-seed-saves-the-context-mid-bridge`
- `convert-to-group-fails-generically-with-an-income-homonym-category`

## Cobertura

Unit `PersonalToGroupConversionTests` (lógica + puente real) y XCUITest `PersonalToGroupConversionUITests`.
