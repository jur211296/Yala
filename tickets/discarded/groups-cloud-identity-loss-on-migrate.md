---
id: groups-cloud-identity-loss-on-migrate
status: discarded
priority: high
area: groups
created: 2026-07-27
updated: 2026-08-26
source: YalaWiki/Backlog/qa_grupos-nube-perdida-identidad-y-migracion.md
---


# Grupos de la nube: se perdían al cambiar de Apple ID, y un gasto podía perderse al migrar

Why: Discarded 2026-08-26. C-3/C-4 CloudKit QA obsolete 2026-08-17. Ticket claimed groupsBackend compiled false; channel is 100. No remaining written AC for the backend path.

Chip `task_47089b29` de la auditoría de escenarios de Modo Nube — bugs **C-3** y **C-4**
de [[MODO-NUBE-DECISIONES-ESCENARIOS]] §9. Los dos viven en el canal de sync de Grupos,
los dos están **dormidos hoy** (`CloudSyncFlags.groupsBackendEnabled` es `false`
compilado) y los dos son **pérdida de datos el día del encendido**.

## Qué le pasaba al usuario

**C-3.** Si cerrabas sesión de iCloud o cambiabas de Apple ID en el dispositivo, los
grupos que ya vivían en la nube de Yala desaparecían — y no volvían nunca, ni volviendo
a entrar con la misma cuenta. Los datos seguían intactos en el servidor; el dispositivo
simplemente dejaba de pedirlos.

**C-4.** Al mudar un grupo a la nube, un gasto que un invitado acababa de registrar
podía perderse en silencio. Sin aviso, sin rastro, y justo en la operación que más
confianza necesita.

## Implementación

**Commit `612b21ee`** (2026-07-27) · 16 ficheros, +1846/-34.

### C-3 — la limpieza de identidad pasa a distinguir por canal

| Fichero | Qué cambia |
|---|---|
| `Yala/App/Logic/GroupsIdentityPurgeGate.swift` | **NUEVO.** Decisión pura + adaptador de filas: qué se borra y qué se conserva cuando cambia la identidad de iCloud |
| `Yala/Services/Groups/SplitSyncManager.swift` | `clearAllLocalGroupData` pasa por el gate; `.signOut` enruta por `performAccountSwitchCleanup` (D2); nace `recreateEnginesAfterIdentityChange`; 4 guards de escritura a CloudKit ensanchados |
| `Yala/Models/SplitGroup.swift` | `+ rejoinRevokedAt: Date?` — marca LOCAL-only, jamás mapeada a CloudKit |
| `Yala/Services/Groups/CKRecordTranslator.swift` | No re-hidrata el token de re-invitación en un grupo revocado |
| `Yala/App/Services/GroupBackendInviteEntryHandler.swift` | `legacyMemberKeyForRejoin` devuelve `nil` en zona revocada |
| `Yala/Services/Groups/PendingJoinStore.swift` | `+ revokeLegacyMemberKey(zoneName:)` — quita el rebind, conserva el token |
| `Yala/Services/Groups/GroupService.swift` | `refreshCurrentUserFlags` salta el canal backend en sus dos bucles |
| `Yala/Services/CloudSync/Groups/GroupMigrationUploader.swift` | `reconcileMarkers` acotado a `isOwner` |

### C-4 — la mudanza espera a la sincronización correcta

| Fichero | Qué cambia |
|---|---|
| `Yala/App/Logic/GroupFetchQuiescenceGate.swift` | **NUEVO.** Decisión pura del gate: `.proceed` / `.wait` / `.deferToNextBoot` |
| `Yala/Services/Groups/SplitSyncManager.swift` | Testigo PASIVO del ciclo de fetch (contadores alimentados por el delegate) + `privateFetchGateSignal` |
| `Yala/Services/CloudSync/Groups/GroupMigrationUploader.swift` | Gate de pasada antes de `fetchCandidates` + re-chequeo por grupo con re-validación del modelo |
| `Yala/Services/Metrics/MetricsService.swift` | `+ groupMigrationDeferred` — serie propia |
| `Yala/Services/CloudSync/Groups/GroupsSyncBreadcrumb.swift` | 4 breadcrumbs nuevos (retención, purga parcial, gate diferido, apply fallido) |

## Decisiones técnicas y su porqué

