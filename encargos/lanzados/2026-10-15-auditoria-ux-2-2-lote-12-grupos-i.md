# Auditoría UX 2.2 · lote 12: Grupos I: entrar, crear, invitar y unirse

> **ALCANCE ESTRICTO:** solo los flujos del lote 12. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: la de título «Auditoría UX 2.2 · lote 12: …» (búscala con `tablero listar --version 2.2`; muévela a in progress al empezar y a done al cerrar) (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 12).
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 12 · Grupos I: entrar, crear, invitar y unirse (del mapa)
| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 12.1 | Entrar a Grupos y ver mis grupos | Pestaña Grupos · FAB del Panel › Grupo · `yala://groups/<id>` · notificación · ventana nueva (iPad) | `GroupsContainerView` (resumen, nudge, tarjetas, «Ver archivados») → `GroupDetailView` (Registros, Saldos, Estadísticas) | `V/Groups/GroupsContainerView.swift`, `GroupCardView.swift`, `GroupDetailView.swift` | `GroupsSmoke`, `GroupDetailDeeplinkColdLaunch`, `AdaptiveNavigation` |
| 12.2 | Ver el estado vacío que me toca | Pestaña sin grupos | `YalaEmptyState` en 5 variantes (sin grupos, cómo funcionan, están en tu cuenta, crea tu cuenta, un último paso) | `V/Groups/GroupsContainerView.swift`, `GroupsEmptyStateLogic` | parcial (`GroupsEmptyState`, 3 de 5) |
| 12.3 | Ver cómo funcionan los grupos | Primera visita · «Ver cómo funciona» · bienvenida | `GroupsOnboardingView`, 3 pasos → «Ir a Grupos» / «Iniciar sesión» / «Crear mi cuenta» | `V/Groups/Onboarding/GroupsOnboardingView.swift` | `GroupsEducational` |
| 12.4 | Iniciar sesión o crear cuenta para Grupos | Estados vacíos · educativo · crear grupo sin sesión · invitación | `GroupsSignInView` (Apple/Google) → `GroupsAccountIsCompleteBlockView` si toca → `GroupsConsentView` | `V/Groups/GroupsSignInView.swift`, `GroupsAccountIsCompleteBlockView.swift` | no |
| 12.5 | Aceptar el consentimiento de Grupos | Tras iniciar sesión · «Un último paso» | `GroupsConsentView` → «Aceptar y continuar» | `V/Groups/GroupsConsentView.swift` | parcial (`GroupsEmptyState`, `WelcomeChooser`) |
| 12.6 | Activar las notificaciones de grupo | Alerta al tener el primer grupo | Alerta → permiso de iOS o «Abrir Ajustes» | `V/Groups/GroupsContainerView.swift` | no |
| 12.7 | Crear un grupo | Estado vacío · FAB «+» › Nuevo grupo | Comprobaciones (disponibilidad, consentimiento, sesión) → `GroupFormView` (nombre, icono, color, simplificar deudas, divisa, división por defecto) | `V/Groups/GroupFormView.swift`, `GroupCreateRoutingLogic` | parcial (`GroupsSmoke`) |
| 12.8 | Crear mi primer grupo desde la bienvenida | Bienvenida › «Vengo por un grupo» › «Crear mi primer grupo» | `WelcomeGroupsChooserView` → `WelcomeGroupsGateView` → educativo → sesión → consentimiento → `GroupsOrganizerNameView` → `GroupFormView` | `V/Onboarding/WelcomeGroupsChooserView.swift`, `WelcomeGroupsGateView.swift`, `V/Groups/GroupsOrganizerNameView.swift` | `WelcomeChooser` |
| 12.9 | Invitar a alguien por enlace | Detalle › Miembros › «Invitar por enlace» · registros vacíos | `GroupMembersView` → hoja de compartir | `V/Groups/GroupMembersView.swift`, `VM/GroupDetailViewModel.swift` | no |
| 12.10 | Abrir una invitación sin tener la app | Enlace en el navegador | Web `invite.astro` → App Store → bienvenida › «Tengo una invitación» → `InviteRecoveryView` (pegar el enlace) | `Web/src/pages/invite.astro`, `V/Onboarding/InviteRecoveryView.swift` | `WelcomeChooser` |
| 12.11 | Unirme a un grupo con la app instalada | Tocar el enlace · pegarlo · lo retoma el reconciliador | Puerta neutral si toca → sesión → consentimiento → `GroupInviteOnboardingView` (nombre → conectando → tardando / error / pendiente / listo) | `S/GroupBackendInviteEntryHandler.swift`, `V/Groups/GroupInviteOnboardingView.swift`, `SG/PendingJoinStore.swift` | `GroupInviteOnboarding` |
| 12.12 | Unirme desde un teléfono con datos de otro | Invitación en un aparato con datos y sin onboarding personal | `WelcomeGroupsGateView` («Antes de unirte, este teléfono queda en blanco») → «Continuar y borrar» → relanzar → 12.11 | `L/GroupInviteNeutralGateLogic.swift`, `V/Onboarding/WelcomeGroupsGateView.swift` | parcial (`WelcomeChooser`) |
| 12.13 | Tocar un enlace que no vale o de un grupo archivado | Enlace caducado · grupo archivado · canal caído | Alertas «Enlace no válido», grupo archivado, «Hubo un problema con el grupo» | `Yala/App/AppBootstrapper.swift`, `CV` (`GroupInviteModifier`) | no |
| 12.14 | Esperar a que el admin me apruebe | Tarjeta pendiente · banner · enlace | Alerta «Esperando aprobación»; si rechazan, `PendingApprovalBanner` | `V/Groups/GroupCardView.swift`, `GroupDetailView.swift` | `GroupPendingMemberDoor` |
| 12.15 | Ver el estado de una unión en curso o caducada | Pestaña Grupos con una unión pendiente | Chip «Conectando con tu grupo…» / error con «Reintentar» / caducada | `V/Groups/GroupsContainerView.swift` (`joinIntentBanner`) | parcial (`GroupInviteOnboarding`) |

