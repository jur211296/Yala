---
id: 2026-11-20-captura-cuenta-automatica-y-reglas-parte-2
status: done
priority: medium
area: "captura, cuentas, reglas, sync, ia"
created: 2026-11-20
updated: 2026-11-22
source: "tickets/done/2026-11-20-captura-cuenta-automatica-y-reglas.md (parte 2)"
---

## Hecho (encargo 2026-11-21-cuenta-sola-al-leer-parte-2-reglas)

- **Las reglas viven en la cuenta**, no en un modelo propio: `Account.captureRulesRaw` (JSON de `AccountCaptureRule`).
  Motivo: el canal de la Nube de Yala solo sabe versionar columnas; una entidad nueva habría sido la primera tras el
  lanzamiento. Así mueren con su cuenta y con «Vaciar mis datos», y exportar/importar no las lleva (como el número de
  cuenta). CloudKit `CD_captureRulesRaw` (los cuatro `.ckdb`); Nube `accounts.capture_rules_raw`, manifest v9, con apunte y
  reemisión al subir de versión (molde v7). Coste aceptado: dos aparatos que editan las reglas de la misma cuenta a la vez,
  gana el último.
- **Escalera**: paso 1 `CuentaSolaAlLeerReglas` (tarjeta de Apple Pay › comercio › juntas › varias › una; empate hacia
  cuentas distintas → `choqueReglas`, el selector enseña cada cuenta con su regla). Una regla gana también a la IA. La
  usan foto, Apple Pay (tarjeta y comercio), avisos del banco (comercio), voz, Siri y chat (comercio aunque no se nombre
  el medio de pago).
- **Vista**: «Reglas de captura» en Editar cuenta (fila por regla, «Añadir regla», pie), editor «Nueva regla» con vista
  previa, «Recordar» al corregir la cuenta en la hoja de la foto y «Ya tienes esta regla para X. ¿La paso a Y?». Textos en
  `CuentaSolaAlLeer.strings` (16 idiomas).
- **IA (capa B)**: foto con nombres y reglas en la nube o, en iCloud privado, con el permiso de voz y foto v1
  (`AIConsentRevision.processing`, texto nuevo en los 16 idiomas; se vuelve a pedir una vez). Chat con nombres siempre y
  reglas en la nube; `text.parse` devuelve `account`.
- **Servidor**: `g34_01` aplicada en Supabase staging; Worker de staging con manifest v9 y `account` en `text.parse`;
  Worker de producción con los campos de IA de las partes 1 y 2 sobre su manifest v8 (sin la columna nueva).
- **Continuación del 22-nov** (encargo `2026-11-22-cuenta-sola-al-leer-parte-2-continuacion`): la sesión del 21-nov se
  paró por el límite semanal y se cerró sin commit; su trabajo se recuperó del respaldo, se rebasó sobre 2.3 y pasó el
  gate. El revisor pidió que Editar cuenta no reescriba las reglas que no se tocaron (`CuentaSolaReglasFormularioTests`).
- **Pruebas**: `CuentaSolaAlLeerReglasTests`, `CuentaSolaAlLeerReglasSyncTests`, `CuentaSolaReglasUITests`,
  `gateway/test/ai.photo-cuenta.test.ts` y `manifest.capability.test.ts`.

### Pendiente fuera de esta sesión

- **CloudKit** (lo hace Dan, antes de subir ningún build): campo `CD_captureRulesRaw` (STRING) en `CD_Account`, en
  Development y luego Production, en los dos contenedores (`iCloud.com.jurgenschmidt.yala` y `.dev`). Guía:
  `docs/cloudkit-schema-diff-2.1.md`.
- **Supabase producción + Worker v9**: `bash qa/cloud/g34_01-remote.sh production apply` y después el Worker con el
  manifest v9 (orden DDL → Worker). Hasta entonces la app nueva habla v8 en producción y apunta las reglas para subirlas
  al llegar la v9.
- **Device-QA (iPhone 14, con una tarjeta real)**: medir qué texto entrega «Tarjeta» de Wallet en el atajo de Apple Pay.
  Si es genérico, «Paga con Apple Pay» se retira en otra card. Guion:
  1. Ajustes › Tutoriales › «Registrar con Apple Pay», paso «Conecta la tarjeta», y en Atajos pasar la variable Tarjeta.
  2. En Yala, Editar cuenta de la tarjeta › «Añadir regla» › «Paga con Apple Pay» con el nombre que sale en Wallet.
  3. Pagar con esa tarjeta. Esperado: el borrador de la Bandeja sale con esa cuenta.


# Reglas de cuenta al leer una captura (parte 2)