**1. Conservar las filas, JAMÁS tocar el cursor.** La solución que parecía obvia
—«borro el cursor y que el servidor lo vuelva a mandar»— es activamente dañina y por
partida triple. (a) En la ventana de migración a medias el servidor solo tiene la
ficha del grupo y sus miembros, no el dinero: re-entregaría una cáscara, y al re-crearse
como grupo de nube el dispositivo dejaría de pedirle nada a iCloud — cerrando el único
camino de recuperación real. (b) El propio pull pisa el reset: la página en vuelo trae
los cursores autoritativos del servidor y los mergea después de leer el mapa. (c) En
«empiezo de cero» ese cursor superviviente es precisamente la BARRERA que impide que el
corpus del usuario anterior baje al dispositivo del nuevo — el bug que arregló
`31dded30`. Filas conservadas + cursor vivo es el par coherente; era «filas borradas +
cursor vivo» lo que perdía los datos.

**2. Decidir por ZONA, no por fila.** Pueden existir dos `SplitGroup` con el mismo
`cloudKitZoneID` (fenómeno documentado, con servicio de limpieza en el arranque), y el
paso a nube marca solo una. Como los gastos cuelgan de la zona, decidir por fila habría
hecho que la fila duplicada se llevara por delante los gastos del grupo recién
conservado — la pérdida exacta que el arreglo existe para cerrar, causada por el arreglo.

**3. La retención se ata a la sesión de nube (decisión del owner, D4).** Sin identidad
de Yala viva no hay nada que ancle esas filas, así que el dispositivo borra como hoy.
Esto importa porque el marcador de migración VIAJA por CloudKit sin mirar el flag: en
cuanto un solo dueño migre, dispositivos con el canal apagado tendrán copias congeladas.
**Residual ratificado:** la sesión vive en el llavero y sobrevive a un cambio de Apple
ID, así que «hay sesión» no prueba «sigue siendo la misma persona». Si alguien toma el
dispositivo por la vía del sistema sin pasar por «empiezo de cero», verá los grupos de
la nube del anterior. La barrera del relevo sigue siendo «empiezo de cero», que borra el
dominio entero y no pasa por este gate.

**4. Revocar la credencial eran CUATRO cosas, no una.** Borrar el token no dura: vive
cifrado en iCloud y el siguiente sync lo devuelve — y D2 garantiza ese sync. Hizo falta
una marca local durable, cortar la identidad del miembro guardada en el grupo (que es lo
que el CTA de re-entrada lee para pedirle al servidor que te devuelva la membresía
anterior) y limpiar el intent de unión pendiente. Con una sola de las cuatro, quien
tomara el dispositivo entraría **como** la persona anterior, con permiso de editar y
borrar. La revocación es LOCAL: el invite sigue vivo en el servidor y revocarlo de
verdad exige un RPC de expiración — eso es G4-invites, no esto.

**5. D2 exigía recrear los engines.** `clearState` solo borra el fichero; los engines
siguen vivos con su estado en memoria y el delegate lo re-escribe en el siguiente
evento. Sin recrearlos, «resetear los tokens» era no-determinista. Se recrean sin
transferir los cambios pendientes: son del Apple ID que se fue. Ese descarte es
justamente lo que obliga a re-armar el marcador de migración del dueño.

**6. La señal del gate de C-4 es PASIVA.** Forzar una descarga habría sido el error
simétrico: no es por zona, baja la base entera, y en una pasada de N grupos habría
descartado —con avance de token— todo lo de los grupos ya congelados en esa misma
tanda. El gate estaría causando la pérdida que viene a evitar.

**7. Sin canal, el gate PASA.** Sin cuenta de iCloud nadie puede entregar nada y hoy
esos dispositivos migran bien. Un gate que los bloqueara habría matado la migración de
la cohorte de Modo Nube —que no exige iCloud— para siempre y en silencio.

**8. El testigo por zona es NEGATIVO** (zonas cuyo fetch falló), no positivo. Exigir que
cada zona candidata aparezca en un set de «descargadas limpiamente» deadlockea: una zona
sin cambios no emite el evento nunca, así que el gate diferiría en cada arranque.

## Residuales abiertos

- **El invitado que sube su gasto DESPUÉS del congelado** y **la reanudación de una
  mudanza a medias.** El gate no los cubre por construcción. → chip `task_4b2b60c6`
  (rescate del pull), con los seis bloqueantes que la revisión adversarial ya encontró
  escritos dentro.
- **Un apply fallido difiere, no recupera.** Si el guardado de un lote falla con el
  token ya avanzado, ese lote se perdió; lo que el diferimiento evita es congelar un
  grupo cuyo store se sabe incompleto.
