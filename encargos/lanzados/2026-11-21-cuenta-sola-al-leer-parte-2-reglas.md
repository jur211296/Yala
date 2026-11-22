Yala
# Cuenta sola al leer, parte 2: reglas de captura, Yala IA del chat y nombres de cuentas también con iCloud
---
toca: Yala/Models/AccountCaptureRule.swift,Yala/Models/Account.swift,Yala/Utils/SwiftDataConfiguration.swift,Cloudkit Schemas/yala-development.ckdb,Cloudkit Schemas/yala-production.ckdb,Cloudkit Schemas/yala_dev-development.ckdb,Cloudkit Schemas/yala_dev-production.ckdb,capability_manifest.json,supabase-staging.ddl,Yala/Services/CloudSync/EntityEmissionMap.swift,Yala/Services/CloudSync/EntityApplyMap.swift,Yala/Services/CloudSync/CloudSyncEngine.swift,Yala/Services/CloudSync/DeltaEmitter.swift,Yala/App/Logic/CuentaSolaAlLeer/,Yala/App/Services/DraftBuilder.swift,Yala/App/Views/Accounts/AccountFormView.swift,Yala/App/ViewModels/Accounts/AccountFormViewModel.swift,Yala/App/Views/Accounts/CuentaSolaAlLeer/,Yala/App/Views/Image/ImageSelectionView.swift,Yala/App/Views/Image/CuentaSolaAlLeer/,Yala/App/Views/Voice/VoiceDraftReviewCard.swift,Yala/Utils/DataWipeService.swift,Yala/App/Logic/DestructiveScopeLogic.swift,Yala/Utils/TransactionsExportService.swift,Yala/App/Views/ExportWizard/,Yala/App/Views/Import/,Yala/Services/ImportPreviewService.swift,Yala/Services/ChatAssistantService.swift,Yala/Services/TranscriptionParserService.swift,Yala/Utils/L10n+CuentaSolaAlLeer.swift,YalaTests/CuentaSolaAlLeer/,YalaUITests/CuentaSolaAlLeer/,Yala/Resources/de en-GB en es-419 es-AR es-ES es fr it ja nl pl pt-BR pt-PT pt zh-Hans.lproj/CuentaSolaAlLeer.strings,Yala/Resources/de en-GB en es-419 es-AR es-ES es fr it ja nl pl pt-BR pt-PT pt zh-Hans.lproj/Localizable.strings,Yala/Utils/L10n.swift,gateway/src/ai/,gateway/test/ai.photo-cuenta.test.ts,.claude/rules/ai-gateway.md,tickets/backlog/2026-11-20-captura-cuenta-automatica-y-reglas-parte-2.md,tickets/done/2026-11-20-captura-cuenta-automatica-y-reglas-parte-2.md
esfuerzo: high
cierre: cierra-sola
---

