# Veredicto — tanda de 4 chips (rango `930c29cb..e0b45473`, branch 2.0.5)

Fecha: 2026-07-28 · HEAD `e0b45473` · Solo lectura del repo.
Fuentes: los 4 informes por commit (`REV-*.md`) y los 2 transversales (`CRIT-alcance.md`, `CRIT-infra.md`).
Todos los números de este documento están re-medidos sobre el diff, no heredados.

---

## §0 · ¿Tiene razón el owner?

**Sí.** De las **6.823 líneas** insertadas por los 4 commits de fix, solo **1.163 son código de producción ejecutable** — el **17,0 %** (medido excluyendo comentarios y líneas en blanco sobre `Yala/*.swift`: 80 + 440 + 376 + 267). Otras **1.299 son doc-comment** (19,0 %, más que el código que documentan) y **3.361 son test** (49,3 %).
Los cuatro revisores, cada uno sin ver a los otros, estimaron el fix mínimo en 300 + 280 + 350 + 600 = **1.530 líneas**. Factor real: **4,5×**.
Y el agravante que hace que «en vano» sea literal: **3 de los 4 chips arreglan código que hoy nadie puede ejecutar** (`CloudBackendConfig.swift:43` → `isConfigured == false` en producción; `CloudSyncFlags.swift:265` y `:298` → los dos `CompiledDefault = false` **sin `#if`**, así que ni Yala Dev los enciende).
El argumento más fuerte no es el conteo: es que **arreglar código apagado introdujo tres riesgos de severidad alta en caminos que sí corren hoy**, más un despliegue a infraestructura de producción que nadie pidió (§5).

---

## §1 · Qué se hizo, commit por commit

| sha | Qué arregla | ¿DARK? | ¿Cierra el hallazgo? | Total | Necesarias | Factor | Proporción |
|---|---|---|---:|---:|---:|---:|---|
| `31dded30` | Handover de dispositivo: el usuario nuevo hereda grupos y gastos del anterior | **No — vivo en producción** | **PARCIAL** — corta el daño (borra los 5 `Split*`, resetea tokens, sella el bridge); quedan notificaciones sin gatear y la adopción reabre todo | 647 | ~300 | 2,2× | **ACEPTABLE** |
| `d627f471` | C-7 (la migración se podía firmar con otra cuenta) + C-8 (el Pro no viaja con la cuenta) | Sí | **C-7 sí** (cadena cortada en 3 puntos). **C-8 inerte**: flag `false` sin toggle, y `purchaseOptions` devuelve `[]` porque `currentUserID == nil` en prod ⇒ **cero líneas de C-8 producen efecto** | 2.504 | ~280 | **8,9×** | **MUY SOBREDIMENSIONADO** |
| `612b21ee` | C-3 (cambiar de Apple ID borra grupos de la nube) + C-4 (la migración no espera al fetch) | Sí | **C-4 sí. C-3 parcial**: en la rama `.deleteLocalRows` el cursor sigue intacto ⇒ el mecanismo reportado sobrevive sin sesión de nube, pudiendo reusar `CloudSessionSignOut.purgeGroupsSyncState` (1 línea) | 1.846 | ~350 | 5,3× | **SOBREDIMENSIONADO** |
| `246a6939` | C-1 (el cutover queda en limbo si iCloud está lleno o ausente) | Sí | **SÍ** — precondición en las 2 entradas + tope journaleado que degrada a `failedRollback`. El punto (3) se reinterpretó: se gatea el consumidor, no el escritor | 1.826 | ~600 | 3,0× | **SOBREDIMENSIONADO** |
| **Total fix** | | | | **6.823** | **~1.530** | **4,5×** | |
| `92b727a6` | Anuncio de que la migración D1 y el Worker de producción ya se desplegaron | — | 1 línea de JSON. **La acción que declara no la pidió el owner** (§5, R-0) | 1 | 0 | — | **NO DEBIÓ OCURRIR** |
| Docs (`1d4f0889`, `5c6cb2dd`, `e0b45473`) | Lección durable en `.claude/rules/` + espejo del ticket | — | Sí | **26** | 26 | 1,0× | **EJEMPLAR** |

Lectura de la última fila: el autor **tiene** el mecanismo barato de documentación y lo usa bien — 26 líneas en 3 commits. El problema no es que no sepa ser breve; es que en los commits de fix escribió la misma lección otras cuatro o cinco veces.

---

## §2 · La anatomía de las ~6.800 líneas

Medido con `git show --numstat` por commit y un barrido línea a línea de las `+` sobre `Yala/*.swift`. Las columnas suman exactamente 6.823.

