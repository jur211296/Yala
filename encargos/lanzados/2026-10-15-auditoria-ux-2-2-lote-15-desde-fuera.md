# Auditoría UX 2.2 · lote 15: Desde fuera de la app

> **ALCANCE ESTRICTO:** solo los flujos del lote 15. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: la de título «Auditoría UX 2.2 · lote 15: …» (búscala con `tablero listar --version 2.2`; muévela a in progress al empezar y a done al cerrar) (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 15).
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 15 · Desde fuera de la app (del mapa)
| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 15.1 | Ir a una pestaña desde un widget de datos | Saldo, Gasto, Flujo de caja → Panel; categorías → Distribución; Últimos registros → Registros; Presupuestos; Pagos programados; Resumen del mes (iPad XL); widgets de pantalla bloqueada | Navega a la pestaña | `YalaWidgets/Widgets/`, `YalaWidgets/YalaWidgetsBundle.swift` | `DeeplinkRouting` |
| 15.2 | Apuntar desde un widget de entrada rápida | Manual / Voz / Imagen | Panel → formulario, voz o imagen (o paywall / consentimiento) | `YalaWidgets/Widgets/QuickEntryWidgets.swift` | `WidgetEntryToPanel`, `WidgetEntryBackground` |
| 15.3 | Tocar un widget estando en solo grupos | Cualquier widget de datos | «Aún no tienes finanzas personales» → `yala://activate-full` | `YalaWidgets/Views/GroupsOnlyInviteView.swift` | no |
| 15.4 | Apuntar desde el Centro de Control | Controles «Registro por voz» y «Foto o archivo» | Clave en el App Group → al volver, Panel → hoja | `YalaWidgets/ControlWidgets.swift`, `Yala/Shared/ControlCenterIntents.swift` | no |
| 15.5 | Apuntar con un atajo de Siri que abre la app | «Registra en Yala», «Registra con voz…», «Escanear gasto…» | Deep link → Panel | `Yala/App/Intents/AppShortcutsProvider.swift`, `QuickExpenseIntent.swift` | parcial (`WidgetEntryToPanel`, las URLs) |
| 15.6 | Apuntar hablándole a Siri sin abrir la app | «Anota un gasto en Yala» → «¿Qué quieres registrar?» | Borrador en la Bandeja → notificación → `InboxAlertModal` | `QuickExpenseIntent.swift` (`SiriNaturalEntryIntent`), `SiriPendingStore.swift`, `S/InboundCaptureDrain.swift` | no |
| 15.7 | Capturar un pago de Apple Pay | Automatización de Wallet en Atajos | Borrador en la Bandeja → notificación → `InboxAlertModal` | `QuickExpenseIntent.swift` (`ApplePayTransactionIntent`), `ApplePayPendingStore.swift` | parcial (`InboxNewItemsModal`) |
| 15.8 | Configurar Apple Pay con la guía | Ajustes › Tutoriales › Apple Pay | `ApplePayAutomationGuideView` → `YalaStepGuide` → abre Atajos | `V/Settings/ApplePayAutomationGuideView.swift` | `StepGuide` |
| 15.9 | Leer qué le puedo decir a Siri | Ajustes › «Siri y Atajos» | `SiriShortcutsView` | `V/Settings/SiriShortcutsView.swift` | no |
| 15.10 | Tocar una notificación de Yala | Recordatorio, presupuesto, pago, informe, grupo, Siri/Apple Pay | Navega a la pestaña; `inbox` abre la Bandeja | `YS/NotificationService.swift` (`parseDestination`) | no |
| 15.11 | Usar Yala en varias ventanas (iPad) | Menú contextual de un registro o grupo | Ventana nueva; la otra muestra «Yala te espera en otra ventana» | `Yala/App/Scenes/` | `MultiWindow` |
| 15.12 | Usar los atajos de teclado | ⌘N, ⌘⇧N, ⌘,, ⌘F, ⌘K, ⌘1…6, ⌘E, Supr, ↑/↓ | Según la acción | `Yala/App/Commands/YalaCommands.swift` | `KeyboardShortcuts` |
| 15.13 | Girar el iPhone o redimensionar la ventana | Horizontal · Split View | `ListDetailSplit` | `V/Shared/ListDetailSplit.swift` | `IPhoneLandscape`, `AdaptiveNavigation` |

