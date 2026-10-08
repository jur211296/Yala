---
id: account-form-redesign
status: backlog
priority: medium
area: "accounts, ui"
created: 2026-10-03
updated: 2026-10-08
source: diseño aprobado por Jürgen el 2026-10-03 (lienzo «Cuentas del Panel — propuestas», página «Rediseño de cuentas», pantallas 5 y 8)
---

# Formulario de cuenta: vista previa, color de vuelta y editar el saldo bien explicado

## La idea

Tercera entrega del rediseño de cuentas, **después** de `account-form-as-medium-detent-sheet` (PR #341). Diseño: https://claude.ai/artifact/LvWp7bj43PJY1S2Rin9Cu3

- Arriba, **vista previa en vivo** de la tarjeta («Así se verá en el Panel»).
- Nombre, **saldo de hoy** y moneda primero; el **tipo** con iconos; el **color** con muestras.
- «Más opciones» plegado: número de cuenta, excluir de estadísticas, día de pago de tarjeta.
- Archivar y eliminar al fondo, solo al editar.
- **Editar el saldo** (pantalla 8), que Jürgen pidió «clara, bien explicada y fácil»: «Según Yala» tachado,
  «¿Cuánto tienes de verdad hoy?», la diferencia calculada, y «¿Cómo lo corregimos?» con las dos opciones de hoy
  (`AdjustmentMode`: ajustar por registro / cambiar saldo inicial) contadas en llano, con cuándo usar cada una y
  la fecha del movimiento; abajo «Al guardar, X queda en S/ Y».

## Medido el 2026-10-03

- **El formulario no deja elegir color.** `colorSection` existe en `AccountFormView.swift` pero el `body` no la
  monta: toda cuenta nueva sale con `AppConstants.defaultColorHex`. El icono tampoco se elige: sale del tipo al
  guardar (`AccountFormViewModel.swift:636`).
- «Balance inicial» (`account.initialBalance`) es el saldo de hoy al crear; el nombre confunde.

## Medido en 2.1 (triage 2026-10-08)

- `colorSection` sigue definida y sin montar: su única aparición es la declaración (`Yala/App/Views/Accounts/AccountFormView.swift:669`). No hay vista previa de la tarjeta ni «Más opciones».
- Desde el 03-oct el formulario solo cambió por `b8a371f9d` (archivar excluye) y `4ec6f0c5e` (PR #400, divisas): ninguno es esta entrega.

Triage 2026-10-08: abierto · medium → medium · ninguna pieza de la tercera entrega está hecha y el color sigue sin poder elegirse (colorSection sin montar, AccountFormView.swift:669).