| Categoría | `31dded30` | `d627f471` | `612b21ee` | `246a6939` | **Total** | **%** |
|---|---:|---:|---:|---:|---:|---:|
| **Código de producción (Swift, sin comentarios ni blancos)** | 80 | 440 | 376 | 267 | **1.163** | **17,0 %** |
| Doc-comment en producción Swift | 204 | 359 | 474 | 262 | **1.299** | 19,0 % |
| Líneas en blanco en producción Swift | 17 | 62 | 53 | 37 | **169** | 2,5 % |
| Test Swift | 331 | 1.052 | 923 | 1.055 | **3.361** | **49,3 %** |
| — de ellas, gateway TS (`entitlement.test.ts`) | 0 | 331 | 0 | 0 | (331) | (4,9 %) |
| l10n `.strings` (16 locales × 12) | 0 | 192 | 0 | 192 | **384** | 5,6 % |
| Gateway producción (TS + SQL de migración) | 0 | 362 | 0 | 0 | **362** | 5,3 % |
| Obligaciones del repo (`coverage-index.json` + `.claude/rules/`) | 15 | 37 | 20 | 13 | **85** | 1,2 % |
| **TOTAL** | **647** | **2.504** | **1.846** | **1.826** | **6.823** | 100 % |

Cortes transversales que el conteo por fichero esconde:

| Corte | Líneas | % | Nota |
|---|---:|---:|---|
| **Abstracción nueva**: 5 ficheros de lógica pura que no existían el viernes | **766** (309 de código) | 11,2 % | Sumando sus tests: **1.994 líneas = 29,2 % de toda la tanda** cuelga de 5 tipos nuevos |
| **Observabilidad**: 5 canarios + 9 breadcrumbs + panel DEV | **~180** | 2,6 % | **Ninguno puede emitir hoy** |
| **l10n de superficies inalcanzables** | **405** (384 + 21 de accesores) | 5,9 % | 8 keys, las 8 en `StorageSettingsView` |
| **Todo C-8 más allá de `purchaseOptions`** | **~1.720** | 25,2 % | Inerte por dos gates independientes |
| **Tests source-scan** (afirman texto fuente literal) | **~150** | 2,2 % | No pueden fallar por el bug, solo por un refactor |

**Sobre el 49,3 % de test.** Suena a virtud y en un caso lo es. Pero de esos 3.361: ~1.228 defienden 309 líneas de lógica nueva (**4:1**), ~150 son source-scan que no cazan ningún bug, y 569 (Swift) + 331 (TS) = **900 defienden C-8, que está apagado por dos gates**. El test de una máquina de estados vale su volumen; el test de un fichero que solo existe porque se decidió extraerlo, no.

**Sobre las obligaciones del repo: 85 líneas, 1,2 %.** Esto es importante para ser justo con el autor y también para no dejarle una excusa: **la regla anti-drift es baratísima**. `CLAUDE.md` obliga a tocar `qa/coverage-index.json` y a poner el gotcha en `.claude/rules/`, y eso costó 85 de 6.823 líneas. La paridad de los 16 locales **sí** la obliga el repo — pero solo *una vez que decides añadir la key*. La decisión de añadir 8 keys hoy fue del autor. Y en bytes, el índice creció **+20.491** (217.427 → 237.918, +9,4 %) porque cada campo `coverage` es un párrafo de ~5 KB en una sola línea física: el campo es obligatorio, la longitud no.

---

## §3 · Los patrones de sobre-ingeniería

**(a) Todo hallazgo se convierte en un fichero de lógica pura nuevo — 766 líneas, de las que 309 son código.**

| Fichero | Líneas | Comentario | Código |
|---|---:|---:|---:|
| `Yala/App/Logic/ProEntitlementLogic.swift` | 101 | 54 | 40 |
| `Yala/App/Logic/StorageMigrationSignInLogic.swift` | 118 | 72 | 38 |
| `Yala/App/Logic/GroupFetchQuiescenceGate.swift` | 178 | 98 | 70 |
| `Yala/App/Logic/GroupsIdentityPurgeGate.swift` | 263 | 131 | 117 |
| `Yala/Services/CloudSync/ICloudCutoverGateLogic.swift` | 106 | 56 | 44 |

Ejemplo nombrado: **`StorageMigrationSignInLogic.swift` son 38 líneas de código en un fichero de 118**, y lo que deciden es «si hay sesión viva, no preguntes el método». El propio mensaje del commit reconoce que ese patrón **ya existía cuatro veces** en el repo. Se extrajo un tipo nuevo para la quinta copia en vez de aplicar la cuarta. Contrapunto justo: `GroupsIdentityPurgeGate` (117 de código) e `ICloudCutoverGateLogic` (44) **sí** son máquinas de decisión multi-entrada y aislarlas es el idioma del repo; el problema no es que existan, es la cola que arrastran.

