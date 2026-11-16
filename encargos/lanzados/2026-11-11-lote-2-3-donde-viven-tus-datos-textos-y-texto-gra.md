Yala
# Mejoras necesarias 2.3 · Dónde viven tus datos: textos que mandan a otra fila, cifras y texto grande
card: tablero-mejoras-necesarias-2-3-donde-viven-tus-d-s0v6
toca: Yala/App/Views/Settings/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 11 de 11 de la consolidación final de las revisiones por vistas 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`). Cada punto es un defecto objetivo con evidencia: un bug, un fallo de accesibilidad o un texto que dice algo falso. No se elige ninguna alternativa de rediseño de las revisiones.
Fichas de origen: docs/ux/revision-vistas-2.3/41-nube-almacenamiento/ficha.md (problemas en la tabla; secundarios en `02-revision.html`). PRs de las revisiones: https://github.com/jur211296/Yala/pull/865.

## Encargo y criterio de terminado
Implementar SOLO estos 5 puntos:
1. Con texto grande el estado se aprieta en media columna y el pie fijo de la hoja de activar ocupa casi la mitad de la pantalla (problema 8 de la zona 41; la ficha dice que puede ir sin esperar).
2. El consentimiento manda a «Ajustes → Exportar datos» y esa fila se llama Exportar registros (storage.consent.pointAccess frente a l20d.settings.exportRecords).
3. Salir de mis grupos enseña palabras internas (Salidos, Transferidos, Sin procesar) y «Puedes retomarlo… desde Vaciar datos» manda a una fila distinta de la que se usó (settings.batchLeave*; GroupBatchLeaveView).
4. Las cifras de la subida salen con tres formatos: «650 de 1537», «5,006 cambios» y «1.537» (storage.steps.uploadedCount).
5. La nota de cuenta rechazada se pinta como texto en naranja (warningForeground), que en el tema claro no llega a AA (StorageSettingsView.migrateCard).

Reglas del lote:
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Si un punto exige una decisión de producto, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa.
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Solo textos y maquetación. No toques la lógica de activar, volver, cancelar ni salir de grupos: los cinco puntos de datos de la zona 41 esperan decisión en la card tablero-decidir-cinco-puntos-de-datos-de-la-revi-46yz.
- No elijas los nombres fijos de la zona (T1 o T2): el punto 2 solo hace que el texto nombre la fila que existe hoy.
- Punto 1: solo cambia en tamaños de accesibilidad; a tamaño normal, al píxel. Capturas a tamaño normal y AX3 en iPhone 17 Pro y iPad Pro 13.
- Punto 4: un solo formato de número según el idioma del teléfono; no cambies qué se cuenta.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día. Card a in qa con su guion; el device-QA no bloquea el merge.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones (resueltas en autónomo, bypass, modo nocturno)

- **Base y dependencia.** `origin/2.3` ya tiene el merge de 2.2 (PR #879 y #884). Faltan 16 commits de 2.2 (borradores de Grupos, docs, TestFlight 9): ninguno toca las vistas de la zona 41 (`git log origin/2.3..origin/2.2 -- <vista>` vacío en las cinco). Se sigue.
- **Los cinco puntos siguen vivos en 2.3** (medido en código): tarjeta de estado en `HStack` y pie con `safeAreaInset`; `pointAccess` dice «Exportar datos»; `batchLeaveStat*` y `batchLeaveStoppedBody` con las palabras internas y «Vaciar datos»; tres formatos de cifra; `refusedNote` en `warningForeground`.
- **Punto 1.** Solo con texto de accesibilidad: la tarjeta de estado apila icono encima del texto y la hoja de activar mete sus botones al final del desplazamiento (lo que la ficha llama X1; es el único arreglo objetivo y la ficha dice que puede ir sin esperar). A tamaño normal, el mismo código de antes.
- **Punto 2.** El texto nombra la fila que existe hoy (`l20d.settings.exportRecords`) en los 16 idiomas. No se eligen nombres de la zona (T1/T2).
- **Punto 3.** Las cifras dicen de qué son («Grupos que dejaste», «… que transferiste antes de salir», «… en los que sigues») y «retomarlo» nombra «Salir de todos mis grupos», en Ajustes de Grupos. Sin tocar la lógica de salir.
- **Punto 4.** Un solo formato: el del idioma de la app (`AppLocale`), como ya hacía la subida. Se pasan a él los avisos con cifra de la pantalla (`localizedStringWithFormat` usaba la región; `String(format:)` sin locale no agrupaba), la cifra de la hoja de activar y las del aviso de datos previos al volver (incluidas las del Welcome que esa frase reutiliza). No cambia qué se cuenta. El resto de la app no se toca.
- **Punto 5.** La nota de cuenta rechazada, y su gemela «otra cuenta» (mismo patrón, misma tarjeta), pasan al molde de la pantalla: icono naranja y texto en `.secondary`.
- **Tests.** Unit para 2, 3, 4 y 5 (catálogos fuente de los 16 idiomas, formato con idioma ≠ región, scan de la vista); XCUITest con AX3 para el 1.
- **Sin decisión de producto pendiente.** Nada que preservar con checkpoint nocturno.

## Resultado (2026-11-11, sesión nocturna)

- **Los cinco puntos, hechos.** Cada uno con su test, rojo sobre `origin/2.3` sin el arreglo y verde con él (medido: la base con los tests nuevos dio 6 unit y los 2 XCUITest de AX3 en rojo; sus dos controles a tamaño normal, verdes).
- **Punto 1, al píxel a tamaño normal:** diff de píxeles antes/después en la misma sesión = 0 en la tarjeta de estado y en la hoja, en el iPhone 17 Pro y en el iPad Pro 13.
- **Punto 4, alcance medido:** las cifras de «Dónde viven tus datos» venían de tres sitios (`number()` con el idioma de la app en los pasos; `localizedStringWithFormat` con la región en los avisos de cambios; `String(format:)` sin locale en los datos previos al volver). Todo pasa por `L10n.formatWithAppLocale`, y con él las cinco cifras del Welcome que comparten la frase de los datos previos (sin ellas, la pantalla de restaurar mezclaba formatos).
- **Tests que fijaban lo viejo, actualizados:** `UXAudit22Lote04Tests` (L20-10 ya no exige que «retomarlo» mande a «Vaciar datos»), `MigrationIdentityGateWiringTests`, `UXAudit22Lote20NubeTests`, `WelcomeLote6FixesTests`.
- **Gate:** build Yala y Yala Dev sin warnings nuevos; `YalaTests` entero (13.456 tests, solo cayeron los cuatro de arriba; corregidos y repetidos: 193 en 25 suites, verde); 39 XCUITest en 10 suites verdes; los 20 pasos del CI local verdes.
