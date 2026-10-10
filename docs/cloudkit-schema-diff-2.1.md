# Esquema de iCloud del contenedor personal: diff contra 2.1 y guía de deploy

Fecha: 2026-10-10 · Árbol medido: `origin/2.1` en `cd1138023` · Ticket:
`tickets/blocked/personal-cloudkit-schema-snapshot-misses-optional-fields.md`

## El veredicto, primero

- **El snapshot del repo no tenía 14 campos que la app escribe** en el contenedor de producción
  (`iCloud.com.jurgenschmidt.yala`), y **31** en el de desarrollo (`iCloud.com.jurgenschmidt.yala.dev`).
  Además, un campo (`CD_CashFlowOverride.CD_line`) figura con un tipo distinto del que escribe la app.
- **No se sabe si Production los tiene.** El snapshot es un export del 2026-07-10 (`c76b5c2a8`, «deploy del
  owner»), pero esta sesión no tiene token de `cktool` y no pudo leer el esquema vivo. Eso lo tiene que mirar
  Jürgen con la guía de abajo; son diez minutos.
- **2.1 no empeora nada respecto a 2.0.** Los 14 campos existen desde 1.0–2.0 y los escriben los mismos
  sitios en `v2.0.4` y en `2.1` (medido contando escritores en los dos árboles). Si Production no los tiene,
  el fallo ya está vivo en la App Store desde esas versiones, y **el deploy lo arregla para todas las
  versiones a la vez, sin actualizar la app**.
- **Recomendación:** comprobar Production antes de enviar 2.1 y, si faltan, desplegar. No hace falta un
  build nuevo para eso.

## Qué le pasa al usuario si Production no tiene el campo

iCloud rechaza el registro entero cuando trae un campo que su esquema de Production no conoce. La app no
enseña ningún error: el registro se queda en el teléfono y no llega al otro dispositivo. Ejemplos, en
lenguaje de usuario:

- Una cuenta con **número de cuenta** rellenado no aparece en el iPad.
- Un **favorito con importe** no se sincroniza.
- Un **presupuesto único** (con fecha de inicio y fin) no se sincroniza.
- Un **pago programado** semanal, anual o con fecha de fin no se sincroniza.
- Una línea del **flujo de caja** enlazada a un pago programado, o un plan con **fecha del saldo inicial**,
  no se sincronizan.
- Una **notificación personalizada** con días de la semana no se sincroniza.

Que el rechazo de un registro frene también el resto de la subida es **inferido, no medido**.

## Cómo se calculó el esquema esperado

No se escribió a mano. El test `YalaTests/CloudSync/PersonalCloudKitSchemaParityTests.swift` construye el
`NSManagedObjectModel` que SwiftData genera para los 17 tipos de `SwiftDataConfiguration.personalSchema`
(`makeManagedObjectModel(for:)`), que es el que lee el espejo de CloudKit, y traduce cada atributo al tipo de
campo que crea el espejo:

| En el modelo | Campo en CloudKit |
|---|---|
| `String`, `UUID`, `URL` | `STRING` |
| `Int`, `Bool` | `INT64` |
| `Double`, `Float` | `DOUBLE` |
| `Date` | `TIMESTAMP` |
| `Data`, tipos `Codable` (transformables) | `BYTES` (+ `CD_<campo>_ckAsset ASSET` si es almacenamiento externo) |
| Relación a-uno | `STRING` (el recordName del destino) |
| Relación a-muchos | ningún campo (la guarda el lado a-uno, o `CDMR`) |

El script del ticket original daba falsos positivos: contaba variables locales (`var result`,
`var dates`, `var components`) como propiedades y no veía las relaciones a-uno. Por eso su tabla y esta no
coinciden: `CD_ExchangeRate.CD_result` no existe y sí faltan `CD_CashFlowLine.CD_scheduledPayment` y
`CD_InboxDraft.CD_targetTransactionID`.

## El diff, contenedor de producción (`iCloud.com.jurgenschmidt.yala`)

Idéntico en `yala-production.ckdb` y `yala-development.ckdb`. «Desde» es el commit que añadió la propiedad
al modelo y la versión de la app en ese commit; todas las versiones posteriores la escriben.

### Faltan (14)

