# Auditoría UX 2.2 · lote 16: Ajustes: perfil y preferencias

> **ALCANCE ESTRICTO:** solo los flujos del lote 16. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: la de título «Auditoría UX 2.2 · lote 16: …» (búscala con `tablero listar --version 2.2`; muévela a in progress al empezar y a done al cerrar) (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 16).
- SIMULADOR A CUALQUIER HORA (Jürgen, 2026-10-14): ya NO existe la franja de 9:00 a 11:00 Lima. Si el mapa (docs/ux/mapa-de-flujos-2.2.md, regla 7) o un encargo viejo dice lo contrario, está desactualizado: ignóralo. Sigue: 1 simulador a la vez y apagado al terminar.
- PASO 0 extra: en docs/ux/mapa-de-flujos-2.2.md, regla 7 («Simulador»), quita «nada de simulador de 9:00 a 11:00 (Lima),». Va en el PR de este lote.
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 16 · Ajustes: perfil y preferencias (del mapa)
| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 16.1 | Editar mi nombre, foto o icono de perfil | Ajustes › avatar o «Editar» | `PersonalDetailsView` | `V/Profile/PersonalDetailsView.swift`, `PV` | no |
| 16.2 | Cambiar la divisa principal | Ajustes › «Divisa y tipo de cambio» | `CurrencySettingsView` → `CurrencyPickerSheet` → «recalculando conversiones» | `V/Settings/CurrencySettingsView.swift`, `CurrencyPickerSheet.swift`, `CurrencyChangeService` | `CurrencySettings`, `CurrencyPicker` |
| 16.3 | Ver los tipos de cambio | Divisa › «Ver todo» | `ExchangeRatesSheet` | `V/Settings/ExchangeRatesSheet.swift` | no |
| 16.4 | Cambiar el idioma de la app | Ajustes › Personalización › «Idioma de la app» | `LanguagePickerSheet` | `V/Settings/PersonalizationSettingsView.swift` | no |
| 16.5 | Pasar a modo solo gastos | Personalización › interruptor | Diálogo «Se ocultarán los ingresos, transferencias y saldos…» | `V/Settings/PersonalizationSettingsView.swift` | `PersonalizationGroupedList` |
| 16.6 | Ajustar la personalización (iconos coloridos, textos de ayuda, botón de chat, período, primer día, decimales, formato, campo con foco) | Personalización › filas | Hojas de selección | `V/Settings/PersonalizationSettingsView.swift` | `PersonalizationColorfulIcons`, `PersonalizationGroupedList`, `VoiceImageSettingsFab` |
| 16.7 | Cambiar el tema | Ajustes › Temas | `ThemeSettingsView` → paywall o variante | `V/Settings/ThemeSettingsView.swift` | no |
| 16.8 | Cambiar el icono de la app | Ajustes › Icono de la app | `AppIconSettingsView` → alerta del sistema o paywall | `V/Settings/AppIconSettingsView.swift` | no |
| 16.9 | Configurar la barra de pestañas | Más › editar | `MoreEditorSheet` → `TabBarConfigView` | `V/More/MoreEditorSheet.swift`, `V/Settings/TabBarConfigView.swift` | `ProfileSettings` |
| 16.10 | Proteger Yala con Face ID (guía) | Ajustes › Seguridad › «Proteger con Face ID» | `FaceIDProtectionGuideView` → `YalaStepGuide` | `V/Settings/FaceIDProtectionGuideView.swift` | `SecurityFaceIDGuide`, `StepGuide` |
| 16.11 | Revisar los permisos del sistema | Seguridad › Permisos | Ajustes de iOS | `PV` | no |
| 16.12 | Configurar notificaciones y recordatorios | Ajustes › Notificaciones | `NotificationsSettingsView` → `NotificationEditorSheet` | `V/Settings/NotificationsSettingsView.swift`, `NotificationEditorSheet.swift` | `NotificationsSettings` |
| 16.13 | Valorar la app | Seguridad › Valorar | `requestReview` | `PV` | no |
| 16.14 | Hacer un tutorial | Ajustes › Ayuda › Tutoriales | `TutorialsListView` → `TutorialDetailView` → `TutorialCompletionView` | `V/Settings/TutorialsListView.swift`, `TutorialDetailView.swift` | parcial (`StepGuide`) |
| 16.15 | Leer las preguntas frecuentes | Ayuda › FAQ | `FAQView` | `V/Settings/FAQView.swift` | no |
| 16.16 | Escribir a soporte | Ayuda › Contacto | `SupportFormSheet` → `mailto:` | `V/Profile/SupportFormSheet.swift` | no |
| 16.17 | Leer privacidad y términos | Ajustes › Legal | Navegador | `PV` | no |
| 16.18 | Ver qué versión tengo | Pie de Ajustes | Texto fijo | `PV`, `Yala/Utils/L10n.swift` | no |
| 16.19 | Personalizar el resumen IA | Personalización › «Personalizar resumen IA» | `SmartInsightsSettingsView` | `V/Settings/SmartInsightsSettingsView.swift` | no |
| 16.20 | Ver Más y sus tarjetas | Pestaña Más | `MoreView` (Perfil, Registros, Reportes, Presupuestos, Activar Yala completo…) | `V/More/MoreView.swift` | `ProfileSettings` |
| 16.21 | Recorrer Ajustes en iPad | Hoja de Ajustes en `ListDetailSplit` | Ajustes en dos columnas | `PV` (`settingsContainer`) | `AdaptiveNavigation` |
| 16.22 | Guardar el resumen del widget del Panel a otro tamaño | «?» de un widget › tamaño | `WidgetInfoSheet` | `V/Panel/InfoSheets/WidgetInfoSheet.swift` | no |

