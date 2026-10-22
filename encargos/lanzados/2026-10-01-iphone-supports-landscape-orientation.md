# Carril adaptativo, paso 11 de 13: abrir horizontal en iPhone (opción A ya decidida)

## Contexto
Alternancia Cola A ↔ adaptativo (una sesión Yala a la vez). Acaba de cerrar Cola A con PR #317 en cola de merge a 2.1. Toca el carril adaptativo. Ticket: `tickets/backlog/iphone-supports-landscape-orientation.md`. Léelo entero.

Decisión de producto YA tomada por Jürgen (2026-09-27 noche, post plan PR #285): **opción A** — habilitar horizontal tras la fase 1. La fase 1 (`ipad-sidebar-and-list-detail-for-records-and-planning`) ya está en qa/mergeada. NO preguntes de nuevo A vs B. Jürgen no quiere ser cuello de botella: decide tú los detalles con práctica nativa Apple (size class + ancho del contenedor; APIs de orientación del sistema), sin AskUserQuestion salvo acceso/dispositivo o algo irreversible.

Plan: `docs/exploracion/adaptativo-ipad-duo.md` §7 paso 11. Depende de fase 1 y de large-text (ambas hechas).

## Que se pide
Implementar opción A del ticket:
1. Abrir las orientaciones soportadas en iPhone (y Duo cerrado heredará) de forma coherente con el HIG; no dejar solo Portrait si A está elegida.
2. Pasada por pantallas principales: girar no debe perder registro abierto ni formulario a medias.
3. Capturas antes/después en `YalaLane-Adapt-iPhone-SE` y `YalaLane-Adapt-iPhone-ProMax`, vertical y horizontal, tamaño por defecto y AX5.
4. Layout por size class / ancho del contenedor, nunca por modelo ni por `if` de orientación en la raíz.
5. XCUITest de navegación en horizontal en los dos iPhone, por UDID. Gate verde. PR a 2.1.

## Que NO hay que tocar
- Sync, datos, Cola A, cloud/sesiones.
- Fase Duo (paso 6): necesita Xcode 27.1; no la abras aquí.
- Multiventana real (paso 12) ni widgets grandes (paso 13).
- Simuladores: SOLO `YalaLane-Adapt-*` por UDID (`-destination id=<UDID>`). UDIDs actuales en esta Mini: SE `C248A9E8-BBBE-4370-AF7E-77ADB01A1A07`, ProMax `AACA53D7-DCAE-456A-A779-6BF0D8F9926A`, iPad Pro 13 `A31B3363-C8F4-4F96-8C1F-1772D1140C7E`, iPad mini `91B4E3F8-B14D-478A-8FF5-07DC0D3EFAC1`. Si faltan, recrearlos con la receta §6.2 (runtime instalado). Prohibido `simctl shutdown all`, `erase all`, `killall Simulator` o tocar sims sin ese prefijo. DerivedData propio (`-derivedDataPath .ddp`). Usa `sim-lock.sh` / cola de sims cuando corras XCUITest.

## Como se sabe que esta bien
El «Hecho cuando» del ticket (opción A): capturas SE + ProMax vertical/horizontal a default y AX5 de pantallas principales; girar con registro abierto y formulario a medias no pierde estado; XCUITest horizontal verde por UDID; gate verde; PR mergeado o en cola de auto-merge a 2.1; ticket a qa/done; `docs/TICKETS.md` al día.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1 (auto-merge si el repo lo usa), board (`tickets/` + `docs/TICKETS.md`) y **`/cerrar-total` autónomo al terminar** — nunca dejes la sesión colgada. No mates un cierre si ya arrancó. Es horario diurno: AskUserQuestion solo por acceso, dispositivo o decisión demasiado grave para asumir; el resto (opción A incluida) ya está decidido.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) decisión/acceso de Jürgen; (2) abriste el PR; (3) terminaste y vas a /cerrar-total, resumen corto en lenguaje de usuario; (4) quieta a medias, una vez. NO avises por test rojo que vas a reclasificar ni CI advisory.

## Paso 0 (autónomo, 2026-10-01)

| | Decisión | Por qué |
|---|---|---|
| D1 | iPhone: vertical + horizontal izquierda y derecha; **sin** vertical invertida | Plantilla de Xcode y HIG para iPhone; los iPhone con Face ID no giran boca abajo. iPad sigue con las cuatro |
| D2 | Se abre en los cuatro build settings (Yala Debug/Release, Yala Dev Debug-Dev/Release-Dev) | Una configuración sin abrir saca un build que no gira (`project.pbxproj:553/601/864/911`, medido) |
| D3 | Ningún `if` de orientación ni de modelo; la app ya decide por size class (fase 1) | ADR «por espacio». Solo se toca código si una pantalla girada se rompe o pierde estado |
| D4 | Pantallas principales = Panel, Estadísticas, Planificación, Registros, registro abierto, formulario de nuevo registro, Grupos | Las seis páginas de la barra + los dos estados que pide el ticket |
| D5 | «Antes» = HEAD `10a79d448` (solo vertical); «después» = el PR. Mismo XCUITest temporal de capturas, borrado antes del commit | Receta del paso 10 |
| D6 | XCUITest permanente nuevo `IPhoneLandscapeUITests` (girar y navegar; registro abierto; formulario a medias), corre también en iPad | El estado al girar vale en cualquier ventana |
| D7 | Gate en el simulador del carril (Pro Max) por UDID, no en `iPhone 17 Pro` | Regla del carril §6.2; así lo hizo el paso 10 |
| D8 | Disco: 20 GB al empezar; una sola `.ddp`; al cerrar, `erase` de SE y Pro Max | Memoria: una tanda de capturas cuesta ~12 GB |