**Visto en el código:**
- 15.9 está **verificado**: la pantalla enseña tres frases que Siri no conoce. Ticket
  `siri-settings-screen-lists-phrases-siri-does-not-know`.
- Sin Pro, Siri contesta «Activa Yala Pro para usar registro con Siri.» y no abre nada.
- El aviso de saldo de cuenta (`deepLink: "accounts"`) no lleva a ningún sitio.
- Con algo abierto en el iPad, soltar un archivo se rechaza sin decir por qué.
- Supr sin modificador borra el registro abierto.
- No existen Spotlight, Handoff ni accesos rápidos del icono (lo dice `docs/entry-points.md`).

**Tickets abiertos del lote:** `siri-settings-screen-lists-phrases-siri-does-not-know`,
`siri-shortcut-error-replies-speak-english-on-a-spanish-iphone`,
`qa/after-session-redesign-review-widgets-siri-applepay-and-web-copy`, `notification-deeplink-accounts-not-parsed`,
`apple-pay-capture-in-a-groups-only-session-has-no-personal-inbox`, `iphone-duo-native-app`.
**Cards de 2.2 que lo cambian:** «Integrar Yala con el nuevo Siri con IA de iOS 27», «Registrar movimientos desde la
notificación del banco». Este lote revisa lo que hay **hoy**; lo que cambie Siri con IA se audita con su card.

---

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L15-1, L15-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 15 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones y la ruta de sus capturas.

## Elecciones de UI: variantes y CERRAR (Jürgen, 2026-10-14 13:01)
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L15.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Guarda también las PNG de cada variante en ~/Claude/entregas/<sesión>/capturas/ (`L15-k-antes.png`, `L15-k-A.png`…), porque Frank se las enseñará a Jürgen pregunta por pregunta.
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

## Paso 0 — decisiones (Frank, 2026-10-15, auto-contestadas: sesión autónoma)

- **Base:** la rama nace de `origin/2.2` (ce9873ab9); `git log origin/2.2..HEAD` vacío. PR contra 2.2.
- **Simulador:** iPhone 17 Pro iOS 27.0 (46287CFE), Yala Dev, español de Perú, modo oscuro, semilla `realista`.
  Las entradas de fuera se disparan como las dispara el sistema: `simctl openurl yala://…` (widgets, atajos,
  Centro de Control), `simctl push` (notificaciones) y la galería de widgets del simulador. Fuera del simulador
  de 9:00 a 11:00 Lima.
- **Lo que el simulador no da:** Siri por voz, la automatización de Wallet y el Centro de Control real no se
  conducen; se auditan por código y por lo que sí se ve (la URL, la Bandeja, la notificación), y se dice.
- **iPad (15.11, 15.12):** iPad Pro 11 (FE5FC26C) por turnos, nunca dos simuladores a la vez.
- **Formato:** el de los lotes 10–14 (informe.md + `datos-lote-15.json` + `render.py` al HTML acumulado +
  `variantes-L15.html` + cards por script).
- **Bug claro** = texto falso para quien lo lee, un toque que no lleva a ningún sitio, una preferencia que no se
  respeta, o algo que borra sin aviso cuando el resto de la app avisa. Cambiar qué se pide, en qué orden o cómo
  se ve → card de Jürgen.
- **Tickets abiertos del lote:** no se rehacen; si una mejora los cubre, se cita. El de `siri-settings…` (frases
  que Siri no conoce) es copy de una pantalla del lote y ya está verificado: entra como bug si el arreglo es
  quitar lo falso; si pide decidir qué frases enseñar, mejora.
- **Maquetas:** `MockL15.swift` + `-mockL15 N`, fichero local que no se commitea; se guarda como
  `maquetas-lote-15.patch` en la entrega.
