---
created: 2026-07-28
updated: 2026-07-28
tags: [modo-nube, decision, release, 2.1]
---

# Modo Nube — Decisión de release: todo en 2.1, encendido, sin escalonado

> **SUPERSEDE [[MODO-NUBE-ESTRATEGIA-RELEASE]] por completo.** Ese documento describe dark shipping sobre trunk único con `cloudModeEnabled` apagado y publicación de 2.x con el código dormido. **Eso ya no es el plan.** Lo único que sobrevive de él son los **3 vectores de no-regresión** (migración de schema SwiftData · deploy de schema CloudKit · código compartido) y su checklist: siguen aplicando, porque un usuario de 2.1 que NO migre debe seguir funcionando igual que en 2.0.

**Decisión del owner (2026-07-28), textual:** «todo lo que estamos montando en 2.0.5 será directamente release 2.1 con flag encendida y todo ON, ya no haremos escalonado. Todo de una, con pruebas en TestFlight primero. Todo en v1. Ya no aplacemos nada ni pensemos que subiremos una versión en dark.»

## Qué significa, operativamente

| Antes (dark shipping) | Ahora (2.1 encendido) |
|---|---|
| Se mergea inerte tras el flag; se publican 2.x con el código dormido | **2.1 sale con los flags ON**; no hay versión intermedia dormida |
| El encendido es un evento futuro, separado del release | **El release ES el encendido** |
| Un hallazgo DARK es deuda futura | **Un hallazgo DARK es un bloqueante de release** |
| Rollout escalonado por % con kill remoto | **Todo de una vez**, TestFlight primero y luego App Store |
| «Diferir a post-v1» era una salida válida | **Ya no se aplaza nada**: entra en v1 o no existe |

## Consecuencias inmediatas, y dos son duras

1. **Cablear el cliente contra el Supabase de PRODUCCIÓN es el bloqueante #1 de 2.1** — y es **código, no infraestructura**. Hoy `CloudBackendConfig.supabaseURL` y `anonKey` devuelven `nil`/`""` fuera de `DEV_BUILD` (`Yala/App/Services/CloudBackendConfig.swift:23-44`) ⇒ `isConfigured == false` ⇒ toda la superficie de nube y auth está inerte en un build de producción. **Lo que falta es meter la URL y la anon key de producción** en la rama `#else` de ese mismo fichero — **dos líneas**. **Corrección 2026-07-28: NO van por `Secrets.xcconfig`**, como decía la versión anterior de esta línea. La cabecera de `CloudBackendConfig.swift` documenta a propósito el patrón contrario («commiteada, per-scheme, SIN secretos… la `anonKey` es PÚBLICA por diseño… NUNCA la `service_role`»): es una JWT de rol `anon` gobernada por RLS, una clave *publicable*, y la de staging ya viaja commiteada en `:34`. La regla de CLAUDE.md sobre no hardcodear apunta a **secretos**, y ésta no lo es. Inspeccionado el 2026-07-28: el schema de producción está desplegado (18 migraciones, hasta `g10`); **queda por verificar PITR**, que el conector MCP no expone.

   > **Corrección del owner, 2026-07-28: el proyecto Supabase de producción SÍ EXISTE.** La versión inicial de este documento decía que no, y era falso. El error vino de tomar como hecho un **comentario obsoleto dentro del código**: `CloudBackendConfig.swift:22` afirma literalmente «producción PLACEHOLDER vacío (el proyecto de producción no existe aún)». **Ese comentario hay que corregirlo** — es drift dentro del fichero que gobierna el gate maestro de toda la épica, y ya indujo a error una vez. Nota de método: el MCP de Supabase solo ve **una Org a la vez**, así que para inspeccionar el proyecto de producción hay que reconmutar el conector; no dar por inexistente lo que el conector no está mirando.
2. **`groupsBackendCompiledDefault` tiene que ir a `true`** (`Yala/Services/CloudSync/CloudSyncFlags.swift:239`, hoy `false` sin `#if`). El flag remoto se queda **solo como kill-switch**, no como palanca de rollout.
3. **El owner y Pia tienen que estar en el MISMO build.** Con Grupos migrando de CloudKit al backend, un usuario en 2.0.x y otro en 2.1 no se ven entre sí. Si el plan de simplificación borra el transporte CloudKit, los grupos compartidos entre ellos **solo funcionan cuando ambos estén en 2.1**.
4. **Todos los hallazgos DARK de [[MODO-NUBE-AUDITORIA-ESCENARIOS]] se reclasifican a bloqueantes de release.** Los 10 bugs del encendido de [[MODO-NUBE-DECISIONES-ESCENARIOS]] §9 dejan de ser «trabajo antes de encender» y pasan a ser «trabajo antes de subir a TestFlight».
5. **D-A2 queda resuelta y cerrada**: no hay flag propio para escalonar el muro de Grupos, porque no hay escalonado. Todo se activa junto.
6. **La verificación deja de ser opcional.** Con dark shipping un fix podía aterrizar sin probarse en device porque nadie lo ejecutaba. Ahora cada pieza necesita QA real en TestFlight antes de App Store. **El coste de un fix mal dimensionado ya no es solo código muerto: es riesgo en producción.**

## Lo que NO cambia

- Los **3 vectores de no-regresión de 2.x** siguen vigentes y son más importantes que antes: la rama `.icloud` de un usuario que no migra debe quedar **byte-idéntica**. «Todo ON» significa que la nube está *disponible y funcional*, no que todo el mundo se mueva.
- **D-A3** (borrar la zona del container privado personal al cerrar el cutover) sigue en pie, con su orden obligatorio `zona → verificar → mapa`.
- El **ratchet de `qa/coverage-index.json`** y la paridad de l10n en 16 locales siguen siendo obligaciones del repo.

