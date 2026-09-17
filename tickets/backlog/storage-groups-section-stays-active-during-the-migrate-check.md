---
id: storage-groups-section-stays-active-during-the-migrate-check
status: backlog
priority: low
area: "modo-nube, settings, groups"
created: 2026-09-16
source: "segunda pasada de la review de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (lente de controller y vista, hallazgo 5), 2026-09-16"
---

# «Desasociar» sigue activo mientras «Activar la nube» comprueba la cuenta

## El problema, en lenguaje de usuario

Tengo mi cuenta de grupos asociada y la red va lenta. Toco «Activar la nube» y, mientras el botón gira, toco
«Desasociar» en la sección «Grupos», justo debajo. Sale su diálogo. Cuando la comprobación contesta, el consentimiento o
el aviso de la cuenta pueden no llegar a verse, y «Activar la nube» puede quedarse sin abrir nada hasta que salga de la
pantalla.

## Lo medido (2026-09-16, rama `encargo/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating`)

- Con la sesión de grupos viva, el toque lanza `CloudMigrationController.preflightMigrationIdentity`, que pone `isWorking`
  y pregunta a `/account/exists` antes de abrir el consentimiento (`showConsent = true` desde un `Task`).
- `GroupsAssociationSection` no recibe `isWorking`: sus botones («Asociar», «Desasociar» y sus diálogos) no se deshabilitan
  durante la comprobación. Las tarjetas de migrar, adoptar y volver a iCloud sí lo hacen (`isDisabled: controller.isWorking`).
- Inferido, sin medir en el simulador: la regla del productor asíncrono de `.claude/rules/swiftui-ds.md` dice que una
  presentación encendida desde un `Task` puede llegar con otra ya arriba en el mismo anchor.

**No es solo de este cambio**: la sección tampoco se deshabilitaba durante `startMigration`. La comprobación al toque
alarga la ventana con una llamada de red.

## Qué se espera

Deshabilitar las acciones de la sección mientras el controller trabaja, con el mismo `isWorking` que ya leen las tarjetas.

## Criterios de aceptación

- [ ] Mientras la comprobación de «Activar la nube» está en vuelo, «Asociar» y «Desasociar» no se pueden tocar.
- [ ] Al terminar, vuelven a estar activos sin salir de la pantalla.
