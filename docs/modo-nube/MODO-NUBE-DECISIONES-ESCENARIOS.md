---
created: 2026-07-27
updated: 2026-07-27
tags: [modo-nube, decisiones, escenarios, encendido]
---

# Modo Nube — Decisiones de escenarios de usuario (2026-07-27)

> **SSOT de las 7 decisiones que cierran las brechas de [[MODO-NUBE-AUDITORIA-ESCENARIOS]].** Donde este documento contradiga a [[MODO-NUBE-GESTION-DATOS-UX]] (§1.4, D8) o a [[groups-backend-v1]] (§migración de grupos vivos), **gana este documento**. Los apartados superseded están marcados en cada doc con un puntero aquí.

**Origen.** La auditoría de escenarios (2026-07-27, branch `2.0.5`, 21 agentes, 113 hallazgos / 110 supervivientes) midió la implementación contra el UX que el owner espera en 6 escenarios. Veredicto: 0 % alcanzable en producción por dos gates maestros (`CloudBackendConfig.isConfigured == false`, `groupsBackendCompiledDefault = false`).

**Reencuadre del owner, y la pregunta real de esta sesión.** El estado DARK **no es el problema** — es esperado y deliberado. La pregunta es: **el día que se enciendan los flags, ¿funcionará como el owner espera?** La respuesta de la auditoría, releída con esa lente, separa los hallazgos en cuatro grupos:

| Grupo | Qué es | Lo arregla el encendido? |
|---|---|---|
| **A** | Código que NO existe: elección born-cloud, liberación del container privado, gate de sign-in al entrar a Grupos | **No.** Encender no crea código |
| **B** | Existe pero no puede cumplir el objetivo: migración de grupos owner-only; 7 caminos que engordan CloudKit, uno en cada arranque | **No.** Cierra unos caminos y deja otros abiertos |
| **C** | Bugs que **solo aparecen al encender** (hoy dormidos) | **No: los estrena** |
| **D** | Lo que sí cumple: migración y reversa, alcance de «Vaciar datos», `.privateReset`, auth ⟂ container, widgets/extensiones ciegos | Sí |

Estas 7 decisiones atacan A y B; el grupo C es trabajo de corrección sin decisiones pendientes (§9).

---

## D-A1 · Puerta de Grupos: **muro + lectura de legacy**

**Decisión.** Al encender, abrir el tab Grupos **no exige firmar para VER**: el usuario consulta saldos y puede exportar sus grupos CloudKit existentes. Se **bloquea hasta firmar** todo lo que escribe: crear grupo, invitar, registrar gasto o liquidación, y aceptar invitaciones.

**Por qué, y no el muro duro.** El muro duro (la formulación inicial del owner) le quita de golpe la vista de deudas abiertas a un usuario que solo actualizó la app. La lectura preservada consigue el objetivo real —forzar el sign-in para toda escritura— sin esconderle dinero que debe o le deben.

**Aviso de mecánica que la decisión NO resuelve.** El gate del tab **no es la palanca** para dejar de generar container de grupos en iCloud. Esa palanca está en el boot, fuera de la UI: `SplitSyncManager.initialize()` (`AppBootstrapper.swift:308`, sin gate por flag ni por `storageMode`) y `recoverOwnedGroupZonesIfNeeded` (`SplitSyncManager.swift:397-434`), que llama `createZone` en cada arranque para todo grupo legacy del que el usuario sea owner. Cerrar el muro sin gatear esos dos deja la meta incumplida con la UI diciendo lo contrario.

**Estado actual a corregir.** Ninguna rama del tab lee la sesión de nube (`ContentView.swift:1952-1971`). Los dos únicos gates son el código beta `"1050"` y la cuenta iCloud del OS — **y el de iCloud se retira precisamente al encender el flag** (`:1960`), así que encender hoy *empeora* el gating.

