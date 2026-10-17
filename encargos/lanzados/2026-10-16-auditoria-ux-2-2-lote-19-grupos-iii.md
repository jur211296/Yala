# Auditoría UX 2.2 · lote 19: Grupos III: administrar, salir y modos

> **ALCANCE ESTRICTO:** solo los flujos del lote 19. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: la de título «Auditoría UX 2.2 · lote 19: …» (búscala con `tablero listar --version 2.2`; muévela a in progress al empezar y a done al cerrar) (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 19).
- SIMULADOR A CUALQUIER HORA (Jürgen, 2026-10-14): ya NO existe la franja de 9:00 a 11:00 Lima. Si el mapa (docs/ux/mapa-de-flujos-2.2.md, regla 7) o un encargo viejo dice lo contrario, está desactualizado: ignóralo. Sigue: 1 simulador a la vez y apagado al terminar.
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 19 · Grupos III: administrar, salir y modos (del mapa)
| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 19.1 | Aprobar o rechazar solicitudes | Detalle › Miembros | `GroupMembersView` → ✓/✗ → diálogo → «¿Añadir saldo inicial?» | `V/Groups/GroupMembersView.swift`, `GroupMemberRow.swift` | `GroupMembersAdmin` |
| 19.2 | Cambiar el rol o quitar a un miembro | Menú «…» de la fila | «Cambiar rol» (sin confirmación) · «Quitar» (con aviso si debe) | `V/Groups/GroupMemberRow.swift` | parcial (`GroupMembersAdmin`) |
| 19.3 | Editar el grupo, sus opciones y su presupuesto | Detalle › engranaje | `GroupSettingsView` | `V/Groups/GroupSettingsView.swift` | no |
| 19.4 | Archivar o desarchivar un grupo | Ajustes del grupo · «Ver archivados» | Diálogo → sección de archivados | `V/Groups/GroupSettingsView.swift`, `GroupsContainerView.swift` | no |
| 19.5 | Eliminar el grupo | Ajustes del grupo › «Eliminar grupo» (desactivado con deudas) | «¿Eliminar este grupo?…» | `V/Groups/GroupSettingsView.swift`, `GroupOwnerExitLogic` | no |
| 19.6 | Salir de un grupo, o transferirlo y salir | Ajustes del grupo · tarjeta de solicitud rechazada | Diálogo con aviso de deuda | `V/Groups/GroupSettingsView.swift`, `GroupLeaveErrorLogic` | no |
| 19.7 | Salir de varios grupos a la vez | Ajustes › Vaciar datos › «También salir de mis grupos» | `GroupBatchLeaveView` | `V/Settings/GroupBatchLeaveView.swift`, `SG/GroupBatchLeaveOrchestrator.swift` | `GroupBatchLeave`, `UserDataResetScope` |
| 19.8 | Volver a un grupo migrado o congelado | Banner del detalle | `MigratedGroupBanner` | `V/Groups/GroupDetailView.swift` | no |
| 19.9 | Asociar o desasociar la cuenta de grupos | Ajustes › «¿Dónde viven tus datos?» › Grupos | `GroupsAssociationSection` → `GroupsSignInView` / diálogo «Conservar los gastos que pagué» / «Quitarlo todo del Panel» | `V/Settings/GroupsAssociationSection.swift`, `SG/GroupsAssociationDetach.swift` | `GroupsAssociationRow` |
| 19.10 | Usar Yala solo para grupos | Llegar por invitación o «Vengo por un grupo» sin onboarding personal | Barra reducida a Grupos, Ajustes reducido, nudges | `V/Groups/GroupsContainerView.swift`, `PV`, `SG/BridgeModeResolver.swift` | `ProfileGroupInvite`, `DeeplinkRouting`, `SessionExitsPerCell` |
| 19.11 | Exportar en modo solo grupos | Ajustes › Exportar datos | `GroupsExportView` (CSV directo) | `V/ExportWizard/GroupsExportView.swift` | no |
| 19.12 | Ver un error de sincronización de grupo | Lo lanza la app | Alerta «Hubo un problema con el grupo» | `CV` (`GroupInviteModifier`), `SG/GroupExpenseService.swift` | no |
| 19.13 | Ver que este teléfono no puede sincronizar grupos | Fijo en la pestaña | Banner sin acción | `V/Groups/GroupsContainerView.swift` (`groupsAttestTerminalBanner`) | `GroupsAttestTerminalBanner` |
| 19.14 | Volver tras cerrar la sesión de grupos | Estado vacío «Tus grupos están en tu cuenta» | `GroupsSignInView` | `V/Groups/GroupsContainerView.swift` | no |
| 19.15 | Recibir avisos de grupo (gasto nuevo, recordatorio de pago) | Notificación | `groups/<id>` | `SG/GroupNotificationService.swift`, `GroupSettlementReminderService` | no (sin recorrer) |