Segunda parte de «La cuenta se elige sola al leer una captura» (la parte 1 entró en 2.3 con https://github.com/jur211296/Yala/pull/1093). El encargo completo, con la decisión A + B de Jürgen, criterios y lista de ficheros, está en `tickets/backlog/2026-11-20-captura-cuenta-automatica-y-reglas-parte-2.md`: síguelo tal cual.

## Decisiones nuevas de Jürgen (21-nov, 05:54 Lima)
1. **Los nombres de las cuentas sí viajan a Yala IA también cuando los datos están en el iCloud privado** (no solo en la Nube de Yala). Versiona el permiso de voz y foto (`aiConsent.processingMessage` y lo que lo acompañe) en los 16 idiomas para que lo diga con claridad, y que la app vuelva a pedir el permiso a quien aceptó la versión anterior si así lo exige la regla de consentimiento vigente (`.claude/rules/ai-gateway.md`). Nunca saldos ni números de cuenta, solo nombres, últimos 4 dígitos ya visibles y reglas.
2. **OK para desplegar el gateway de producción** con los dos campos nuevos `payment` y `account` del `PHOTO_SCHEMA` (hoy solo en staging) y con lo que esta parte agregue. Primero staging, pruebas del gateway en verde, después producción, siguiendo `reference_desplegar_el_gateway_desde_la_mini` (las credenciales están en la Mini; si corres en la Max, el despliegue lo haces desde la Mini por ssh o lo dejas listo y lo anotas como pendiente con el comando exacto).
3. Los campos nuevos de CloudKit de las reglas: no subas ningún build hasta que estén desplegados. Deja en el cierre el paso exacto de despliegue (Development y luego Production, dos contenedores) para que lo haga Dan, igual que con el Flujo de caja.

## Entrega
Artifact visual con capturas antes y después (claro y oscuro) de las reglas en Editar cuenta, el editor, «Recordar» y el permiso nuevo. Puedes usar un segundo simulador en la Max o el iPhone 14 por DeviceMCP (paso 1 del ticket). Termina con /cerrar-total cuando el PR esté dentro de 2.3.

Nota (21-nov, Dan): en `~/Yala/gateway` el `node_modules` está roto (falta `workerd`); reinstala dependencias o usa un worktree limpio antes de desplegar el gateway. El PAT de Supabase del Llavero está inválido; el válido está en `~/Secrets/yala-supabase-mgmt/pat`.

Índices compartidos (21-nov): `docs/TICKETS.md` y `qa/coverage-index.json` no se declaran en `toca:` para que esta sesión pueda correr junto a otra de Yala. Edítalos solo al final, justo antes del PR, tras `git rebase origin/2.3`; si hay conflicto, resuélvelo por área o fila (no pises lo de la otra sesión).

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 (Frank, 21-nov, modo semi)

Medido en el árbol antes de decidir:
- El canal de la Nube de Yala tiene 16 entidades y **ninguna se añadió después del lanzamiento**: el manifest solo sabe
  versionar COLUMNAS (`since`), no tablas. Una entidad nueva obligaría a inventar la versión por tabla en el Worker, el
  Merkle y el cliente, con los iPhone de 2.2 delante.
- El molde de una columna nueva de una sola pieza existe y está probado: `scheduled_payments.custom_logo_ref` (v7) y las
  del ciclo de tarjeta en `accounts` (v5).

Decisiones (lo menor y técnico, decidido; se anota en el cierre):
1. **Las reglas se guardan en la cuenta, no en un modelo propio**: `Account.captureRulesRaw` (JSON de
   `AccountCaptureRule`, tipo de valor en `Yala/Models/AccountCaptureRule.swift`). CloudKit: campo `CD_captureRulesRaw` en
   los cuatro `.ckdb`. Nube de Yala: `accounts.capture_rules_raw`, `since: 9`, con su apunte de lo filtrado y su re-emisión
   al subir de versión (molde v7). Consecuencias buscadas: las reglas mueren con su cuenta, con «Vaciar mis datos» y viajan
   con la cuenta en exportar/importar sin código de borrado propio. Coste aceptado: si dos aparatos editan las reglas de la
   MISMA cuenta a la vez, gana el último (LWW de la columna).
2. **Orden de despliegue**: DDL de staging → Worker de staging (manifest v9) → app. Producción de Supabase y de CloudKit
   no se tocan (encargo). El Worker de producción se despliega con lo que corre hoy + solo `gateway/src/ai/` (campos de la
   foto y `account` del chat), **sin** el manifest v9: un Worker v9 sin la columna en la base daría error en cada subida de
   cuentas. Con la app nueva contra un Worker v8, el teléfono declara v8 y no sube la columna: apunta y la sube al llegar.
   Quedan para Dan: CloudKit (Development y Production, dos contenedores) y para después la columna en Supabase de
   producción + Worker v9.
3. **«Paga con Apple Pay» se queda** aunque no se haya medido el texto de «Tarjeta» en el iPhone (necesita un pago real
   con una tarjeta de Jürgen): casa el texto de la tarjeta tal cual. Medirlo va al device-QA del ticket; si sale genérico,
   la condición se retira en otra card.
4. **Permiso de voz y foto con versión** (`AIConsentRevision.processing = 1`, clave `aiDataConsentVersion`): el texto
   añade que se envían los nombres de las cuentas y las reglas, nunca saldos ni números. En iCloud privado la foto manda
   nombres y reglas solo con el permiso vigente. Quien aceptó el anterior: la foto sigue como antes y la hoja de la foto
   le vuelve a pedir el permiso UNA vez (aceptar lo sube; «Ahora no» sigue sin nombres). Los últimos 4 de las cuentas no
   viajan (la escalera del teléfono ya los usa; «ya visibles» se lee como los de la propia captura).
5. **Chat (capa B)**: el registro del chat manda nombres + reglas y la IA devuelve `account` (campo nuevo, nullable, en el
   esquema de `text.parse`). En privado, los nombres ya los promete el permiso de Yala IA; las reglas solo viajan en la
   nube (ticket). Voz y Siri no mandan cuentas (no lo pide el ticket).
6. **Ficheros fuera del `toca`** (una o dos líneas cada uno, sin otra sesión encima): `ApplePayDraftService`,
   `BankNoticeDraftService`, `VisionDraftFactory` (pasan comercio y origen a la escalera), `SyncCapability`,
   `AccountLinkReemit`, `ViewModifiers` y `AppPreferences` (versión del permiso), `AccountSelectorSheet` (motivo de la
   regla) y `gateway/test/manifest.capability.test.ts`.
