Yala
# Mejoras necesarias 2.3 · Dónde viven tus datos: textos que mandan a otra fila, cifras y texto grande
card: tablero-mejoras-necesarias-2-3-donde-viven-tus-d-s0v6
toca: Yala/App/Views/Settings/,Yala/Resources/
esfuerzo: high

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
FIN