## D-A2 · Activación: un solo encendido *(asunción del asistente, no decisión del owner)*

El muro se activa con `CloudSyncFlags.groupsBackendEnabled` (compilado && remoto), coherente con la decisión ya ratificada «UN SOLO ENCENDIDO» de [[MODO-NUBE-GRUPOS-BACKEND-V1-DISENO]]. El flag remoto sigue siendo el kill-switch. **Si el owner quiere escalonar el muro por separado del canal de sync, hace falta un flag remoto propio** — decidirlo antes de implementar D-A1.

## D-A3 · Liberar el container privado: **automático al cerrar el cutover**

**Decisión.** El cutover de la migración personal termina **borrando la zona del container privado de iCloud**. El container queda libre de inmediato: si el usuario quiere en el futuro una cuenta privada nueva en iCloud, puede.

**Orden obligatorio, y es lo que hace la decisión segura.** `borrar zona → verificar → limpiar el mapa CK local` (`SyncIdentity.ckRecordName` / `ckZoneName` → `nil`). Nunca al revés.

- El diseño declaró **inseguro** que un migrado degrade a la reversa born-cloud (§h.6): esa ruta asume «sin records CloudKit preexistentes», falso para un migrado ⇒ duplicados/resurrección (el FATAL 1 que §h.3 previene, `MODO-NUBE-ARQUITECTURA.md:519`).
- **Borrar la zona vuelve verdadera esa premisa.** Un migrado con zona borrada y mapa limpio **es** un born-cloud a todos los efectos, y su reversa es una primera subida limpia. Esto es exactamente lo que §m ya anticipaba para el borrado *manual*.
- Si el borrado de zona **falla**: se conserva el mapa, se reintenta, y la reversa clásica sigue disponible. Limpiar el mapa primero nos metería en el estado que el código ya nombra `cloudReverseDegradedNoMap`.
- El caso de **pérdida accidental** del mapa (recreación del container) **sigue siendo un estado de error explícito**, no una degradación. Esta decisión solo cubre el borrado deliberado.

**Estado actual a corregir.** No existe **ni una línea** en el repo que borre una zona del container privado: 0 hits de `deleteRecordZone` / `CKModifyRecordZones` / `purgeCloudKit`. Y la migración, además de no borrar, **inserta** un record (`MigrationWorkExecutor.swift:457`, `:471`).

### REVISIÓN 2026-07-28 (owner): el borrado NO es inmediato — espera **2 días**

**Qué cambia.** El cutover deja de borrar la zona *al cerrar*. La zona sobrevive **2 días** (el owner acotó a «1 o 2, no más»; se toma 2 por el motivo de abajo) y se borra después. Todo lo demás de D-A3 —el orden obligatorio, el argumento de la reversa born-cloud, el manejo del fallo— queda intacto: solo se mueve el *cuándo*.

**Por qué, y el disparador fue mirar el dashboard.** Producción **no tiene PITR** (es un add-on de pago, no contratado) y solo hay **backup diario** con ~7 días de retención. Combinado con el D-A3 original eso abría un agujero con horas concretas: el usuario migra a las 10:00, D-A3 borra su copia de iCloud, un fallo se lleva sus datos a las 15:00, y el único punto de restauración es el de las 07:45 de esa mañana — **anterior a su migración, así que no contiene sus datos**. Para quien migra y pierde datos el mismo día, el backup diario no vale nada, y hablamos de su historial financiero completo.

**Y el PITR es peor herramienta de lo que parece para esto**: restaura el proyecto ENTERO a un instante, o sea rebobina a todos los usuarios. Para el fallo más probable —«a un usuario se le mangaron los datos»— es casi inutilizable: habría que restaurar a un proyecto nuevo y extraer sus filas. El PITR asegura contra la catástrofe global; la copia del propio usuario asegura contra su incidente. ⇒ **retrasar el borrado es más barato Y mejor** que contratar PITR: coste recurrente cero, granularidad por usuario, y el usuario se recupera solo.