## Migración de los usuarios actuales: **opt-in silencioso** (decisión owner, 2026-07-28)

**Decisión.** Los usuarios que hoy están en iCloud **no se mueven**. La migración vive en Ajustes («Dónde viven tus datos») y la usa quien la busque. Sin prompt, sin banner, sin campaña.

**Consecuencias aceptadas:**
- La app queda **bimodal de forma indefinida**: iCloud y nube conviven, y toda la complejidad de dos modos se mantiene para siempre (los ~10 gates de quiescencia, las dos rutas de wipe, los dos caminos de sign-out, el doble copy).
- En la práctica **casi nadie migrará**, así que la nube arranca con una población mínima. Eso hace que el valor inmediato del modo nube para usuarios existentes sea casi nulo — y es coherente, porque **la motivación de la épica nunca fue mover a los actuales**: fue habilitar web, IA server-side y multiplataforma (decisiones de Fase 0). El modo nube es una capacidad, no una campaña.
- **De dónde vendrá la población de nube, entonces: de los usuarios NUEVOS.** Por eso **D-A7 (born-cloud en v1) deja de ser opcional y se vuelve la pieza central del valor de 2.1** — es el único camino por el que la nube crece. Un born-cloud sin construir + opt-in silencioso = nube vacía.
- La regla de no-regresión sube de importancia: como la inmensa mayoría se queda en `.icloud`, **cualquier regresión en esa rama afecta a todos los usuarios reales** y el modo nube no compensa nada.

## Trabajo que esta decisión cancela

- Todo el andamiaje pensado para **escalonar el encendido**: rampas por porcentaje, gates de rollout parcial, y los hazards que solo existen cuando dos poblaciones corren builds distintos con el mismo backend.
- **Corrección (misma fecha, error de este documento):** la versión original decía que **C-10** («grupo congelado sin salida durante el rollout») estaba «ya descartado». **No lo estaba: estaba commiteado.** El chip se descartó en la sesión de auditoría creyéndolo sin sentido por el giro de Grupos, pero el trabajo ya había aterrizado — `90ebabea` (06:54, +1.405) y `ed38c1ea` (07:20, +1.845), **3.250 líneas**, once minutos antes de que se escribiera esta línea. No es trabajo cancelado: es trabajo **pagado que se tira**. Lo que sí se cancela es su cola (device-QA, 26 keys × 16 locales, la UI de espera y el deploy pendiente de dos field keys a CloudKit Production). Queda como el ejemplo más caro de por qué las decisiones de alcance tienen que llegar a los chips ANTES de que corran, no después.
- La cláusula «diferir a post-v1» de [[MODO-NUBE-DIFERIDOS]]: los items cuyo gatillo era «cuando se encienda» pasan a tener gatillo **«antes de 2.1»**. Revisar el registro entero con esa lente.

---

## D-R1 · Cómo se enciende el canal de Grupos — DECIDIDO por el owner el 2026-07-30

**En DOS pasos separados, y el encendido después de cerrar el bridge.**

**Paso 1 — la configuración, ya.** Solo el bloqueante #4: las dos ramas `#else` de `CloudBackendConfig`
(`supabaseURL` y `anonKey`), en su propio build a TestFlight. NO mueve ningún dato de Grupos —
`groupsBackendCompiledDefault` sigue en `false`. Lo que hace es volver **verificable** lo que hasta hoy se
configuró a ciegas en el proyecto de producción: el sign-in real con Apple y con Google, los Authorized
Client IDs, el schema, el `revoke` de `migrate_group` y el aviso de versión obligatoria (que hoy no emite
tráfico porque `CloudRemoteConfig.refreshIfDue` gatea por `isConfigured`).

**Paso 2 — el encendido, después del fix del bridge remoto.** El flip de
`groupsBackendCompiledDefault` a `true`, en un segundo build. Ahí los dos canales quedan vivos a la vez y
**el kill-switch remoto todavía funciona** (el flag remoto solo puede MATAR): es la única ventana para
probar el recorrido completo con un segundo humano en dos devices y poder apagarlo en segundos.

### Por qué separados, y no en un build

Son dos clases de fallo distintas: el paso 1 prueba INFRAESTRUCTURA, el paso 2 mueve DATOS reales.
Juntándolos, un fallo no diría cuál de los dos lo causó.

### Por qué el flip espera al bridge, y los 4 apagones NO lo bloquean

S2/S3/S4/S6 son consecuencias del **borrado** (Fase 3), no del encendido ⇒ no bloquean. El fix del bridge
remoto sí va antes, porque el flip mueve datos: **medido el 2026-07-30, ese defecto existe en los DOS
canales** — `GroupsSyncClient.scheduleBridge` (`:2009`) usa el mismo reintento en-sesión sin respaldo
persistente que `SplitSyncManager`. Encender antes de arreglarlo no lo empeora, pero pone datos nuevos
encima de un agujero conocido. **Corolario para el chip del bridge: su fix tiene que cubrir los dos
canales, no solo el viejo.**

### Descartado

- **Todo en un build**: más rápido, pero mezcla las dos clases de fallo.
- **Parar en la Fase 2** (que el plan admite como estado final válido): dejaría Grupos exigiendo iCloud a
  todos los miembros, que es exactamente lo que este épico existe para quitar.
