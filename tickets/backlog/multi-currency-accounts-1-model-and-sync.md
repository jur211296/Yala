---
id: multi-currency-accounts-1-model-and-sync
status: backlog
priority: high
area: "accounts, currency, sync, cloudkit, schema"
created: 2026-10-10
updated: 2026-10-10
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

## Bloqueo

**Bloqueada por [`personal-cloudkit-schema-snapshot-misses-optional-fields`](personal-cloudkit-schema-snapshot-misses-optional-fields.md)** (high).
Esta entrega añade un campo opcional a `CD_Account` y lo despliega a Production. El snapshot `.ckdb`
del repo no tiene campos opcionales que la app ya escribe (`CD_Account.accountNumber` entre ellos),
así que hoy no sirve para saber qué hay en Production ni para planificar el campo nuevo. Ese ticket
se cierra primero: consola de iCloud mirada, snapshots regenerados y el test de paridad del `.ckdb`
personal en su sitio. Con ese test, esta entrega sabe al instante si el campo nuevo falta en el
snapshot.

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
- `Cloudkit Schemas/*.ckdb` (los cuatro personales)
- Tests de paridad del sync: `CloudCapabilityManifestParityTests`, `EntityEmissionParityTests`,
  `CloudSyncSchemaParityTests`
- `qa/coverage-index.json`: `accounts-crud`, `cloud-backend-schema`, `cloud-sync-capture`,
  `cloud-sync-pull-apply`

## Criterio de hecho

- [ ] `Account.parentAccountID` existe, es opcional y vale `nil` por defecto. Los 135 `Account(...)`
      de los tests compilan sin tocarse.
- [ ] Suite de la lógica de líneas en verde, con un caso por regla: misma divisa, divisa de la
      principal, segundo nivel, ciclo, autoenlace, huérfana, tipo de cuenta no tarjeta, y vincular
      con movimientos sin que cambie ninguna transacción.
- [ ] `isBillableUserAccount` es `false` para una línea y `true` para su principal; un test lo fija.
- [ ] Test con el UUID de la principal colapsado y regenerado: la línea sigue enlazada al nuevo.
- [ ] Test de deduplicación: dos líneas `(tarjeta, PEN→USD)` llegadas de dos teléfonos acaban en una.
- [ ] Ida y vuelta por Modo Nube: emitir una línea y aplicarla en otro store conserva el enlace. Un
      cliente sin el applier de la columna la ignora y conserva los saldos (test con el manifest
      viejo).
- [ ] DDL aplicado en staging y sondeado, y después en producción. Salida de la sonda pegada en el PR.
- [ ] `CD_Account.CD_parentAccountID` visible en el esquema de **Production** de los dos contenedores
      personales, comprobado en la consola de iCloud (lo hace Jürgen si la sesión no tiene acceso), y
      `.ckdb` regenerados.
- [ ] Test de paridad del `.ckdb` personal (lo trae el ticket que bloquea) en verde con el campo nuevo.
- [ ] Review adversarial (varias lentes + refutación por hallazgo) hecha y sus hallazgos cerrados o
      con ticket.
- [ ] `/gate` en verde.

## Dependencias y orden

- Depende de: `personal-cloudkit-schema-snapshot-misses-optional-fields`.
- De esta dependen: [`multi-currency-accounts-2-card-view`](multi-currency-accounts-2-card-view.md),
  [`multi-currency-accounts-3-pickers-and-capture`](multi-currency-accounts-3-pickers-and-capture.md)
  y [`multi-currency-accounts-4-reports-and-export`](multi-currency-accounts-4-reports-and-export.md).
- Va sola y antes que nada: ningún cliente puede escribir el campo antes de que la nube y iCloud de
  producción lo conozcan.