| Record type | Campo | Tipo | Desde | Versión | Quién lo escribe |
|---|---|---|---|---|---|
| `CD_Account` | `CD_accountNumber` | STRING | `aa7adc70c` (2026-01-24) | 1.0 | Formulario de cuenta |
| `CD_Budget` | `CD_startDate` | TIMESTAMP | `aa7adc70c` (2026-01-24) | 1.0 | Editor de presupuesto (único) |
| `CD_Budget` | `CD_endDate` | TIMESTAMP | `aa7adc70c` (2026-01-24) | 1.0 | Editor de presupuesto (único) |
| `CD_Budget` | `CD_currentPeriodStart` | TIMESTAMP | `aa7adc70c` (2026-01-24) | 1.0 | Legado; el modelo lo conserva |
| `CD_CashFlowLine` | `CD_customMonthsRaw` | STRING | `ce20edafe` (2026-03-17) | 1.1.1 | Nadie lo asigna hoy (0 escritores) |
| `CD_CashFlowLine` | `CD_scheduledPayment` | STRING (relación) | `ce20edafe` (2026-03-17) | 1.1.1 | Línea enlazada a un pago programado |
| `CD_CashFlowPlan` | `CD_startingBalanceDate` | TIMESTAMP | `df550f362` (2026-03-27) | 1.1.1 | Plan de flujo de caja |
| `CD_FavoritePayment` | `CD_amount` | DOUBLE | `aa7adc70c` (2026-01-24) | 1.0 | Favorito con importe |
| `CD_InboxDraft` | `CD_targetTransactionID` | STRING | `4aea99a74` (2026-05-05) | 2.0 | Borradores que apuntan a un movimiento |
| `CD_NotificationItem` | `CD_weekdaysRaw` | STRING | `0eb85611a` (2026-01-29) | 1.1 | Notificación con días de la semana |
| `CD_ScheduledPayment` | `CD_endDate` | TIMESTAMP | `aa7adc70c` (2026-01-24) | 1.0 | Editor de pago programado |
| `CD_ScheduledPayment` | `CD_selectedWeekdays` | STRING | `aa7adc70c` (2026-01-24) | 1.0 | Pago semanal |
| `CD_ScheduledPayment` | `CD_yearlyDay` | INT64 | `aa7adc70c` (2026-01-24) | 1.0 | Pago anual |
| `CD_ScheduledPayment` | `CD_yearlyMonth` | INT64 | `aa7adc70c` (2026-01-24) | 1.0 | Pago anual |

Todos son opcionales. Encaja con cómo crea campos CloudKit en Development: solo cuando se guarda un valor
que no es `nil`. Development de este contenedor solo lo alimentan los builds Debug del scheme `Yala`; Jürgen
desarrolla con `Yala Dev`, que usa el otro contenedor. [inferido]

### Cambia de tipo (1) — hallazgo aparte

| Record type | Campo | Snapshot | La app escribe |
|---|---|---|---|
| `CD_CashFlowOverride` | `CD_line` | REFERENCE | STRING |

El espejo de CloudKit guarda toda relación a-uno como `STRING`; las otras 15 del snapshot lo son. Este record
type es el único sin índices, lo que sugiere que se creó a mano y no desde un build. **Si Production lo tiene
como REFERENCE, ningún ajuste de un mes del flujo de caja sincroniza**, y un tipo no se puede cambiar en
Production: el arreglo es de código (otro nombre para la relación). Ticket nuevo:
`personal-cloudkit-cashflow-override-line-declared-as-reference`. El test lo tolera solo con ese tipo
exacto (`knownTypeMismatches`) para no ocultar nada más.

### Sobran (no se tocan)

`CD_Budget.CD_month`, `CD_Budget.CD_year`, `CD_ScheduledPayment.CD_natureOverride`,
`CD_TransactionItem.CD_natureOverride` y los record types `CD_Split*`: el modelo ya no los escribe (los
`Split*` viven en el contenedor de Grupos). Siguen en Production para siempre y las versiones viejas los
usan. **No se borran.**

## El diff, contenedor de desarrollo (`iCloud.com.jurgenschmidt.yala.dev`)

Solo lo usan los builds `Yala Dev`. Le faltan los 14 de arriba y 17 más, casi todos del Modo Nube y de
grupos:

| Record type | Campos que faltan, además de los 14 |
|---|---|
| `CD_Budget` | `CD_natures`, `CD_tagIDs` |
| `CD_CashFlowPlan` | `CD_showAccumulatedBalance` |
| `CD_Category`, `CD_ExchangeRate`, `CD_MerchantMemory`, `CD_TransactionItem` | `CD_syncID` |
| `CD_InboxDraft` | `CD_syncID`, `CD_tagIDs` |
| `CD_ScheduledPayment` | `CD_groupZoneID`, `CD_needOverride`, `CD_splitParticipantIDsRaw`, `CD_splitTotalAmount`, `CD_splitType`, `CD_splitValuesRaw`, `CD_tagIDs` |
| `CD_Subcategory` | `CD_colorHex` |

Aquí `CD_CashFlowOverride.CD_line` sí es `STRING`.

## Qué cambió en el repo

- Los cuatro `.ckdb` de `yala` y `yala_dev` llevan ahora los campos que faltaban, sin índices (el espejo no
  los necesita). **Pasan a ser el esquema que Production DEBE tener, no un export**, hasta que Jürgen
  re-exporte tras el deploy (paso 6 de la guía).
- `PersonalCloudKitSchemaParityTests` falla si un `@Model` del store personal escribe un campo que alguno de
  los cuatro snapshots no tiene, o con otro tipo. Medido: con los snapshots de antes falla en los cuatro;
  quitando `CD_amount` de uno, falla con `CD_FavoritePayment: falta CD_amount DOUBLE`.

## Guía para Jürgen: comprobar y desplegar

### 0. Antes de empezar

