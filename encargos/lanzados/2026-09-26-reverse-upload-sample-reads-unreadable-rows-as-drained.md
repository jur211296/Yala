# Que la vuelta a iCloud no se dé por terminada cuando el muestreo no pudo leer las filas

## Contexto
Ticket `tickets/backlog/reverse-upload-sample-reads-unreadable-rows-as-drained.md` (léelo entero). Cola A de Yala (riesgo real: el usuario cree que sus datos volvieron a iCloud y no es así). `MigrationWorkExecutor.reverseUploadStatus()` calcula `pending = exportPending + noMetadata` e ignora las filas `failed`. Si `CKIdentityCapture.captureResolved` no puede abrir SQLite, no encuentra la tabla de metadata o faltan columnas, marca TODAS las filas `failed`, sale `pending == 0` y la reversa se da por `.drained` (corre el cierre: borra marcador, persiste `.icloud`, `reverse_complete`). El fetch que lanza ya se arregló el 23-sep (`an-incomplete-inventory-reads-as-the-whole-corpus` devuelve `.unreadable`); usa ese mismo camino.

## Qué se pide (decisión ya tomada, no la preguntes)
1. Fallo ESTRUCTURAL del muestreo (SQLite no abre, falta tabla o columnas de metadata, o cualquier caso en el que la captura no pudo mirar ninguna fila) no da `.drained`: da `.unreadable`, que ni cierra la vuelta ni cuenta como avance, y deja actuar al techo/salida que ya existe.
2. Fallos POR FILA (`no-zent`, `zone-fk-missing`…): en esta sesión NO cambian el cálculo (podrían ser benignos y permanentes y la vuelta no drenaría nunca). Añade telemetría/log local de los motivos de `failed` durante una reversa para poder medirlos en device, y crea un ticket nuevo (medium, modo-nube) con el guion de medición en device y la decisión pendiente sobre contarlos.
3. Test con mutante: volver a la suma vieja para el caso estructural pone el test en rojo.

## Qué NO hay que tocar
- El techo de la reversa ni su copy, salvo lo imprescindible para enrutar `.unreadable`.
- `mcp/` (hay otra sesión trabajando ahí), `marketing/`, otros proyectos.

## Cómo se sabe que está bien
- Tests unitarios verdes, incluido el del mutante.
- El caso «captura estructural fallida» no ejecuta el cuarteto de cierre.
- Ticket de medición por fila creado; este ticket movido a qa con guion de device.

## MODO AUTÓNOMO
Queda suspendida la regla del repo de pedir aprobación si se tocan más de 3 ficheros y el «¿Sigo?» tras el plan: implementa de punta a punta sin pedir permiso para continuar, abre PR contra 2.1, mergea cuando esté verde y cierra con `/cerrar-total`, dejando el ticket movido en `tickets/` y `docs/TICKETS.md` actualizado con conteos correctos. Bugs o decisiones nuevas de camino van a ticket propio antes de cerrar. Es horario diurno (06:00–21:00 Lima): puedes usar AskUserQuestion solo para decisiones reales de producto o de acceso; a partir de las 21:00, elige la opción recomendada o aparca en ticket.

## Paso 0

Decisiones (auto-contestadas, MODO AUTÓNOMO):

1. **Qué es «estructural»**: que la captura no pudo leer la metadata de CloudKit de NINGUNA fila. Seis casos:
   el SQLite no abre, no hay tabla de metadata, faltan sus columnas, el mapa `Z_PRIMARYKEY` sale vacío o ilegible,
   ningún identificador de fila se deja resolver, o la consulta de metadata falla en TODAS las filas que la
   intentaron. Lo decide `CKIdentityCapture` (`Report.structuralFailure`), que es quien sabe por qué no miró.
2. **Por fila sigue igual**: `no-zent`, `zone-*`, `uri-unparseable` de una fila suelta y `meta-query` parcial no
   cambian el cálculo. «Todas `no-zent` con el mapa lleno» se queda por fila a propósito: es el caso benigno y
   permanente del que habla el encargo.
3. **Enrutado**: `reverseUploadStatus()` devuelve `.unreadable`, el camino que ya existe (#23-sep). El runner no
   cambia: ni cierra ni avanza, y el techo largo sigue venciendo (test ya existente en `MigrationRunnerTests`).
4. **Medición por fila**: breadcrumb local con los motivos agrupados y canario `canaryOnce` con el conjunto de
   motivos (sin cifras, para que deduplique). Un segundo canario para el estructural. El gateway valida canarios
   por forma: sin despliegue.
5. **Ficheros**: `CKIdentityCapture.swift`, `MigrationWorkExecutor.swift`, `CloudSyncEngine.swift` (breadcrumbs),
   `MetricsService.swift` (canarios), `CKIdentityCaptureTests`, `MigrationWorkExecutorTests`, índice de cobertura,
   la regla de `swiftdata-cloudkit.md`, este ticket a `qa` y uno nuevo para la medición.
