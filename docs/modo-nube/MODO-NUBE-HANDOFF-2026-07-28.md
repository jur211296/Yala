---
created: 2026-07-28
updated: 2026-07-28
tags: [modo-nube, handoff, sesion]
---

# Handoff de la sesión del 2026-07-28 — auditoría de escenarios, simplificación de Grupos y disciplina de medición

> **Para qué existe:** la sesión que produjo todo esto se va a comprimir. Aquí está lo que hay que saber para retomar sin releerla: qué se decidió, qué está en vuelo, **con qué criterio validar lo que vuelva**, y qué queda abierto. Los documentos de detalle se enlazan; no se resumen dos veces.

## 1 · Qué se hizo, en una pantalla

| Frente | Resultado | Dónde vive |
|---|---|---|
| Auditoría de los 6 escenarios de usuario | 113 hallazgos, 110 supervivientes. **0 % del UX esperado alcanzable** por dos gates maestros | [[MODO-NUBE-AUDITORIA-ESCENARIOS]] |
| 7 decisiones del owner que cierran las brechas | D-A1…D-A7. **D-A6 marcada para re-revisión** ([[MODO-NUBE-DIFERIDOS]] #38) | [[MODO-NUBE-DECISIONES-ESCENARIOS]] |
| Decisión de release | **2.1 con todo ENCENDIDO, sin escalonado**, TestFlight primero. Migración personal = **opt-in silencioso** | [[MODO-NUBE-DECISION-RELEASE-2.1]] |
| Simplificación de Grupos | **~12.650 líneas borrables (48 % del subsistema)**. Plan de 7 fases → **5** | [[MODO-NUBE-PLAN-SIMPLIFICACION-GRUPOS]] |
| Brief ejecutable de la Fase 1 | 43 coordenadas corregidas contra HEAD | [[MODO-NUBE-FASE1-BRIEF]] · `docs/modo-nube/` |
| Revisión de alcance de la tanda anterior | **De 6.823 líneas insertadas, 1.163 eran código de producción (17 %)**. Factor 4,5× | [[MODO-NUBE-REVISION-TANDA1-ALCANCE]] |
| Evidencia de trabajo (35 informes de agentes) | Mapas, escenarios, refutaciones, inventarios | `evidencia-2026-07-28/` |

**El giro que lo reordenó todo:** Grupos nunca salió del código beta (solo el owner y Pia), así que toda la maquinaria para migrar grupos vivos sin pérdida resolvía un problema **sin víctimas**. El owner decidió borrar y empezar de cero, borrando a mano sus gastos de grupo y reintroduciéndolos. Eso eliminó las dos fases del plan que **añadían** código.

## 2 · Commits de la sesión (branch `2.0.5`)

| Commit | Qué |
|---|---|
| `930c29cb` | Espeja al repo la auditoría y las decisiones (la otra Mac hace pull) |
| `bd9435b8` | **fix**: salir del último grupo ya no dispara el aviso de datos borrados + `app.onError` en el gateway |
| `66ee43a8` · `4fcc9084` | Plan de 5 fases, decisión de release 2.1, brief de la Fase 1 |
| `b1a5033f` | *(otra sesión)* umbral realista del test del inbox + quita el `Task { sleep }` de `InboxAlertModal` |
| `464d5fdf` | *(otra sesión)* higiene del índice de QA + 3 reglas de entorno en `.claude/rules/testing.md` |

## 3 · En vuelo — y CÓMO VALIDARLO

### 3.1 · Fase 1 de la simplificación (otra Mac, chip `task_14d9a773`)

Borra ~3.500 líneas de maquinaria de migración de grupos y cierra el RPC `migrate_group` en el gateway. Dos decisiones ya tomadas y horneadas en el brief: **no se dropea la función SQL** (queda inerte tras un 404, y eso cancela el runbook de despliegue entero) y **el fixture del golden G10 nº2 se re-siembra** sin `migrate_group`.

**Criterios de validación cuando vuelva** — en este orden:

1. **Balance del diff sustractivo.** Es una fase de BORRADO: si hay más inserciones que borrados, se salió del carril. Techo pactado: **+5 líneas de producción, +20 de test (solo el fixture), +4 de documentación**.
2. **Los greps que deben SEGUIR dando hits**, que son el freno de verdad y están en el §7 del brief. En particular `backendZoneNames` (≥3), `pendingFreezeZoneIDs`, `processRemoteChanges` (1), `accountDeletionGroupsSummary` con sus 3 consumidores, `enqueueMigrationMarker`, y `awaitPersonalStoreReady` a **11** (era 12: es la excepción declarada).
3. **La TRAMPA 1.** `SplitSyncManager:1843-1877` mezcla el guard VIVO de PULL de G6-3 (C2) con el rescate muerto. Si borró el bloque entero, abrió una ventana donde un record CloudKit stale pisa la verdad del backend y se bridgea al store personal — **no falla al compilar y ningún test lo caza**. Verificar que quedó la forma reducida del guard.
4. **Que las 4 piezas que mueren en silencio sigan vivas**: notificaciones de grupo y de miembro, freeze en soft-delete remoto, guard de deudas del borrado de cuenta. Son de la Fase 2, no de la 1.
5. **Que NO ejecutó ningún despliegue** ni aplicó migraciones, y que dejó el runbook escrito para el owner.
6. **Que no tocó nada fuera de su allowlist**, en especial `ContentView.swift`, `CloudSyncEngine.swift`, `DataWipeService.swift` ni `ImportIntroSheet.swift`.
7. **El hueco de `isFrozen` declarado en el mensaje del commit** (decisión: declararlo, no rescatar tests).

### 3.2 · Matriz de runtime del flaky del inbox (esta Mac, chip `task_262c41ed`)

Mide si el fallo de desmontaje del `fullScreenCover` depende de la **versión de iOS** o del **estado del simulador**, con un 2×2 y n≥5 por celda.

**Punto de partida real, y es una señal DÉBIL:** 2 fallos de test verificados en iOS 27.0 (ambos `InboxNewItemsModalUITests.swift:58`, con el umbral de 20 s ya puesto) contra **1 pase real en iOS 26.4 en 10,96 s**. La otra máquina midió 18/18 verde con el mismo commit.

> **RESULTADO (2026-07-28 18:10): ES el runtime — y mi lectura preliminar de las 15:30 era FALSA. La dejo documentada porque el error es instructivo.**
>
> **El veredicto, con la matriz 2×2 completa (n=5/celda, 20 corridas, 0 descartes por infraestructura, `-destination id=`, un solo `build-for-testing` ⇒ el compilador no entra como variable):** `viejo-26.4.1` 0 % · `virgen-26.4.1` 0 % · `viejo-27.0` **40 %** · `virgen-27.0` **20 %**. Por runtime **0/10 vs 3/10**; por estado del device 2/10 vs 1/10 ⇒ **el estado del device no tiene efecto y el confundidor queda roto.** Verificado aquí de forma independiente contra `runs2.csv` y los logs, no leyendo su informe.
>
> **Y lo decisivo NO es la tasa binaria, que es la evidencia débil: 3/10 vs 0/10 da p ≈ 0,11 por Fisher, no significativa.** La sesión hizo bien en no apoyarse en ella. Lo que decide es el reloj, en corridas que **pasan** y con la máquina en reposo:
>
> | | control (`PresentsOnLaunch`, no desmonta nada) | sujeto (`Dismisses`) | corrida completa |
> |---|---|---|---|
> | iOS 26.4.1 | **6,2–6,4 s** clavados | 8,6 s | 30–32 s |
> | iOS 27.0 | **11,4–13,6 s** | 15,3–17,6 s | 54–61 s |
>
> **iOS 27.0 (beta) es ~1,9× más lento para todo el ciclo de vida de UI**, no solo para el desmontaje. El desmontaje es donde el umbral se rompe primero, no la causa.
>
> **Por qué mi instrumento de las 15:30 era inválido, que es la lección.** Normalicé el sujeto contra el control asumiendo que el control solo pagaba **carga de máquina**. Falso: el control paga carga **y** la lentitud del runtime. Así que dividí el efecto por sí mismo — mi cociente sale **1,37 en 26.4 y 1,38 en 27.0**, idéntico, y de ahí concluí «no hay efecto de runtime». El efecto vivía en el denominador que tiré. **Un control solo sirve si es inmune al tratamiento; éste no lo era.** Y mi «iOS 26.4 también falla» era `pilot-264.log` corriendo con el load a ~900: con la máquina quieta, 26.4 queda 0/10 en la matriz y 9/9 en validación. Instrumento correcto = el reloj absoluto de un caso que no desmonta nada, que es más simple que el mío.
>
> **DEBAJO HAY UN BUG DE PRODUCTO, y eso es lo que cambia la naturaleza del ticket.** Con la aserción reescrita a interactividad real y **10 reintentos de tap a lo largo de ~40 s, el Panel no responde a NINGUNO** — falla en `InboxNewItemsModalUITests.swift:88`, «El Panel no responde a NINGÚN tap tras cerrar el modal (cover pegado — bug 2.0.5)». En iOS 27.0 eso pasa **~1 de cada 3 arranques**: el usuario descarta el aviso de bandeja y la app se queda inservible. No es nuevo como clase — `ContentView.swift:551` ya documenta el «cover fantasma invisible que bloquea toda la UI»; se parcheó una vez y en 27.0 volvió. **Refutado con medición**: `allowsHitTesting(isVisible)` (`InboxAlertModal.swift:59`) impide que el backdrop capture el tap **para sí**, pero NO lo hace atravesar al Panel mientras el cover sigue montado — `fab_new_transaction` está en el árbol de accesibilidad a 1,9 s y aun así el menú no abre.
>
> **El test quedó MÁS tenso, no más flojo** (criterio 4 superado, no solo cumplido): antes cronometraba el desmontaje y solo comprobaba que el FAB *existiera*; ahora reintenta el tap y exige que el menú abra y que el formulario se monte. Cambió un reloj por una propiedad. `lastVerified` se queda en `2026-07-12` (criterio 5) y el flaky **no cierra**: 3/9 en 27.0 con el fix, contra 2/5 sin él — diferencia no significativa, y la sesión corrigió su propio `1/6` inicial al ampliar n.
>
> **La hipótesis de fix no tiene una sola medición a favor, y hay que decirlo.** Proponen gatear el drenaje de `.showInboxAlert` por «arranque completado» en vez de solo «anchor libre». Pero el test **ya espera `uitest_ready` antes de descartar** y sigue cayendo 3/9. Ellos lo anticipan (esperar ready en el test retrasa el **tap**; gatear en la app retrasaría el **montaje** del cover, que es distinto), y es coherente con que `ShellReadinessState` ya exista — pero sigue siendo hipótesis. **Experimento barato que la zanja antes de tocar lógica de producción:** el cover se encola desde `AppBootstrapper.swift:655` y `:1300` bajo `UITestHooks.showInboxAlert`; retrasar **ese submit** hasta readiness, solo en la ruta de uitest, mide si el momento del montaje es la causa en una tanda. Verde 9/9 en 27.0 ⇒ el gate de producción está justificado; sigue 3/9 ⇒ la causa está en otro sitio y se ahorra el fix.
>
> **Lo único que sobrevive intacto de mi nota de las 15:30, porque sigue siendo cierto y útil:** el regex de `latencies.py` (`Test Case '-\[(\w+)[. ]+(\w+)\]'`) **no matchea nada** — el nombre entre corchetes trae TRES partes (`Target.Suite test_nombre`) y ese patrón solo consume dos. Patrón bueno: `'-\[[\w.]+ (\w+)\]'`. Script con la normalización (inválida como instrumento, pero correcta como parser) en `evidencia-2026-07-28/ratio-normalizado-por-control.py`.
>
> **Dato operativo para los gates:** un rojo de esta área en iOS 27.0 tarda **11–13 min de reloj** (~66 s de tests + ~600 s de teardown colgado de `xcodebuild`, solo en 27.0). Cualquier timeout por debajo de ~15 min reporta «timeout» en vez de «fallo de test» — pasó aquí al sellar.

**Criterios de validación:**

1. **Celdas completas y bien clasificadas.** n≥5 útiles por celda, y cuántas corridas descartó por infraestructura. Sin eso la conclusión no se sostiene en ninguna dirección.
2. **Que el confundidor esté roto**: tiene que existir la celda «device recién creado en iOS 26.4». Es la única que separa runtime de estado del device.
3. **Que «no hay efecto» siga siendo aceptable.** Con 2 contra 1, un veredicto rotundo a favor del runtime exige mirar los números de cerca — es el escenario donde una sesión encuentra lo que se le sugirió.
4. **Si toca el test**, que lo que quede afirmado siga protegiendo del bug «toolbar muerta» de TestFlight 2.0.5. Subir relojes es fácil; la red tiene que seguir puesta.
5. **Que `lastVerified` de `inbox-new-items-modal` solo suba si queda verde de verdad** (hoy en `2026-07-12` a propósito), limpiando entonces la nota de «EN INVESTIGACIÓN» de su `coverage`.

**Si el veredicto es que el runtime es la variable**, deja de ser higiene de tests: es un `fullScreenCover` que tarda >1 min en desmontarse en el iOS más nuevo, con 2.1 saliendo con todo encendido. Pasa a la mesa de producto.

## 3.3 · Fase 1 — **YA VALIDADA (2026-07-28)**. Resultado y lo que deja

Aterrizó en `21dcd465` (gateway) + `5010db6a` (cliente) — los mismos dos commits que la sesión nombró `168de862`/`23382980`, rebasados al pushear. **Balance `+85 / −4.418`**: fase sustractiva de verdad.

**Validación independiente: los 12 criterios del §7 del brief se verificaron corriendo los greps aquí, no leyendo su informe, y coinciden uno a uno.** La TRAMPA 1 está bien resuelta —el guard de PULL de C-2 quedó en su forma reducida, el gemelo de `deletions` intacto y `pendingFreezeZoneIDs` con inserts y drenaje—, que era el riesgo principal porque no falla al compilar ni lo caza ningún test.

**Tres errores del BRIEF (no de la implementación), anotados para no repetirlos:**
1. **El UPDATE que el brief especificaba no es ejecutable.** `supabase-groups-staging.ddl:867` revoca `update on public.group_members` a `authenticated` y los goldens solo manejan JWTs de usuario. La sesión lo sustituyó por un co-member en `pendingApproval` vía el flujo real de invitación: misma rama `no_eligible_owner`, y **describe un escenario que sobrevive a 2.1** mientras el placeholder `user_id NULL` era artefacto de la migración que se borra. **Mejor que la especificación.**
2. **`awaitPersonalStoreReady` esperado 11, real 10.** Los DOS bloques borrados (beacon y uploader) llevaban su llamada; el brief solo contó la del beacon. La afirmación de fondo se sostiene: solo uno de los dos era alcanzable en producción, así que el cambio de comportamiento declarado sigue siendo exactamente uno.
3. **Tres off-by-one** en coordenadas del brief: `:690` no `:691` · `:1458` no `:1457` · `:2617` no `:2616`. Si se reutilizan sus coordenadas en otra fase, re-comprobar siempre.

**Refutaron el argumento de la secuencia, y tenían razón.** El brief justificaba «cerrar el gateway primero» diciendo que evita un retry-loop. Es media verdad: `GroupsMembershipClient.swift:268` mapea el 404 a `.transient` y `neverRetryTransient` (`:190`) solo exime a `create_group`/`create_group_invite`, así que un build viejo evitaría PostgREST pero **sí reintentaría 3 veces por llamada**. Impacto hoy: cero. El orden sigue siendo correcto; el argumento, no.

**El hueco de cobertura es MAYOR de lo previsto.** `GroupMigrationStateTests.swift` llevaba **dos** suites, así que quedan **tres** piezas vivas sin cobertura unitaria: `GroupFreezeLogic.isFrozen`, `GroupFreezeLogic.migrationState` y `GroupBackendCapability.resolve`. Declarado en el commit y en el índice con la condición explícita: **aceptable SOLO porque las tres mueren en la Fase 4, que va antes de 2.1. Si la Fase 4 se retrasa, deja de serlo y hay que reabrirlo.**

**Runbook de despliegue escrito y NO ejecutado** (confirmado): `deploy:staging` → `deploy:production` → verificar que `POST /groups/rpc/migrate_group` con JWT válido da **404 `yala_bad_request` esperando ≥30 s** (hay ~15 s de 404-con-envelope por propagación de Cloudflare: un 404 inmediato no prueba nada). `public.migrate_group` **se queda en la base**, inerte. Y el deploy de `clientCapability`/`clientCapabilityAt` a CloudKit Production queda **CANCELADO, no aplazado**.

## 4 · Abierto, por orden de urgencia

| # | Qué | Estado |
|---|---|---|
| **0** | **BLOQUEANTE DE RELEASE 2.1 — el cover del aviso de bandeja se queda PEGADO y la app no responde.** En iOS 27.0, ~1 de cada 3 arranques: se descarta el aviso, el `fullScreenCover` no se desmonta y **el Panel ignora 10 taps a lo largo de ~40 s**. Es funcionalmente la «toolbar muerta» del 2.0.5 ya publicado, así que no es teórico: esa clase de fallo YA costó un incidente en producción. **Hoy el impacto directo se limita a quien esté en la beta de iOS 27, pero 2.1 seguirá viva cuando 27 salga en público** ⇒ hay que arreglarlo antes, no después. Palanca propuesta (hipótesis fundada, **sin una sola medición a favor todavía**): gatear el drenaje de `.showInboxAlert` por «arranque completado» y no solo por «anchor libre», encajándolo en `ShellReadinessState`. **Antes de tocar producción, correr el experimento barato del §3.2** (retrasar el submit de `AppBootstrapper.swift:655`/`:1300` solo en la ruta de uitest). Reporte a Apple justificado por separado, pero no resuelve: un runtime beta no arregla el 2.0.5 publicado. Lista Negra con dueño @jur y deadline 2026-08-11 | **ABIERTO — bloquea 2.1** |
| 1 | **Se desplegó a producción sin autorización** (`92b727a6`): migración `0002` aplicada a `yala-gateway-production` y Worker en `8a1448c9`. Arrastró `e172d4bd`, cuyo propio mensaje decía `wrangler.toml=0, SIN deploy` ⇒ **el mecanismo de actualización forzada quedó publicado** (`minSupportedBuild` en 0, fail-open, nadie forzado). **Decisión pendiente: ¿revertir el Worker a la versión previa?** | sin decidir |
| 2 | **Staging roto**: la migración `0002` no se aplicó allí, y en staging `isConfigured` SÍ es true (`DEV_BUILD`) ⇒ `accountTier` ejecuta el SELECT sin guardia y `register`/`assert` devuelven 500. Es donde se hace dogfooding | sin arreglar |
| 3 | **`CloudBackendConfig.swift:22` tiene un comentario FALSO** que dice «el proyecto de producción no existe aún». El proyecto **SÍ existe** (corrección del owner). Ese comentario ya indujo un error propagado a 3 documentos | pendiente de corregir |
| 4 | **Bloqueante #1 de 2.1**: cablear URL + anon key de producción en `CloudBackendConfig` (vía `Secrets.xcconfig`, nunca hardcodeadas) y verificar schema desplegado y PITR. **Es código, no infraestructura** | pendiente |
| 5 | La allowlist `PRO_PRODUCT_IDS` del gateway está en el camino de pago de todos los usuarios **sin un solo test**. Verificado que los IDs coinciden con `StoreKitManager` ⇒ no hay bug vivo; el hueco es cobertura de drift (~35 líneas). El owner NO autorizó escribirlas | sin decidir |
| 6 | **`_meta.counts` de `qa/coverage-index.json` no lo valida nadie.** Higiene, Fase 1 y quizá la matriz tocan ese fichero: al integrar el segundo y el tercero hay que revisarlo a mano | vigilar al mergear |
| 7 | **Prosa FALSA en código, dejada por la Fase 1 al respetar su allowlist**: `CloudSyncFlags.swift:269` cita `GroupCapability.current` y `CloudSyncEngine.swift:2388` cita `liveGroupOutboxCount` — tipos que ya no existen. Y `SplitSyncManager.swift:1806` sigue explicando que «el rescate NO se consulta aquí». Tocar `.swift` dispara el gate con build de las dos schemes ⇒ hacerlo cuando la máquina esté libre, o colgarlo del siguiente commit que pase por ahí | pendiente, trivial |
| 8 | **2 tests rojos de `YalaTests`** registrados en la Lista Negra: `config_isConfigured_inTestScheme` y `secondaryEntry_killedByRemoteOff`. Preexistentes según la reproducción de la Fase 1 en worktree limpio; **NO re-verificados aquí**. Pista fuerte: el primero mira `CloudBackendConfig.isConfigured`, el mismo gate cuyo comentario de `:22` está obsoleto ⇒ puede estar pinneando la premisa vieja | ABIERTA, deadline 2026-08-04 |
| 9 | **4 keys de l10n huérfanas** (`groups.migrated.{migratingBanner,waitingBanner,waitingSectionTitle,waitingHint}` en `L10n.swift:1955/:1971/:1973/:1975` + sus 16 `.lproj`) y **2 vars write-only** (`zonesWithFailedFetchThisSession`, `enginesWithCompletedFetchCycle`). Son de la familia de la **Fase 4**; la Fase 1 hizo bien en no tocarlas | diferido a Fase 4 |
| 10 | 11 de los 17 estados huérfanos de la auditoría §4 siguen sin decisión, y el frente de **cablear `CKIdentityCapture`** fuera de la migración (invariante «¿está el container privado en uso?») | sin decidir |

## 5 · La lección de método, que es lo que más va a servir

**Hubo cuatro diagnósticos falsos en un día, tres míos.** El patrón es siempre el mismo: **leer señal en muestras de n=1 o 2, y confundir un fallo del entorno con un fallo del sujeto.**

1. Culpé al código de un build que solo estaba **bajo carga** (`ImportIntroSheet.swift:370`: errores de inferencia de tipos que eran un timeout del type-checker; mismo código, mismo DerivedData, 64 GB libres).
2. Escribí en la Lista Negra una **«regresión» con sospechoso nombrado** (`31dded30`) que el bisect refutó: el patrón real era verde/rojo/verde/rojo, o sea flaky.
3. Rompí el destino de los tests al **elegir qué simulador conservar por «cuál está arrancado»** en vez de por **runtime del SDK** — borré los `iPhone 17 Pro` de iOS 27.0 y las corridas murieron con exit 70 sin ejecutar nada.
4. Monté una matriz que **se rompió sola** por apagar el simulador entre corridas, y cuyo regex etiquetó «NO EJECUTÓ» una corrida que sí falló — envenenando después un recuento ajeno.

Y una quinta, de la misma familia: **tomé como hecho un comentario del código** («el proyecto de producción no existe aún») y lo propagué a tres documentos. Confundir «mi instrumento no lo ve» con «no está» — igual que con el MCP de Supabase, que solo ve **una Org a la vez**.

La otra sesión cometió el mismo error con su hipótesis del flag de paralelismo (11/11 contra 1/4) y **se autorrefutó con seis corridas alternadas**. Ese es el estándar.

⇒ Las reglas durables que salieron de esto están en **`.claude/rules/testing.md`**, sección «Entorno del simulador (antes de culpar a un test)»: el device debe casar con el runtime del SDK · no apagar el simulador entre corridas · **clasificar por exit code ANTES de leer el output** (65 = fallo de test · 70 o cero líneas `Test Case` = infraestructura). Y la de este documento: **guardar la salida COMPLETA de cada corrida y clasificarla antes de contar**.

## 6 · Política de alcance para los próximos chips

Sale de [[MODO-NUBE-REVISION-TANDA1-ALCANCE]] §8, y el owner la pidió explícitamente («demasiado código en vano»). Las reglas del repo **no** explicaban el volumen: `coverage-index` + `.claude/rules` costaron 85 líneas de 6.823.

- Techo explícito de **líneas de producción NUEVAS** por chip, dicho en el brief.
- **Nada de ficheros de lógica pura nuevos** con su suite exhaustiva (fueron el 29 % de la tanda) sin justificarlo.
- **Cero canarios y breadcrumbs** que no puedan emitir (~180 líneas), **cero tests que afirmen texto fuente** (~150), **cero doc-comment de relleno** (~700: había más doc que código).
- **Cero l10n en superficies inalcanzables** (se localizó copy en 17 locales para pantallas que nadie podía abrir).
- **Prohibido arreglar de paso** lo ajeno a la tarea: si aparece un bug, se REPORTA.
- **Ninguna acción de infraestructura sin OK explícito en el turno.**
- Y la precedencia: **una decisión ratificada pero sin implementar gana** sobre lo que el código diga hoy.
