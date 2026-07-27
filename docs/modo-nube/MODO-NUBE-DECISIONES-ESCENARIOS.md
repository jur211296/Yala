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

| # | Bug | Evidencia | Por qué muerde al encender |
|---|---|---|---|
| C-1 | **Limbo `.cloud` con `mirrorOffArmed = false`**: modo nube con el mirror encendido = doble escritura indefinida, UI clavada al 89 %, sin tope ni degradación | `MigrationRunner.swift:582-596`; `MigrationWorkExecutor.swift:425`, `:661-679`; `SwiftDataConfiguration.swift:241-242` | **Determinista**, no accidente: pasa si iCloud está lleno o ausente al cerrar el cutover |
| C-2 | **Los ~10 gates de quiescencia quedan inertes**: sin mirror no hay `importEvent` ⇒ `isImportQuiescent` devuelve `true` siempre | `SyncQuiescenceCoordinator.swift:6-24`; `iCloudSyncService.swift:94-101`; `SubcategoryDedupGate.swift:41-46`; `NotificationService.swift:531`; `ApplePayDraftService.swift:44` | Notificaciones canceladas contra grafos a medio aplicar, drafts sobre datos incompletos, dedup colapsando entidades sin su pareja |
| C-3 | **Cambio/cierre de Apple ID borra los grupos backend y no vuelven**: se borran las filas pero **no** el cursor ⇒ el pull incremental no re-entrega el historial | `SplitSyncManager.swift:1425-1439`, `:1460-1485`, `:2059-2088`; `CloudSessionSignOut.swift:595-596` | Pérdida permanente de todos los grupos migrados |
| C-4 | **Gasto del invitado perdido durante la migración de su grupo**: el uploader se gatea por la quiescencia del import **personal**, no del fetch de grupos | `AppBootstrapper.swift:421`; `GroupMigrationUploader.swift:170`, `:181`; `SplitSyncManager.swift:1518` | Pérdida silenciosa de un gasto, justo en la operación que más confianza necesita |
| C-5 | **Reinstalar en modo nube devuelve a la copia congelada de iCloud**: `storageMode` vive en `UserDefaults` y el uninstall lo borra; el faro que lo detectaría solo lo lee una pantalla oculta | `CloudSyncFlags.swift:37`, `:52`; `WelcomeCloudSignInView.swift:403`; `RestoreOfferGate.swift:26` | El usuario aterriza en datos viejos creyendo que son los suyos. Con D-A3 (zona borrada) el aterrizaje cambia, pero el faro sigue sin lector |
| C-6 | **Tras migrar, cerrar sesión** deja el device en `.icloud` y el Welcome hace bypass directo a restaurar la copia obsoleta | `SwiftDataConfiguration.swift:372`, `:236`; `WelcomeAccountChoiceLogic.swift:59`; `WelcomeFlowContainer.swift:137` | Dos corpus divergentes y ambos editables. D-A3 lo mitiga pero no lo cierra |
| C-7 | **Nada impide firmar la migración personal con una cuenta distinta a la de grupos** | `StorageSignInChooserView.swift:21`; `CloudMigrationController.swift:249`, `:266` | Personal en una cuenta y grupos en otra, contra el copy que promete lo contrario y contra el invariante R9 |
| C-8 | **La suscripción Pro no viaja con la cuenta** (sin `appAccountToken`) | `StoreKitManager.swift:243`; `FeatureGateService.swift:126-130` | Quien migra a la nube para no depender de Apple y entra en un device con otro Apple ID **ve sus datos y pierde Pro sobre ellos** |
| C-9 | **Copy activo que promete la arquitectura vieja**: «sin servidores nuestros», sin gatear por el flag | `Localizable.strings:4432`, `:4856`; `ContentView.swift:1968` | El día del encendido es falso, y una de esas superficies es una **promesa de privacidad** |
| C-10 | **El freeze del grupo migrado viaja por CloudKit pero la recuperación depende de flags locales** | `SplitGroup.swift:54-61`; `GroupFreezeLogic.swift:43-50`; `GroupsContainerView.swift:369-379` | Un miembro en un build con el flag OFF queda **congelado sin salida** durante el rollout escalonado |

