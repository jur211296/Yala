---
id: adopt-window-user-edit-uploads-the-value-the-mirror-wrote-over-it
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial (lente de consumidores) de `adopt-window-late-imports-overwrite-newer-cloud-edits`, 2026-09-26"
---

# En la ventana del adopt, una edición mía que el espejo pisa después sube con el valor del espejo

## El problema, en lenguaje de usuario

Activo la nube en mi segundo iPhone. Antes de cerrar y volver a abrir la app, cambio el importe de un gasto a 9,00. Justo
después, iCloud termina de bajar una versión vieja de ese gasto con 4,00. Al reabrir, lo que sube a la nube es 4,00.

## Lo medido (2026-09-26, en el código) e inferido

- Medido: el drain construye cada cambio desde la fila VIVA (`CloudSyncEngine.appendUpsert(model:)`), no desde el valor de
  la transacción. El primer drain tras el remonte lee las dos transacciones a la vez: la del usuario (se traduce) y la del
  espejo (desde `adopt-window-late-imports-overwrite-newer-cloud-edits` no se traduce si la fila la conoce el backend).
- Medido: la del usuario emite solo las columnas que tocó, con el valor que dejó el espejo y un HLC fresco.
- Inferido, sin reproducir: que el orden «edición local y después import del espejo sobre la misma fila» pase en la práctica;
  exige editar justo esa fila en la ventana entre el paso 3 del adopt y el relanzamiento.

## Opciones, sin decidir

- Si en la misma vuelta del drain el espejo cambió después esa fila conocida, no traducir tampoco la edición local (manda
  el backend; la edición del usuario se pierde).
- O leer el valor de la columna en la transacción del usuario en vez de la fila viva (el History de SwiftData no lo expone
  hoy: habría que medirlo).

## Relación

- Surge de `adopt-window-late-imports-overwrite-newer-cloud-edits` (regla «Y lo que el espejo importa TARDE…», punto 4).
