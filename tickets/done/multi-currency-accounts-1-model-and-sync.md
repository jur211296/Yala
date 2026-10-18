---
id: multi-currency-accounts-1-model-and-sync
status: done
priority: high
area: "accounts, currency, sync, cloudkit, schema"
created: 2026-10-10
updated: 2026-10-18
source: multi-currency-accounts (entrega 1 de A1, decidida por Jürgen el 2026-10-09/10)
---

# Tarjeta multidivisa, entrega 1: el enlace entre cuentas, en el modelo y en el sync, sin pantallas

## Qué cambia para el usuario

Nada visible todavía. Esta entrega prepara el terreno: una cuenta puede quedar enlazada a otra como
«línea en otra divisa» de la misma tarjeta, y ese enlace viaja por iCloud y por Modo Nube sin que un
teléfono con una versión anterior sume mal. Hasta la entrega 2 nadie puede crear el enlace desde la
app.

Contexto y decisiones: [`multi-currency-accounts`](multi-currency-accounts.md) y
[`docs/multi-currency-accounts-impact-2026-10.md`](../../docs/multi-currency-accounts-impact-2026-10.md),
secciones 4-6.

## Bloqueo (resuelto)

**Resuelto antes de empezar:** el esquema de Production se comprobó (card o2li) y el 16-oct los cuatro `.ckdb` quedaron
byte a byte iguales a los exportados (card 1hfp). Lo de abajo queda como registro.

**Bloqueada por [`personal-cloudkit-schema-snapshot-misses-optional-fields`](../blocked/personal-cloudkit-schema-snapshot-misses-optional-fields.md)**
(high, en `blocked`). Esta entrega añade un campo opcional a `CD_Account` y lo despliega a Production.

