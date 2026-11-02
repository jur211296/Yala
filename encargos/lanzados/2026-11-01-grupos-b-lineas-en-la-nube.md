---
esfuerzo: high
release: no
---
# Grupos B: guardar las líneas de tu parte en la nube personal (servidor e iCloud)

Cards: tablero-grupos-b-1-guardar-las-lineas-de-tu-part-vqhe

## Contexto
Manda la opción B que Jürgen acordó el 1-nov: `docs/disenos/grupos-tu-parte-en-lineas/README.md`, sección «Versión final acordada», y el diseño técnico en `tickets/in-progress/grupos-tu-parte-en-lineas.md` (PR #733).

## Qué hacer
### Card 1: Guardar las líneas de tu parte en la nube personal (servidor + iCloud)
- Columna tx_items.split_lines_raw (since: 6, manifest v6), DDL g27_xx staging → producción, Worker v6, campo TransactionItem.splitLinesRaw en los cuatro .ckdb y deploy a Production de CloudKit antes del build. Molde: g26_01 + cashflow_lines.amount_changes_raw. Review adversarial (sync).
- Desbloqueo: PR de la sesión grupos-opcion-b-version-final mergeado.
- Hecha cuando: El campo viaja ida y vuelta entre dos teléfonos en Modo Nube (staging) y por iCloud; tests de sync como CashFlowAmountChangeSyncTests; DDL aplicado en staging y producción; deploy de CloudKit anotado en «Necesita de ti».

## Antes de empezar
Esta sesión empieza cuando el PR #733 (grupos-opcion-b-version-final) ya esté fusionado en 2.2. Si sigue abierto, avísalo y espera.

## Servidor: staging primero
- Aplica el DDL en **staging** antes de producción.
- Prueba en staging el Worker v6, con el campo yendo y volviendo entre dos teléfonos en Modo Nube.
- Solo después, producción.

## CloudKit: el despliegue a Production es paso de Jürgen
El campo nuevo `TransactionItem.splitLinesRaw` va en los cuatro `.ckdb` y **se despliega a Production de CloudKit ANTES del build**. Este paso es de Jürgen.
- `YALA_CLOUDKIT_MGMT_TOKEN` (con `xcrun cktool`) sirve para `import-schema` y `validate-schema` en el entorno de **desarrollo**, y para exportar y validar contra Production.
- Por lo que sé de cktool, no promueve a Production; si quieres confirmarlo, mira `xcrun cktool import-schema --help`. Si de verdad no promueve, el despliegue a Production se hace desde CloudKit Console ("Deploy Schema Changes").
- Si encuentras un camino desde la sesión, pide el OK explícito de Jürgen antes de usarlo.
- En cualquier caso, anótalo en «Necesita de ti» y no subas el build hasta que esté hecho.

## Reglas
- Lo que toque el servidor (Worker o Supabase) se prueba en staging antes de producción.
- Si algo no cabe, crea su card en 2.2 antes del barrido QA (S36).

Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir (2026-11-01).** PR #733 fusionado en `2.2` (`7711c1cef`). `/config` de staging y de
producción: `manifestVersion: 5`. El Worker de producción se desplegó a las 03:11 UTC del 31-oct, justo tras fusionar #705,
y desde entonces ningún commit de `2.2` toca `gateway/` ni los manifests: desplegar desde esta rama solo lleva el manifest
v6. `g27_01` ya existe (candado de saldos iniciales). En la Mini no hay token de gestión de CloudKit (`xcrun cktool
get-teams` → «No management token found»; tampoco `YALA_CLOUDKIT_MGMT_TOKEN` en el entorno). La PAT de la Management API
de Supabase (`~/Secrets/yala-supabase-mgmt/pat`) y la sesión de Wrangler sí están.

**D1 · Nombre de la migración** → `qa/cloud/g28_01_tx_items_split_lines.sql` (+ `g28_01_rollback.sql`).
Por qué: `g27_01` es de otro tema y cada tema estrena número. Alternativa descartada: `g27_02`, que lo colgaría de los saldos iniciales.

**D2 · Clase de la columna en el manifest** → `"safe": true`, `pg_type text`, `format utf8`, `since: 6`.
Por qué: el puente vuelve a derivar las patas desde el gasto del grupo en cada pasada, y una receta que no cuadra con tu
parte es un estado previsto (D6 del diseño: borrador a la Bandeja), no una corrupción. Es el molde de `amount_changes_raw`.
Alternativa descartada: meterla en `tx_split` o `money`; el manifest es append-only y el grupo no se podría cambiar
después, y esos grupos son del editor personal y del dinero, no del puente.

**D3 · Formato en el servidor** → `text` NULLABLE sin CHECK. NULL = sin receta.
Por qué: quien la entiende es `GroupSplitLinesRecipe`, que ya lee lo ilegible o de versión posterior sin lanzar (D7 del
diseño). Un CHECK en Postgres rechazaría la fila entera de un aparato más nuevo.

**D4 · Lo que no subió mientras se hablaba v5** → apunte POR FILA (`syncID` del `TransactionItem`), también al vaciarla,
y reemisión al subir de versión: molde de la v3. Una sola columna, así que no hace falta el apunte por columna de la v5.

**D5 · «Dos teléfonos en Modo Nube (staging)»** → una sonda contra el Worker de staging DESPLEGADO con el usuario de
test A y dos nodos: el nodo 1 sube la receta declarando v6; el nodo 2 la baja con v6 y no la ve con v5; el Merkle v6 la
hashea y el v5 no; vaciarla viaja como NULL. El cliente lo cubren tests de sync al estilo de `CashFlowAmountChangeSyncTests`.
Por qué: ninguna pantalla escribe todavía la receta (cards 2-6). Dos simuladores necesitarían un seam solo para QA, código
sin uso en producción. Alternativa descartada: ese seam. El device-QA real llega con la card 2.

**D6 · iCloud** → el campo va en los cuatro `.ckdb` (STRING sin índices, como `CD_amountChangesRaw`) y
`PersonalCloudKitSchemaParityTests` lo fija. El alta en Development y el deploy a Production los hace Jürgen desde la
consola (sin token no hay otro camino), con su paso en `docs/despliegue-cloudkit-2-2.md`. Va a «Necesita de ti», y ningún
build que escriba la receta se sube antes. La ida y vuelta por iCloud entre dos teléfonos no se puede medir desde aquí:
queda en el device-QA de la card 2.

**D7 · Producción en esta sesión** → sí: DDL en producción y Worker v6 en producción, tras staging en verde.
Por qué: el encargo lo pide, y es seguro con la app de hoy en la calle: el cliente declara la menor entre su versión y la
anunciada, así que 2.1 y 2.2 sin esta build siguen en v1/v5. Orden: DDL staging → Worker staging → sonda → DDL producción →
Worker producción. Riesgo aceptado: si el PR no llegara a fusionarse, producción quedaría en v6 y `2.2` en v5; el guard
`check-manifest-not-older` impediría que un despliegue posterior la bajara sin querer.

**D8 · Alcance en la app** → solo el campo y su viaje (modelo, emisión, aplicación, `SyncCapability` v6, reemisión). Nada
lo escribe todavía; preservar la receta al recrear patas es de la card 2.