- **`runIdentityBootGuard` sigue muerto con el canal encendido.** Un cambio de Apple ID
  con la app cerrada no tiene cinturón proactivo. Hueco de M1/D8, ya anotado como
  condición de encendido.

## Método

Dos rondas de diseño con verificación adversarial por lentes independientes. La primera
tumbó las dos propuestas iniciales (el reset de cursor y el gate que forzaba descargas);
la segunda encontró que el rescate de C-4 podía corromper el servidor para todo el grupo
—empujar records pre-migración con reloj fresco pisa las ediciones posteriores— y por eso
salió a ticket propio.

**Verificación por mutación** en vez de «rojo antes»: como los ficheros no existían en
`HEAD`, un rojo habría sido rojo-por-no-compilar, que no prueba nada. Se rompió cada
pieza a propósito y se comprobó que muere. Los 7 mutantes: sesión ignorada · predicado a
medias · decidir por fila · token re-hidratado · rebind vivo · gate siempre asentado ·
escape sin-canal. Todos cazados. El último se llevó por delante también los 3 tests que
ya existían del uploader — la prueba de que sin ese escape la migración de Modo Nube
quedaba bloqueada.

## QA pendiente

Lo que el simulador NO puede ejercitar (`isAccountAvailable` es false ahí y el evento de
cuenta nunca llega), y por tanto exige device con iCloud real:

1. Sign-out de iCloud con grupos de la nube presentes → siguen visibles, sin CTA de
   «vuelve a entrar».
2. Switch de Apple ID → ídem, y los grupos de solo-iCloud SÍ desaparecen.
3. Volver a entrar con el mismo Apple ID → re-descarga completa de las zonas de grupos
   (antes no se re-descargaba nada). Es el único cambio observable en producción hoy.
4. Que el marcador de migración del dueño se vuelva a subir tras el cambio de identidad
   (se re-arma a propósito porque su cola se fue con el estado viejo).

## 2026-08-17 — re-medición contra 2.0.5

Árbol: `jur211296/Yala` rama `2.0.5`, HEAD `012cabe0`. **No se ejecutó QA hoy.** `status` / `qa-status` se dejan (`needs-testing`: el ticket es mixto). **No rename** — Joan revisa el nombre. YalaWiki no tiene `status: obsolete` (convención Backlog: open / backlog / in-progress / needs-testing / done / reopened / discarded). No se cierra el ticket entero.

**D (obsoleto) — por AC, no el ticket entero.** No es «ya verificado en device».

| AC escrito (QA pendiente 1–4) | Clase |
|---|---|
| 1. Sign-out de iCloud con grupos de la nube presentes | **D** — engines CK de Grupos 404 |
| 2. Switch de Apple ID | **D** — idem |
| 3. Volver a entrar / re-descarga de zonas | **D** — idem |
| 4. Re-subir marcador de migración tras cambio de identidad | **D** — `SplitSyncManager` 404 |

**Premisa FALSE:** «`CloudSyncFlags.groupsBackendEnabled` es `false` compilado» y por tanto C-3/C-4 «están dormidos hoy». Hoy `groupsBackendCompiledDefault = true` (`CloudSyncFlags` en `Yala/Services/CloudSync/CloudSyncFlags.swift`; comentario: desde D-R1 2026-07-30). El getter compuesto sigue exigiendo el remoto.

**Premisas 404 (transporte / gates CK):**

- `Yala/App/Logic/GroupsIdentityPurgeGate.swift` → **404**
- `Yala/App/Logic/GroupFetchQuiescenceGate.swift` → **404**
- `Yala/Services/Groups/SplitSyncManager.swift` → **404**

El commit de implementación `612b21ee` **existe** (2026-07-28). La Fase 3 se llevó los ficheros. `AppBootstrapper` declara retirado el retome de `GroupsIdentityPurgeIntent` (el armador y el drenador vivían dentro de `SplitSyncManager`). El evento `.accountChange` de Grupos no tiene a quién avisarle.

**REMAINS:** no hay AC escrito de «cambio de Apple ID con grupos **backend** en disco». No se inventa. Residuales del ticket (invitado que sube gasto después del congelado; apply fallido; `runIdentityBootGuard` muerto) son de la mudanza CK y no se reabren aquí.

No tratar este ticket como cerrado. Detalle y cola: [[QA-TRIAGE-SIMULADOR-VS-DEVICE-2026-08-17]].

migrated from YalaWiki Backlog/qa_grupos-nube-perdida-identidad-y-migracion.md @ 1934e8ad
