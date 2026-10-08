---
id: forward-identity-capture-advances-when-it-could-not-read-any-row
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-26
updated: 2026-10-08
source: "review adversarial de `reverse-upload-sample-reads-unreadable-rows-as-drained` (2026-09-26, lente de consumidores)"
---

# Al pasar a la nube, la captura de identidad sigue adelante aunque no pudo leer ninguna fila del espejo

## El problema, en lenguaje de usuario

Activo la nube desde un teléfono que tenía los datos en iCloud. Si Yala no consigue leer lo que iCloud sabe de mis
datos, la activación sigue igual, sin apuntar dónde vive cada dato en iCloud. Más tarde, eso puede hacer que un borrado
no viaje bien o que el aviso de «tus datos tienen que llegar a iCloud» se salte cuando no debería.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

Desde `reverse-upload-sample-reads-unreadable-rows-as-drained`, `CKIdentityCapture.Report.structuralFailure` dice cuándo
la captura no miró NINGUNA fila (el SQLite no abre, faltan las tablas del espejo…). La vuelta a iCloud ya lo usa. La IDA
no lo mira:

- `MigrationWorkExecutor.assignIdentity` (paso 3) captura, guarda y sigue: con el estructural, cero coordenadas y la
  fase avanza.
- `pinAdoptedIdentities` tampoco lo lee.

Consecuencias inferidas por la review:

- `RelayIdentityLedger` y la traducción de borrados de filas re-identificadas (#244) necesitan esas coordenadas.
- `probeICloudChannel` lee la huella de `SyncIdentity.ckRecordName != nil`. Sin coordenadas puede salir `false`, y sin
  cuenta de iCloud eso da `.noChannelNoFootprint`, que quita la espera del marcador sin haber mirado.

Solo muerde en la PRIMERA captura: las coordenadas ya persistidas no se borran.

## Qué hay que decidir

1. ¿Un estructural en `assignIdentity` es `.localFailure` (techo corto de la ida, «este dispositivo no pudo preparar
   tus datos»)? Es lo que ya hace un inventario ilegible en ese mismo paso.
2. ¿`pinAdoptedIdentities` debe parar o solo dejar rastro?

## Criterios de aceptación

- [ ] Decidido qué hace la ida con un estructural.
- [ ] Test con control y mutante.

## Relacionado

- `reverse-upload-sample-reads-unreadable-rows-as-drained`.
- `an-incomplete-inventory-reads-as-the-whole-corpus`: el mismo paso, con el inventario.

## Medido en 2.1 (triage 2026-10-08)

- `MigrationWorkExecutor.assignIdentity` sigue sin leer `report.structuralFailure`: captura, guarda, siembra el registro y emite el breadcrumb. El único consumidor del campo es `reverseUploadStatus` (devuelve `.unreadable`).
- `pinAdoptedIdentities` tampoco lo mira: siembra y marca el adopt igual.
- Los dos commits posteriores sobre el fichero (`84c3c3b3e`, `73a16599b`) no tocan este paso.
- Recomendación para la decisión 1: tratarlo como `.localFailure`, igual que un inventario ilegible en el mismo paso; para la 2, solo rastro (el adopt ya es best-effort).

Triage 2026-10-08: abierto · low → low · assignIdentity y pinAdoptedIdentities siguen ignorando structuralFailure, pero hace falta que el SQLite del espejo no abra en la primera captura.
