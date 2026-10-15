---
id: records-orphaned-by-earlier-account-deletions-stay-invisible
status: backlog
priority: medium
area: "accounts, transactions, data-repair"
created: 2026-10-15
updated: 2026-10-15
source: encargo tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst (medido en simulador)
---

# Los movimientos que ya se quedaron sin cuenta por un borrado anterior siguen ahí, sin contar y sin salida

## Qué le pasa al usuario

Hasta la 2.1 de este encargo, eliminar una cuenta dejaba sus movimientos sin cuenta (`Account.transactions` es
`.nullify`). El arreglo impide que pase más, pero **no repara lo que ya pasó**: en el iPhone de QA de Jürgen siguen
Taxi 25 y Teléfono 33 de «Efectivo QA».

## Lo medido (2026-10-15, simulador iPhone 17 Pro, seed `cuenta-con-movimientos`, build anterior al arreglo)

Tras eliminar «Efectivo QA» (dos gastos, −58):

- El Panel pasó de **S/ 942** a **S/ 1.000**: los 58 desaparecieron del saldo y de «Gastos» (S/ 0,00).
- Estadísticas › Resumen dice «1 movimiento»; Estadísticas › Registros lista los tres, con el resumen «Gasto S/ 0,00».
- Las dos filas salen sin nombre de cuenta. Captura: `capturas/antes-2.png` del PR del encargo.

## Qué falta decidir

Si la app ofrece reasignar esos movimientos (p. ej. un aviso en Registros: «N movimientos sin cuenta»), los deja
como están, o los trata como gastos fuera de cuenta. Es decisión de producto: no se tocó.