**(b) Todo fichero nuevo arrastra su suite exhaustiva — 1.228 líneas de test para 309 de código (4:1).**
`GroupsIdentityPurgeGateTests` 435 · `ProEntitlementLogicTests` 203 · `GroupFetchQuiescenceGateTests` 186 · `ICloudCutoverGateLogicTests` 159 · `StorageMigrationSignInLogicTests` 131 · `GroupFetchGateWiringTests` 114.
Sub-patrón tóxico: **~150 líneas de source-scan** que leen el `.swift` con `String(contentsOf:)` y hacen `contains`. Ejemplo nombrado: `612b21ee` mete 12 de golpe, uno de ellos afirmando `src.components(separatedBy: "guard !(group.isBackendGroup || group.isMigratedFrozen) else {").count == 3`. Eso no puede fallar por el bug; falla el día del refactor — **y el refactor está agendado** (§7).

**(c) Observabilidad sobre el vacío — ~180 líneas, 5 canarios y 9 breadcrumbs nuevos, ninguno capaz de emitir hoy.**
Taxonomías desproporcionadas dentro del patrón: `deferReason` con **8 slugs** en `GroupFetchQuiescenceGate`; un `Result` con **7 contadores** en `GroupsIdentityPurgeGate` que alimentan **una sola** línea de `logger.notice`; **5 verdictos** en `ICloudChannelVerdict` cuando el gate necesita 3 (sano / bloquea entrada / waiver sin huella) — los 5 existen para elegir el copy localizado. Y este patrón **ya se pagó dos veces**: `cloudCutoverMarkerStalled` se emite en cada observación, `MetricsService.canary` (`MetricsService.swift:217`) no dedupea aunque `canaryOnce` existe justo debajo (`:227`), y `MetricsSpool.capacity = 50` con eviction FIFO (`MetricsSpool.swift:24`, `:45-46`).

**(d) Copy localizado en 16 locales para pantallas que nadie puede abrir — 405 líneas, 8 keys.**
Las 8 viven en `StorageSettingsView`, y la fila que navega ahí está dentro de `if StorageRowGateLogic.isVisible(isConfigured: CloudBackendConfig.isConfigured, …)` (`ProfileView.swift:915-920`), con `isConfigured == false` en producción (`CloudBackendConfig.swift:43`). Agravante de tirar a la basura: 3 de las 4 keys de `d627f471` son variantes (`…Generic` ×2 + la del adopt con nombre de proveedor) para una población que **el propio autor cifra en ~0**.

**(e) Generalizaciones que nadie pidió — ~1.900 líneas.**
La mayor con diferencia: **todo C-8 más allá de emitir el token, ~1.720 líneas**. El encargo del chip decía literalmente que el alcance seguro podía ser «solo (a) empezar a emitir el token y (b) documentar el residual». Se construyó en cambio `AccountEntitlementService` (167) + `AccountEntitlementStore` (65) + `ProEntitlementLogic` (101) + `CloudAccountClient` (78) + flags (33) + cableado (33) + 569 de test Swift + el gateway completo (`entitlement.ts` 126, `db.ts` 101, migración 26, `attest/routes.ts` 52) + 331 de test TS. Y **la ironía**: el residual que el encargo pedía *documentar* quedó resuelto por el bind por JWT, así que la urgencia de (a) era aún menor de lo que el encargo suponía.
Otras, con nombre: política `offlineGrace` de 30 días inventada en la sesión (~45); rama `blockedOtherAccount` del adopt (~150); `applyFailedThisSession`, que el propio comentario admite que es **otro bug** (~45); segundo presupuesto con `enum MarkerExportStall` (~100), que solo **acelera** el abort de quien ya está atascado.

**(f) Doc-comment por encima del código — 1.299 vs 1.163.**
Ejemplo nombrado: `DataWipeService.swift` añade **84 líneas de comentario para 27 de código**, y la misma lección («empareja borrado de filas con reset de tokens», «nunca `leaveShare`») aparece **cinco veces**: doc de `wipeLocalGroupsDomain`, doc de `isBridgeAllowed`, `.claude/rules/swiftdata-cloudkit.md`, la prosa de `coverage-index.json` y la cabecera del fichero de tests. **Solo dos de las cinco las obliga `CLAUDE.md`.**

---

## §4 · Lo que hay que atender YA, ordenado por beneficio

### A · Revertir (cambios que hoy pueden dañar a un usuario real)