La parte 1 (la cuenta se elige sola por nombre, últimos 4 y la IA como segunda capa) está en
`tickets/done/2026-11-20-captura-cuenta-automatica-y-reglas.md`, con las maquetas, los textos y los criterios de esta
parte. Artifact «Cuenta sola al leer»: https://claude.ai/artifact/SLKNr8yEwSrW156erj6EEj.

## Decisión vigente (Jürgen, 20-nov): A + B

- **La escalera manda**: la regla del usuario es el paso 1 de `CuentaSolaAlLeer.leer` (tarjeta de Apple Pay › comercio ›
  palabras juntas › varias palabras › una palabra; empate entre reglas hacia cuentas distintas → no elige).
- **Las reglas también viajan a la IA como texto**, junto a los nombres de las cuentas, en la foto y el chat con la
  cuenta en la nube (`CuentaSolaAlLeerPeticion`, que hoy deja el hueco: `texto(_:)` añade el bloque de cuentas). La IA
  sigue siendo segunda capa: si contradice una regla, gana la regla.
- **Capa B en el chat**: la petición se arma en `ChatAssistantService` (fuera del `toca` de la parte 1).
- Que los nombres viajen también en iCloud privado exige versionar el permiso de voz y foto (`aiConsent.processingMessage`):
  decisión de Jürgen, aparte.

## Qué construir

1. **Medir primero en el iPhone 14** qué texto entrega el dato «Tarjeta» de Wallet (la parte 1 ya lo recibe en
   `ApplePayPendingExpense.card`). Si no distingue tarjetas, la condición «Paga con Apple Pay» se cae.
2. Modelo nuevo de regla (cuenta, tipo de condición, valor, modo de palabras, fecha) con CloudKit y canal de la nube.
3. «Reglas de captura» en Editar cuenta, editor «Nueva regla», «Recordar» al corregir y aviso de regla repetida.
4. Choques: la más concreta gana; empate → el selector muestra las dos con su regla (`CuentaSolaAlLeerSelectorPista`).
5. Pasa por el revisor con la lista de confiabilidad (paso 4 bis de `/gate`): sync y migración.

## Lista de ficheros (`toca` para encolarla)

```
Yala/Models/AccountCaptureRule.swift (nuevo)
Yala/Models/Account.swift
Yala/Utils/SwiftDataConfiguration.swift
Cloudkit Schemas/yala-development.ckdb
Cloudkit Schemas/yala-production.ckdb
Cloudkit Schemas/yala_dev-development.ckdb
Cloudkit Schemas/yala_dev-production.ckdb
capability_manifest.json
supabase-staging.ddl
Yala/Services/CloudSync/EntityEmissionMap.swift
Yala/Services/CloudSync/EntityApplyMap.swift
Yala/Services/CloudSync/CloudSyncEngine.swift
Yala/Services/CloudSync/DeltaEmitter.swift
Yala/App/Logic/CuentaSolaAlLeer/
Yala/App/Services/DraftBuilder.swift
Yala/App/Views/Accounts/AccountFormView.swift
Yala/App/ViewModels/Accounts/AccountFormViewModel.swift
Yala/App/Views/Accounts/CuentaSolaAlLeer/ (nuevo: sección y editor de reglas)
Yala/App/Views/Image/ImageSelectionView.swift
Yala/App/Views/Image/CuentaSolaAlLeer/
Yala/App/Views/Voice/VoiceDraftReviewCard.swift
Yala/Utils/DataWipeService.swift
Yala/App/Logic/DestructiveScopeLogic.swift
Yala/Utils/TransactionsExportService.swift
Yala/App/Views/ExportWizard/
Yala/App/Views/Import/
Yala/Services/ImportPreviewService.swift
Yala/Services/ChatAssistantService.swift
Yala/Services/TranscriptionParserService.swift
Yala/Utils/L10n+CuentaSolaAlLeer.swift
Yala/Resources/*.lproj/CuentaSolaAlLeer.strings
YalaTests/CuentaSolaAlLeer/
YalaUITests/CuentaSolaAlLeer/
```

## Criterios de aceptación

- Una regla «El texto dice “zip”» manda una captura con «Zip» a Zip Visa aunque exista una cuenta llamada «Zip».
- Corregir la cuenta y tocar «Recordar» crea la regla; la siguiente captura con esa palabra va sola.
- Dos reglas de igual concreción hacia cuentas distintas → no elige y el selector muestra las dos con su regla.
- Las reglas se sincronizan entre dos aparatos y desaparecen al borrar su cuenta, con «Vaciar mis datos» y en la
  exportación e importación.
- Con la cuenta en la nube, la petición de la foto y la del chat llevan las reglas como texto; nunca saldos ni números.
