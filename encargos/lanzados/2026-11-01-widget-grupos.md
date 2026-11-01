---
esfuerzo: high
release: no
depende: PR #721 (S35f widgets-auditoria-rediseno, tanda 1 de los widgets)
---
# Widget de Grupos: cuánto debes y cuánto te deben, en la pantalla de inicio

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `widget-grupos` · Sesión cola **S35f3** · al cerrar → **S35k** (`registro-unificado-implementar`).

## Contexto
Jürgen (31-oct) pidió widgets con contenido de valor «según lo que ya exponga la app: saldos, gasto del mes vs presupuesto, próximos pagos, **grupos**». La tanda 1 (S35f, PR #721) no pudo hacer el de Grupos: los grupos no viajan en la foto del App Group que leen los widgets. Base, reglas y banco de capturas de la tanda 1: `docs/widgets/AUDITORIA-WIDGETS-2-2.md`, `.claude/rules/widgets.md`, `qa/widget-render/`.

**Antes de empezar**: comprueba que el PR de S35f está en `origin/2.2`; si no, rebasa sobre su rama y dilo en el PR.

Cards:
- `tablero ver tablero-widget-de-grupos-lo-que-debes-y-te-deben-505a`

## Qué se pide
1. **Llevar los grupos a la foto**: campos OPCIONALES y con default en `WidgetDataSnapshot` (molde de `paymentsMonth` y `accountFlows`), en las DOS copias del DTO (`Yala/Services/WidgetDataCache.swift` y `YalaWidgets/Services/WidgetDataService.swift`); lo fijan `WidgetDTOParityTests` y `WidgetSnapshotLegacyDecodeTests` (`.claude/rules/swiftdata-cloudkit.md`, «Un campo Codable NUEVO… apaga TODOS los widgets»). Por grupo: nombre, emoji/icono y color si los hay, y lo que debes o te deben en tu divisa de grupo, con la MISMA cuenta que la lista de Grupos (`Color.groupOweAmount`/`groupOwedAmount` y su lógica). Solo con sesión que vea grupos; la shell solo grupos ya tiene su invitación propia.
2. **Widget «Grupos»** (M y L): resumen arriba (debes / te deben, los dos tokens de la lista de Grupos) y los grupos con saldo; toque a Grupos y, por fila, al grupo (`groups/<id>`, que `AppBootstrapper` ya entiende). Sin grupos: estado vacío que invita a crear uno.
3. Refresco: la foto se reescribe cuando cambia un saldo de grupo (comprueba que el camino de Grupos llega a `WidgetDataCache.updateCache`).
4. Capturas antes/después con el banco (añade el widget a `qa/widget-render/Harness/Catalog.swift`) y comprobación real en el simulador.

## Qué NO hay que tocar
La lógica de saldos de Grupos (solo se lee), la sincronización y el servidor. Ni `marketing/` ni `Web/`. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Widget de Grupos funcionando con las cifras de la lista de Grupos, foto compatible hacia atrás (tests de decodificación verdes), review adversarial del diff (sí aplica: datos de grupo), PR a 2.2 con auto-merge y capturas en el digest. La card a «in qa» de Jürgen para mirarlo en el iPhone con grupos reales.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen: card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra. Si sale algo que no cabe, cards 2.2 «ready to launch», `cierra-sola`, alta, de frank, listadas en el PR.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 (Frank, 2026-11-01)

Comprobado: PR #721 está en `origin/2.2` (`a47e3bcbe`). Base = `origin/2.2` (`2f2a0d644`).

| Decisión | Elegido | Por qué |
|---|---|---|
| Qué viaja en la foto | `groups: WidgetGroupsSummary?` (opcional, default `nil`) en las DOS copias: resumen (debes / te deben por divisa), nº de grupos activos y una fila por grupo activo (id, nombre, icono SF, color, debes / te deben por divisa) | Molde de `paymentsMonth`. El modelo no tiene emoji: lleva `iconName` + `colorHex`, como `GroupIconBadge` |
| Qué cuenta | Las MISMAS funciones que la lista: resumen = `GroupBalanceService.globalSummary` sobre los grupos no archivados (como `GroupsViewModel.recalculate`); fila = `GroupsViewModel.computeCurrentUserDebts` con `simplifyDebts`/`showDebtsInSingleCurrency` del grupo, neteado por divisa con `groupDebtsByDirection` (la banda del detalle) | La lógica de saldos solo se lee. Test de paridad contra `GroupsViewModel` |
| Dónde se calcula | `WidgetGroupsSnapshotBuilder` (app), con el `context` que recibe `buildSnapshot`, sin pasar por `GroupService.shared` | El paso 9 del arranque escribe la foto antes del paso 16 que da contexto a los servicios de grupos |
| Refresco | `WidgetGroupsRefresh.requestCheck()` desde `SessionState.incrementDataVersion` (molde de `CreditCardReminderScheduler.requestReplan`): coalesce, recalcula SOLO la parte de grupos y llama a `updateCache` si cambió respecto a la última foto | Hay ~30 escritores de Grupos (servicios + pull remoto) y todos suben `dataVersion`; el pull no se gatea en segundo plano. Un guardado personal no reconstruye dos veces (la parte de grupos no cambia) |
| Solo grupos | El widget lleva `invitesToActivateFullWhenGroupsOnly()` como los demás | Encargo: «la shell solo grupos ya tiene su invitación propia». Conservador; queda card a Jürgen por si lo quiere con datos ahí |
| Orden de filas | Debes → te deben → al día; dentro, el orden de la lista (nombre) | «Primero lo que debes» (decisión del 30-oct en la lista) |
| Tamaños | M: resumen + 2 filas · L: resumen + 5 filas + frescura | Molde de Pagos |
| Sin grupos | «Aún no tienes grupos · Toca para crear uno» → `groups` (el estado vacío con pasos de la pestaña) | Crear un grupo pide sesión y consentimiento: la pestaña ya guía esos pasos |
| Foto vieja (sin `groups`) | «Abre Yala para ver tus grupos» | Una foto anterior a 2.2 no sabe nada de grupos |
| Colores | `WidgetColors.groupOweText` / `groupOwedText`, espejo de `Color.groupOweAmount`/`groupOwedAmount`, con paridad | Encargo: los dos tokens de la lista |
| Antes/después | «Antes» = la lista de Grupos en la app con la semilla `grupos` (las cifras que el widget copia); «después» = el banco + pantalla de inicio real | El widget no existía: no hay «antes» del widget |