**No incumple el escenario 6**, que pedía que el container se libere y que se pueda crear una cuenta privada nueva **«a futuro»**. Dos días son compatibles con eso al pie de la letra.

**Por qué 2 y no 1.** Con 1 día, quien migra por la tarde y detecta el problema a la tarde siguiente ya está fuera de ventana. Dos cubren el ciclo completo «migro, duermo, lo uso un día, noto que algo falta». El coste del día extra es un día más de container ocupado, contra una promesa que era explícitamente a futuro.

**Dos detalles de implementación que deciden si el retraso sirve:**
1. **La cuenta atrás corre en el DEVICE, al arrancar**, no en el servidor: «si la migración cerró hace más de 2 días, borra». Así quien no abre la app conserva su copia más tiempo, que es el lado seguro del error, y el borrado ocurre con la app viva y capaz de verificar.
2. **Verificar la copia de la nube ANTES de borrar**, no solo verificar que el borrado salió bien. El orden obligatorio de D-A3 (`borrar → verificar → limpiar mapa`) valida la operación de borrado; el retraso añade una precondición distinta: que lo que se conserva en el backend esté completo y sano.

**PITR: decisión consciente de NO contratarlo ahora.** Con opt-in silencioso casi nadie migra en 2.1 y los born-cloud son cuentas nuevas sin historial que perder, así que la población en riesgo es mínima. Se revisa cuando la población de nube sea no trivial. Mitigación adicional al runbook: **backup manual antes de cualquier deploy destructivo o cambio de migración**.

**Supersede.** [[MODO-NUBE-GESTION-DATOS-UX]] §1.4 (operación manual «Borrar mi copia antigua en iCloud») y su **D8** («primer hardening post-encendido»): ya no es una acción de usuario diferida, es el paso final del cutover.

## D-A4 · Migración de grupos: **cualquier miembro migra**

**Decisión.** Se quita `isOwner` del predicado de candidatos. El primer miembro que abra la app con el canal encendido migra el grupo; el resto rebindea por `legacy_member_key`.

**Por qué era obligatorio cambiarlo.** El backend **no puede migrar por su cuenta**: nadie salvo un dispositivo con las credenciales iCloud del dueño puede leer una zona privada de CloudKit. Owner-only ⇒ un grupo cuyo dueño no abre la app **no se migra nunca**, y el corte al 100 % es imposible por construcción.

**Estado actual.** `GroupMigrationUploader.swift:125` — `#Predicate { $0.isOwner == true && $0.movedToBackendAt == nil && $0.ckSystemFieldsData != nil }`. Se conservan las dos últimas condiciones; cae la primera.

## D-A5 · Propiedad del grupo migrado: **reclamo diferido**

**Decisión.** Quien migra queda **dueño provisional** en el backend; la fila de miembro **conserva `is_owner` del dueño original**; cuando este firma, recupera la propiedad emparejando por `legacy_member_key`.

**Por qué no se le puede asignar directamente.** El dueño original puede no tener todavía cuenta en el backend, así que no hay `user_id` que poner en `owner_user_id`.

**Cambios de backend que exige.**
1. `migrate_group` hoy hace `owner_user_id = auth.uid()` incondicionalmente, y si el dueño original intenta migrar después recibe **`yala_group_exists`** (un error), no un «ya está» (`supabase-groups-staging.ddl`, §migrate_group). Debe distinguir «ya migrado por otro miembro» de «colisión real» y dejar pasar al reclamo.
2. **RPC nuevo `claim_group_ownership`**: transfiere `owner_user_id` al llamante si su `legacy_member_key` coincide con el miembro marcado `is_owner`. `SECURITY DEFINER`, y **al rango del test cross-member** (que hoy cubre 71/71) — es una escalada de privilegio por diseño y necesita su test negativo.