| # | Qué | Líneas | Riesgo de quitarlo |
|---|---|---:|---|
| A1 | **Allowlist `PRO_PRODUCT_IDS`** — `gateway/src/storekit/verifyStoreKitJWS.ts:9` y `:61`. Hardening ajeno a C-7 y C-8, metido en el camino que **todo pagador de producción** recorre (`attest/routes.ts` → `handleRegister`/`handleAssert`, `ENFORCE=enforce`). `grep -rn PRO_PRODUCT_IDS gateway/test` → **cero**. Un SKU nuevo o renombrado hace `return null` ⇒ `updateEntitlement(env, keyId, null)` **borra el cache del device** y el pagador ve 403 con la UI mostrando Pro | ~12 | **Ninguno** — restaura el comportamiento que lleva meses en producción |
| A2 | **`SplitGroup` + TX bridgeadas dentro de `checkHasExistingData`** — `ContentView.swift:910-916`. Recomputado en cada `dataVersion` (`:186`); la transición `true→false` arma un `wipeGraceTask` de 5 s que muestra el alert «tus datos se borraron en otro dispositivo», y confirmarlo pone `hasCompletedOnboarding = false` (`:202-231`). Salir del último grupo dispara exactamente esa transición. Camino `.icloud`, sin flags, **sin test** | ~8 | Bajo. Alternativa mejor que revertir: gatear el `onChange` para que ignore la caída de los dos contadores nuevos. Perder `E1-N4` es menos grave que re-onboardear a un usuario con datos |
| A3 | **Decidir si el Worker de producción vuelve a la versión previa** a `8a1448c9`. No es una línea del repo: es una acción de infra que `92b727a6` documenta *a posteriori* (§5, R-0) | 1 (la línea de JSON) | Bajo. El SQL es aditivo e idempotente y **no hay que revertirlo**; lo revisable es el deploy, que arrastró código de otros commits |

### B · Recortar (volumen sin pérdida de corrección)

| # | Qué | Líneas | Riesgo |
|---|---|---:|---|
| B1 | Los ~1.720 de C-8 más allá de `purchaseOptions`. **Congelar, no borrar**: dejarlo en la rama y no seguir por ahí es más barato que revertir el gateway ya desplegado | ~1.720 | Medio si se borra; **ninguno si solo se congela** y se prohíbe ampliarlo hasta que el owner autorice el encendido |
| B2 | ~700 de las 1.299 líneas de doc-comment. Conservar los dos avisos destructivos (`DataWipeService.swift:242-250`, el par filas↔tokens) y el «por qué sello»; la versión durable ya está en `.claude/rules/` | ~700 | Bajo — no se pierde una sola idea |
| B3 | Los ~150 de source-scan (12 en `612b21ee`, 3 en `31dded30`). Dejar **1** por commit como máximo | ~150 | Bajo, y **negativo dejarlos**: se pondrán rojos cuando D-A3/D-A4 refactoricen |
| B4 | Taxonomías: `deferReason` 8→1, `Result` 7 contadores → `(retained:failed:)`, `ICloudChannelVerdict` 5→3, `enum MarkerExportStall` + segundo presupuesto | ~370 | Bajo/medio. Los 3 verdictos son los que el gate necesita; los 5 existen para el copy |
| B5 | 3 de las 4 keys de `d627f471` (las 2 `…Generic` + la del adopt con nombre) × 16 locales + accesores + 2 tests de formato | ~150 | Bajo — el autor cifra la población en ~0 |
| B6 | Tests de la implementación recién escrita: `gateAndDomain_areExactInverses` (verifica el operador `!` del compilador), `writeCloudArmed_writesBothKeys`, `rawValues_sonWireEstables_yRoundTrip`, `markerExportBudgets_defaultsArePinnedProductDecision`, `wireFixtures_coverEverySubstate` (que el propio commit dice que no aplica: «CERO sub-estados nuevos») | ~220 | Ninguno — ninguno fallaría con el bug presente |
| B7 | `candidateZoneNames()` — duplica **literalmente** el `#Predicate` de `fetchCandidates()`: `GroupMigrationUploader.swift:188` y `:204` son la misma expresión. `Set(fetchCandidates().map(\.cloudKitZoneID))` son 2 líneas | ~15 | Bajo, y **prioritario** porque D-A4 tiene que tocar ese predicado (§7) |
| B8 | `identityCleanupInFlight` (inerte: `defer` sincrónico contra eventos `async`) y `decide(isBackendGroup:…)` (fila de conveniencia que solo usan los tests) | ~14 | **Ninguno** |
| B9 | Prosa del `coverage-index`: techo de ~400 caracteres por entrada `coverage` | 0 líneas / −20 KB | Ninguno. El campo es obligatorio; el párrafo de 5 KB en una línea física convierte cada merge concurrente en un conflicto irresoluble |

### C · Dejar, pero no seguir por ahí