1. Abre <https://icloud.developer.apple.com> e inicia sesión con la cuenta del equipo `3WKFFVD66J`.
2. Saca un **token de gestión**: CloudKit Console → arriba a la derecha, tu nombre → **Manage Tokens** →
   **Create Management Token**. Cópialo; solo se enseña una vez.
3. En la Mini, guárdalo para `cktool` (pega el token cuando lo pida):

   ```
   xcrun cktool save-token --type management
   ```

### 1. Exportar lo que hay de verdad

Desde la raíz del repo (`~/Yala`), en una rama limpia de `2.1` ya con este PR mergeado:

```
xcrun cktool export-schema --team-id 3WKFFVD66J --container-id iCloud.com.jurgenschmidt.yala \
  --environment production --output-file "Cloudkit Schemas/yala-production.ckdb"
xcrun cktool export-schema --team-id 3WKFFVD66J --container-id iCloud.com.jurgenschmidt.yala \
  --environment development --output-file "Cloudkit Schemas/yala-development.ckdb"
```

Sin `cktool`: CloudKit Console → contenedor `iCloud.com.jurgenschmidt.yala` → **Schema** → arriba elige
**Production** → **Record Types** → abre `CD_FavoritePayment` y `CD_Account` y mira si están `CD_amount` y
`CD_accountNumber`. Con eso basta para saber cuál de las dos lecturas es la buena.

### 2. Leer la respuesta

```
git diff --stat -- "Cloudkit Schemas/"
git diff -- "Cloudkit Schemas/yala-production.ckdb" | grep '^-  *CD_'
```

- **Sin líneas `-` de campos `CD_`**: Production ya los tiene. El snapshot solo estaba viejo. Commitea el
  export (`docs(cloudkit): export real del esquema personal`) y salta al paso 6.
- **Con líneas `-`**: esos campos faltan en Production. Es el bug real. Sigue con el paso 3.
- Mira también el tipo de `CD_line` en `CD_CashFlowOverride`: si dice `REFERENCE`, apúntalo en el ticket
  `personal-cloudkit-cashflow-override-line-declared-as-reference`.

Para volver a dejar el snapshot esperado: `git checkout -- "Cloudkit Schemas/"`.

### 3. Llevar los campos a Development

El deploy a Production solo copia lo que ya está en Development. Con el snapshot esperado del repo
(`git checkout -- "Cloudkit Schemas/"` si lo pisaste en el paso 1):

```
xcrun cktool validate-schema --team-id 3WKFFVD66J --container-id iCloud.com.jurgenschmidt.yala \
  --environment development --file "Cloudkit Schemas/yala-development.ckdb"
xcrun cktool import-schema --team-id 3WKFFVD66J --container-id iCloud.com.jurgenschmidt.yala \
  --environment development --file "Cloudkit Schemas/yala-development.ckdb"
```

`import-schema` **sustituye** el esquema de Development por el del fichero. Por eso el paso 1 exporta
Development antes: si el diff de ese fichero tenía líneas `-` que no estén en Production, añádelas al
fichero antes de importar, o se perderían de Development (de Production nunca se borra nada).

### 4. Desplegar a Production

1. CloudKit Console → contenedor `iCloud.com.jurgenschmidt.yala` → **Schema** → **Deploy Schema Changes…**
   (abajo a la izquierda, con Development seleccionado).
2. La lista que enseña tiene que ser **solo de altas** («Add field …»): los campos de la tabla de arriba.
   Si aparece cualquier «Remove» o «Change», **cancela**: algo del paso 3 no cuadra.
3. **Deploy**.

Qué pasa con las versiones viejas de la app: nada malo. Un campo nuevo en Production es invisible para una
versión que no lo escribe, y la que sí lo escribe deja de ser rechazada desde ese momento. Los registros que
iCloud rechazó antes los vuelve a subir el espejo en su siguiente intento. [inferido: no medido en device]

Lo que **nunca** se hace: borrar un campo o un record type de Production, ni cambiarle el tipo. CloudKit no
lo deja hacer con datos, y las versiones publicadas los siguen usando.

### 5. Lo mismo para el contenedor `.dev` (menos urgente)

Repite los pasos 1 a 4 con `--container-id iCloud.com.jurgenschmidt.yala.dev` y los ficheros
`yala_dev-production.ckdb` / `yala_dev-development.ckdb`. Solo afecta a los builds `Yala Dev`.

### 6. Dejar el repo fiel

Tras el deploy, vuelve a exportar Production y Development de los dos contenedores sobre los cuatro ficheros
(paso 1) y corre el test:

```
xcodebuild test -project Yala.xcodeproj -scheme "Yala Dev" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:YalaTests/PersonalCloudKitSchemaParityTests
```

Verde = el export real cubre todo lo que la app escribe. Commitea los cuatro `.ckdb` exportados.

## Para el siguiente campo nuevo

Un campo nuevo en un `@Model` del store personal pone rojo `PersonalCloudKitSchemaParityTests` hasta que se
añade a los cuatro `.ckdb`. Añadirlo al fichero no basta: hay que llevarlo a Production (pasos 3 y 4) **antes
de publicar** el build que lo escribe.
