---
created: 2026-07-03
updated: 2026-07-03
tags: [modo-nube, estrategia, release, dark-shipping, versionado, no-regresion]
---

# Modo Nube — Estrategia de versionado, dark shipping y garantía de no-regresión de 2.x

Cómo se desarrolla el Modo Nube (destino **3.0**) EN PARALELO a la línea 2.x (bugfixes, mejoras, vistas nuevas) sin ramas de larga vida y **sin romper la app actual**. Complementa [[modo-nube-epic]] y el plan de incrementos de [[MODO-NUBE-ARQUITECTURA]] §5.

## 1. Modelo de release: un solo trunk + dark shipping

- **NO se abre una rama 3.0 de larga vida.** El motor toca modelos, onboarding, bootstrap y `PreferenceSyncService` — los mismos archivos que los fixes de 2.x. Una rama que diverge de un 2.x en movimiento durante meses = infierno de merges (peor con un solo dev).
- Se trabaja sobre la **misma línea de release** que hoy. Cada incremento (I0–I14) se mergea **DARK**: código presente en el binario pero **inerte** hasta encender el flag.
- Se sigue publicando 2.0.5, 2.1, etc. con el código del modo nube dormido dentro. Los fixes/vistas de 2.x son trabajo normal del trunk, sin afectarse.
- **"3.0" = el release donde se enciende `cloudModeEnabled`.** Incluso puede encenderse por remote-config sin binario nuevo, tras validar en TestFlight.
- Ramas cortas por incremento (PR normal, merge rápido). Nunca una rama de integración larga.

## 2. Los interruptores de encapsulación

| Interruptor | Default en prod | Qué gatea |
|---|---|---|
| `cloudModeEnabled` (remote-config plano) | **OFF** | TODA entrada al modo nube (botón migrar, activación del motor). Off = el usuario no lo ve. |
| `cloudOnboardingChoiceEnabled` (§j.1) | **OFF** | La pantalla de elección privacy-first-vs-nube en onboarding. Se enciende en un escalón POSTERIOR a validar migración. |
| `storageMode` (.icloud / .cloud) | **`.icloud`** | El `CloudSyncEngine` solo corre en `.cloud`. Para todos los demás, la app se comporta idéntica a 2.x. |
| Worker `ENFORCE` (observe/enforce) | **observe** | Los endpoints `/sync/*` del Worker. iOS no los llama hasta que el flag se encienda. |
| `DEBUG` / scheme Yala Dev | — | El flag arranca ON en Yala Dev/DEBUG para desarrollo y tests, OFF en Release/prod. |

**Aislamiento de código:** todo el modo nube vive en una carpeta/namespace propio (ej. `Yala/CloudSync/`) — fácil de revisar, razonar y excluir mentalmente. Los componentes nuevos (CloudSyncEngine, SyncIdentity/Outbox/Cursor, la pantalla de elección) viven ahí.

## 3. ¿Puede romper la app actual durante el proceso? — Análisis honesto

**El flag protege el RUNTIME: con `cloudModeEnabled=OFF` y `storageMode=.icloud`, el motor no se ejecuta y la app se comporta como 2.x.** PERO hay **tres cosas que llegan a TODOS los usuarios aunque el flag esté off** — no son gateables por un flag de runtime porque son estructurales o compartidas. Estos son los ÚNICOS vectores reales de romper 2.x, y cada uno tiene su regla de mitigación:

### Vector A — Migración de schema SwiftData (llega a todos)
Añadir `syncID?` + campos de tombstone a los modelos de dominio + los 3 `@Model` nuevos dispara una migración lightweight en CADA usuario, aunque el feature esté off.
- **Riesgo si se hace mal:** una migración no-lightweight (campo no-opcional, default obligatorio, cambio incompatible) puede FALLAR al arrancar = crash-loop / pérdida de datos para TODOS.
- **Regla:** estrictamente ADITIVO. Campos `Optional`, SIN default obligatorio, SIN `@Attribute(.unique)` (reglas CloudKit-compat que el repo ya sigue). Las 3 tablas de bookkeeping (`SyncIdentity`/`SyncOutbox`/`SyncCursor`) van **`cloudKitDatabase: .none` (local-only)** → no tocan CloudKit. Probar la migración sobre una copia de datos reales antes de publicar.