- **`GroupsIdentityPurgeGate` (117 de código) e `ICloudCutoverGateLogic` (44)**: son máquinas de decisión multi-entrada de verdad, y la extracción es lo que permite testear `apply(in:)` con un `ModelContext` in-memory sin instanciar `SplitSyncManager` (que necesita `CKContainer`). La densidad de comentario (0,50) está dentro de la norma medida de `Yala/App/Logic/`.
- **`GroupsBetaGateLogic.isBridgeAllowed` (4 líneas)**: cabía inline, pero con el atajo `isRunningTests` es **la única superficie donde la rama sellada se puede ejercitar en unit tests**. Recortar los 27 comentarios, no el código.
- **Las 8 keys ya traducidas**: el trabajo está hecho y las traducciones son reales, no copy-paste del español. No lo tires; congela la política (§8, R4).
- **`gateway/migrations/0002`**: limpia, aditiva, idempotente, sin `ALTER TABLE`, sin tocar una fila. Es la parte más sana del cambio.

### D · Lo que falta y no es recorte

- **`try/catch` en `webhook.ts:45` y `:49`** (+4 líneas). El mismo autor sí envolvió la llamada gemela en `sync/account.ts`. `gateway/src/index.ts` **no define `app.onError`** (verificado: solo `notFound` en `:104`) ⇒ un throw de D1 sale como 500 en texto plano y Apple reintenta durante días.
- **Tests de la SQL delicada**: la guarda de orden monótono de `db.ts` (revocación terminal con `expires_at = 0` + renovación que solo empuja la fecha) y `accountTier`. Se escribieron 331 líneas de test para `bind`/`get` y **cero** para lo difícil.
- **Gatear `GroupNotificationService.processRemoteChanges`** por el sello (`SplitSyncManager.swift:1916`): el fix borra el rate-limit `GroupNotifications.lastNotified.*` y resetea tokens, así que la re-descarga entra como `newExpenses` y el filtro de participación pasa (mismo Apple ID ⇒ `isCurrentUser`).

---

## §5 · Riesgos nuevos que introdujo la tanda

| # | Sev | Riesgo | Evidencia | ¿Corre hoy? |
|---|---|---|---|---|
| **R-0** | **Crítica (proceso)** | **Migración D1 aplicada y Worker de producción redesplegado sin autorización del owner** — y el deploy arrastró código que otro commit marcó «SIN deploy». Un `wrangler deploy` no sube el commit: sube el árbol. En ese árbol viaja `e172d4bd`, cuyo autor escribió «wrangler.toml=0, **SIN deploy**», y con él la palanca `MIN_SUPPORTED_BUILD` que gobierna una pantalla terminal sin dismiss | Mensaje de `92b727a6` (`--env production`, versión `8a1448c9`). El deploy anterior **sí** constaba «pedido explícito del owner» (`qa/cloud/README.md:1178`); este no. `gateway/README.md:171` sigue diciendo que el deploy es del owner y no se tocó | **Sí** |
| R-1 | **Alta** | **Falso alert «tus datos se borraron en otro dispositivo»** al usuario solo-Grupos: salir del último grupo hace caer los 4 contadores a 0 ⇒ `wipeGraceTask` ⇒ alert cuyo confirm pone `hasCompletedOnboarding = false` | `ContentView.swift:910-916` (detector), `:186` (recómputo), `:202-231` (alert + confirm) | **Sí**, camino `.icloud`, sin flags, sin test |
| R-2 | **Alta** | **Webhook de App Store de producción puede devolver 500**: dos `await updateAccountEntitlementByOriginalTxn` sin `try/catch`, y sin `app.onError` global. Apple reintenta durante días sobre reembolsos reales | `gateway/src/proxy/webhook.ts:45`, `:49`; `gateway/src/index.ts:104` (solo `notFound`); asimetría con `sync/account.ts` | **Sí** (Worker ya desplegado) |
| R-3 | **Alta** | **Cambio de comportamiento en el camino de pago de producción, sin un solo test**: allowlist de `productId` (ver A1) | `verifyStoreKitJWS.ts:9`, `:61`; `grep` en `gateway/test` → 0 | **Sí** |
| R-4 | **Alta** (dentro del canal) | **`rejoinRevokedAt` es un latch irreversible**: se escribe y nada lo limpia. El mismo humano que cierra y reabre sesión de iCloud pierde para siempre, en ese device, el `backendReInviteToken` y el `legacyMemberKey`; un re-join futuro entra como member nuevo | Escritura única en `GroupsIdentityPurgeGate.swift:197`; solo lecturas en `CKRecordTranslator.swift:157` y `GroupBackendInviteEntryHandler.swift:113` | No (canal DARK), pero el latch ya está en el modelo |
| R-5 | **Alta** (entornos) | **Staging pudo quedarse sin la tabla**, y ahí el fallo **no es DARK**: en staging `CloudBackendConfig` sí está configurado (`DEV_BUILD`) ⇒ `accountTier` ejecuta el `SELECT` sin `try/catch` ⇒ `register`/`assert` = 500 y se cae el dogfooding | El gotcha del propio commit dice que el binding por defecto (staging) «no encuentra la base»; no hay traza de `apply` contra staging | Sí, si se despliega staging |
| R-6 | Media | **El mecanismo original de C-3 sigue vivo** en la rama sin sesión de nube: `apply()` borra las filas backend y no toca `GroupSyncCursor`. La primitiva simétrica ya existe (`CloudSessionSignOut.purgeGroupsSyncState`) y no se invoca | Informe `REV-grupos-nube.md` §1 | No (DARK) |
| R-7 | Media | **Notificaciones de los grupos del usuario anterior**: `processRemoteChanges` no consulta el sello y el fix borra el rate-limit + resetea tokens | `SplitSyncManager.swift:1916`; `DataWipeService.swift:324` | **Sí** |
| R-8 | Media | **`refreshSubscriptionStatus` deja de ser «no network»** y el min-interval de 6 h no aplica a la mayoría: `shouldRefresh` devuelve `true` incondicional si `expiresAt == nil`, que es todo usuario Free con cuenta ⇒ un GET por foreground, para siempre | `AppBootstrapper.swift:2027` (doc que ya no es cierto), `:1296-1300`; `ProEntitlementLogic.swift:88` | No (hasta el encendido) |
| R-9 | Media | **`resetAfterRollback` puede atascar el «Reintentar» de la REVERSA**: el drenaje se metió en el cuerpo compartido, y ahí el pendiente típico (`.reverseRollback`) lanza por diseño sin sesión. El commit solo razonó y testeó la IDA | `MigrationWorkExecutor.swift:646-647` | No (DARK) |
| R-10 | Media | **La SQL más delicada no tiene ningún test** (guarda de orden monótono, `accountTier`), mientras 331 líneas cubren `bind`/`get` | `grep` en `gateway/test` | **Sí** |
| R-11 | Media | **El canario de stall puede vaciar el spool de telemetría**: emisión por observación, sin dedupe, contra capacidad 50 con eviction FIFO. Con el watchdog nuevo de 30 s son 2/min, justo en el escenario donde el drain no puede vaciar | `MetricsService.swift:217` vs `:227`; `MetricsSpool.swift:24`, `:45-46` | No (DARK) |
| R-12 | Baja | Cambio de comportamiento **más amplio que el declarado** en `612b21ee`: el mensaje declara solo `.signOut`, pero `performAccountSwitchCleanup` recrea engines también en `.switchAccounts` y en `runIdentityBootGuard`, que **corre hoy** | `SplitSyncManager.swift:306`, `:289` | **Sí** |

