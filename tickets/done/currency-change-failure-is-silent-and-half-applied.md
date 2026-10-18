---
id: currency-change-failure-is-silent-and-half-applied
status: backlog
priority: medium
area: "currency, fx, settings"
created: 2026-10-15
updated: 2026-10-15
source: "auditoría UX 2.2, lote 16 (Ajustes), PR #509"
---

# Si falla el cambio de divisa principal, nadie se entera y queda a medias

## Qué le pasa al usuario

Cambia su divisa principal en Ajustes › Divisa y cambio. Si la migración de registros falla, la pantalla vuelve
como si nada: la divisa sigue siendo la vieja, pero la que eligió ya no está entre sus secundarias, y parte de los
registros puede acabar guardada en la divisa nueva la próxima vez que otra pantalla guarde.

## Lo medido (lectura de código, árbol `0fc925cf8`)

- `CurrencySettingsView.updatePreferredCurrency` quita la divisa nueva de las secundarias ANTES de migrar
  (≈ líneas 379-383) y, si `CurrencyChangeService.updateAllTransactions` lanza, solo hace `print` en DEBUG
  (≈ 430-434). Sin aviso.
- `CurrencyChangeService.updateAllTransactions` muta todas las `TransactionItem` en el contexto y guarda al final;
  si `context.save()` lanza, los cambios siguen pendientes en el contexto y el siguiente guardado de cualquier
  pantalla los escribe con la preferencia todavía en la divisa vieja.
- La barra de progreso nunca pasa del 50 % (`updateProgress = progress * 0.5`).

No reproducido en el simulador: hace falta forzar el fallo del `save()`.

## Qué hacer

Deshacer los cambios del contexto si la migración falla (sin tirar cambios ajenos pendientes), quitar la secundaria
solo tras el éxito, y avisar con el motivo. Toca persistencia de cálculos financieros: **review adversarial**.
Hermano: `currency-change-asks-rates-for-the-old-currency`. La propuesta de confirmación previa es la card L16-3.

## Hecho cuando

- Un fallo forzado de la migración deja todos los registros y las secundarias como estaban, y la pantalla lo dice.
- Test con el `save()` fallando y mutante en rojo.
