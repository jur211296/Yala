---
id: barrido-bugs-lote-b
status: done
priority: very-high
area: "modo-nube, icloud, cierre-de-sesion, documentacion"
created: 2026-11-14
updated: 2026-11-14
source: "barrido de QA en el iPhone 14 (14-nov), cards zy1d, atde, 4lld, p9q0 y f8pd"
---

# iCloud y cerrar sesión: iCloud vaciado, «Volver a tu iCloud» colgado, copia al iCloud privado y vista de cerrar sesión

## Qué pasaba (para quien usa Yala)

1. **(zy1d)** Con el iCloud recién vaciado, «Ya tienes datos — 62 categorías»; y al restaurar datos creados solo en
   iCloud, la nota «Esta copia de iCloud es de antes de que pasaras tus datos a tu cuenta de Yala».
2. **(atde)** «Volver a tu iCloud» se quedaba en «Traer tus datos de tu cuenta de Yala» más de 6 minutos, sin cifra y
   con «Cancelar» apagado, también tras reabrir.
3. **(4lld)** Parecía que una cuenta en la nube copiaba sus datos al iCloud privado del teléfono («Tu iCloud ya tiene
   2351 registros», la misma cifra que los datos de prueba).
4. **(p9q0)** Cerrar sesión en la nube terminaba en «Ya casi está · Vuelve a abrir Yala» en 2 de 2 intentos.
5. **(f8pd)** El índice de la revisión por vistas 2.3 decía «3 de 11 zonas revisadas».

## Causas

- **1 y 2:** las arregla el PR del 13-nov «Volver a tu iCloud sin quedarse trabado» (subida por tandas de 50 con cifra,
  «Cancelar» activo, la puerta ya no cuenta las categorías de serie). Estaba abierto con todo en verde y nunca se mergeó:
  chocaba solo en dos documentos. El barrido probó una build sin él. Este lote lo trae entero.
- **1, la nota:** el faro del iCloud-KV sobrevive y la nota solo miraba el faro. Ahora tampoco sale si algún movimiento de
  la copia es posterior a la fecha de enlace del faro (`CloudBeacon.linkedAt`).
- **3, no era una copia (medido):** «Cargar datos de prueba» usa una semilla fija (42), así que da los mismos 2.351
  registros en cualquier modo el mismo día. En el iPhone: cuenta recién creada y vacía → iCloud ya tenía 2.359; tras cargar
  2.351 en la cuenta y esperar, iCloud seguía en 2.359. Cero eventos del espejo en la consola y cero tablas del espejo en
  el archivo del almacén. Sin código.
- **4, dos causas, una medida:** (a) **medida en el iPhone**: el cambio de almacén en caliente sí se consumaba
  (`CloudSignOut swap COMPLETED`), pero la pantalla «Ya casi está» se armaba en el árbol viejo justo antes del cambio y
  UIKit la dejaba presentada, huérfana, encima de la bienvenida nueva. (b) **leída en el código**: con las notificaciones
  permitidas, el chequeo de avisos del arranque entrega el contexto del almacén a los avisos de Grupos (recordatorio de
  deudas y tope de gasto) y el cambio no los soltaba: el almacén seguía vivo y el cambio abortaba.

## Arreglo

- La pantalla de reabrir no se arma mientras el cambio en caliente está en vuelo; si el cambio termina sin consumarse, se
  arma en el árbol que quedó (`SignOutRelaunchNetModifier`). «Empezar de cero» en la nube desde la bienvenida enciende el
  testigo con la fase.
- `releaseModelContextsForSwap` suelta los dos avisos de Grupos, y un test de paridad exige que todo servicio que recibe el
  contexto lo suelte.
- La nota de la copia antigua mira la fecha del enlace.
- Los breadcrumbs del cambio en caliente se imprimen también en DEBUG: así se leyó la causa en el iPhone.
- `docs/ux/revision-vistas-2.3/README.md`: 11 de 11 zonas, decisiones cruzadas con `decisiones-discusion.md`.

## Probado en el iPhone 14 (14-nov, Yala Dev de esta rama, cuenta test@)

- p9q0: antes (misma build sin el arreglo del cover) «swap COMPLETED» y «Ya casi está»; después, con notificaciones
  permitidas, «Cerrando sesión…» → bienvenida sin reabrir. Eliminar la cuenta: «Eliminando tu cuenta…» → «Tu cuenta se ha
  eliminado» → «Continuar» → bienvenida. Con iCloud privado sí pide reabrir y lo explica.
- atde: con 3.195 cambios en cola, «Traer tus datos» con barra y «X de Y» y «Cancelar» activo; cerrar Yala a mitad y
  reabrir siguió con lo pendiente (200 de 2.645); completó hasta «En tu iCloud». La salida por «Cancelar» no se probó en el
  teléfono (la cubren los tests del PR del 13-nov).
- 4lld: la medición de arriba.
- zy1d: restaurar una copia con movimientos posteriores al enlace, sin la nota. «Revisando qué hay en tu iCloud…» tardó
  28,6 s con ~2.400 registros (no se tocó la sonda; queda en `private-icloud-gate-takes-almost-a-minute-to-check`).

## Tests

`YalaTests/BarridoBugsLoteB/` (paridad de contextos del cambio en caliente, cover que espera al cambio, nota con fecha de
enlace) y el scan ajustado de `RestoreLoteN3Tests`. Mutantes: quitar cualquiera de los tres arreglos pone en rojo su test.
