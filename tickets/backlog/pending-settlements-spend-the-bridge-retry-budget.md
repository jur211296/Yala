---
id: pending-settlements-spend-the-bridge-retry-budget
status: backlog
priority: low
area: "groups, bridge"
created: 2026-11-12
updated: 2026-11-12
source: "review adversarial del encargo «saldar como en Splitwise» (decisión 37 de 2.3)"
---

# Un pago pendiente gasta los reintentos del puente y dispara `groupsPendingBridgeDropped`

Leído en el código por la review del 2026-11-12, sin medir: `GroupTransactionBridge.bridgeSettlement` mira
`isConfirmed` antes de la salida que da por atendido un pago entre otros, así que un pago pendiente cuenta como «no
atendido» en el teléfono de cada miembro. `GroupsPendingBridgeIntent` lo reintenta en cada arranque y a los tres lo
descarta con el canario `groupsPendingBridgeDropped`, y `arm` conserva los intentos gastados si después llega la
confirmación. Hasta la decisión 37 casi no había pagos pendientes; desde C1 son normales, así que el canario pierde
señal. La confirmación remota sí vuelve a lanzar el puente (`GroupsSyncClient.applySettlement`), así que no se pierde
el movimiento en el caso normal.

## Hecho cuando

Un pago pendiente no cuenta como intento fallido del puente (o reinicia el presupuesto al confirmarse), con test.
