# Auditoría UX 2.2 · lote 20: Tus datos: exportar, vaciar, cerrar sesión, nube y avisos del sistema

> **ALCANCE ESTRICTO:** solo los flujos del lote 20. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: la de título «Auditoría UX 2.2 · lote 20: …» (búscala con `tablero listar --version 2.2`; muévela a in progress al empezar y a done al cerrar) (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 20).
- SIMULADOR A CUALQUIER HORA (Jürgen, 2026-10-14): ya NO existe la franja de 9:00 a 11:00 Lima. Si el mapa (docs/ux/mapa-de-flujos-2.2.md, regla 7) o un encargo viejo dice lo contrario, está desactualizado: ignóralo. Sigue: 1 simulador a la vez y apagado al terminar.
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 20 · Tus datos: exportar, vaciar, cerrar sesión, nube y avisos del sistema (del mapa)
| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 20.1 | Exportar mis movimientos a CSV o Excel | Ajustes › «Exportar datos» | `ExportFiltersStepView` → `ExportColumnsStepView` → `ExportSummaryStepView` (CSV / Excel) → compartir → «Exportación completada» | `V/ExportWizard/ExportFiltersStepView.swift`, `ExportColumnsStepView.swift`, `ExportSummaryStepView.swift` | `ExportFreePeriods` |
| 20.2 | Exportar antes de vaciar | Vaciar datos › exportar | `UserDataResetView` → `ExportFiltersStepView` | `V/Settings/UserDataResetView.swift` | no |
| 20.3 | Vaciar mis datos | Ajustes › Datos › «Vaciar datos» | `UserDataResetView` → `DestructiveScopeSheet` → «¿Seguro? Esto es definitivo.» | `V/Settings/UserDataResetView.swift` | `UserDataResetScope` |
| 20.4 | Cerrar sesión | Ajustes › Seguridad › «Cerrar sesión» · Tu cuenta de Yala | `DestructiveScopeSheet` → segunda confirmación si no hay copia → progreso → `SignOutRelaunchView` | `PV`, `Yala/Services/CloudSync/CloudSessionSignOut.swift`, `V/Settings/SignOutRelaunchView.swift` | `SessionExitsPerCell` |
| 20.5 | Ver «Tu cuenta de Yala» | Ajustes › Seguridad (solo con cuenta en la nube) | `YalaAccountView` | `V/Profile/YalaAccountView.swift` | `YalaAccount` |
| 20.6 | Eliminar mi cuenta de Yala | Tu cuenta de Yala › «Eliminar mi cuenta» | `DestructiveScopeSheet` → «Esto es definitivo» → «Reintentar» si falla → relanzar | `PV`, `Yala/Services/CloudSync/AccountDeletionService.swift` | `DeleteAccountDialog` |
| 20.7 | Pasar mis datos de iCloud a una cuenta de Yala | Ajustes › «Dónde viven tus datos» › «Activar la nube» (oculto en producción) | `StorageSettingsView` → `CloudConsentView` → `StorageSignInChooserView` → «¿Activar la nube?» → «¿Seguro?» → progreso → «reinicia Yala»; bloqueo `StorageMigrationBlockedView` | `V/Settings/StorageSettingsView.swift`, `StorageSignInChooserView.swift`, `StorageMigrationBlockedView.swift` | `StorageMigrationAttest`, `StorageMigrationIdentityBlock`, `PendingICloudWipeMigration`, `StorageJournalUnreadable` |
| 20.8 | Activar la nube en este dispositivo | Misma pantalla, tarjeta de este dispositivo | Consentimiento → Apple/Google → progreso | `V/Settings/StorageSettingsView.swift` | parcial |
| 20.9 | Volver a iCloud | Storage › «Volver a iCloud» · Tu cuenta de Yala | Dos diálogos → progreso cancelable → relanzar | `V/Settings/StorageSettingsView.swift`, `V/Profile/YalaAccountView.swift` | no |
| 20.10 | Volver a entrar cuando caduca la sesión | Tarjeta de sincronización de Storage | Entrar con Apple/Google | `V/Settings/StorageSettingsView.swift` | no (sin recorrer) |
| 20.11 | Ver el estado de iCloud y forzar la sincronización | Ajustes › iCloud · banner de sincronización | `iCloudSyncSettingsView` («Reintentar», «Diagnosticar», sin cuenta) | `V/Settings/iCloudSyncSettingsView.swift`, `V/Shared/SyncStatusBanner.swift` | no |
| 20.12 | Aviso: iCloud listo tarde | Automático (crítico) | Alerta «Cierra y vuelve a abrir la app…» | `V/Shared/ShellDataAlertsModifier.swift` | no |
| 20.13 | Aviso: datos borrados de iCloud desde otro aparato | Automático (crítico) | Alerta «Datos no disponibles»: «Empezar de cero» / «Seguir esperando» | `V/Shared/ShellDataAlertsModifier.swift`, `CV` | `RemoteWipeNoticeRouting` |
| 20.14 | Aviso: cambiaste de Apple ID | Automático (crítico) | `AppleIDCloseNoticeView` | `V/Shared/AppleIDCloseNoticeView.swift` | `AppleIDCloseNotice` |
| 20.15 | Reabrir Yala tras cerrar sesión o migrar | Fin de 20.4, 20.6, 20.7, 20.9 | `SignOutRelaunchView` («Ve a la pantalla de inicio y vuelve a abrir Yala») | `V/Settings/SignOutRelaunchView.swift` | parcial (`SessionExitsPerCell`) |
| 20.16 | Exportar al cerrar sesión con cambios sin subir | Cerrar sesión con cambios pendientes | Rescate «Exportar» en `PV` | `PV` | no (sin recorrer) |
| 20.17 | Usar el panel de pruebas de la nube (solo builds Dev) | `DEV_BUILD` | `CloudSyncDebugView` | `V/Settings/` | no |

