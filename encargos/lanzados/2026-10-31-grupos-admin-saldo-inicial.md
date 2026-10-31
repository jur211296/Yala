---
esfuerzo: high
release: no
---
# Grupos: cualquier admin del grupo puede añadir, editar y borrar saldos iniciales, no solo el dueño

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `grupos-admin-saldo-inicial` · Sesión cola **S35** · al cerrar → **S35a** (`yala-ia-cuenta-segunda-linea`).

## Contexto
Hoy `updateOpeningBalance` / `removeOpeningBalance` (y el alta) de `GroupExpenseService`, y la UI, exigen `group.isOwner`. En el grupo Matri Jürgen es admin y la opción ni aparece. Jürgen (2026-10-30): cualquier admin del grupo debe poder cambiar los saldos iniciales.

Card:
- `tablero ver tablero-grupos-cualquier-admin-puede-anadir-edit-yd2w`

## Qué se pide
1. UI: mostrar añadir / editar / borrar saldo inicial a cualquier admin (dueño incluido), no solo al dueño.
2. `GroupExpenseService`: add, `updateOpeningBalance` y `removeOpeningBalance` aceptan admin en lugar de solo owner.
3. Servidor (Supabase): revisa las RPC y políticas RLS que exijan owner para saldos iniciales y haz que acepten admin, con migración nueva si aplica. Producción es `yala-modo-nube-production`: cualquier cambio de servidor va PRIMERO a staging, se prueba ahí y solo después a producción. Deja en el PR y en la card qué se aplicó y dónde.
4. Se mantiene el guard de liquidaciones confirmadas: con liquidaciones confirmadas no se cambia el saldo, sea dueño o admin.
5. Tests (servicio + servidor si hay suite) y XCUITest de un admin no dueño; capturas antes/después en `capturas/`.
Al abrir el PR, card a «in qa» de Jürgen (QA en dispositivo con el grupo Matri).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
Otros permisos de grupo (miembros, roles, gastos) fuera de los saldos iniciales. Ningún dato real de grupos en producción. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Un admin no dueño ve y usa añadir, editar y borrar saldo inicial; el guard de liquidaciones confirmadas se mantiene; el servidor acepta admin (staging y luego producción); tests verdes, review adversarial del diff, PR a 2.2 con auto-merge.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir (2026-10-31): la app exige `group.isOwner` en tres guards de `GroupExpenseService` (alta, edición, borrado) y en cinco sitios de UI (botón de la pestaña Saldos, editar/borrar del detalle, sección «Saldos iniciales» de Miembros, «Saldo inicial» del menú de cada miembro, la pregunta al aceptar a alguien). El servidor **no** lo exige: en staging y en producción las políticas de `split_expenses`/`split_shares` piden `is_group_writer`, `apply_group_delta` es SECURITY INVOKER con el mismo md5 en los dos proyectos y no mira dueño ni `is_opening_balance`, y ninguna función ni trigger de `public` menciona el saldo inicial salvo el lector del pull.

**D1 · ¿Quién cuenta como admin para los saldos iniciales?** → el dueño (`group.isOwner`, como hoy) **o** el miembro propio resuelto (`resolveCurrentUserMember`), activo y con `isAdmin`. Una sola función pura la decide para UI y servicio.
Por qué: es el mismo criterio que pinta los demás botones de admin (`isCurrentUserAdmin`), y servicio y UI tienen que decidir igual o salen botones que fallan. Conservar el `isOwner` hace el cambio un superconjunto estricto: ningún dueño pierde nada. Alternativa descartada: `role == "admin"` a secas, como `requireCurrentUserAdmin` — dejaría fuera al dueño cuya fila aún no resuelve.

**D2 · ¿Servidor?** → sin migración. Se deja una sonda de staging (`qa/cloud/opening-balance-admin-staging-probe.sh`): un admin no dueño crea, edita y borra un saldo inicial, con control negativo de alguien de fuera. Producción se verifica solo leyendo definiciones (Management API, `read_only`), sin tocar datos.
Por qué: no hay nada que cambiar; escribir en producción no aporta y el encargo lo veta. Alternativa descartada: una migración «por simetría» que añada un chequeo de admin en el servidor — restringiría más que hoy y es otra decisión de producto.

**D3 · Guard de liquidaciones confirmadas** → intacto; es independiente del rol. Un test lo fija para un admin no dueño.

**D4 · Copy del error** (`errorNotOwner`: «Solo quien creó el grupo puede gestionar los saldos iniciales») → pasa a decir «administradores», con clave nueva `errorNotAdmin` y el caso `notAdmin`, en los 16 `.lproj`.
Por qué: el texto viejo sería falso. Los avisos push («%@ registró un saldo inicial») nombran a quien lo hizo y no cambian.

**D5 · Alcance de UI** → los cinco sitios, sin mover nada: el dueño ve exactamente lo de antes y un admin no dueño ve lo mismo que el dueño. La sección de Miembros conserva su condición (sin exigir participar) para no cambiar nada al dueño.

**D6 · XCUITest de admin no dueño** → flag `-uitest-invitee-admin` sobre el perfil `grupos-invitado` (me da `role = "admin"`), en vez de un perfil nuevo.
Por qué: un flag toca dos ficheros; un perfil nuevo arrastra los `switch` de `DevSeedService`.

**D7 · ADR** → no hace falta: es un permiso de producto que el propio código documenta; la decisión queda en este encargo, la card y el PR.

**D8 · Los avisos de «Hacer administrador» y «Quitar como administrador» enumeran lo que puede un admin** → se les añade «los saldos iniciales», en los 16 idiomas.
Por qué: este cambio da a los admins un poder nuevo, y sin tocarlos la confirmación de rol quedaría incompleta (y la de quitar no avisaría de que lo pierde). Es una incoherencia que introduce este cambio, no una heredada.