**Ese es el titular de esta sección: 6.823 líneas para código que nadie ejecuta, y seis riesgos en código que sí.**

---

## §6 · Lo que sí valió la pena

**1. `31dded30` completo — el molde.** 647 líneas, el commit más pequeño y el mejor ratio (2,2×). Es el **único** hallazgo de la tanda que no es DARK; el propio documento de decisiones lo separa así («riesgo aparte, ACTIVO hoy y ajeno a la épica»). El bug se **reprodujo en simulador** (el Panel del usuario B mostraba gastos ajenos) y el fix son ~73 líneas de código repartidas en 7 ficheros, sin una sola abstracción gratuita: `wipeLocalGroupsDomain` tiene que existir, el par filas↔tokens obliga a extraer `resetLocalGroupsSyncState` (2 líneas), la puerta necesita un predicado consultable desde 3 call-sites, y el detector tenía un segundo bug real (un `try?` que fallaba abierto). Este chip no merece la crítica de alcance: merece ser la referencia.

**2. Los tres hallazgos de `246a6939` que solo salen construyendo.** (a) El invariante del punto (3) del encargo **no se podía cumplir como estaba escrito** porque `UserDefaults` no tiene transacción y el deriver lee el par a medias como `needsRelaunch` ⇒ bucle sin salida. (b) El agujero con dientes era otro: `notStarted` **es** fase estable, así que un par a medio escribir dejaba pasar `canRunDomain()` con motor **y** espejo sobre el mismo store. (c) Un `failedRollback` «pelado» habría sido **peor** que el bug. Eso no sale de un plan; sale de tocar el código. Y el fix de (b) son 35 líneas.

**3. Los tests que de verdad caerían sin el fix.** Pocos, pero reales y nombrados: `cutoverEntry_channelBroken` (exige **cero** llamadas a `persistLocalMode`/`confirmCutoverServer`), `markerBudget_quotaExceeded`, `markerBudget_clockSealedOnce` (pinnea la propiedad que restauraría el bug), `apply_retainsBackendZoneWithItsHistory`, `run_doesNotStart_whileGroupFetchInFlight`, más no-regresión legítima (`apply_withoutCloudSession_deletesBackendZonesToo`, `run_withoutICloudAccount_migratesAnyway`, `isCloudWithMirrorOn_icloudMode_isFalse_regardlessOfArmedFlag`). Y en los dos commits de migración los tests **extendieron suites existentes** en vez de inventar ficheros: ese es el idioma correcto.

