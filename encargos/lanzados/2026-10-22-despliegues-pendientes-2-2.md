Encargo Yala 2.2 · Despliegues pendientes (ops, sin compilar la app ni usar el simulador). Jürgen autorizó el 2026-10-22 a las 07:39, en su 1:1 con Frank, hacer TODOS los despliegues de 2.2, en staging y en producción. Cards del tablero (`tablero listar --proyecto yala --buscar desplegar` / `--buscar DDL` / `--buscar Worker`):
1) Aplicar el DDL g21_01 y desplegar el Worker v3 del Modo Nube.
2) Desplegar «cambiar el rol de un miembro» (g22_01 y Worker) en staging y producción.
3) Desplegar el Worker con el arreglo de la primera foto (PR #594, límite por minuto separado de la sincronización).
4) CloudKit: CD_amountChangesRaw a Development y Production, y CD_parentAccountID a Production. Si se puede con `cktool` y credenciales que ya existan, hazlo. Si no, deja los pasos exactos para el panel de CloudKit en un .md y la card asignada a jurgen.
Orden: staging primero, verifica (probes y smoke) y después producción, en el orden correcto entre migración y Worker. Si algo falla en producción, para, revierte si hace falta y explícalo. Haz un respaldo o snapshot antes de cada migración en producción.
Si te falta un permiso o una credencial (Cloudflare, Supabase o Apple), no inventes nada: déjalo anotado con el comando exacto para que lo ejecute Frank o Jürgen, y sigue con lo demás. El token de gestión de Supabase de ~/Secrets/yala-supabase-mgmt/pat está inválido; Jürgen va a rotarlo.
Nunca imprimas secretos. No toques tmux salud--, sat-lab-- ni clinicas-dentales-bi--. No toques en ~/Yala Yala.xcscheme ni encargos/pendientes/. La web de invitación NO entra aquí (espera a que 2.2 entre en 1.0).
Al terminar: mueve las cards (done o in qa a jurgen), digest en español neutro con qué quedó desplegado dónde y qué falta. /cerrar-total

## Paso 0

Medido al arrancar (2026-10-22), no heredado:

- **Credenciales.** wrangler tiene sesión con `workers (write)` en la cuenta de admin@yala-app.pe. El token de gestión de
  Supabase **responde 200** y lista staging y producción, aunque el encargo lo daba por inválido. `cktool` no está
  instalado como binario; se mide `xcrun cktool`.
- **Estado.** Staging: g18_01 aplicado, Worker `af424141` con `manifestVersion 2`. Producción: Worker `ea8206c8`
  (19-oct) sin `sync` en `/config`, es decir código de 1.0 y manifest v1; g18_01 y g21_01 sin aplicar.
- **PR #588 (g22_01 y `set_member_role`) NO está en 2.2**: abierto, en cola de auto-merge pero en CONFLICTO, con
  `tests` cancelado. `qa/cloud/g22_01*` no existe en 2.2.

Decisiones:

1. **g18_01 en producción entra en este encargo.** Es requisito de g21_01 (el Worker v3 sirve también la columna de v2)
   y la autorización cubre todos los despliegues de 2.2.
2. **Un despliegue de Worker por entorno, desde `origin/2.2` (5fb3a3f88).** Lleva a la vez v3 (#582), la primera foto
   (#594) y lo pendiente de `gateway/RUNBOOK.md`. Los cards 1 y 3 se cierran con el mismo deploy.
3. **Orden por entorno:** medir → DDL (g18_01 si falta, g21_01) → comprobar columnas → Worker → `/config` v3 → sonda y
   goldens (staging) o smoke sin escribir datos de usuarios (producción) → `wrangler tail`.
4. **Respaldo antes de cada migración en producción:** se apunta el último backup físico de Supabase (API de gestión)
   y se guarda una foto de esquema y conteos de `accounts` y `cashflow_lines`. Las dos migraciones solo añaden una
   columna nullable; su marcha atrás real es el `*_rollback.sql` de cada una y `wrangler rollback` al `ea8206c8`.
5. **Los teléfonos 1.0 no se rompen con el Worker v3:** mandan `X-Yala-Capability-Set: v1` y el Worker les poda las
   columnas posteriores (`resolveCapabilitySet`). Medido en `origin/1.0`.
6. **g22 (cambiar el rol de un miembro) no se despliega.** Desplegar un Worker desde una rama sin mergear dejaría la
   allowlist fuera de 2.2 en el siguiente deploy; resolver el conflicto de #588 es trabajo de código con gate, fuera
   de este encargo de ops. Se deja la card a Jürgen con los pasos exactos.
7. **CloudKit:** si `xcrun cktool` tiene token de gestión guardado, se hace; si no, guía `.md` y card a Jürgen.
8. **Asumido:** «aplicar» por la API de gestión (`/database/query`, rol `postgres`) equivale al SQL Editor que pide el
   runbook. Los avisos `raise notice` no vuelven por esa vía: la prueba es releer `information_schema` después.

## Resultado (2026-10-22)

| | Staging (`fostjbbwstyuunmmefuk`) | Producción (`kefvaiymtgytemwbltlz`) |
|---|---|---|
| g18_01 `accounts.parent_account_id` | ya estaba (18-oct) | **aplicada** |
| g21_01 `cashflow_lines.amount_changes_raw` | **aplicada** (y re-aplicada: idempotente) | **aplicada** |
| Worker (2.2 @ `5fb3a3f88`: v3 + primera foto + contador de «Eliminar mi cuenta») | `af424141` → **`043cdff6`** | `ea8206c8` → **`2e2c05c4`** |
| `/config` → `sync.manifestVersion` | 3 | 3 |
| Verificación | sonda g21 10/10, goldens sync 13/13, sonda g18 7/10 (los 3 rojos son su `== 2` literal) | columnas + grants, PostgREST las sirve (control negativo 400), smoke sin sesión igual que staging, tail sin errores (y sin tráfico) |
| g22_01 + Worker con `set_member_role` | **no** — PR #588 en conflicto, no está en 2.2 | **no** |
| CloudKit `CD_amountChangesRaw` (Dev+Prod) y `CD_parentAccountID` (Prod) | **no** — sin token de gestión; pasos en `docs/despliegue-cloudkit-2-2.md` | — |

Respaldo antes de migrar producción: backup físico del día `2037455155` (2026-10-22 07:50 UTC; PITR apagado) y foto de
esquema + huella de datos de `accounts` y `cashflow_lines` (0 filas en las dos).
