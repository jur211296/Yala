---
id: late-remote-wipe-cut-keeps-what-it-cannot-date-until-the-mirror-decides
status: backlog
priority: low
area: "sync, settings"
created: 2026-09-28
source: "encargo y review adversarial de `late-remote-wipe-signal-also-wipes-rows-created-after-it` (2026-09-28); medido leyendo código, NO reproducido"
---

# El corte del vaciado tardío conserva lo que no puede fechar, y lo retira el espejo

## Qué pasa

`Account`, `Category`, `Subcategory` y `ExchangeRate` no tienen fecha de creación. El receptor tardío los decide por uso
(`RemoteWipeCutLogic.takesUndated`), y lo que no usa nadie se queda si el parque ya empezó de nuevo (marca del KV o una
fila personal posterior a la señal). Ahí caben la semilla nueva del origen —lo que se quiere conservar— y las categorías
y cuentas viejas sin uso, que el receptor no puede distinguir. Esas las retira el espejo cuando trae los borrados del
origen. Cuatro casos en los que no:

- **Filas que el origen nunca tuvo** (creadas en el receptor sin red antes del vaciado y nunca exportadas): no hay
  borrado que traer. Se quedan y resucitan en el origen.
- **Reloj desfasado**: la señal lleva la hora del origen y las filas la de quien las creó. Una fila creada segundos
  después en un dispositivo con el reloj atrasado se trata como anterior.
- **Relación sin hidratar**: si el espejo trae una fila nueva antes que su cuenta, o sin la referencia resuelta, la cuenta
  no cuenta como usada (el presupuesto sí se mira por su CSV).
- **`MerchantMemory.lastApprovedAt` no es de creación**: una memoria vieja reaprobada después de la señal se queda.

## Qué hay que decidir

Si merece un campo de creación en esos cuatro modelos (migración SwiftData + schema de CloudKit desplegado a
Production, y las filas de builds viejos seguirían sin él) o aceptar el residual.

## Relacionados

- [[late-remote-wipe-signal-also-wipes-rows-created-after-it]]
- [[late-remote-wipe-survivors-can-point-at-rows-the-origin-deleted]]