- **Ya resuelto** (PR #442, 2026-10-10): los cuatro `.ckdb` personales llevan los 14 campos que
  faltaban, y `PersonalCloudKitSchemaParityTests` vigila que el snapshot coincida con los modelos.
  Con ese test, esta entrega sabe al instante si el campo nuevo falta en el snapshot.
- **Lo que falta, y bloquea:** nadie ha mirado el esquema de **Production** de los contenedores
  personales. Si faltan esos 14 campos, hay que desplegarlos antes, o el deploy de esta entrega sale
  sobre un esquema que ya rechaza guardados. Ese paso espera a Jürgen: hace falta un token de gestión
  de CloudKit (`cktool`), que la Mini no tiene.
- Lo más barato es desplegar los 14 campos y `CD_parentAccountID` en la misma pasada por la consola.

## Alcance

1. **Modelo.** `parentAccountID: UUID?` en `Account` (`Yala/Models/Account.swift`), con valor por
   defecto `nil`. Apunta al `shortcutID` de la cuenta principal. Aditivo: sin plan de migración ni
   one-shot. El nombre es provisional y se fija aquí.
2. **Lógica pura de líneas**, sin SwiftData en la firma, en `Yala/App/Logic/`:
   - una tarjeta no puede tener dos líneas en la misma divisa, ni una línea en la divisa de la
     principal;
   - un solo nivel: una línea no tiene líneas, y una cuenta con líneas no puede pasar a ser línea;
   - sin ciclos ni autoenlace;
   - **línea huérfana** (el padre no existe o está borrado): se trata como cuenta suelta. Falla
     cerrado y visible, nunca escondida;
   - válida para **cualquier tipo de cuenta** (decisión 3): el modelo no filtra por tipo;
   - vincular dos cuentas con movimientos es legal (decisión 4) y no toca ninguna transacción.
3. **Límite Free** (decisión 5). `isBillableUserAccount` (`Account.swift:96`) excluye las líneas
   **dentro del predicado**, no en cada llamador. La principal cuenta una vez.
4. **Identidad colapsada.** El campo entra en la reconstrucción que sigue a la regeneración de
   `shortcutID` (`CategoryDeduplicationService.repairCollapsedIdentityUUIDs` y la regla del CSV
   mirror): si la principal cambia de UUID, sus líneas se reenlazan al nuevo.
5. **Dos líneas en la misma divisa creadas en dos teléfonos.** Deduplicación por `(tarjeta, divisa)`
   con el molde del bridge (`SystemEntityMergePolicy`, `CloudSyncReconciler`). Las líneas **no**
   usan `isSystemAccount`: el bridge las tomaría por patas virtuales (análisis, 2.10).
6. **Modo Nube.** Columna nueva en `accounts`, `"safe": true`:
   - DDL en `qa/cloud/` con el molde de `g14_01_group_budget_limit.sql`; staging, sonda y producción
     según `docs/RUNBOOK-staging-ddl.md`; `supabase-staging.ddl` al día;
   - `capability_manifest.json`, emisión (`EntityEmissionMap.swift`) y apply (`EntityApplyMap.swift`);
   - viaja como referencia, igual que `account_ref`: le aplica la regla de referencias colgadas;
   - **orden de despliegue:** DDL, manifest y Worker antes que cualquier build que escriba el campo.
     Si el Worker no conoce la columna rechaza la fila entera (`unknown_column`).
7. **iCloud.** `CD_parentAccountID` en `CD_Account`, desplegado a **Production** en los dos
   contenedores personales (`yala` y `yala_dev`), y snapshots `.ckdb` regenerados.

## Fuera de alcance

Cualquier pantalla: carrusel, ficha, Ajustes, formulario, selectores, captura e informes son las
entregas 2, 3 y 4.

## Ficheros implicados

- `Yala/Models/Account.swift`
- `Yala/App/Logic/` — lógica nueva de líneas y su suite en `YalaTests/`
- `Yala/App/Services/CategoryDeduplicationService.swift`, `Yala/App/AppBootstrapper.swift`
  (reconstrucción tras UUID colapsado)
- `Yala/Services/CloudSync/EntityEmissionMap.swift`, `EntityApplyMap.swift`,
  `SystemEntityMergePolicy.swift`, `CloudSyncReconciler.swift`
- `capability_manifest.json`, `supabase-staging.ddl`, `qa/cloud/<nuevo>.sql`
- `Cloudkit Schemas/*.ckdb` (los cuatro personales) y `docs/cloudkit-schema-diff-2.1.md` (guía de deploy)
- Tests de paridad del sync: `CloudCapabilityManifestParityTests`, `EntityEmissionParityTests`,
  `CloudSyncSchemaParityTests`
- `qa/coverage-index.json`: `accounts-crud`, `cloud-backend-schema`, `cloud-sync-capture`,
  `cloud-sync-pull-apply`

## Criterio de hecho

Cerrado el 2026-10-18 (encargo `encargos/lanzados/2026-10-18-tarjeta-varias-divisas-entrega-1.md`, Paso 0 con las
decisiones). Los dos despliegues a producción salen de este ticket a sus cards, porque no los hace una sesión.

- [x] `Account.parentAccountID` existe, es opcional y vale `nil` por defecto. Ningún `Account(...)` de los tests cambió.
- [x] Suite de la lógica de líneas en verde, con un caso por regla (`YalaTests/AccountLineLogicTests`), y vincular con
      movimientos sin que cambie ninguna transacción (`AccountLineServiceTests#link_withMovements_*`).
- [x] `isBillableUserAccount` es `false` para una línea y `true` para su principal (`AccountBillableCountTests`).
- [x] UUID de la principal colapsado y regenerado: la línea sigue enlazada al nuevo, en el reparador y en el one-shot;
      con dos candidatas posibles queda suelta en vez de adivinar.
- [x] Dos líneas `(tarjeta, PEN→USD)` de dos teléfonos acaban en una. **Cambio de diseño tras la review**: se
      desduplica leyendo (`AccountLineLogic.resolve`), no desvinculando; ver el Paso 0.
- [x] Ida y vuelta por Modo Nube conserva el enlace (`AccountLineSyncTests#roundTrip_*`), y un cliente sin el applier de
      la columna la ignora y conserva los saldos (`oldPhone_*`). Más: el gate por versión del manifest
      (`SyncCapability`), que no estaba en el ticket y lo exigía el orden de despliegue.
- [x] DDL aplicado en staging y sondeado: `qa/cloud/g18_01-staging-probe.sh` 10/10.
- [ ] **DDL y Worker en producción** → card de Jürgen «Aplicar en producción el DDL de parentAccountID de Modo Nube»
      (`tablero-aplicar-en-produccion-el-ddl-de-parentac-c849`). Requisito antes de publicar 2.2.
- [ ] **`CD_Account.CD_parentAccountID` en Production** de `yala` y `yala_dev` → card de Lola «Desplegar
      CD_parentAccountID a Production en CloudKit» (`tablero-desplegar-cd-parentaccountid-a-productio-1fl7`). Requisito
      antes de publicar 2.2. Los cuatro `.ckdb` ya lo llevan.
- [x] `PersonalCloudKitSchemaParityTests` en verde con el campo nuevo.
- [x] Review adversarial (tres lentes + refutación por hallazgo): hallazgos cerrados o con ticket
      (`gateway-deploys-from-2-1-are-not-guarded-against-a-manifest-downgrade`,
      `account-line-relink-can-diverge-when-two-phones-repair-the-same-collapse`,
      `capability-upgrade-reemits-a-v1-link-edit-with-a-fresh-hlc`; lo de pantalla, en el ticket de la entrega 2).
- [x] `/gate` en verde.

## Dependencias y orden

- Depende de: [`personal-cloudkit-schema-snapshot-misses-optional-fields`](../blocked/personal-cloudkit-schema-snapshot-misses-optional-fields.md)
  (en `blocked`: espera el token de gestión de CloudKit).
- De esta dependen: [`multi-currency-accounts-2-card-view`](multi-currency-accounts-2-card-view.md),
  [`multi-currency-accounts-3-pickers-and-capture`](multi-currency-accounts-3-pickers-and-capture.md)
  y [`multi-currency-accounts-4-reports-and-export`](multi-currency-accounts-4-reports-and-export.md).
- Va sola y antes que nada: ningún cliente puede escribir el campo antes de que la nube y iCloud de
  producción lo conozcan.
