---
name: campo-de-icloud-pendiente-frena-la-subida
description: Antes de archivar una build de TestFlight, mirar pendingProductionDeploy y el esquema vivo de Producción con cktool (hay token en la Mini); un campo sin desplegar para la subida y es decisión de Dan y Jürgen.
metadata:
  type: reference
---

Medido el 2026-11-25 (build 9 de 2.3, Mini): la build escribía `CD_InboxDraft.CD_joinRecordRaw` y Producción no lo
tenía. Lo vi tarde, después del barrido, al leer `scripts/asc-preflight.sh`.

- **Mira primero** `PersonalCloudKitSchemaParityTests.pendingProductionDeploy`: si no está vacío, la subida se para
  (el preflight lo frena y en TestFlight la cuenta dejaría de sincronizar sin aviso).
- **El esquema vivo se lee en la Mini** con `xcrun cktool export-schema --team-id 3WKFFVD66J --container-id
  iCloud.com.jurgenschmidt.yala --environment production --output-file <scratchpad>` (el token de gestión ya está
  guardado; `cktool get-teams` lo confirma). La lista del test puede ir por detrás del despliegue real.
- **Desplegar a Producción no es mío**: CloudKit Console (cktool no despliega a Producción), Dan con el OK de Jürgen.
  En nocturno: checkpoint y card «Espera decisión».

**How to apply:** en cualquier encargo de subida, este chequeo va en el Paso 0, antes del barrido, para que la card
salga a primera hora y no al final. Relacionado: [[upload-ok-no-es-build-aceptado]].
