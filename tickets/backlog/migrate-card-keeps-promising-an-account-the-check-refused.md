---
id: migrate-card-keeps-promising-an-account-the-check-refused
status: backlog
priority: low
area: "modo-nube, settings, copy"
created: 2026-09-16
source: "segunda pasada de la review de `settings-migrate-to-cloud-adopts-silently-instead-of-migrating` (lente de controller y vista, hallazgo 6), 2026-09-16"
---

# Tras «Entendido», la tarjeta sigue prometiendo la cuenta que el aviso acaba de rechazar

## El problema, en lenguaje de usuario

Mi cuenta de grupos ya tiene finanzas personales. Toco «Activar la nube» y Yala me dice «Esa cuenta ya tiene finanzas
personales». Toco «Entendido» y la tarjeta sigue diciendo «Usarás tu cuenta de Yala actual, la de Google: así tus datos
y tus grupos viven en la misma cuenta», con el botón activo. Cada toque vuelve a preguntar a la red y a enseñar el mismo
aviso.

## Lo medido (2026-09-16, rama `encargo/2026-09-16-settings-migrate-to-cloud-adopts-silently-instead-of-migrating`)

- La nota sale de `StorageSettingsView.accountReuseNote` (`storage.migrate.accountReuseNote`) con cualquier sesión viva, y
  el botón solo se deshabilita con `controller.isWorking` o con el bloqueo del faro (`isBlockedOtherAccount`).
- Nada recuerda que la comprobación rechazó esa cuenta: `migrationIdentityBlock` se suelta al montar la hoja.

## Lo que hay que decidir (Jürgen, copy)

1. Recordar el `sub` rechazado mientras dure la sesión y, con él, apagar el botón y decir el motivo en la tarjeta (copy
   nuevo en 16 idiomas).
2. Dejarlo: el aviso vuelve a explicarlo en cada toque y no se escribe nada.

## Criterios de aceptación

- [ ] Tras un aviso de la comprobación con la sesión de grupos, la tarjeta no promete esa misma cuenta, o el caso se
      decide y se documenta como aceptado.