## D-A6 · Corte por fecha: **relativo, N días desde que ese usuario ve el muro**

> **🔁 MARCADA PARA RE-REVISIÓN A DETALLE (petición explícita del owner, 2026-07-27).** No implementar el corte sin volver a sentarse sobre esta decisión, **con datos en la mano**: cola real de grupos legacy sin migrar tras el rollout de D-A4, y % de usuarios que firman en los primeros N días. En la re-revisión entran las cuatro razones de [[MODO-NUBE-DIFERIDOS]] #38 — el corte no termina nunca globalmente y exige una métrica que no existe; la degradación a solo-exportar es interpretación no ratificada; D-A4 puede cambiar radicalmente el tamaño de la cola; y es la acción más agresiva de la épica hacia un usuario que no hizo nada mal. **Incluida la alternativa de no cortar.** El muro (D-A1) NO espera a esto: va primero y es independiente.

**Decisión (provisional hasta esa re-revisión).** Se persiste, por usuario, la fecha en que ve el muro por primera vez. Pasados N días, sus grupos legacy no migrados dejan de ser plenamente utilizables. N configurable remoto.

**Interpretación derivada — ⚠️ PENDIENTE DE RATIFICAR.** D-A1 ya deja los grupos legacy en solo-lectura para quien no firma, así que el corte de D-A6 solo añade algo si **degrada esa lectura a solo-exportar**. Se implementará así salvo que el owner diga otra cosa.

**Consecuencia aceptada, y hay que decirla en voz alta.** Con un plazo relativo por usuario **el corte nunca termina globalmente**: siempre habrá alguien empezando su cuenta atrás. Por tanto **CloudKit no se podrá apagar por fecha**, solo cuando la cola de grupos legacy activos baje de un umbral medido. Eso convierte «cuándo apagamos el canal CloudKit» en una decisión por métrica, y exige la métrica.

## D-A7 · Born-cloud: **entra en v1**

**Decisión.** Se construye la elección de ubicación en el alta: un usuario nuevo elige iCloud o nube, y un Solo Grupos nuevo nace con cuenta. Ratifica la decisión de Fase 0 («ambos caminos en v1»), que llevaba desde entonces **decidida y sin construir**.

**Estado actual — no es un flag apagado, es código muerto.** `WelcomeAccountChoiceLogic.visibleNewOptions` (`:36`) tiene **0 callsites en `Yala/` y 6 en tests**; su propio doc-comment afirma que `bornCloudEnabled` «queda cableado a `false` en el callsite» y **ese callsite no existe** (`:11-12`). Ningún usuario nuevo puede elegir nube.

