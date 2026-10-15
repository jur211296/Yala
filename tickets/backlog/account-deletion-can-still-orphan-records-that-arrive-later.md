---
id: account-deletion-can-still-orphan-records-that-arrive-later
status: backlog
priority: low
area: "accounts, sync, cloudkit, modo-nube"
created: 2026-10-15
updated: 2026-10-15
source: review adversarial del encargo tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst (lente datos/sync, inferido)
---

# Eliminar una cuenta puede dejar sin cuenta movimientos que llegan después

## Qué le pasa al usuario

Desde la 2.1, eliminar una cuenta con movimientos pregunta si moverlos o borrarlos. La pregunta se basa en lo que **ya
está en este teléfono**. Dos casos se escapan:

1. **Importación de iCloud a medias** (reinstalación, teléfono nuevo): la cuenta llegó y sus movimientos todavía no. La
   app la ve vacía, la elimina sin preguntar, y los movimientos que llegan después quedan sin cuenta.
2. **Otro dispositivo escribe a la vez**: el iPad apunta un gasto en la cuenta antes de recibir el borrado. Ese gasto
   queda sin cuenta en los dos dispositivos (iCloud y Modo Nube).

## Lo medido / inferido

Inferido del código (`AccountRemovalService.inventory` lee solo el store local; no hay espera de importación asentada).
Sin reproducir: pide dos dispositivos o una restauración real.

## Por qué no se cerró en el encargo

Esperar a una importación asentada (`hasCompletedFirstImport`) puede no abrirse nunca en algunos escenarios
(`ICloudRestoreInProgressLogic`, «es una ventana, no un interruptor»), y bloquear el borrado ahí dejaría a la persona sin
poder eliminar. El arreglo natural va con `records-orphaned-by-earlier-account-deletions-stay-invisible`: dar salida a
los movimientos sin cuenta, vengan de donde vengan.