**Reparto en sesiones (chips creados 2026-07-27).** Modo de trabajo: cada chip es una sesión propia en worktree aislado; la sesión de auditoría revisa y coordina.

| Chip | Cubre | Estado |
|---|---|---|
| `task_5b9e6b8b` — cutover a prueba de iCloud lleno o ausente | C-1 | creado |
| `task_57c6661a` — la quiescencia queda inerte en modo nube | C-2 | creado |
| `task_47089b29` — pérdida de grupos y de gastos en el canal nube | C-3 + C-4 | creado |
| `task_d82c8eb7` — una cuenta, una identidad (proveedor y Pro) | C-7 + C-8 | creado |
| `task_e9786629` — copy «sin servidores nuestros» | C-9 | creado |
| `task_dd7b9cc2` — grupo congelado sin salida en el rollout | C-10 | creado |
| — | **C-5 + C-6** (re-entrada tras el cutover: faro sin lector al reinstalar, y sign-out post-migración que ofrece restaurar la copia obsoleta) | **EN ESPERA de D-A3**: con la zona borrada ya no hay copia congelada que restaurar, así que el arreglo cambia de forma. Hacerlos DESPUÉS de implementar D-A3, en la misma sesión o justo detrás |

**Riesgo aparte, ACTIVO hoy y ajeno a la épica:** handover de dispositivo — el store de Grupos sobrevive el wipe por diseño y el bridge no comprueba identidad, así que tras «cerrar sesión» + «Soy nuevo» el usuario B ve los grupos de A y sus gastos en Panel, Inbox, presupuestos y reportes (`DataWipeService.swift:280-284`; `GroupTransactionBridge.swift:150`). **ARREGLADO 2026-07-27** (chip `task_20585d3b`) → [[qa_handover-dispositivo-grupos-fuga]]: reproducido en simulador y cerrado con la purga local del dominio Grupos en los dos caminos de «empiezo de cero» + un SELLO per-device que mantiene el bridge cerrado hasta que el usuario nuevo adopte Grupos. El alcance de `wipeAllUserData` NO cambió («Vaciar datos» de Ajustes sigue conservando Grupos, con sus tests intactos). Hallazgo añadido durante el arreglo: `checkHasExistingData` (`ContentView.swift:875`) no contaba lo bridgeado, así que un A que venía de «Solo Grupos» hacía que «Soy nuevo» **no corriera wipe alguno** (`NEW-E2-03`). Residual que este fix no cierra y sí cierra la épica: adoptar Grupos adopta el dominio del Apple ID — el aislamiento real exige identidad por CUENTA (o el sello de corpus descrito en el ticket).

---

## §10 · Lo que estas decisiones NO resuelven

- **Invariante «siempre se sabe si el container privado está en uso»**: sigue incumplida. El detector existe, es barato, funciona sin red y está validado en device (`CKIdentityCapture.swift:43-51`, `scanOrphanMetadata` en `:249-266`), pero sus únicos consumidores de producto viven dentro de la migración. Y la señal que gobierna el mount, el gate de Grupos y el restore es `ubiquityIdentityToken != nil` (`SwiftDataConfiguration.swift:36-38`) = **iCloud Drive, no CloudKit**; `accountStatus` y `CKAccountChanged` = 0 hits en el repo. **Cablearlo es un frente propio, aún sin decisión.**
- **La identidad del miembro de grupo sigue siendo el Apple ID** (`userRecordID`) para los grupos migrados; el `member_key` nuevo solo aplica a los nacidos en backend. Mientras eso siga, Grupos no es del todo independiente de iCloud.
- **Los 17 estados huérfanos** de [[MODO-NUBE-AUDITORIA-ESCENARIOS]] §4: estas decisiones cubren 6; los otros 11 siguen abiertos.