**Visto en el código:**
- No existe exportar a PDF. El subtítulo de exportar solo menciona CSV, aunque también hay Excel.
- Tras exportar antes de vaciar, el final dice «Volver a ajustes» aunque vengas del borrado.
- Varias salidas piden cerrar la app a mano: «Ve a la pantalla de inicio y vuelve a abrir Yala», «Cierra Yala del
  todo (deslízala fuera del selector de apps)».
- En 20.13 el botón destructivo «Empezar de cero» va primero, en un aviso que la persona no provocó.
- 20.7 está oculta en producción por un flag remoto.

**Tickets abiertos del lote:** `export-errors-are-hardcoded-in-spanish`, `exportable-insights`,
`settings-sign-out-scope-says-groups-stay-in-an-account-that-may-not-exist`, `sign-out-wipe-abort-in-icloud-says-nothing`,
`groups-only-account-deletion-skips-export-wait`, `storage-sync-sign-in-count-has-no-plural`,
`forcesync-returns-ok-without-touching-the-network`, `remote-wipe-receiver-has-no-behaviour-test`,
`reverse-tap-on-a-stale-card-aborts-instead-of-starting`.
**Cards de 2.2 que lo cambian:** «Partir la IA según modo nube o privado», «Endurecer el conector MCP en producción».

---

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L20-1, L20-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 20 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones y la ruta de sus capturas.

## Elecciones de UI: variantes y CERRAR (Jürgen, 2026-10-14 13:01)
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L20.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Guarda también las PNG de cada variante en ~/Claude/entregas/<sesión>/capturas/ (`L20-k-antes.png`, `L20-k-A.png`…), porque Frank se las enseñará a Jürgen pregunta por pregunta.
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

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué cuenta como «bug claro» que se arregla en el PR?** → Lo que contradice lo que la propia pantalla promete o deja a la persona sin salida: (B1) el período de exportar incluye mañana y el resumen dice que acaba mañana; (B2) filas del resumen tituladas «Todas las cuentas/categorías»; (B3) «Exportar antes» de vaciar abre con 30 días; (B4) errores de exportar fijos en español (ticket `export-errors-are-hardcoded-in-spanish`); (B5) «Esto es definitivo» de eliminar la cuenta no aparece desde «Tu cuenta de Yala»; (B6) siete confirmaciones de «Dónde viven tus datos» sin el botón de no hacer nada; (B7) «1 cambios» sin plural (ticket `storage-sync-sign-in-count-has-no-plural`).
Por qué: son defectos verificables en el simulador o en el código, sin elección de producto. Alternativa descartada: arreglar también «Exportación completada aunque canceles», que el lote 19 dejó como mejora (L19-16); se decide junto, como mejora.

**D2 · B5: ¿cómo se arregla la alerta que no sale?** → Mover las presentaciones del cierre de sesión y del borrado de cuenta de la raíz de la pila de Ajustes al contenedor de la pila (siempre visible), sin tocar su lógica; un solo anchor, como hoy.
Por qué: la alerta cuelga de una vista tapada por la pantalla empujada; la hoja sí sale, la alerta no. Alternativa descartada: duplicar la alerta en `YalaAccountView` (dos anchors ante el mismo estado, prohibido por `swiftui-ds.md`).

**D3 · B6: ¿alert o botón sin rol?** → Botón sin `role: .cancel` dentro del mismo `confirmationDialog`.
Por qué: es el molde ya medido en la misma pantalla (`PendingICloudWipe`), y en `cancelReverse` el texto del botón depende del estado, que un `.alert` no admite. Alternativa descartada: pasar a `.alert` (molde lote 18), que obligaría a partir un diálogo en dos.

**D4 · B3: ¿qué exporta «Exportar antes»?** → Abre el mismo asistente con «Todo el tiempo» preseleccionado; la persona puede acotarlo.
Por qué: antes de borrar todo, la copia por defecto tiene que ser todo. Alternativa descartada: exportar sin asistente (`allTransactions`), que cambia el flujo y es decisión de producto (va a mejora).

**D5 · Copy nueva de los bugs** → Solo la de B4 (tres mensajes de error) y el plural de B7, en los 16 idiomas (es-AR con voseo). B2 reutiliza «Cuentas»/«Categorías», que ya existen.

**D6 · Elecciones visuales** → Variantes en el simulador para tres mejoras: exportar en una pantalla (L20-1), activar la nube más corto (L20-11) y reabrir Yala (L20-18). Maqueta local por launch arg, fuera del PR.
