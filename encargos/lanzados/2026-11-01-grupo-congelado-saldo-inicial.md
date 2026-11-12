---
esfuerzo: medium
release: no
---
# En un grupo congelado, ocultar o bloquear «Saldos iniciales» con explicación en vez de fallar al guardar

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `grupo-congelado-saldo-inicial` · Sesión cola **S35h** · al cerrar → **S36** (`barrido-qa-2-2-b`).

## Contexto
Hallazgo del cierre de `grupos-admin-saldo-inicial` (PR #714): en un grupo congelado (migrado), la sección «Saldos iniciales» se sigue viendo y el guardado falla, para el dueño y ahora también para los admins.

Cards:
- `tablero ver tablero-en-un-grupo-congelado-no-se-muestra-ni-s-jqgy`

## Qué se pide
1. Detectar el estado congelado/migrado del grupo con la misma fuente que usa el resto de la app para bloquear escrituras.
2. En ese estado, ocultar o deshabilitar la sección «Saldos iniciales» (menú ··· y detalle de miembro incluidos) con una explicación corta y clara, alineada al copy de grupos migrados; nunca intentar guardar.
3. Defensa en la capa de guardado: si llega una escritura sobre un grupo congelado, se rechaza sin llamar al servidor y sin error genérico.
4. Tests unitarios y un XCUITest del caso; capturas antes/después en `capturas/`.
Si sale algo que no cabe, crea cards en 2.2, «ready to launch», `cierra-sola`, asignadas a frank (nada a backlog) y lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
Migración ni lógica de congelado; Worker y esquema del servidor. Nada de marketing/ ni Web/. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
En un grupo congelado la sección no deja guardar y explica por qué, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen: no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Medido en el árbol (base `b76dbff4f`):
- La fuente del freeze es `SplitGroup.isMigratedFrozen` (`GroupFreezeLogic.isFrozen`), la misma que usan `canCurrentUserParticipate` y `validateGroupIsWritable`.
- El detalle del grupo YA lo respetaba: «Añadir saldo inicial» de Saldos y Editar/Eliminar del detalle cuelgan de `canManageOpeningBalances` (incluye el freeze). El menú ··· de cada persona también (`canActAsAdmin` excluye el freeze).
- El agujero real es la sección «Saldos iniciales» de **Miembros**: cuelga solo de `isOpeningBalanceManager` (sin freeze) y ofrece «Añadir» y abre el editor de cada saldo. Más el atajo tras aceptar a alguien, también sin freeze.
- Servicio: `setOpeningBalance`/`updateOpeningBalance` comprueban permiso de gestión ANTES del freeze; el freeze llegaba tarde, dentro de `createExpense`/`updateExpense`. El grupo congelado nunca es backend, así que no hay llamada al servidor, pero el rechazo podía salir como `notAdmin` en vez de «se movió».

Decisiones:
1. **Deshabilitar, no ocultar** la sección: los saldos que había se siguen viendo (solo lectura, sin chevron ni editor), sin «Añadir», con una nota. Ocultarla escondería datos que el resto del grupo congelado sí enseña (solo lectura). Conservador y reversible.
2. **Copy**: una key nueva neutra para los tres estados congelados (rejoin / actualizar / pausa): «Este grupo se movió a la nube de Yala. Los saldos iniciales se pueden ver, pero no cambiar aquí.» No reuso `movedToBackend` porque promete «Vuelve a entrar», falso en «actualizar» y «pausa»; el banner del detalle ya da la salida de cada estado.
3. **Servicio**: `validateGroupIsWritable` al principio de `setOpeningBalance` y `updateOpeningBalance` (como ya hacía `removeOpeningBalance`): `movedToBackend` antes de leer nada. La alerta del editor ya traduce ese error a texto localizado.
4. El atajo tras aceptar a alguien pasa a `canManageOpeningBalances`.
5. Seam `-uitest-invitee-frozen` sobre `grupos-invitado` (congela el grupo y siembra un saldo de antes) para el XCUITest y las capturas. Fuera: migración, lógica de congelado, Worker.
