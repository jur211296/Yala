---
id: 2026-11-19-pago-planificado-logo-propio-foto
status: done
priority: high
area: planning
created: 2026-11-19
updated: 2026-11-20
source: Jürgen, 19-nov 21:28 (encargo 2026-11-20-pago-planificado-logo-propio-foto)
---
# Pagos planificados: logo propio con una foto, sincronizado en iCloud y Modo Nube

Hoy un pago planificado solo lleva un logo del banco de comercios. Si el comercio no está (colegio, alquiler, gimnasio,
una tienda del barrio), queda el icono de la categoría. Jürgen quiere que la persona pueda poner su propio logo con una
foto, y que viaje a sus otros teléfonos por iCloud y por el Modo Nube.

Las decisiones de diseño están en el Paso 0 del encargo (`encargos/lanzados/2026-11-20-pago-planificado-logo-propio-foto.md`).

## Hecho (2026-11-20)

- **Qué cambia para quien usa la app.** En el editor de un pago planificado, la fila «Logo» sale en todo pago personal
  (antes solo si el nombre casaba con una marca). El selector tiene arriba «Tu propio logo» → «Usar una foto» (galería).
  La foto se recorta al cuadrado del centro, se guarda en 256 × 256 px JPEG y se pinta en círculo donde ya salía el logo
  del pago: lista, línea de tiempo, calendario, editor y selector. Con la foto puesta, la fila dice «Tu foto» y el
  selector la marca con «Cambiar» al lado; elegir «Automático», «Sin logo» o una marca la quita.
- **iCloud.** `ScheduledPayment.customLogoData` (`.externalStorage`) y `customLogoRef`: tres campos nuevos en
  `CD_ScheduledPayment` (`CD_customLogoData` Bytes, `CD_customLogoData_ckAsset` Asset, `CD_customLogoRef` String), en
  los cuatro `.ckdb`. Su paso a Production lo hace Jürgen en la consola (`docs/despliegue-cloudkit-2-2.md`, sección del
  2026-11-20).
- **Modo Nube.** Columna `scheduled_payments.custom_logo_ref` (`since: 7`, manifest v7) + bucket privado
  `scheduled-payment-logos` con 4 políticas por carpeta (`qa/cloud/g32_01_*`). `PagoLogoPropioSync` sube, baja y borra
  las fotos en el ciclo del motor; eliminar la cuenta vacía la carpeta antes.
- **Desplegado** en staging y producción (migración g32_01 + Worker v7 sobre el código que ya corría). Sonda
  `qa/cloud/g32_01-staging-probe.sh`: 26/26.
- **Pruebas.** `YalaTests/PagoLogoPropio/` (lógica, guardado, pintado, emisión/aplicación v6-v7, ida y vuelta entre
  dos teléfonos, subida de versión, pasada de Storage con un Storage de mentira, borrado de cuenta), el XCUITest
  `PagoLogoPropioUITests` (galería real, oscuro y claro) y los del gateway.

## Pendiente

- **Antes de cualquier TestFlight de 2.3: los tres campos de `CD_ScheduledPayment` en CloudKit Production** (Jürgen, en la
  consola; pasos en `docs/despliegue-cloudkit-2-2.md`, sección «Añadido el 2026-11-20»). Sin ellos, todo pago con foto se
  rechaza en iCloud sin avisar y deja de sincronizar también sus otros cambios.
- Device-QA en dos iPhone con iCloud (la foto viaja como asset) y en dos con Modo Nube contra producción: los pasos están
  en la guía de CloudKit y en el PR.

## Guion de device-QA (iPhone 14 + otro aparato de la misma cuenta)

1. **iCloud** (tras desplegar los campos en Production): en el iPhone A, Planificación → Pagos planificados → un pago sin
   logo (p. ej. «Colegio») → Editar → «Logo» → «Usar una foto» → elige una → Guardar. Esperado: la foto en círculo en la
   lista. En el aparato B, al rato: la misma foto en ese pago.
2. Con la app cerrada en B, cambia la foto en A («Cambiar»). Esperado: al abrir B, la foto nueva.
3. En A, «Logo» → «Sin logo» → Guardar. Esperado: en B vuelve el icono de la categoría.
4. **Modo Nube** (dos aparatos en la misma cuenta de Yala): repetir 1-3. Esperado: lo mismo; sin conexión en A, elegir la
   foto la enseña al momento en A y llega a B cuando A vuelve a tener red.
5. Un aparato con 2.2 en la misma cuenta: el pago con foto se ve con su icono por defecto; editar su importe ahí no quita
   la foto en A.

Cerrado en el barrido de QA 2026-11-23 (antes de la build 7): caso 4 de la tabla del barrido; XCUITest y sync con test Evidencia: `PagoLogoPropioUITests`, `PagoLogoPropioSyncTests`
