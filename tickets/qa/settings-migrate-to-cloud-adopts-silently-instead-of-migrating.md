---
id: settings-migrate-to-cloud-adopts-silently-instead-of-migrating
status: backlog
priority: high
area: "modo-nube, settings"
created: 2026-09-10
source: "medido durante `cloud-sign-in-discovers-account-kind` (bloque [I], paso 3 del rediseño de sesiones)"
---

# «Migrar a la nube» sobre una cuenta que ya tiene datos no migra: adopta, y no lo dice

## El problema, en lenguaje de usuario

Tengo mis finanzas en este iPhone y quiero llevarlas a la nube. Voy a Ajustes → «¿Dónde viven tus
datos?» → «Migrar a la nube», acepto el consentimiento y **dos confirmaciones destructivas**, y entro
con mi cuenta de Google. Esa cuenta ya tenía datos de Yala en la nube (de otro móvil, o de un intento
anterior). Yala **no sube lo mío**: descarga lo que ya había y sigue como si nada. Mis meses de
histórico local se quedan donde estaban y nadie me avisa de que la migración que pedí no ocurrió.

## Lo medido (2026-09-10, árbol `8964c734`)

- La puerta **no consulta `GET /account/exists`** antes de nada: lo que decide es
  `StorageMigrationSignInLogic.decide` (`Yala/App/Logic/StorageMigrationSignInLogic.swift:64-77`), y sus
  inputs son **solo locales** — `hasSession`, el proveedor del Keychain y el hash del faro
  (`StorageSettingsView.swift:545-555`).
- El descubrimiento llega **después**, en el claim: `MigrationWorkExecutor.performClaim`
  (`:228-258`) recibe `existing_stable`, y `MigrationStateMachine` (`:618-621`) lo enruta a
  `.adoptBackendAccount` con el comentario «Already migrated & stable → returning-user. **NEVER
  re-migrate/re-seed**». Correcto para lo que esa máquina protege, y **no es lo que el usuario pidió**.
- `runAdoptFlow` (`MigrationWorkExecutor.swift:1145`) **no sube el corpus local**: hace quiescencia,
  orphan-reconcile, fast-forward del History y persiste el par `.cloud` + `mirrorOffArmed`.
- El copy solo cambia si el **mirror de CloudKit** ya trajo un `CloudMigrationMarker` de otro
  dispositivo del mismo Apple ID (`StorageSettingsView.swift:180`). Una cuenta poblada **por otra vía**
  —por ejemplo la cuenta de grupos que se promovió a completa— no dispara ese copy, porque
  `markerDecision()` mira una fila local del mirror, no el backend.
- El único bloqueo que existe hoy (`StorageMigrationSignInLogic.Decision.blockedOtherAccount`, `:43`)
  compara el hash del faro contra la sesión viva. **No mira el tipo de cuenta ni pregunta al backend.**

## Por qué no lo arregló el paso 3

El bloque [I] dejó las **tres celdas de esta puerta en la tabla** (`CloudIdentityRoutingLogic`, con
test), pero **sin cableado**, y por dos razones medidas: (1) el sign-in de esta puerta ocurre *dentro*
de `startMigration`, así que preguntar `exists` antes exige reordenar el flujo y tocar
`CloudMigrationController`, que el runbook del rediseño avisa que colisiona entre pasos; (2) la celda
«solo grupos → promover **mi asociada**» necesita saber cuál es la asociada, y esa identidad **no se
persiste hoy** (la puerta de Grupos solo escribe `groups.hadSessionEver`) — la trae el ticket 10.

## Lo que se espera

`Destination.blockedAccountIsComplete` y `.promoteAssociatedAccountThenCutover` ya existen y ya están
probados: lo que falta es que esta puerta **pregunte antes de cobrar dos confirmaciones destructivas**
y presente el bloqueo con sus dos salidas en vez de adoptar en silencio.

## Criterios de aceptación

- [ ] La puerta consulta `CloudIdentityDiscovery` **antes** de las confirmaciones destructivas, no después.
- [ ] Cuenta destino `complete` → bloqueo con sus dos salidas; **cero escrituras** y cero claim.
- [ ] Cuenta destino `groups_only` que ES la asociada → promoción + cutover (necesita el ticket 10).
- [ ] Cuenta destino `groups_only` que NO es la asociada → «una cuenta a la vez».
- [ ] Cuenta nueva → el cutover de hoy, sin cambios.
- [ ] Los tests de `StorageMigrationSignInLogic` y de la máquina de migración siguen verdes.

## Depende de

`groups-account-association-in-storage-row` (paso 10) para la celda de la promoción.
