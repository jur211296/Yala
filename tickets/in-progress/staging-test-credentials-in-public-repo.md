---
id: staging-test-credentials-in-public-repo
status: in-progress
priority: high
area: cloud
created: 2026-08-31
updated: 2026-09-01
---
# Las credenciales de los usuarios de test de staging están en el repo público

`jur211296/Yala` es **público** (`gh repo view` → `visibility: PUBLIC`). Las contraseñas de
las tres cuentas de test del Supabase de staging (`i5-user-a`, `i5-user-b`, `i5-user-c`
@test.yala) están escritas en claro en el árbol, junto a la `SUPABASE_ANON_KEY` y la URL del
proyecto. Con esas tres piezas, cualquiera puede pedir un JWT por password-grant y hablar con
el backend de staging como usuario autenticado. Lo que vea después lo limita RLS, no la clave.

No es catastrófico —son cuentas sintéticas en staging, sin datos reales— pero es una puerta
abierta a un backend real, y cerrarla es barato.

## Estado al 2026-09-01

**El paso 1 ya está hecho: Jürgen rotó las tres contraseñas** en Supabase staging el 2026-08-31 y
confirmó que **no actualizó el árbol**. O sea: lo que sigue escrito en el repo público son las
contraseñas **antiguas**, que ya no autentican.

Eso cambia la naturaleza del ticket. **Deja de ser urgente por seguridad** —la puerta al backend
ya está cerrada— y pasa a ser higiene, con dos cabos sueltos concretos:

**1 · Cuatro exenciones vivas en la allowlist, que son un punto ciego.** Para desbloquear el
PR #52 se añadieron a `~/.claude/hooks/secretos-permitidos.txt` las 4 rutas de los tests Swift,
acotadas al patrón `par clave/valor`. Con las contraseñas muertas es correcto —esa lista significa
«he mirado esto y no es un secreto»—, pero **mientras duren, el hook no mira ahí**: si alguien
escribe las contraseñas NUEVAS en esas líneas, no las verá. **Esas 4 líneas se retiran en el mismo
movimiento que saque las credenciales al entorno, no después.**

**2 · Los 4 tests E2E de Swift ahora fallan si se lanzan.** Hacen login por password-grant contra
credenciales rotadas. **No hay rojo en CI**: llevan guarda `@Test(.enabled(if:))` sobre
`YALA_CLOUD_E2E == "1"` y ningún workflow de `.github/` define esa variable. Sólo revientan si
alguien los corre a mano. Lo mismo cabe esperar de los `.sh` y los `.ts`, que no se comprobaron.

Y conviene no perder de vista lo que ya avisaba el inventario: **el hook sólo veía 4 de las ~25
apariciones**. Las otras 21 —`.sh`, `.ts`, documentación— nunca estuvieron protegidas por él, ni
lo están ahora. El arreglo de este ticket es lo único que las cubre.

## Inventario medido (2026-08-31)

~25 apariciones en 16 ficheros. Las contraseñas NO se transcriben aquí a propósito.

| Dónde | Forma |
|---|---|
| `YalaTests/CloudSync/{PrefsSync,CloudSync,MigrationCutover,CloudAccountClaim}E2EStagingTests.swift` | literal JSON en el `httpBody` de `login()` |
| `qa/cloud/{cross-user-rls,cross-member-rls,pgcrypto-spike,push-e2e}-test.sh` | valor por defecto de `${USER_x_PASS:-…}` |
| `gateway/test/{sync,push.fanout,groups,account}.goldens.test.ts` | argumento literal de `login(…)` |
| `qa/cloud/README.md`, `qa/cloud/g3_02_*.sql` | documentadas en el texto |
| `docs/modo-nube/_archive/{groups-backend-v1,MODO-NUBE-HANDOFF-2026-07-28}.md` | citadas en archivo histórico |

**El hook de secretos solo ve 4 de las ~25.** Su patrón `par clave/valor` exige la forma
`"password":"…"`, así que caza los tests Swift y se le escapan los `.sh` (usan `A_PASS=`, no
`PASSWORD=`), los `.ts` (argumento posicional) y la documentación. Un tercer usuario,
`i5-user-c`, no aparecía en ningún hallazgo. Conviene no leer ese informe como cobertura.

## Trabajo

1. ~~**Rotar primero** las tres contraseñas en Supabase staging.~~ **HECHO el 2026-08-31**
   (Jürgen). Era lo único urgente: sacarlas del código sin rotar no habría cambiado nada, porque
   el histórico del repo público las conserva y reescribirlo no las desactiva.
2. ~~Sustituir los literales por lectura de entorno en los tres frentes (Swift, `.sh`, `.ts`).~~ **HECHO el 2026-09-01** (ver «Implementación» abajo).
   Los tests Swift ya están gateados por `YALA_CLOUD_E2E=1` y los `.sh` ya aceptan
   `USER_A_PASS`, así que la forma existe: lo que falta es quitar el valor por defecto.
   Al construir el cuerpo JSON, evitar `"password":"\(var)"` — el patrón del hook lo seguiría
   viendo; usar un diccionario y `JSONSerialization`.
