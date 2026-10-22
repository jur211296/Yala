# Grupos: la lista quema CPU (VStack no lazy + deudas en cada tecla)

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, merge a 2.1 y /cerrar-total sin preguntar. Solo parar ante decisión/acceso real de Jürgen.

## Contexto
Ticket: `tickets/backlog/groups-tab-missing-panel-perf.md` (high). El freno del Panel ya está; lo que quema ahora es la **lista** de Grupos.

Medido en el ticket (re-medir; coords pueden estar caducadas):
- `GroupsContainerView` usa `VStack` no `LazyVStack` → construye todas las tarjetas.
- Cada fila evalúa `currentUserDebts(for:)` → `calculateDebts` completo (gastos × repartos).
- `searchText` invalida el body y rehace todas las filas a cada tecla.

Cola nocturna Jürgen: bypass. leave-rpc (#75/#76) y Unirme (#74) ya en 2.1. No mezclar pending-member ni kill-switch.

Rama nace desde origin/2.1. Secrets.xcconfig en worktree-enlaces.

## Que se pide
1. Re-medir el hot path de la lista en HEAD actual.
2. Arreglar el coste: lazy stacking y/o no recalcular deudas de todos los grupos en cada tecla / cada body (caché, debounce, o defer de deudas fuera del path de búsqueda — elige lo mínimo medible).
3. No rediseñar UI de tarjetas ni cambiar semántica de deudas; solo perf.
4. Tests o medición antes/después que demuestre la mejora (o el harness más cercano).
5. Ticket → qa/board; PR a 2.1; merge cuando gate verde (UI advisory: contrastar base); /cerrar-total.

## Que NO hay que tocar
- marketing/
- groups-pending-member, kill-switch, leave-rpc (cerrados)
- No inventar PASS de device

## Como se sabe que esta bien
- La lista de Grupos no rehace el trabajo pesado de deudas a cada tecla / con muchos grupos.
- Gate verde; PR mergeado; /cerrar-total con resumen en lenguaje de usuario.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando: (1) decisión de producto/acceso; (2) PR o preview listo; (3) terminaste y /cerrar-total — resumen de qué se hizo; (4) idle mid-ticket una vez. NO avises por test rojo a reclasificar, build a reintentar, ni ruido de setup cp/cd. URL/key solo en la Mini.
