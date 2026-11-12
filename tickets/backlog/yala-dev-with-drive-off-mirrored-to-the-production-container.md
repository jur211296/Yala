---
id: yala-dev-with-drive-off-mirrored-to-the-production-container
status: backlog
priority: low
area: "icloud, qa"
created: 2026-10-25
updated: 2026-10-25
source: "lote 12.2 (card n5zw): medido en los entitlements y en el código; el efecto en el contenedor, inferido"
---

# Con iCloud Drive apagado, `Yala Dev` espejaba contra el contenedor de PRODUCCIÓN

## Qué pasó

Hasta el 2026-10-25 el mount `.localNoMirror` (iCloud Drive apagado) usaba `cloudKitDatabase: .automatic`, que toma el
primer contenedor de los entitlements: `iCloud.com.jurgenschmidt.yala`, el de producción, también en `Yala Dev`. El
arreglo de la card n5zw nombra el contenedor. Lo que deja atrás, inferido:

- Mientras el iPhone de QA tuvo Drive apagado con `Yala Dev`, sus filas de prueba pudieron exportarse a la base privada de
  PRODUCCIÓN de ese Apple ID. Si ese Apple ID tiene la Yala de producción en otro teléfono, pueden aparecer allí.
- El primer arranque de un dispositivo `Yala Dev` con Drive apagado y este build cambia de contenedor una vez (vuelve al
  `.dev`) y puede repetir el «arranca vacía» mientras reimporta.

## Qué hacer

Mirar en el CloudKit Console (contenedor de producción, base privada del Apple ID de QA) si hay registros de esas fechas
(15 y 19-oct) y, si sobran, borrar la zona desde Ajustes › iCloud de ese Apple ID o desde el Console.
