---
id: migrate-card-keeps-promising-an-account-the-check-refused
status: done
priority: low
area: "modo-nube, settings, copy"
created: 2026-09-16
updated: 2026-10-06
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

- [x] Tras un aviso de la comprobación con la sesión de grupos, la tarjeta no promete esa misma cuenta, o el caso se
      decide y se documenta como aceptado.

## Decisión (Jürgen, 2026-10-04)

Opción 1 (la «A» del centro de mando): recordar el rechazo mientras dure esa sesión, apagar el botón y decir el motivo
en la tarjeta.

## Parte (2026-10-06)

**Re-medido sobre `origin/2.1` (7d78e3054)**: el bug seguía tal cual (captura del antes con
`-uitest-fake-cloud-session -uitest-fake-migration-identity personalData`: tras «Entendido», «Usarás tu cuenta de Yala
actual…» y «Activar la nube» activo).

**Qué cambia para la persona.** Tras el aviso de la comprobación con la sesión de sus grupos, la tarjeta «Migrar a la
nube» ya no promete esa cuenta: en su lugar dice el motivo y la salida (una nota por cada uno de los cuatro avisos de la
hoja), y «Activar la nube» queda apagado. Si cambia la cuenta o la sesión —desasociar en «Grupos», cerrar y volver a
entrar—, o si se relanza Yala, la tarjeta vuelve a lo de siempre y el toque vuelve a preguntar.

**Cómo.**
- `StorageMigrationIdentityGateLogic`: `LiveSession`, `RefusedSession`, `refusalToRemember` y `cardRefusal` (puras).
- `CloudAuthService.sessionEpoch`: contador en memoria que sube en los dos canjes (Apple, Google) y en `signOut()`.
- `CloudMigrationController`: recuerda el rechazo en `publishBlock` —el único que publica avisos de la hoja, de la
  comprobación o del claim— solo si queda sesión viva; guarda una copia observable de la sesión (`liveSession`) que
  renuevan `refresh()` y cada aviso, porque `CloudAuthService` no es observable; la tarjeta lee `liveSessionRefusal`.
- `StorageSettingsView`: nota `storage_account_refused_note` en lugar de la promesa, y botón apagado solo cuando
  reusaría esa sesión. El adopt no lo lee.
- Copy: `storage.migrate.refused{PersonalData,OtherGroups,Returned,FreshStart}` en los 16 locales (es-AR voseo, es-ES
  perfecto, `es` = `es-419` y `pt` = `pt-BR` byte a byte).

**Pruebas.** Unit de la lógica (por motivo, sin sesión, otra cuenta/otra época/sin sub/sin sesión), source-scan del
cableado (escritor único, lector, copia en `refresh()`, época en los tres sitios, tarjeta) y el XCUITest
`StorageMigrationIdentityBlockUITests#test_liveSession_accountWithPersonalData_blocksBeforeTheConsent` ampliado: tras
«Entendido», la nota del motivo, sin la promesa y con el botón apagado.

**Mutantes: 12/12 muertos, cada uno en su aserción.** Seis de source-scan (no recordar, `signOut` sin época, `refresh()`
sin copia, Google sin época, botón sin apagar, el adopt leyendo el rechazo) y seis compilados (la lógica sin época, sin
`sub` y recordando sin sesión, por unit; no recordar, botón activo y seguir prometiendo, por el XCUITest).

**Medido en el simulador** (`-uitest-fake-cloud-session -uitest-fake-migration-identity personalData`): tras
«Entendido», la nota del motivo y el botón apagado; tras «Desasociar → Conservar los gastos que pagué», la tarjeta vuelve
sola a «Usarás tu cuenta de Yala actual…» con el botón activo, sin salir de la pantalla.

**Review adversarial (1 lente, refutación por hallazgo).** Cazó dos cosas que se arreglaron: (1) la época entre
`authSignedIn()` y `AdoptSessionOwnership.record(nil)` rompía `AdoptSessionOwnershipTests`; (2) `CloudAuthService` no es
observable y el tick de 1 s de la pantalla no se lee en el body, así que desasociar dejaba el botón apagado hasta salir
y volver — de ahí la copia observable `liveSession`.

**Residuales aceptados.**
- El rechazo se ata a la sesión viva al publicar el aviso, no a la que se comprobó: si en los segundos de la consulta
  de red la persona desasocia y entra con OTRA cuenta, el rechazo de la primera se aplicaría a la segunda hasta cambiar
  de sesión o relanzar. Pide cambiar de cuenta en otra pestaña durante una consulta de red en curso.
- La nota usa `DS.Semantic.warningForeground` como texto, igual que la nota de «otra cuenta» de al lado; ese color
  sobre la tarjeta clara no llega a AA (lo dice el propio fichero en la tarjeta de vuelta). Es el patrón existente, no se
  tocó aquí.