### Vector B — Deploy de schema CloudKit Production (el más filoso — ya nos quemó)
En 2.x el store personal sigue espejado a CloudKit. Cualquier campo nuevo en un modelo personal (`syncID`, tombstone) se mirror-ea al container personal `iCloud.com.jurgenschmidt.yala`.
- **Riesgo si se hace mal:** si el campo se añade al modelo pero NO se despliega al schema de **Production**, CloudKit RECHAZA todo save de ese record type → **sync personal muerto BIDIRECCIONAL y silencioso** (idéntico al incidente `isOpeningBalance` de la saga de Grupos: 4 días de sync muerto invisible; CKSyncEngine descarta el rechazo definitivo sin reintentar).
- **Regla (ya en CLAUDE.md para Grupos, ahora aplica al container personal):** desplegar el campo nuevo a Production en el **MISMO release** que lo introduce (append-only, CloudKit Console) + crear un **test de paridad del container personal** análogo a `CloudKitGroupsSchemaParityTests` que cruce los campos de los modelos personales contra un snapshot del schema vivo → un campo sin desplegar rompe CI, no producción. Este es el incremento I2 del plan; no se publica I2 sin el deploy + el test verde.

### Vector C — Cambios en código compartido (llega a todos por el path `.icloud`)
El diseño modifica componentes compartidos: `PreferenceSyncService` (rama por `storageMode`), `AppBootstrapper` (`awaitPersonalStoreReady`), la purga de persistent history, `WelcomeFlow` (pantalla intermedia nueva), `FullModeActivationView`, y la asignación de `syncID` en App Intents (Apple Pay/Siri — feature viva recién arreglada).
- **Riesgo si se hace mal:** un bug en la rama `.icloud` de un path compartido rompe a los usuarios actuales aunque el modo nube esté off.
- **Regla:** la rama `.icloud` debe quedar **idéntica al comportamiento actual**. Los cambios son ADITIVOS: `if storageMode == .cloud { nuevo } else { comportamiento-existente-intacto }`. Cada cambio a un path compartido lleva un test que prueba que el path `.icloud` NO cambió. La purga de history del motor coordina con CloudKit/Grupos (regla del consumidor más conservador, spike I0-S2) para no invalidar el token del mirror y reabrir crashes de quiescencia.

### Vectores que el flag SÍ cubre del todo (no rompen 2.x)
- El `CloudSyncEngine`, la migración, la reversa, el sign-in, los endpoints del Worker: inertes con el flag off. No se ejecutan.
- Dependencias nuevas en el binario (Supabase SDK, entitlements de Sign in with Apple/Google): presentes pero no invocadas → sin efecto en runtime. (Verificar que el entitlement no altere el build/firma — chequeo estándar.)

## 4. Checklist de "release dark seguro" (por cada versión 2.x que lleve código nuevo del modo nube)

Antes de publicar CUALQUIER 2.x que incluya un incremento nuevo:
- [ ] `cloudModeEnabled` y `cloudOnboardingChoiceEnabled` confirmados **OFF** en la config de prod.
- [ ] `/verify-ios` verde en **ambos** schemes (Yala + Yala Dev).
- [ ] `/test-smart` verde, incluidos los tests que prueban que el path `.icloud` NO cambió.
- [ ] Si el incremento tocó modelos personales (Vector B): **schema CloudKit desplegado a Production** + `CloudKitPersonalSchemaParityTests` verde.
- [ ] Migración de schema probada sobre datos reales (Vector A) — arranque limpio, sin pérdida.
- [ ] `/device-qa`: confirmar que la app en modo `.icloud` (el 99% de usuarios) se comporta idéntica — onboarding, sync CloudKit, App Intents, widgets, Grupos.
- [ ] Flujo Complejo del repo por incremento (Plan Mode → review-plan → verify → test → code-review → device-qa → commit).

## 5. El prerequisito `.groupInvite` (código vivo, no gateado)
El fix del bug prod `.groupInvite` NO es dark ni gateado — es un fix a la ruta de sync de Grupos que ya está en producción, beneficioso por sí mismo. Se hace como ticket propio ANTES de arrancar Fase 4, con su propio testing + device-QA cross-device (es cambio a sync vivo → tratar con el rigor de la saga de Grupos).

## 6. Cadencia y encendido
- I0–I8 se mergean DARK sin exponer nada.
- Tras I11 (migración + reversa validadas), `cloudModeEnabled` se enciende **solo para el owner** (dogfooding en TestFlight).
- Luego beta cerrada (mide volumen de escritura en `observe`, gate de costo §j.2 del diseño).
- Luego % gradual. `cloudOnboardingChoiceEnabled` (born-cloud) se enciende en un escalón POSTERIOR — la migración se valida primero.
- El release donde el flag queda ON para el público general **es 3.0**.

## Resumen en una línea
El flag garantiza que el modo nube esté **inerte** para los usuarios de 2.x. Lo que NO cubre el flag —migración de schema, deploy de schema CloudKit, y cambios en código compartido— se neutraliza con: **aditivo + opcional + CloudKit-compat + deploy-en-el-mismo-release con test de paridad + rama `.icloud` intacta + verify/test/device-QA por release**. Con esa disciplina, el proceso no rompe la app actual; sin ella, el Vector B es exactamente cómo se rompería.