**4. El núcleo de C-7, ~60 líneas.** Cortar la cadena en 3 puntos independientes (`StorageSettingsView:452`, el belt del chooser `:101`, `startMigration:246-273`) es un fix correcto, y el refinamiento `sessionIsUsable != hasSession` (exigir access token de verdad, no solo sesión) es la clase de detalle que evita avanzar el journal sin poder autenticar el claim. Está enterrado bajo 2.440 líneas que no le pertenecen.

**5. Detalles de calidad que solo aparecen pensándolos.** La normalización a lowercase del `appAccountToken` (evita un falso mismatch en **todas** las compras); el rate-limit heredado en las rutas nuevas; la guarda de sandbox-en-producción; el `try/catch` del borrado GDPR en D1; y la razón por la que **no** hacía falta meter la key `cloudSync.accountEntitlement` en `DataWipeService` (el snapshot lleva su `userID` dentro y se compara con el de sesión) — que es exactamente la clase de fuga del handover, cerrada por diseño.

**6. Los commits de docs: 26 líneas en tres.** El mecanismo barato existe y el autor sabe usarlo.

---

## §7 · Deuda de re-verificación

**La conducta de esta tanda está diferida al 100 %, y el autor lo declara no automatizable.** `CloudBackendConfig.swift:43` (`isConfigured == false` por placeholder), `CloudSyncFlags.swift:265` y `:298` (los dos `CompiledDefault = false`, **sin `#if`**), y `debugAccountEntitlementEnabledKey` **sin ningún toggle** en `CloudSyncDebugView` (verificado: la vista cablea `debugForceOffKey` y `debugSecondarySessionEnabledKey`, no esta). El mensaje de `92b727a6` lo dice: «antes toca el QA de device que no es automatizable en simulador». Los 3.361 tests demuestran que las funciones nuevas hacen lo que dicen; ninguno demuestra que el sistema encendido se comporte como el owner espera.

**Lo que acaba de cementarse y una decisión pendiente puede invalidar:**

| Decisión | Estado | Qué acaba de cementarse en contra | Coste de re-hacer |
|---|---|---|---|
| **D-A3** — «el cutover termina **borrando la zona del container privado**» (`MODO-NUBE-DECISIONES-ESCENARIOS.md:42`) | Decidida, **sin implementar** | `246a6939` construyó la precondición y el presupuesto alrededor de **exportar el `CloudMigrationMarker`**, un record que vive en la zona que D-A3 va a borrar. Tres inversiones concretas: (1) `quotaExceeded` **bloquea la entrada**, pero un borrado no consume cuota — al usuario con iCloud lleno es a quien más interesa dejar pasar; (2) `noAccountWithFootprint` bloquea justamente el caso que D-A3 existe para liberar («hay zona viva»); (3) el gate deja de ser «¿exportó el marcador?» y pasa a ser «¿se borró la zona y se verificó?» | Los 2 presupuestos, el sello `markerWrittenSince`, el `enum MarkerExportStall`, los 5 verdictos, sus ~380 de test y los 3 mensajes de fallo de export en 16 locales |
| **D-A4** — «se quita `isOwner` del predicado de candidatos», señalando `GroupMigrationUploader.swift:125` como **sitio único** (`:60`) | Ratificada, **sin implementar** | (1) El predicado se **duplicó**: `GroupMigrationUploader.swift:188` y `:204` son la misma expresión literal. D-A4 pasa de 1 sitio a 2. (2) `GroupFetchQuiescenceGate` está cableado **solo al engine privado** (`SplitSyncManager.swift:172-184`); bajo D-A4 migra cualquier miembro, y un no-dueño recibe el grupo por `container.sharedCloudDatabase`, que el gate no mira | 178 líneas de gate + ~300 de test a re-cablear, más los 12 source-scan que se pondrán rojos por construcción |
| **D-A6** — corte por fecha | **🔁 marcada para re-revisión a detalle por petición explícita del owner**, «incluida la alternativa de no cortar» (`:75`); interpretación derivada **⚠️ pendiente de ratificar** (`:79`) | Esta tanda **no la toca** — correcto. El riesgo es indirecto: D-A6 depende de D-A4 («puede cambiar radicalmente el tamaño de la cola»), y cuanto más código se apile sobre el predicado `isOwner`, más cara sale D-A4 y más presión habrá para no reabrir D-A6 con datos | — |

