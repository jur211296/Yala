---
id: 2026-11-20-captura-cuenta-automatica-y-reglas-parte-2
status: backlog
priority: medium
area: "captura, cuentas, reglas, sync, ia"
created: 2026-11-20
updated: 2026-11-20
source: "tickets/done/2026-11-20-captura-cuenta-automatica-y-reglas.md (parte 2)"
---

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
