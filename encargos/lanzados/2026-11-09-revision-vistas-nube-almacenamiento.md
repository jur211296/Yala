---
esfuerzo: high
toca: docs/ux/revision-vistas-2.3/41-nube-almacenamiento/
release: no
---

# Revisión por vistas 2.3 · Dónde viven tus datos: nube, iCloud y cierre de sesión (solo comprensión)

## Contexto
Viene de la cola del 7-nov-2026 que Jürgen pausó ese día a las 12:42 Lima; el 9-nov-2026 la confirmó en la nueva cola oficial («las revisiones y la consolidación de revisiones»). Las revisiones por vistas 2.3 de las otras zonas ya están mergeadas en 2.3 (PR #846, #847, #848, #852, #853, #856, #859, #860; revisión del usuario nuevo PR #837). Esta sesión no ve nada más que este encargo.

Rama base: origin/2.3 en jur211296/Yala. Un solo PR de documentación a 2.3 y un solo cierre: termina con `/cerrar-total`. Cierre autónomo (cierra-sola). Commits y PR sin firma de IA. NO cambies código de la app, tests, gateway, auth, producción, marketing/, colas ni sesiones: es revisión y prototipo de UX, sin cambios funcionales ni merge de funcionalidad. Sin publicación pública, hosting nuevo ni compras. Da siempre una descripción corta en español a cada comando Bash. Dudas no vitales: resuélvelas con la opción recomendada y anótalas con alternativas en el cierre; nada de seguridad o producto crítico sin Jürgen. Justo antes del PR: `git fetch` y un solo rebase sobre origin/2.3.

Simuladores: puedes y debes usarlos para capturas actuales con datos ficticios. En la Mini, tope 1; en la Max, tope 2 (puedes abrir un segundo aunque otra sesión de otro proyecto use uno) o el iPhone 14 por DeviceMCP. Build `xcodebuild -jobs 2` sin sim encendido, luego bootear, capturar, apagar y borrar solo lo que encendiste (simuladores, DerivedData propio, temporales). No toques recursos de otras sesiones.

## Qué se pide
### Vistas y estados a revisar (lista cerrada)
StorageSettingsView, iCloudSyncSettingsView, CloudConsentView, CloudProgressStepsView, StorageSignInChooserView, StorageMigrationBlockedView, ReturnToFullYalaView, SignOutRelaunchView, GroupBatchLeaveView (CloudSyncDebugView solo si es visible al usuario).
Caso guía: Entender dónde están mis datos, activar la nube y volver a iCloud, cerrar sesión. Área sensible: SOLO comprensión, textos y jerarquía con maquetas; no actives ni borres datos reales; usa simulador con datos ficticios; ningún cambio de lógica. Lo que sea seguridad o pérdida de datos va a tarjeta para Jürgen, sin proponer atajos.

### Método (igual en todas las revisiones por vistas)
1. Lee el estado actual en origin/2.3 de cada vista listada (lectura focalizada, sin auditoría general) y la revisión del PR 837 (`docs/ux/revision-usuario-nuevo-2026-11/`): reutiliza sus fricciones si aplican a esta zona, sin duplicar la guía visual del usuario nuevo. Lee el mapa de cobertura `/Users/jur/Claude/flota/cobertura-vistas-yala-2.3.md` y revisa SOLO tu zona.
2. Capturas actuales en simulador (iPhone; iPad y texto grande donde aplique) de cada vista y estado: vacío, con datos, cargando, error, sin permisos/sin conexión, según la vista.
3. Revisión adversarial con los siete perfiles SIMULADOS del PR 837 como lentes (no entrevistas): ¿se entiende?, ¿es clara?, terminología, jerarquía, encontrabilidad, carga cognitiva, cantidad de pasos, errores, accesibilidad (VoiceOver, texto grande), iPad.
4. Eficiencia técnica: recomputaciones, cargas, scroll y rendimiento. Separa medido (con cómo se midió) de hipótesis. Ninguna cifra inventada, ningún refactor.
5. Para cada problema prioritario: 3-5 alternativas con MAQUETAS DE PANTALLA de iPhone con el estilo de Yala, distinguibles, con el mismo caso y datos ficticios rotulados; secuencias de 2-4 pantallas si es conducta. Nada de tablas o texto disfrazados de maqueta. Recomendación justificada con tradeoffs; decide Jürgen.
6. Entrega en `docs/ux/revision-vistas-2.3/<tu-subdir>/`: HTML ligero portable (imágenes livianas, sin un único archivo gigante) + PDF VISUAL de respaldo + `ficha.md` corta (vistas cubiertas, problemas, recomendación, decisiones para Jürgen). NO edites ningún índice común.
7. Verifica visualmente el HTML a tamaño teléfono y escritorio en un navegador (Playwright o Chrome) y corrige legibilidad, imágenes y controles.
8. Cierre: rutas absolutas de HTML/PDF, capturas del artefacto probado, link del PR, «Saltado o asumido sin preguntar» y decisiones pendientes. Card a `in qa`.

## Qué NO hay que tocar
- Código de la app, tests, gateway, auth, producción, marketing/, colas ni sesiones: es revisión y prototipo de UX, sin cambios funcionales.
- Ningún índice común de `docs/ux/revision-vistas-2.3/`: solo tu subcarpeta.
- Sin publicación pública, hosting nuevo ni compras; nada de datos reales (solo datos ficticios en simulador).
- Commits y PR sin firma de IA (nada de «Generated with Claude Code», «Co-Authored-By» ni enlaces de sesión).

## Cómo se sabe que está bien
Cada vista listada tiene capturas actuales, problemas priorizados y, para los prioritarios, 3-5 maquetas comparables; HTML+PDF verificados en teléfono y escritorio; un PR de documentación en 2.3; card en in qa; `/cerrar-total`.

## Paso 0
Resuelto por la sesión (modo semi, 9-nov-2026, Max). Lo que no es vital se toma con la opción recomendada.

1. **Base.** La rama nació de `2.2` (263fee878); se rehízo sobre `origin/2.3` antes del primer cambio, como pide el encargo.
2. **Mapa de cobertura.** Vive en la Mini (`/Users/jur/Claude/flota/…`); se leyó por ssh. Zona 41, sin tocarlo.
3. **CloudSyncDebugView.** Solo existe en Yala Dev (`#if DEV_BUILD` en Almacenamiento y en iCloud): no la ve el usuario y queda fuera.
4. **Qué se revisa además.** La hoja «Antes de activar la nube» (`CloudActivationSheet`) y la tarjeta de «reabre Yala» (`RelaunchChecklist`) son la cara real de la activación y del cierre; entran como parte de StorageSettingsView y SignOutRelaunchView. «Tu cuenta de Yala» y Vaciar datos son de la zona 40: solo se citan.
5. **Capturas.** Simuladores propios clonados (iPhone 17 Pro e iPad Pro 13, iOS 27.2), semillas de prueba y ganchos `-uitest-*` que ya existen (progreso, bloqueo, fallo, nube activa, iCloud previo, salir de grupos…). Conductor XCUITest temporal, que no entra en la app: queda como `.txt` en `fuente/`. Texto grande: AX3.
6. **Estados sin gancho** (la tarjeta de «reabre Yala» tras activar o volver, la espera de otro dispositivo, iCloud real sin conexión): se documentan leídos del código y se rotulan así; no se inventa captura.
7. **Nada de datos reales ni de lógica.** Ningún botón que mueva datos se pulsa hasta el final en una cuenta real: todo es simulador con datos ficticios. Lo que sea pérdida de datos o seguridad va a decisión de Jürgen, sin atajos.
8. **Formato.** Molde de la zona 39 (HTML ligero por páginas + `estilo.css` + capturas JPEG + PDF + `ficha.md`) en `docs/ux/revision-vistas-2.3/41-nube-almacenamiento/`. Ningún índice común.