**Lo que exige, más allá de cablear la vista.**
1. **`StorageMode` no tiene caso «sin iCloud»** — solo `.icloud` y `.cloud` (`CloudSyncFlags.swift:27`). La rama «local» del mount es además la única que no declara su modo de CloudKit y hereda `.automatic`, que el propio fichero llama peligroso (`SwiftDataConfiguration.swift:701-702`).
2. **Backups del backend como requisito de primera clase** (decisión épica #4): un born-cloud sin iCloud tiene su **única** copia en el backend.
3. El caso «este device no puede atestar ⇒ no sube un byte a su único respaldo» ya está identificado en el diseño y **no tiene canario**.

## D-A8 · Orden de ejecución

1. **Documentación** (este documento y sus punteros). ✅
2. **Bugs del encendido** (grupo C, §9) — sin decisiones pendientes, y son los que muerden el día del encendido.
3. **Los tres frentes de feature**: muro de Grupos (D-A1) · liberar container (D-A3) · migración+propiedad de grupos (D-A4/A5/A6) · born-cloud (D-A7).

Modo de trabajo acordado: cada frente va a **su propia sesión** vía chip task; la sesión de auditoría queda como soporte y revisión.

---

## §9 · Los bugs del encendido (grupo C) — trabajo sin decisiones pendientes

Ninguno depende de las 7 decisiones. Todos están **dormidos hoy** y se estrenan el día del encendido. Referencias completas en [[MODO-NUBE-AUDITORIA-ESCENARIOS]] §4 y §7.

| # | Bug | Evidencia | Por qué muerde al encender | Estado |
|---|---|---|---|---|
| C-1 | **Limbo `.cloud` con `mirrorOffArmed = false`**: modo nube con el mirror encendido = doble escritura indefinida, UI clavada al 89 %, sin tope ni degradación | `MigrationRunner.swift:582-596`; `MigrationWorkExecutor.swift:425`, `:661-679`; `SwiftDataConfiguration.swift:241-242` | **Determinista**, no accidente: pasa si iCloud está lleno o ausente al cerrar el cutover | ✅ **ARREGLADO** 2026-07-27 · `246a6939` |
| C-2 | **Los ~10 gates de quiescencia quedan inertes**: sin mirror no hay `importEvent` ⇒ `isImportQuiescent` devuelve `true` siempre | `SyncQuiescenceCoordinator.swift:6-24`; `iCloudSyncService.swift:94-101`; `SubcategoryDedupGate.swift:41-46`; `NotificationService.swift:531`; `ApplePayDraftService.swift:44` | Notificaciones canceladas contra grafos a medio aplicar, drafts sobre datos incompletos, dedup colapsando entidades sin su pareja |
| C-3 | **Cambio/cierre de Apple ID borra los grupos backend y no vuelven**: se borran las filas pero **no** el cursor ⇒ el pull incremental no re-entrega el historial | `SplitSyncManager.swift:1425-1439`, `:1460-1485`, `:2059-2088`; `CloudSessionSignOut.swift:595-596` | Pérdida permanente de todos los grupos migrados |
| C-4 | **Gasto del invitado perdido durante la migración de su grupo**: el uploader se gatea por la quiescencia del import **personal**, no del fetch de grupos | `AppBootstrapper.swift:421`; `GroupMigrationUploader.swift:170`, `:181`; `SplitSyncManager.swift:1518` | Pérdida silenciosa de un gasto, justo en la operación que más confianza necesita |
| C-5 | **Reinstalar en modo nube devuelve a la copia congelada de iCloud**: `storageMode` vive en `UserDefaults` y el uninstall lo borra; el faro que lo detectaría solo lo lee una pantalla oculta | `CloudSyncFlags.swift:37`, `:52`; `WelcomeCloudSignInView.swift:403`; `RestoreOfferGate.swift:26` | El usuario aterriza en datos viejos creyendo que son los suyos. Con D-A3 (zona borrada) el aterrizaje cambia, pero el faro sigue sin lector |
| C-6 | **Tras migrar, cerrar sesión** deja el device en `.icloud` y el Welcome hace bypass directo a restaurar la copia obsoleta | `SwiftDataConfiguration.swift:372`, `:236`; `WelcomeAccountChoiceLogic.swift:59`; `WelcomeFlowContainer.swift:137` | Dos corpus divergentes y ambos editables. D-A3 lo mitiga pero no lo cierra |
| C-7 | ~~**Nada impide firmar la migración personal con una cuenta distinta a la de grupos**~~ **ARREGLADO 2026-07-27** | `StorageMigrationSignInLogic.swift` (nuevo); `CloudMigrationController.startMigration(consentPath:signIn:)`; `StorageSettingsView.proceedToSignInStep`; `StorageSignInChooserView` (belt) | Con sesión viva ya no se pregunta el método: se reusa esa cuenta y la card lo anuncia. El guard vive además en la máquina — `hasSession` ⇒ jamás se re-firma, llegue el plan que llegue |
| C-8 | ~~**La suscripción Pro no viaja con la cuenta**~~ **ARREGLADO 2026-07-27, DARK + PENDIENTE DE DEPLOY** | `StoreKitManager.purchaseOptions` (appAccountToken); `ProEntitlementLogic` (nuevo); `AccountEntitlementStore`/`Service`; `gateway/src/sync/entitlement.ts` + migración D1 `0002` | El derecho se resuelve como (local OR cuenta) tras `CloudSyncFlags.accountEntitlementEnabled` (hoy `false`: monetización intacta). La EMISIÓN del token y el bind corren ya, para que el día del encendido el vínculo cuenta↔suscripción exista. Falta: `wrangler d1 migrations apply` + deploy del Worker, y encender el flag |
| C-9 | **Copy activo que promete la arquitectura vieja**: «sin servidores nuestros», sin gatear por el flag | `Localizable.strings:4432`, `:4856`; `ContentView.swift:1968` | El día del encendido es falso, y una de esas superficies es una **promesa de privacidad** |
| C-10 | **El freeze del grupo migrado viaja por CloudKit pero la recuperación depende de flags locales** | `SplitGroup.swift:54-61`; `GroupFreezeLogic.swift:43-50`; `GroupsContainerView.swift:369-379` | Un miembro en un build con el flag OFF queda **congelado sin salida** durante el rollout escalonado |

**Reparto en sesiones (chips creados 2026-07-27).** Modo de trabajo: cada chip es una sesión propia en worktree aislado; la sesión de auditoría revisa y coordina.

| Chip | Cubre | Estado |
|---|---|---|
| `task_5b9e6b8b` — cutover a prueba de iCloud lleno o ausente | C-1 | **ARREGLADO** 2026-07-27 (`246a6939`) |
| `task_57c6661a` — la quiescencia queda inerte en modo nube | C-2 | creado |
| `task_47089b29` — pérdida de grupos y de gastos en el canal nube | C-3 + C-4 | **HECHO 2026-07-27** — commit `612b21ee` → [[qa_grupos-nube-perdida-identidad-y-migracion]]. **C-3 completo**: la limpieza de identidad distingue por CANAL (nace `GroupsIdentityPurgeGate`, decide por ZONA porque el duplicado de fila vaciaría el grupo conservado) y RETIENE el canal backend mientras haya sesión de nube viva (decisión owner D4), retirándole las CUATRO credenciales de re-entrada — el token, su re-hidratación desde CloudKit, la identidad CloudKit-era del member y el intent pendiente; con una sola viva, quien tomara el device entraría COMO el anterior con permiso de escritura. El cursor NO se toca: resetearlo re-entrega una cáscara (el dinero sube en el paso 4, después del freeze), lo pisa el merge de `page.cursors` del pull en vuelo, y en «empiezo de cero» es la BARRERA de `31dded30`. **D2 aplicado** (ratificado por el owner, único cambio observable en prod hoy): `.signOut` resetea también el estado del engine — y de verdad, recreándolos, porque `clearState` solo borra el fichero y el delegate re-escribía la serialización viva. Ensanchados los 4 sitios de escritura a CKSyncEngine + `refreshCurrentUserFlags` (apagaba `isCurrentUser` en el grupo retenido, dejándolo sin «quién soy»). **C-4 solo el GATE**: señal PASIVA de quiescencia del fetch de grupos (`GroupFetchQuiescenceGate`); jamás fuerza un fetch —no es por zona y descartaría lo de los grupos ya congelados en esa misma pasada— y PASA sin canal, que si no mataría la migración de la cohorte de Modo Nube. Verificado por MUTACIÓN (7 mutantes, todos cazados). **El RESCATE sale a chip propio `task_4b2b60c6`** → ticket [[qa_rescate-pull-grupos-descartados]] — **HECHO 2026-07-28**, commit `d00a7078` (insert-only por decisión del owner; 4 mutantes cazados). Pendiente de QA en device con el canal encendido: la revisión adversarial mostró que adoptar records desconocidos puede EMPUJAR al servidor records pre-migración con HLC fresco y pisar las ediciones posteriores de todo el grupo. Residuales abiertos ahí: el invitado que sube DESPUÉS del flip y el camino de resume |
| `task_d82c8eb7` — una cuenta, una identidad (proveedor y Pro) | C-7 + C-8 | **HECHO 2026-07-27** — commit `d627f471`. C-7 completo. C-8 completo en código (cliente + gateway + tier de IA por cuenta), DARK tras `CloudSyncFlags.accountEntitlementEnabled`. **Backend ENCENDIDO 2026-07-27**: migración `0002` aplicada a `yala-gateway-production` y Worker desplegado (versión `8a1448c9`), verificado con smoke test en prod (401 sin auth / 401 con JWT inválido; `/healthz`, `/config` y `/account/exists` sin regresión). **Falta para que el usuario lo note**: `accountEntitlementCompiledDefault = true` + release, tras el QA de device (compra sandbox con `appAccountToken`, entrada con otro Apple ID, corte por reembolso). Review adversarial de 5 lentes: los hallazgos reales (throttle que quitaba Pro en cada renovación, revocación resucitable con un JWS guardado, 409 sin salida tras borrar cuenta, GDPR que no limpiaba D1, sandbox de TestFlight otorgando derecho de cuenta en prod, red en el camino crítico del boot, UI Pro abierta con 403 del proxy) van arreglados en el mismo commit |
| `task_e9786629` — copy «sin servidores nuestros» | C-9 | creado |
| `task_dd7b9cc2` — grupo congelado sin salida en el rollout | C-10 | creado |
| — | **C-5 + C-6** (re-entrada tras el cutover: faro sin lector al reinstalar, y sign-out post-migración que ofrece restaurar la copia obsoleta) | **EN ESPERA de D-A3**: con la zona borrada ya no hay copia congelada que restaurar, así que el arreglo cambia de forma. Hacerlos DESPUÉS de implementar D-A3, en la misma sesión o justo detrás |

**C-1 CERRADO 2026-07-27** (chip `task_5b9e6b8b`, commit `246a6939`, 39 archivos). Precondición del canal iCloud en las **dos** entradas del cutover (`verifying` rama `.match` y `cutover(.pending)` — la segunda cubre el resume tras un kill), veredicto puro en `ICloudCutoverGateLogic` con **fail-open** (la ambigüedad nunca aborta una migración). Tope del paso 4 **por tiempo journaleado** (`markerWrittenSince`, sellado una sola vez), no por intentos: la cadencia real es boot + foreground + tap, así que un contador castigaría a quien abre la app muchas veces. Dos presupuestos: **900 s** cuando CloudKit ya dictó que el write no entra, **259 200 s** cuando aún no se sabe. Al agotarlo, abort **local sin red** con orden obligatorio `.persistICloudMode` → `.deleteCloudKitMarker` → `.rollback` (el primero es el único que no puede lanzar).

Tres hallazgos del arreglo que el informe del chip no anticipaba:

1. **El invariante del punto (3) no se puede cumplir como estaba escrito.** Invertir el orden (armar antes de persistir `.cloud`) deja la mitad `armado + .icloud`, y `CloudMigrationUIStateDeriver.derive` la lee como `needsRelaunch(.toCloud)` **sin mirar `storageMode`** ⇒ tarjeta «cierra y vuelve a abrir» en **bucle sin salida**; y `UserDefaults` no tiene transacción, así que tampoco hay atomicidad. Se enforcea en el **consumidor**: `MigrationRuntimeGate.canRun(phase:cloudWithMirrorOn:)`.
2. **El agujero con dientes era otro y seguía abierto:** `notStarted` **es** fase estable (device adoptado, #30), así que un par a medio escribir dejaba pasar `canRunDomain()` con el mirror montado ⇒ motor **y** espejo sobre el mismo store, sin ningún gate de fase que lo notara. Ese era el daño real, no el 89 % de la barra.
3. **`failedRollback` «pelado» habría sido PEOR que el bug:** deja `.cloud` persistido, y `resetAfterRollback` (el botón «Reintentar») pone `notStarted` — fase estable — tirando además los efectos pendientes con `setPendingEffects([])`. Por eso el abort escribe `.icloud` como **primer** efecto y `resetAfterRollback` ahora **drena antes de limpiar**.

**Residual:** no existe RPC de abort de la ida (solo `reverse_abort`, §h), así que tras el abort el backend sigue con `migrated_at` estampado y un reintento entra por el flujo de **adopt** con `fastForwardHistoryBaseline`. Misma forma que deja una reversa completada (§h.4). El fix robusto sería una acción `migration_abort` en el RPC `migration_progress` — toca gateway + staging, **fuera del alcance de este chip**.

**Precondición dura del encendido que este arreglo hace visible:** el record type `CD_CloudMigrationMarker` tiene que estar desplegado en CloudKit **Production** antes de encender el flag. Sin él el export falla para el 100 % de los devices y toda migración degradaría al vencer el presupuesto largo. El instrumento es el canario `cloudCutoverMarkerStalled`, que se emite en **cada** observación del atasco (no solo al agotar), así que un atasco sistémico se ve en el dashboard mucho antes de que nadie degrade.

**Riesgo aparte, ACTIVO hoy y ajeno a la épica:** handover de dispositivo — el store de Grupos sobrevive el wipe por diseño y el bridge no comprueba identidad, así que tras «cerrar sesión» + «Soy nuevo» el usuario B ve los grupos de A y sus gastos en Panel, Inbox, presupuestos y reportes (`DataWipeService.swift:280-284`; `GroupTransactionBridge.swift:150`). **ARREGLADO 2026-07-27** (chip `task_20585d3b`) → [[qa_handover-dispositivo-grupos-fuga]]: reproducido en simulador y cerrado con la purga local del dominio Grupos en los dos caminos de «empiezo de cero» + un SELLO per-device que mantiene el bridge cerrado hasta que el usuario nuevo adopte Grupos. El alcance de `wipeAllUserData` NO cambió («Vaciar datos» de Ajustes sigue conservando Grupos, con sus tests intactos). Hallazgo añadido durante el arreglo: `checkHasExistingData` (`ContentView.swift:875`) no contaba lo bridgeado, así que un A que venía de «Solo Grupos» hacía que «Soy nuevo» **no corriera wipe alguno** (`NEW-E2-03`). Residual que este fix no cierra y sí cierra la épica: adoptar Grupos adopta el dominio del Apple ID — el aislamiento real exige identidad por CUENTA (o el sello de corpus descrito en el ticket).

---

## §10 · Lo que estas decisiones NO resuelven

- **Invariante «siempre se sabe si el container privado está en uso»**: sigue incumplida. El detector existe, es barato, funciona sin red y está validado en device (`CKIdentityCapture.swift:43-51`, `scanOrphanMetadata` en `:249-266`), pero sus únicos consumidores de producto viven dentro de la migración. Y la señal que gobierna el mount, el gate de Grupos y el restore es `ubiquityIdentityToken != nil` (`SwiftDataConfiguration.swift:36-38`) = **iCloud Drive, no CloudKit**; `accountStatus` y `CKAccountChanged` = 0 hits en el repo. **Cablearlo es un frente propio, aún sin decisión.**
- **La identidad del miembro de grupo sigue siendo el Apple ID** (`userRecordID`) para los grupos migrados; el `member_key` nuevo solo aplica a los nacidos en backend. Mientras eso siga, Grupos no es del todo independiente de iCloud.
- **Los 17 estados huérfanos** de [[MODO-NUBE-AUDITORIA-ESCENARIOS]] §4: estas decisiones cubren 6; los otros 11 siguen abiertos.