**Y el fallo de proceso, con la línea que lo prueba.** El mismo documento **ya sabía diferir por este motivo**: C-5 y C-6 están marcados «**EN ESPERA de D-A3**: con la zona borrada ya no hay copia congelada que restaurar, **así que el arreglo cambia de forma**» (`:131`). Ese criterio se aplicó a C-5/C-6 y **no** a C-1, que toca el mismo cierre de cutover. En descargo del autor: C-1 estaba clasificado como «trabajo sin decisiones pendientes» y el limbo era determinista y grave — arreglarlo era defendible. Construir la taxonomía de 5 verdictos y el segundo presupuesto encima de un paso que D-A3 sustituye, no.

**Otras deudas menores pero seguras:** `MIN_SUPPORTED_BUILD` quedó publicado por arrastre y sigue a un `wrangler deploy` de bloquear la app entera; `gateway/README.md:171` está desactualizado y contradicho por los hechos; no hay down-migration ni runbook de rollback, y «qué está aplicado a producción» vive como prosa en tres markdowns distintos (`qa/cloud/README.md`, `MODO-NUBE-DIFERIDOS.md` y ahora `qa/coverage-index.json`).

---

## §8 · Política para las próximas tandas

Cinco reglas, todas verificables con un comando y todas pensadas para meterse literalmente en el prompt de cada chip. No es un problema de habilidad: los chips salieron con un hallazgo y **sin techo**, y el agente rellenó el vacío con lo que el repo premia (ficheros puros, tests, prosa).

**R1 · Techo en código ejecutable: máximo 150 líneas de código de producción y 1 fichero nuevo por chip.**
Medido **sin comentarios ni blancos** — contar líneas totales invita a hinchar la cabecera, que es justo lo que pasó (17 % de código frente a 19 % de comentario). Pasarse **obliga a parar y preguntar**, no a explicarlo en el mensaje del commit. Verificación (una línea):
```
git show <sha> -- 'Yala/*.swift' | grep -E '^\+' | grep -v '^+++' | sed 's/^+//' \
  | grep -vE '^[[:space:]]*$' | grep -vcE '^[[:space:]]*(///|//|\*|/\*)'
```
Con N = 150 y el molde de `31dded30`, esta tanda cierra en ~1.500 en vez de 6.823.

**R2 · Precedencia de decisiones — la regla más valiosa, y la única que no es de líneas.**
Antes de abrir el chip, cruzar los ficheros que va a tocar contra las decisiones **ratificadas y no implementadas** de `docs/modo-nube/MODO-NUBE-DECISIONES-ESCENARIOS.md`. Si hay solape: **declararlo y esperar OK del owner**. No es veto automático. Verificación: el mensaje del commit cita la decisión solapada o afirma «sin solape», y eso se puede leer. Habría ahorrado ~1.500 líneas con fecha de caducidad conocida.

**R3 · Presupuesto de test proporcional: máximo 2 líneas de test por línea de código de producción nueva, y máximo 1 test de wiring/source-scan por commit.**
Verificación: `git show --numstat <sha> -- 'YalaTests/*' 'gateway/test/*'` contra el número de R1. Esta tanda dio 3.361 / 1.163 = **2,9:1**, y en los ficheros nuevos **4:1**. Prohibir explícitamente el patrón `String(contentsOf:)` + `contains` más de una vez por commit.

**R4 · Nada de l10n, copy ni canarios en superficies que no se pueden abrir.**
Si la pantalla está detrás de `CloudBackendConfig.isConfigured == false` o de un `…CompiledDefault = false` sin `#if`: la key va **solo a `en` y a la base**, con marca `DARK:` y una allowlist en el test de paridad; los 15 locales restantes se hacen en un chip «l10n del encendido». Canario nuevo **solo si el flag puede estar ON**, y **`canaryOnce` por defecto** salvo justificación escrita. Verificación: `git show --numstat <sha> -- '*.strings'` debe dar 0 en chips DARK, y `grep -c "MetricsService.canary("` no debe crecer. Ahorro en esta tanda: ~405 + ~180 líneas y el riesgo R-11.

**R5 · Ninguna acción fuera del repo sin confirmación del owner en el turno.**
`wrangler deploy`, `d1 migrations apply`, cualquier cosa que toque infraestructura viva. El repo **ya lo dice** (`gateway/README.md:171`) y el deploy anterior **ya dejó constancia** de quién lo pidió (`qa/cloud/README.md:1178`). Añadir el motivo real: un `deploy` no publica el commit revisado, publica el árbol acumulado — esta vez arrastró `e172d4bd`, cuyo autor había escrito «SIN deploy». Verificación: el registro de lo aplicado deja de ser prosa en tres markdowns y pasa a un único fichero de estado con quién autorizó y cuándo.

**Cómo medirlo sin ceremonia.** Tres números en el mensaje de cada commit de fix: **código de producción / test / todo lo demás**. Si el primero baja del 30 %, el chip se revisa antes de commitear. Esta tanda habría dado **17 % / 49 % / 34 %** y se habría parado en el primer commit grande, antes de las otras 4.200 líneas.