**Visto en el código:**
- Hacer admin a alguien es un toque sin confirmación.
- El presupuesto del grupo se teclea dentro de un `.alert`.
- Archivar se pinta en rojo aunque se puede deshacer.
- Se puede salir con deuda: «La otra parte seguirá viendo esa deuda como pendiente».
- Salir de varios grupos solo se alcanza desde «Vaciar datos».
- El texto de desasociar es técnico: «Los apuntes de lo que te deben o debes desaparecen en los dos casos».
- 19.13 no ofrece ninguna acción. 19.14: según su ticket, el banner ya no tiene quién lo encienda.

**Tickets abiertos del lote:** `group-presence-predicates-disagree-on-archived-and-hidden`,
`groups-create-approve-remove-show-a-raw-rpc-error`, `qa/session-exits-one-verb-per-session`,
`groups-signout-reentry-banner-has-no-producer`, `detach-purge-failed-copy-says-groups-remain-after-a-cursor-only-failure`,
`groups-only-session-storage-screen-says-data-lives-in-icloud`, `groups-settlement-reminder-stale-clock`.

---

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L19-1, L19-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 19 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones y la ruta de sus capturas.

## Elecciones de UI: variantes y CERRAR (Jürgen, 2026-10-14 13:01)
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L19.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Guarda también las PNG de cada variante en ~/Claude/entregas/<sesión>/capturas/ (`L19-k-antes.png`, `L19-k-A.png`…), porque Frank se las enseñará a Jürgen pregunta por pregunta.
**No esperes la elección de Jürgen.** Cuando termines, `xcrun simctl shutdown all` y cierra normal con /cerrar-total. Frank junta las decisiones después y las guarda en las cards para la fase de implementación.

## Reglas duras de UI
- NADA de degradados, NADA de glows/brillos, NADA de contraste en blanco sólido.
- El botón «Siguiente» NO se toca.
- El liquid glass se queda.
- La moneda «S/» frente a «PEN» es una preferencia del usuario: nunca la pongas como opción A/B/C.
- Capturas de HOY (de esta sesión) y maquetas reales en el simulador para cada propuesta visual.
- Copy nueva en los 16 idiomas (es-AR con voseo).

## Cómo
- Pipeline serie en la Mini: `nice -n 10 xcodebuild -jobs 2`, como máximo 1 simulador, `xcrun simctl shutdown all` al terminar.
- Tests de lo que arregles con -only-testing y /gate.

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas, decide tú. Sin deploy.

## Paso 0 — decisiones (Frank, 2026-10-16, auto-contestado: sesión autónoma)

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Sobre qué base?** → `origin/2.2` (`c1124f7af`). La rama nació de `origin/2.1` (`dd8649da8`) y se recolocó con
`git checkout -B` antes de tocar nada; `git log origin/2.2..HEAD` vacío. PR contra 2.2.

**D2 · ¿Qué se arregla en código?** → Solo bugs claros del lote, cada uno con card (Yala, 2.2, frank) y test. Cuenta
como bug claro: texto falso o en crudo para quien lo lee, un destino roto, un botón que no hace nada, una salida de
«no hacer nada» que no se ve en una decisión sobre datos. Cambiar qué se pide, en qué orden o cómo se ve → card de Jürgen.

**D3 · La card `tablero-bug-2-2-otras-pantallas-de-grupos-siguen-7h4p` (error en crudo).** → Se cierra en este PR: los
cuatro `localizedDescription` de `GroupSettingsView` y las dos hojas de cuenta de la Bandeja que la card asigna al lote
19. Mismo patrón y la card las nombra; `GroupsExportView` no puede recibir esos errores (lee SwiftData y escribe un
fichero), así que se deja y se dice. Alternativa descartada: solo `GroupSettingsView` — deja la card abierta por dos
líneas iguales.

**D4 · ¿Cómo conduzco el simulador?** → iPhone 17 Pro iOS 27.0 (`386CA5C3`), Yala Dev, español de Perú, modo oscuro;
los perfiles y args de los XCUITest de Grupos (`grupos`, `grupos-sin-flag` + `-uitest-icloud-identity`,
`grupos-invitado`, `grupos-saldado`, `solo-grupos`, `-uitest-fake-cloud-session`, `-uitest-groups-attest-terminal`,
`-uitest-groups-batch-*`). Un simulador, apagado al terminar.

**D5 · Sin servidor.** → El simulador no tiene backend: aprobar, quitar, salir o transferir de verdad no llegan al
servidor. Lo que solo pasa contra él se audita por código y por el error que devuelve sin red, y se dice.

**D6 · Estados que ningún perfil siembra (grupo migrado, sesión de grupos cerrada).** → Molde de los lotes 17-18: un
fichero Swift local (`ZZLote19Maquetas.swift`) con ganchos `-l19*` para forzar el estado y pintar las variantes,
nunca commiteado; se retira antes del gate.

**D7 · Formato.** → El de los lotes 10-18: `datos-lote-19.json` + `render.py` al HTML acumulado + `variantes-L19.html`
+ cards por script. Capturas en `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-19-grupos-iii/capturas/`.

**D8 · Tickets abiertos del lote.** → No se rehacen. `groups-signout-reentry-banner-has-no-producer` (19.14) y
`groups-only-session-storage-screen-says-data-lives-in-icloud` (19.9/19.10) piden decisión o retirar código muerto:
se citan en las mejoras, no se tocan.