**Visto en el código:**
- «Un último paso» con «Continuar» no dice qué paso es.
- `GroupsSignInView` dice «…sigue con tu invitación» también a quien está creando su primer grupo.
- Tras sesión y consentimiento entrando por «crear grupo», no vuelve al formulario.
- 12.8 son unas 7 pantallas, y «Crear mi grupo» abre otro formulario.
- Al guardar un grupo no se propone invitar a nadie. Solo el dueño puede invitar.
- La web de invitación no dice que, tras instalar, hay que volver a tocar el enlace o pegarlo.
- Se pide cuenta y consentimiento antes de enseñar a qué grupo se une.
- «Vuelve a entrar en un rato para comprobarlo»: se le pide mirar, no se le avisa.
- Errores mostrados en crudo (`error.localizedDescription`).

**Tickets abiertos del lote:** `qa/groups-consent-door-spec`, `invite-aasa-requires-s-param`,
`invite-link-creation-blames-the-connection-for-any-rpc-failure`, `groups-organizer-intent-is-lost-on-relaunch`,
`invite-neutral-gate-reopens-the-welcome-without-recomputing-readiness`,
`groups-join-intent-expires-silently-after-transient-failures`, `groups-create-approve-remove-show-a-raw-rpc-error`,
`groups-double-load-on-entry-needs-redeciding`.

---

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L12-1, L12-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 12 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones y la ruta de sus capturas.

## Elecciones de UI: variantes y CERRAR (Jürgen, 2026-10-14 13:01)
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L12.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Guarda también las PNG de cada variante en ~/Claude/entregas/<sesión>/capturas/ (`L12-k-antes.png`, `L12-k-A.png`…), porque Frank se las enseñará a Jürgen pregunta por pregunta.
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

## Paso 0 (Frank, 2026-10-15, auto-contestado: sesión autónoma)

- **Base:** la rama nació de `origin/2.1` (a10168931), no de 2.2; se recolocó sobre `origin/2.2` (4384f9c6b) antes de cualquier commit. `git log origin/2.2..HEAD` vacío. PR contra 2.2.
- **Simulador:** iPhone 17 Pro iOS 27.0 (46287CFE), Yala Dev, español de Perú, launch args `-uitest-*` de los XCUITests de Grupos. Ninguna sesión ajena usa simulador (la de QA guiado trabaja con el iPhone físico). Fuera del simulador antes de las 9:00 Lima.
- **Formato:** el de los lotes 10–11 (informe.md + `datos-lote-12.json` + `render.py` al HTML acumulado + `variantes-L12.html` + cards por script).
- **Qué cuenta como bug claro:** texto mal escrito o que dice algo falso para quien lo lee, un destino roto, un botón que no hace nada. Quitar o fusionar pantallas, cambiar qué se pide o en qué orden → card de Jürgen.
- **Sin backend real:** el simulador no tiene Supabase ni Sign in with Apple; los estados con sesión, unión o error se alcanzan con los seams `-uitest-*`. Lo que solo existe contra el backend (crear de verdad, enlace real) se audita por código y se dice.
- **Tickets abiertos del lote:** no se rehacen; si una mejora los cubre, se cita. `qa/groups-consent-door-spec` sigue en qa.
- **Web (`invite.astro`):** se audita en el navegador local si compila; no se despliega nada.
