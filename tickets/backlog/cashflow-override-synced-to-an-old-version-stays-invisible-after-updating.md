---
id: cashflow-override-synced-to-an-old-version-stays-invisible-after-updating
status: backlog
priority: low
area: "cloudkit, sync, cashflow"
created: 2026-10-16
updated: 2026-10-16
source: residual de personal-cloudkit-cashflow-override-line-declared-as-reference (2026-10-16)
---

# Un ajuste de un mes que llega a un teléfono con versión vieja no se ve al actualizarlo

## Qué le puede pasar al usuario

Tiene dos iPhone. Actualiza Yala en el A antes que en el B. Los ajustes de un mes del flujo de caja del A
viajan ahora por el campo nuevo de iCloud (`CD_cashFlowLine`). El B, con la versión vieja, recibe el ajuste pero
no conoce ese campo: lo guarda sin línea y no lo enseña. Al actualizar el B, el ajuste **sigue sin verse** ahí
hasta que alguien lo edite en el A.

## Lo que se sabe y lo que no

- Medido: la versión vieja no borra un ajuste sin línea (2.0.4 no tiene ningún borrado de huérfanos salvo el
  wipe de 1.2.7, ya consumido), así que no se pierde nada: el ajuste sigue en el A y en iCloud.
- **Inferido, sin medir:** que el espejo de SwiftData no vuelve a bajar un registro que ya bajó cuando el modelo
  gana un campo. Si lo re-bajara, este ticket no existe.
- Solo afecta a ajustes que viajaron mientras el otro teléfono seguía en la versión vieja. Antes del cambio no
  viajaba ninguno en Production (el campo viejo los rechazaba).

## Cómo medirlo

Dos iPhone con el mismo Apple ID, el esquema ya desplegado (`docs/cloudkit-schema-diff-2.1.md`, «El campo nuevo de
los ajustes del flujo de caja»): A con la build nueva, B con la de la App Store. Ajusta un mes en A, espera, actualiza
B y abre Flujo de caja. Si el ajuste aparece, cerrar como no reproducible.

## Si se confirma

El ajuste huérfano del B tiene registro en iCloud con `CD_cashFlowLine` puesto. Opciones: forzar en el A una
reescritura de sus ajustes en el primer arranque tras una fecha (barato, idempotente) o leer el registro de iCloud
del huérfano en el B. Decide Jürgen.