3. ~~Documentar en `qa/cloud/README.md` qué variables hay que exportar para correr la batería.~~ **HECHO el 2026-09-01** — sección «Credenciales» al inicio.
4. ~~Decidir qué hacer con las citas del `_archive/`~~ **DECIDIDO: se quedan.** Ya rotadas,
   quedan inertes y valen como registro histórico. Sigue habiendo 1 cita en
   `docs/modo-nube/_archive/MODO-NUBE-HANDOFF-2026-07-28.md:180`.

## Notas

- La `SUPABASE_ANON_KEY` que está al lado **no** es un hallazgo: verificado que los 16 JWT del
  repo llevan `role: anon`, ninguno `service_role`. Es pública por diseño.
- **Obsoleto desde el 2026-08-31:** estas 4 apariciones bloqueaban cualquier subida al remoto, y
  se había decidido **no** exentarlas porque eran credenciales reales. Tras la rotación dejaron de
  serlo —son cadenas muertas— y se exentaron con permiso explícito de Jürgen, acotadas al patrón.
  Ver el bloque «Estado al 2026-09-01» arriba: **retirar esas 4 líneas es parte del punto 2**, no
  un paso posterior.

## Implementación (2026-09-01, rama `fix/staging-creds-al-entorno`)

**Nombres de variables:** se reutilizan los que ya existían en los `.sh` — `USER_A_PASS`,
`USER_B_PASS`, `USER_C_PASS` (esta última opcional). No se inventó un juego nuevo.

| Frente | Qué se hizo |
|---|---|
| Swift (4 tests) | Punto único de lectura en `YalaTests/CloudSync/StagingTestCredentials.swift`. El cuerpo del password-grant se serializa con `JSONSerialization` (interpolarlo reintroduciría el patrón literal). El gate `@Test(.enabled(if:))` exige **además** la contraseña ⇒ sin ella los tests salen *skipped*, no rojos. |
| `.sh` (4) | Fuera el valor por defecto: `${USER_X_PASS:?…}` mata el script nombrando la variable, antes de tocar la red. El user C pasa a opcional de verdad (`${USER_C_PASS:-}`) y su bloque se salta si falta — el sub-caso ya caía de vuelta a B. |
| `.ts` (4) | Helper local `testUser()` por fichero (el árbol del gateway no comparte helpers entre tests), invocado **dentro** del `beforeAll` para que importar el fichero nunca lance. `sync` y `account` necesitaron además el `declare const process` que `groups`/`push.fanout` ya tenían. |
| `qa/cloud/README.md` | Sección «Credenciales» al inicio (qué exportar, y la forma `TEST_RUNNER_` para xcodebuild). Fuera la contraseña en claro de la receta de siembra de B. |
| Allowlist del hook | Retiradas las 4 exenciones `par clave/valor` de `~/.claude/hooks/secretos-permitidos.txt`, con nota de por qué ya no hacen falta. Las 4 de patrón `jwt` **se quedan**: son la anon key, pública por diseño. |

### Verificado (medido, no inferido)

- **Swift, las dos mitades del gate.** Sin credencial: 12 tests en 4 suites *skipped* en 0.001 s
  (sin tráfico). Con `USER_A_PASS` presente (valor falso): el test **se activa**, corre 1.29 s e
  intenta el login real. El gate discrimina — los tests no quedaron muertos.
- **`.sh`**: sin la variable muere en la línea 21 nombrándola, antes de cualquier `curl`.
- **`.ts`**: `beforeAll` lanza con el mensaje explícito; 29 tests *skipped*, sin red.
- **`npm run typecheck` del gateway**: 3 errores, **los mismos 3 que en el árbol limpio**
  (medido con `git stash`) — en `groups.consent.test.ts` y `wrangler.forceupdate.test.ts`, que
  este ticket no toca. El cambio no añade ninguno.
- **`build-for-testing`** del scheme Yala: exit 0, sin errores.

### Nota sobre el alcance real de retirar las exenciones

El hook de secretos **ya no está registrado en ningún `settings.json`** (medido el 2026-09-01;
se retiró del push ese mismo día por el ADR-009 de casa). Así que retirar esas 4 líneas hoy **no
cambia nada operativo**: no había escáner mirando. Se retiran igual porque son la parte del
ticket que evita que el punto ciego reaparezca si alguien reactiva el hook, y porque su bloque de
comentario afirmaba que la rotación no estaba medida — cosa que dejó de ser cierta el 2026-09-01.

### Fuera de alcance (consciente)

- La cita del `_archive/` (decisión 4 arriba).
- Los emails de las cuentas: conservan valor por defecto con override. Son cuentas sintéticas de
  staging, no un secreto, y sacarlas al entorno habría inflado el cambio sin cerrar nada.