**Visto en el código:**
- 16.18 está **verificado**: dice «Versión 1.0.0 (Build 1)» siempre. Ticket `settings-footer-shows-a-fixed-version-1-0-0`.
- Cambiar la divisa principal no pide confirmación, migra todos los registros y, si falla, solo lo imprime en DEBUG.
- La fila de idioma solo aparece si se eligió idioma en el onboarding; el pie dice «Reinicia la app para aplicar el
  cambio.» sin botón.
- Elegir un tema cierra toda la hoja de Ajustes a los 300 ms, sin aviso.
- Abrir la pantalla de iconos sin Pro devuelve el icono original sin preguntar.
- Permisos sale de la app sin avisar.
- Soporte se cierra tras abrir `mailto:` aunque no haya app de correo, y lo escrito se pierde.
- El tope de divisas secundarias solo lo anuncia el hint de accesibilidad.

**Tickets abiertos del lote:** `settings-footer-shows-a-fixed-version-1-0-0`, `qa/settings-redesign-as-grouped-lists-like-ios`,
`currency-change-asks-rates-for-the-old-currency`, `language-override-bypasses-the-cloud-prefs-channel`,
`qa/step-flows-should-match-the-sep15-reference`, `ipad-settings-sheet-size-depends-on-where-it-opens`.

---

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L16-1, L16-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 16 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones y la ruta de sus capturas.

## Elecciones de UI: variantes y CERRAR (Jürgen, 2026-10-14 13:01)
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L16.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Guarda también las PNG de cada variante en ~/Claude/entregas/<sesión>/capturas/ (`L16-k-antes.png`, `L16-k-A.png`…), porque Frank se las enseñará a Jürgen pregunta por pregunta.
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

- **Base:** la rama no nacía de 2.2 (estaba en a10168931, de 2.1); se reinició sobre `origin/2.2` (0fc925cf8)
  antes de tocar nada. `git log origin/2.2..HEAD` vacío. PR contra 2.2.
- **Simulador:** iPhone 17 Pro iOS 27.0 (46287CFE), Yala Dev, español de Perú, modo oscuro, semilla `realista`,
  sin Pro para ver los muros (temas, iconos) y con `-uitest-pro` para el resto. 16.21 en iPad Pro 11 (FE5FC26C),
  por turnos: nunca dos simuladores a la vez. Sin franja horaria (Jürgen, 2026-10-14).
- **Lo que el simulador no da:** valorar (`requestReview` no pinta en el simulador de forma fiable), el correo
  (`mailto:` sin app Mail) y Face ID real; se auditan por código y por lo que sí se ve, y se dice.
- **Formato:** el de los lotes 10–15 (informe.md + `datos-lote-16.json` + `render.py` al HTML acumulado +
  `variantes-L16.html` si hay elecciones visuales + cards por script).
- **Bug claro** = texto falso para quien lo lee, un toque que no lleva a ningún sitio, una preferencia que no se
  respeta, lo escrito que se pierde sin aviso, o algo que borra/migra sin aviso cuando el resto de la app avisa.
  Cambiar qué se pide, en qué orden o cómo se ve → card de Jürgen.
- **Tickets abiertos del lote:** no se rehacen. El del pie de versión (`settings-footer-shows-a-fixed-version…`)
  es texto falso verificado: entra como bug si el arreglo es leer la versión real.
- **Guía de pasos (16.10):** es la misma pieza que la de Apple Pay del lote 15 (L15-10); no se repite la
  propuesta, se cita.
- **Maquetas:** `MockL16.swift` + `-mockL16 N`, fichero local que no se commitea; se guarda como
  `maquetas-lote-16.patch` en la entrega.
- **Mapa:** se quita de la regla 7 la franja de 9:00 a 11:00 (pedido del encargo); va en este PR.
